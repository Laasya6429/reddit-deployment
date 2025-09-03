# Get current Azure subscription
data "azurerm_subscription" "current" {}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}