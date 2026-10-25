output "id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "Use when creating federated credentials for Workload Identity"
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity" {
  value = {
    id           = azurerm_user_assigned_identity.kubelet.id
    client_id    = azurerm_user_assigned_identity.kubelet.client_id
    principal_id = azurerm_user_assigned_identity.kubelet.principal_id
  }
}

output "control_plane_identity" {
  value = {
    id           = azurerm_user_assigned_identity.control_plane.id
    client_id    = azurerm_user_assigned_identity.control_plane.client_id
    principal_id = azurerm_user_assigned_identity.control_plane.principal_id
  }
}

output "node_pool_ids" {
  value = { for k, p in azurerm_kubernetes_cluster_node_pool.this : k => p.id }
}
