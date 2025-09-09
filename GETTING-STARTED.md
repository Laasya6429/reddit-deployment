# Getting Started: Azure DevSecOps Reddit Deployment (Using Existing VM)

Repo: https://github.com/Laasya6429/reddit-deployment

## 0) Clone Repo
```bash
git clone https://github.com/Laasya6429/reddit-deployment.git
cd reddit-deployment
```

## 1) Terraform Remote State (once)
```bash
az login
az account set --subscription 34856a35-fa4e-4dd9-93cd-ebb259a44e98
az group create -n terraform-state-rg -l "East US"
az storage account create -g terraform-state-rg -n redditterraformstate --sku Standard_LRS --encryption-services blob
az storage container create --account-name redditterraformstate -n tfstate
```

## 2) VM Prep
- Start VM (if stopped) and open NSG ports 22, 8080, 9000, 80, 443
```bash
az vm start -g project -n project-1
```

## 3) Install Jenkins & Tools on VM
```bash
ssh <username>@4.145.112.123
sudo su -
apt update -y
curl -fsSL https://raw.githubusercontent.com/Laasya6429/reddit-deployment/main/Jenkins-server-TF/tools-install.sh -o /tmp/tools-install.sh
chmod +x /tmp/tools-install.sh
sed -i "s/azureuser/<username>/g" /tmp/tools-install.sh
bash /tmp/tools-install.sh
```
Verify:
```bash
systemctl status jenkins && docker version && az version && kubectl version --client && terraform version
```

## 4) Jenkins Setup (Browser)
- Open: http://4.145.112.123:8080
- Initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
- Install suggested plugins
- Tools (Manage Jenkins → Global Tool Configuration): `jdk`, `nodejs`, `sonar-scanner`
- Credentials: `githubcred` (GitHub PAT)

## 5) Provision AKS + ACR (Terraform)
```bash
cd AKS-TF
terraform init
terraform apply -var-file=variables.tfvars -auto-approve
```
Outputs → use them later:
```bash
terraform output -raw resource_group_name
terraform output -raw aks_cluster_name
terraform output -raw acr_login_server
terraform output -raw acr_username
terraform output -raw acr_password
```
Create Jenkins cred `azure-acr-credentials` with ACR username/password.
Configure kubectl on your machine:
```bash
az aks get-credentials -g <resource_group_name> -n <aks_cluster_name> --overwrite-existing
```

## 6) Reddit App Pipeline (Jenkins)
- New Item → Pipeline → from SCM
  - Repo: https://github.com/Laasya6429/reddit-deployment.git
  - Script path: `Jenkins-Pipeline-Code/Jenkinsfile-Reddit`
  - Parameter: `ACR_LOGIN_SERVER = <acr_login_server>` (e.g., myacr.azurecr.io)
- Run build → image pushed to ACR → manifest updated & committed

## 7) ArgoCD Install & App (AKS)
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Create app in ArgoCD (UI → New App → Edit YAML):
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

## 8) Verify
```bash
kubectl get pods,svc,ingress -n default
```
Access via Service/Ingress endpoint.

## 9) Optional: Monitoring
```bash
kubectl create namespace monitoring
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/
kubectl -n monitoring port-forward svc/grafana 3000:3000
```
Grafana: http://localhost:3000 (admin/admin), Prometheus datasource: `http://prometheus-k8s.monitoring.svc:9090`

---
For detailed guidance, see `RUNBOOK-Existing-VM-Setup.md` and `RUNBOOK-DevSecOps-Azure.md`. 