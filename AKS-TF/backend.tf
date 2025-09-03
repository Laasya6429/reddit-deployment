terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "redditterraformstate"
    container_name       = "tfstate"
    key                  = "End-to-End-Kubernetes-DevSecOps-Tetris-Project/AKS-TF/terraform.tfstate"
  }
  required_version = ">=0.13.0"
  required_providers {
    azurerm = {
      version = ">= 3.0.0"
      source  = "hashicorp/azurerm"
    }
  }
} 