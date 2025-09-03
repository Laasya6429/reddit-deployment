terraform {
  required_version = ">=0.13.0"
  required_providers {
    azurerm = {
      version = ">= 3.0.0"
      source  = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
} 