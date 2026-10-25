output "cluster_name" {
  value = module.aks.name
}

output "cluster_id" {
  value = module.aks.id
}

output "resource_group_name" {
  value = data.azurerm_resource_group.aks.name
}

output "node_resource_group" {
  value = module.aks.node_resource_group
}

output "oidc_issuer_url" {
  description = "Use when creating federated credentials for Workload Identity"
  value       = module.aks.oidc_issuer_url
}

output "control_plane_principal_id" {
  description = "Send to the DNS team (Private DNS Zone Contributor on the hub zone) and, if they grant it, the network team (Network Contributor on the VNet)"
  value       = module.aks.control_plane_identity.principal_id
}

output "kubelet_identity_object_id" {
  value = module.aks.kubelet_identity.principal_id
}

output "get_credentials_command" {
  value = "az aks get-credentials -g ${data.azurerm_resource_group.aks.name} -n ${module.aks.name} && kubelogin convert-kubeconfig -l azurecli"
}

output "external_secrets" {
  description = "Values for the ESO Helm chart and ClusterSecretStore (cuber-ai-platform repo)"
  value = {
    client_id     = azurerm_user_assigned_identity.external_secrets.client_id
    tenant_id     = azurerm_user_assigned_identity.external_secrets.tenant_id
    key_vault_url = local.shared.key_vault_uri
  }
}
