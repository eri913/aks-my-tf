# External Secrets Operator (ESO) → Azure Key Vault via Workload Identity.
# Terraform owns the Azure side only. ESO itself (Helm chart, ClusterSecretStore) is deployed by GitOps
# from the cuber-ai-platform repo — the API server is private, so Terraform doesn't talk to it.

resource "azurerm_user_assigned_identity" "external_secrets" {
  name                = "id-${var.cluster_name}-external-secrets"
  location            = data.azurerm_resource_group.aks.location
  resource_group_name = data.azurerm_resource_group.aks.name
  tags                = var.tags
}

# Trust tokens issued by this cluster for ESO's service account — no client secret anywhere
resource "azurerm_federated_identity_credential" "external_secrets" {
  name                      = "fic-${var.cluster_name}-external-secrets"
  user_assigned_identity_id = azurerm_user_assigned_identity.external_secrets.id
  issuer                    = module.aks.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.external_secrets.namespace}:${var.external_secrets.service_account}"
  audience                  = ["api://AzureADTokenExchange"]
}

# Key Vault uses RBAC authorization (200-shared). Secrets User = read secret values only.
resource "azurerm_role_assignment" "external_secrets_key_vault" {
  scope                = local.shared.key_vault_id
  role_definition_name = var.external_secrets.key_vault_role
  principal_id         = azurerm_user_assigned_identity.external_secrets.principal_id
}
