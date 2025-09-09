terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "redditterraformstate"
    container_name       = "tfstate"
    key                  = "End-to-End-Kubernetes-DevSecOps-Tetris-Project/AKS-TF/terraform.tfstate"
  }
} 