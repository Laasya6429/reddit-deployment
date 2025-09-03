# 🚀 DevSecOps: Deploy Reddit App to Azure Kubernetes Service (AKS) using ArgoCD

## 📋 Project Overview

This project demonstrates a complete DevSecOps pipeline for deploying a Reddit application to Azure Kubernetes Service (AKS) using ArgoCD for GitOps continuous delivery. The project includes comprehensive security scanning, code quality analysis, and monitoring capabilities.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   Jenkins CI    │    │   Azure ACR     │
│                 │    │                 │    │                 │
│  Reddit App     │───▶│  Build & Test   │───▶│  Container      │
│  Source Code    │    │  Security Scan  │    │  Registry       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ArgoCD        │    │   Azure AKS     │    ┌   Prometheus    │
│   GitOps        │    │   Kubernetes    │    │   + Grafana     │
│   Controller    │───▶│   Cluster       │───▶│   Monitoring    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Technology Stack

### Cloud Platform
- **Azure**
  - Azure Virtual Machines
  - Azure Kubernetes Service (AKS)
  - Azure Container Registry (ACR)
  - Azure Virtual Network
  - Azure Storage (for Terraform state)

### DevOps Tools
- **Jenkins** - CI/CD Pipeline
- **ArgoCD** - GitOps Continuous Delivery
- **Terraform** - Infrastructure as Code
- **Docker** - Containerization

### Security & Quality
- **SonarQube** - Code Quality Analysis
- **Trivy** - Security Vulnerability Scanner
- **OWASP Dependency Check** - Dependency Vulnerability Scanner

### Monitoring & Observability
- **Prometheus** - Metrics Collection
- **Grafana** - Visualization & Dashboards

## 🚀 Prerequisites

### Azure Requirements
1. **Azure Subscription** with sufficient credits
2. **Azure CLI** installed and configured
3. **Service Principal** with appropriate permissions

### Local Requirements
1. **Terraform** >= 0.13.0
2. **Docker** Desktop
3. **Kubectl** CLI tool
4. **Git** for version control

## 📁 Project Structure

```
Reddit-Project/
├── Jenkins-server-TF/          # Azure VM for Jenkins
├── AKS-TF/                     # Azure Kubernetes Service
├── K8s/                        # Kubernetes Manifests
├── Jenkins-Pipeline-Code/      # Jenkins Pipeline Definitions
├── src/                        # Reddit Application Source
├── functions/                  # Firebase Functions
└── README-Azure-Migration.md   # This file
```

## 🔧 Setup Instructions

### Step 1: Azure Infrastructure Setup

#### 1.1 Create Azure Storage for Terraform State
```bash
# Create Resource Group for Terraform state
az group create --name terraform-state-rg --location "East US"

# Create Storage Account
az storage account create \
  --resource-group terraform-state-rg \
  --name redditterraformstate \
  --sku Standard_LRS \
  --encryption-services blob

# Create Blob Container
az storage container create \
  --name tfstate \
  --account-name redditterraformstate
```

#### 1.2 Create Azure Service Principal
```bash
# Create Service Principal
az ad sp create-for-rbac \
  --name "Reddit-Project-SP" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}

# Note down the output for Jenkins credentials
```

### Step 2: Deploy Jenkins Server

#### 2.1 Initialize Terraform
```bash
cd Jenkins-server-TF
terraform init
```

#### 2.2 Configure Variables
Update `variables.tfvars` with your Azure details:
```hcl
resource-group-name = "Reddit-Project-RG"
location           = "East US"
admin-username     = "azureuser"
admin-password     = "YourSecurePassword123!"
vm-size            = "Standard_D8s_v3"
```

#### 2.3 Deploy Infrastructure
```bash
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars
```

#### 2.4 Access Jenkins
```bash
# Get Jenkins public IP
terraform output jenkins_url

# SSH to the server
terraform output ssh_command

# Get Jenkins initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Step 3: Deploy AKS Cluster

#### 3.1 Initialize AKS Terraform
```bash
cd AKS-TF
terraform init
```

#### 3.2 Deploy AKS
```bash
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars
```

#### 3.3 Configure kubectl
```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group Reddit-Project-RG \
  --name Reddit-AKS-Cluster
```

### Step 4: Install ArgoCD

#### 4.1 Create ArgoCD Namespace
```bash
kubectl create namespace argocd
```

#### 4.2 Install ArgoCD
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
```

#### 4.3 Expose ArgoCD Server
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

#### 4.4 Get ArgoCD Access Details
```bash
# Get ArgoCD server URL
kubectl get svc argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 5: Configure Jenkins

#### 5.1 Install Required Plugins
- Eclipse Temurin Installer
- SonarQube Scanner
- NodeJs Plugin
- Docker Plugins
- OWASP Dependency Check
- Terraform
- Azure Credentials
- Prometheus Metrics Plugin

#### 5.2 Configure Credentials
Create the following credentials in Jenkins:

1. **Azure Service Principal**
   - Kind: Azure Service Principal
   - ID: azure-sp
   - Subscription ID: Your subscription ID
   - Client ID: Your service principal client ID
   - Client Secret: Your service principal secret
   - Tenant ID: Your tenant ID

2. **GitHub Token**
   - Kind: Secret text
   - ID: githubcred
   - Secret: Your GitHub personal access token

3. **Azure Container Registry**
   - Kind: Username with password
   - ID: azure-acr-credentials
   - Username: ACR username
   - Password: ACR password

#### 5.3 Create Jenkins Pipelines

1. **AKS Infrastructure Pipeline**
   - Name: AKS-Terraform-Pipeline
   - Pipeline script from SCM
   - Repository: Your GitHub repo
   - Script path: Jenkins-Pipeline-Code/Jenkinsfile-AKS-Terraform

2. **Reddit Application Pipeline**
   - Name: Reddit-App-Pipeline
   - Pipeline script from SCM
   - Repository: Your GitHub repo
   - Script path: Jenkins-Pipeline-Code/Jenkinsfile-Reddit

### Step 6: Deploy Reddit Application

#### 6.1 Build and Push Application
1. Run the Reddit-App-Pipeline
2. Monitor the build process
3. Verify image is pushed to Azure Container Registry

#### 6.2 Create ArgoCD Application
1. Access ArgoCD console
2. Click "Create App"
3. Configure application:

```yaml
project: default
source:
  repoURL: 'https://github.com/yourusername/Reddit-Project.git'
  path: K8s/
  targetRevision: HEAD
destination:
  server: 'https://kubernetes.default.svc'
  namespace: default
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

### Step 7: Setup Monitoring

#### 7.1 Deploy Prometheus and Grafana
```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/

# Deploy Grafana
kubectl apply -f https://raw.githubusercontent.com/grafana/helm-charts/main/charts/grafana/templates/
```

#### 7.2 Access Grafana
```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Access at http://localhost:3000
# Default credentials: admin/admin
```

## 🔒 Security Features

### 1. Code Quality Analysis
- **SonarQube**: Static code analysis for quality gates
- **Code coverage**: Ensures minimum test coverage

### 2. Security Scanning
- **Trivy**: Container image vulnerability scanning
- **OWASP Dependency Check**: Dependency vulnerability analysis
- **SAST**: Static Application Security Testing

### 3. Infrastructure Security
- **Network Security Groups**: Restrict network access
- **Azure RBAC**: Role-based access control
- **Managed Identities**: Secure service-to-service authentication

## 📊 Monitoring & Observability

### 1. Application Metrics
- **Response times**: Track API performance
- **Error rates**: Monitor application health
- **Throughput**: Measure application capacity

### 2. Infrastructure Metrics
- **CPU/Memory usage**: Node resource utilization
- **Network I/O**: Network performance
- **Storage metrics**: Disk usage and performance

### 3. Custom Dashboards
- **Application Overview**: High-level application metrics
- **Infrastructure Health**: Cluster and node status
- **Security Alerts**: Vulnerability and security events

## 🚨 Troubleshooting

### Common Issues

#### 1. Terraform State Lock
```bash
# If state is locked, force unlock
terraform force-unlock <lock-id>
```

#### 2. AKS Node Pool Issues
```bash
# Check node status
kubectl get nodes

# Check node pool health
az aks show --resource-group Reddit-Project-RG --name Reddit-AKS-Cluster
```

#### 3. ArgoCD Sync Issues
```bash
# Check application status
kubectl get applications -n argocd

# Check sync status
kubectl describe application reddit-app -n argocd
```

#### 4. Jenkins Pipeline Failures
- Check Jenkins logs
- Verify Azure credentials
- Ensure required plugins are installed

## 🔄 CI/CD Pipeline Flow

1. **Code Commit**: Developer pushes code to GitHub
2. **Jenkins Trigger**: Jenkins automatically detects changes
3. **Security Scan**: Trivy and OWASP scans run
4. **Quality Gate**: SonarQube analysis ensures code quality
5. **Build & Test**: Application is built and tested
6. **Container Build**: Docker image is created
7. **Security Scan**: Container image is scanned for vulnerabilities
8. **Push to ACR**: Image is pushed to Azure Container Registry
9. **Update Deployment**: Kubernetes manifests are updated
10. **ArgoCD Sync**: ArgoCD automatically deploys to AKS
11. **Monitoring**: Prometheus and Grafana monitor the deployment

## 📈 Best Practices

### 1. Security
- Regular security updates and patches
- Implement least privilege access
- Use managed identities where possible
- Regular vulnerability scanning

### 2. Monitoring
- Set up alerting for critical metrics
- Use log aggregation (Azure Monitor)
- Implement distributed tracing
- Regular capacity planning

### 3. DevOps
- Infrastructure as Code (Terraform)
- GitOps workflow with ArgoCD
- Automated testing and deployment
- Blue-green or canary deployments

## 🎯 Interview Preparation

### Key Points to Highlight

1. **Azure-native Implementation**
2. **DevSecOps**: Integrated security throughout the pipeline
3. **GitOps Workflow**: ArgoCD for declarative deployments
4. **Infrastructure as Code**: Terraform for reproducible infrastructure
5. **Monitoring & Observability**: Comprehensive monitoring stack
6. **Security Scanning**: Multiple layers of security validation
7. **Automation**: End-to-end automated deployment pipeline

### Technical Questions to Prepare For

1. **Why choose Azure?**
   - Cost optimization
   - Integration with Microsoft ecosystem
   - Compliance requirements
   - Team expertise

2. **How do you ensure security in the pipeline?**
   - Multiple scanning tools
   - Quality gates
   - Automated security checks
   - Regular updates

3. **Explain the GitOps workflow**
   - Declarative configuration
   - Git as source of truth
   - Automated synchronization
   - Rollback capabilities

4. **How do you handle monitoring and alerting?**
   - Prometheus metrics collection
   - Grafana dashboards
   - Alerting rules
   - Incident response

## 📚 Additional Resources

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Jenkins Azure Plugin](https://plugins.jenkins.io/azure-credentials/)
- [Prometheus Operator](https://prometheus-operator.dev/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy Deploying! 🚀✨** 