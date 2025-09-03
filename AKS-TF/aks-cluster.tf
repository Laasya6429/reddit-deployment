# Create AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster-name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns-prefix
  kubernetes_version  = "1.28.0"

  default_node_pool {
    name       = "default"
    node_count = var.node-count
    vm_size    = var.vm-size
    vnet_subnet_id = azurerm_subnet.subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = {
    Name = var.cluster-name
  }
}

# Get AKS credentials
data "azurerm_kubernetes_cluster" "aks" {
  name                = azurerm_kubernetes_cluster.aks.name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_kubernetes_cluster.aks]
} 