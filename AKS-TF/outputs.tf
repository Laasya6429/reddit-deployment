output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_cluster_kube_config" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "aks_cluster_host" {
  description = "Host of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config.0.host
}

output "aks_cluster_client_certificate" {
  description = "Client certificate for the AKS cluster"
  value       = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  sensitive   = true
}

output "aks_cluster_client_key" {
  description = "Client key for the AKS cluster"
  value       = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  sensitive   = true
}

output "aks_cluster_cluster_ca_certificate" {
  description = "Cluster CA certificate for the AKS cluster"
  value       = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  sensitive   = true
} 