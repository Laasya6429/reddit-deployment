# Runbook: Using an Existing Azure VM for Jenkins (DevSecOps on Azure)

This guide assumes you already have a VM created and will use it to host Jenkins and tooling for the Azure DevSecOps pipeline.

Example VM (replace values with your own):
- Resource group: `project`
- VM name: `project-1`
- Location: `Southeast Asia (Zone 1)`
- Public IP: `4.145.112.123`
- OS: `Ubuntu 24.04 LTS`
- Size: `Standard B4as v2`
- VNet/Subnet: `vnet-southeastasia/snet-southeastasia-1`
- Admin username: `<username>`

Repository: https://github.com/Laasya6429/reddit-deployment

---

## 1) Start VM and Open Required Ports

Start the VM if stopped:
```bash
az vm start -g project -n project-1
```
Open inbound ports in the VM's Network Security Group (NSG):
- TCP 22 (SSH)
- TCP 8080 (Jenkins)
- TCP 9000 (SonarQube)
- TCP 80/443 (optional for HTTP/HTTPS)

Azure Portal → VM → Networking → Inbound rules → Add the above.

---

## 2) SSH into the VM
```bash
ssh <username>@4.145.112.123
```
Replace `<username>` with your VM admin username.

---

## 3) Install Jenkins, Docker, Terraform, kubectl, Azure CLI
Run the project’s installer (tuned for Ubuntu 22.04/24.04). Replace `azureuser` token before running if your username differs.
```bash
sudo su -
apt update -y
curl -fsSL https://raw.githubusercontent.com/Laasya6429/reddit-deployment/main/Jenkins-server-TF/tools-install.sh -o /tmp/tools-install.sh
chmod +x /tmp/tools-install.sh
sed -i "s/azureuser/<username>/g" /tmp/tools-install.sh
bash /tmp/tools-install.sh
```
Verify services/tools:
```bash
systemctl status jenkins
docker version
az version
kubectl version --client
terraform version
```

---

## 4) Access Jenkins and Initial Setup
- Browser: `http://4.145.112.123:8080`
- Get initial admin password on VM:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
- Complete setup wizard; install suggested plugins.

---

## 5) Configure Jenkins
- Install plugins: Eclipse Temurin Installer, SonarQube Scanner, NodeJS, Docker, OWASP Dependency-Check, Terraform, Azure Credentials, Prometheus Metrics
- Tools (Manage Jenkins → Global Tool Configuration):
  - JDK 17 (name: `jdk`)
  - NodeJS (name: `nodejs`)
  - Sonar Scanner (name: `sonar-scanner`)
- Credentials (Manage Jenkins → Credentials → Global):
  - GitHub token (ID: `githubcred`)
  - ACR credentials (ID: `azure-acr-credentials`) → create after ACR exists (step 6)

---

## 6) Provision AKS + ACR (from admin box or your laptop)
From your workstation where Azure CLI and Terraform are installed:
```bash
cd AKS-TF
terraform init
terraform apply -var-file=variables.tfvars -auto-approve
```
Capture outputs:
```bash
terraform output -raw resource_group_name
terraform output -raw aks_cluster_name
terraform output -raw acr_login_server
terraform output -raw acr_username
terraform output -raw acr_password
```
Create Jenkins credential `azure-acr-credentials` using `acr_username`/`acr_password`.
Configure kubectl locally:
```bash
az aks get-credentials -g <resource_group_name> -n <aks_cluster_name> --overwrite-existing
```

---

## 7) Create Reddit App Pipeline (Jenkins)
- New Item → Pipeline
- Pipeline from SCM:
  - Repo: `https://github.com/Laasya6429/reddit-deployment.git`
  - Script path: `Jenkins-Pipeline-Code/Jenkinsfile-Reddit`
- Build parameter:
  - `ACR_LOGIN_SERVER = <acr_login_server>` (e.g., `myacr.azurecr.io`)
- Run the build. It will:
  - install deps → SonarQube → OWASP → Trivy
  - docker build/push to ACR (`<acr>/reddit:<BUILD_NUMBER>`)
  - update `K8s/deployment.yml` with new image tag and commit to repo

---

## 8) Install ArgoCD on AKS (GitOps)
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
# Admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Open ArgoCD (LB IP), login as `admin`.

Create the application (UI → New App → Edit YAML):
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
Sync the application.

---

## 9) Verify App and Expose
```bash
kubectl get pods,svc,ingress -n default
```
If needed, ensure `K8s/service.yml` and `K8s/ingress.yml` (or root `service.yml`/`ingress.yml`) exist and are applied by ArgoCD.

---

## 10) Monitoring (Prometheus + Grafana)
```bash
kubectl create namespace monitoring
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/
# Quick Grafana access
kubectl -n monitoring port-forward svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)
# Add Prometheus datasource: http://prometheus-k8s.monitoring.svc:9090
```

---

## 11) Day-2 Operations
- Rollback: revert latest Git commit → ArgoCD re-syncs to previous state
- Scale: change `spec.replicas` in `K8s/deployment.yml` → commit
- New release: trigger Jenkins pipeline (new image pushed + manifest updated)

---

## 12) Troubleshooting Quick Commands
```bash
# Kubernetes status
kubectl get nodes -o wide
kubectl get pods -A

# ArgoCD health
kubectl get applications -n argocd
kubectl describe application <app> -n argocd

# Jenkins logs
# Use Jenkins UI → Build Console Output
```

---

This runbook leverages your existing VM to host Jenkins and completes the Azure-native DevSecOps flow: Jenkins CI → Security Scans → ACR push → ArgoCD GitOps → AKS → Monitoring. 