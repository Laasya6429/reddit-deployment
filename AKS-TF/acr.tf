# Create Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "redditacr${random_string.acr_suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Generate random suffix for ACR name
resource "random_string" "acr_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Output ACR details
output "acr_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_username" {
  description = "Azure Container Registry username"
  value       = azurerm_container_registry.acr.admin_username
}

output "acr_password" {
  description = "Azure Container Registry password"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
} 