#!/bin/bash

# 🚀 Azure DevSecOps Reddit Project Deployment Script
# This script automates the deployment of the Reddit application to Azure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        print_status "Installation guide: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        print_status "Installation guide: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        print_status "Installation guide: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    
    print_success "All prerequisites are met!"
}

# Azure login
azure_login() {
    print_status "Logging into Azure..."
    
    if ! az account show &> /dev/null; then
        print_status "Please log in to Azure..."
        az login
    else
        print_success "Already logged into Azure"
    fi
    
    # Get current subscription
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
    print_success "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
}

# Create resource group for Terraform state
create_terraform_state() {
    print_status "Creating Azure Storage for Terraform state..."
    
    # Create resource group
    az group create \
        --name terraform-state-rg \
        --location "East US" \
        --output none
    
    # Create storage account
    az storage account create \
        --resource-group terraform-state-rg \
        --name redditterraformstate \
        --sku Standard_LRS \
        --encryption-services blob \
        --output none
    
    # Create blob container
    az storage container create \
        --name tfstate \
        --account-name redditterraformstate \
        --output none
    
    print_success "Terraform state storage created successfully!"
}

# Create service principal
create_service_principal() {
    print_status "Creating Azure Service Principal..."
    
    SP_OUTPUT=$(az ad sp create-for-rbac \
        --name "Reddit-Project-SP" \
        --role contributor \
        --scopes "/subscriptions/$SUBSCRIPTION_ID" \
        --output json)
    
    # Extract values
    CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.appId')
    CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r '.password')
    TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenant')
    
    print_success "Service Principal created successfully!"
    print_warning "Please save these credentials for Jenkins configuration:"
    echo "Client ID: $CLIENT_ID"
    echo "Client Secret: $CLIENT_SECRET"
    echo "Tenant ID: $TENANT_ID"
    echo "Subscription ID: $SUBSCRIPTION_ID"
}

# Deploy Jenkins server
deploy_jenkins() {
    print_status "Deploying Jenkins server..."
    
    cd Jenkins-server-TF
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -var-file=variables.tfvars
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    terraform apply -var-file=variables.tfvars -auto-approve
    
    # Get outputs
    JENKINS_IP=$(terraform output -raw vm_public_ip)
    JENKINS_URL=$(terraform output -raw jenkins_url)
    
    print_success "Jenkins server deployed successfully!"
    print_status "Jenkins URL: $JENKINS_URL"
    print_status "SSH Command: ssh azureuser@$JENKINS_IP"
    
    cd ..
}

# Deploy AKS cluster
deploy_aks() {
    print_status "Deploying AKS cluster..."
    
    cd AKS-TF
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning Terraform deployment..."
    terraform plan -var-file=variables.tfvars
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    terraform apply -var-file=variables.tfvars -auto-approve
    
    # Get outputs
    AKS_NAME=$(terraform output -raw aks_cluster_name)
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    
    print_success "AKS cluster deployed successfully!"
    print_status "Cluster Name: $AKS_NAME"
    print_status "Resource Group: $RESOURCE_GROUP"
    
    # Get AKS credentials
    print_status "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group $RESOURCE_GROUP \
        --name $AKS_NAME \
        --overwrite-existing
    
    print_success "AKS credentials configured!"
    
    cd ..
}

# Install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Expose ArgoCD server
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
    
    # Wait for external IP
    print_status "Waiting for ArgoCD external IP..."
    while [ -z "$ARGOCD_IP" ]; do
        ARGOCD_IP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -z "$ARGOCD_IP" ]; then
            sleep 10
        fi
    done
    
    # Get ArgoCD password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    print_success "ArgoCD installed successfully!"
    print_status "ArgoCD URL: http://$ARGOCD_IP:8080"
    print_status "Username: admin"
    print_status "Password: $ARGOCD_PASSWORD"
}

# Deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Prometheus Operator
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/
    kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/
    
    print_success "Monitoring stack deployed successfully!"
}

# Main deployment function
main() {
    print_status "Starting Azure DevSecOps Reddit Project deployment..."
    
    # Check prerequisites
    check_prerequisites
    
    # Azure login
    azure_login
    
    # Create Terraform state storage
    create_terraform_state
    
    # Create service principal
    create_service_principal
    
    # Deploy Jenkins server
    deploy_jenkins
    
    # Deploy AKS cluster
    deploy_aks
    
    # Install ArgoCD
    install_argocd
    
    # Deploy monitoring
    deploy_monitoring
    
    print_success "🎉 Deployment completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Access Jenkins at: http://$JENKINS_IP:8080"
    print_status "2. Access ArgoCD at: http://$ARGOCD_IP:8080"
    print_status "3. Configure Jenkins credentials with the service principal details above"
    print_status "4. Create Jenkins pipelines for AKS and Reddit application"
    print_status "5. Deploy the Reddit application via ArgoCD"
    print_status ""
    print_status "Happy Deploying! 🚀✨"
}

# Run main function
main "$@" 