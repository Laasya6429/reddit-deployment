# DevSecOps on Azure: End-to-End Runbook

Repository: https://github.com/Laasya6429/reddit-deployment

## 1) Prerequisites (local/admin box)
- Install: Azure CLI, Terraform, kubectl, Docker
- Login to Azure and select subscription:
```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

## 2) Prepare Terraform Remote State (once)
```bash
az group create -n terraform-state-rg -l "East US"
az storage account create -g terraform-state-rg -n redditterraformstate --sku Standard_LRS --encryption-services blob
az storage container create --account-name redditterraformstate -n tfstate
```

## 3) Provision Jenkins on Azure VM
```bash
cd Jenkins-server-TF
# Update variables.tfvars if needed (resource-group-name, location, admin-username/password, vm-size)
terraform init
terraform apply -var-file=variables.tfvars -auto-approve
```
Outputs to note:
```bash
terraform output jenkins_url
terraform output ssh_command
```
Open Jenkins URL and finish initial setup (get initial admin password from VM if prompted).

## 4) Configure Jenkins
- Plugins: Eclipse Temurin Installer, SonarQube Scanner, NodeJS, Docker plugins, OWASP Dependency Check, Terraform, Azure Credentials, Prometheus Metrics
- Tools (Manage Jenkins → Global Tool Configuration):
  - JDK 17 (name: jdk)
  - NodeJS (e.g., 18+, name: nodejs)
  - Sonar Scanner (name: sonar-scanner)
- Credentials:
  - GitHub token (ID: githubcred)
  - ACR credentials (ID: azure-acr-credentials) → will be created after AKS/ACR provisioning below

## 5) Provision AKS + ACR
```bash
cd ../AKS-TF
# Update variables.tfvars if needed (resource-group-name, location, cluster-name, vm-size, etc.)
terraform init
terraform apply -var-file=variables.tfvars -auto-approve
```
Get outputs and create Jenkins credentials:
```bash
terraform output -raw resource_group_name
terraform output -raw aks_cluster_name
terraform output -raw acr_login_server
terraform output -raw acr_username
terraform output -raw acr_password
```
Create Jenkins credential `azure-acr-credentials` (username/password = acr_username/acr_password).
Configure kubectl:
```bash
az aks get-credentials -g <RESOURCE_GROUP> -n <AKS_CLUSTER_NAME> --overwrite-existing
```

## 6) Create Jenkins Pipelines
- Pipeline: Reddit App
  - Type: Pipeline script from SCM → this repo
  - Script path: `Jenkins-Pipeline-Code/Jenkinsfile-Reddit`
  - Build parameter: `ACR_LOGIN_SERVER = <acr_login_server>` (e.g., myacr.azurecr.io)
  - On run it will: install deps → SonarQube → OWASP → Trivy → docker build/push to ACR → update `K8s/deployment.yml` → commit to repo → ArgoCD deploys

(Optional) Pipeline: AKS Terraform
- Script path: `Jenkins-Pipeline-Code/Jenkinsfile-AKS-Terraform`
- Params: `File-Name=variables.tfvars`, `Terraform-Action=apply`

## 7) Install ArgoCD (GitOps)
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Open ArgoCD UI (LB address), login as `admin`.

## 8) Create ArgoCD Application
In ArgoCD UI → New App → Edit YAML:
```yaml
project: default
source:
  repoURL: 'https://github.com/Laasya6429/reddit-deployment.git'
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
Sync the app.

## 9) Expose and Verify the App
- Ensure `K8s/service.yml` and `K8s/ingress.yml` (or root `service.yml`/`ingress.yml`) are applied by ArgoCD.
- Validate:
```bash
kubectl get pods,svc,ingress -n default
```
Access via the Service/Ingress endpoint.

## 10) Monitoring (Prometheus + Grafana)
```bash
kubectl create namespace monitoring
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/
# Quick access to Grafana
kubectl -n monitoring port-forward svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin) and add Prometheus datasource: http://prometheus-k8s.monitoring.svc:9090
```

## 11) Day-2 Ops
- Revert/roll back: revert last commit in repo → ArgoCD auto-rolls back
- Scale app: edit `K8s/deployment.yml` replicas → commit → ArgoCD syncs
- Rotate image: re-run Jenkins build to push new tag; pipeline auto-updates manifest

## 12) Security Checks Included
- SonarQube Quality Gate
- OWASP Dependency Check
- Trivy (filesystem + image scan)

## 13) Common Troubleshooting
```bash
# Cluster status
kubectl get nodes -o wide
kubectl get pods -A

# ArgoCD app status
kubectl get applications -n argocd
kubectl describe application <app> -n argocd

# Jenkins agent logs
# Use Jenkins UI → Build Console Output
```

## 14) Credentials Summary
- GitHub: `githubcred` (secret text)
- ACR: `azure-acr-credentials` (username/password)
- (Optional) Azure SP: `azure-sp` if needed by any pipeline stage

---
This runbook sets up CI (Jenkins) → Security Scans → Container Build/Push (ACR) → GitOps Deploy (ArgoCD→AKS) → Monitoring (Prometheus/Grafana). 