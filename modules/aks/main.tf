resource "azurerm_resource_group" "aks" {
  name     = "rg-cuberai-aks-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Unset (null) root variables fall back to the module defaults.
module "aks" {
  source = "../modules/aks"

  # Placement
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  node_resource_group = coalesce(var.node_resource_group, "rg-cuberai-aks-${var.environment}-nodes")
  dns_prefix          = var.dns_prefix
  tags                = var.tags

  # Cluster
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel
  node_provisioning_mode    = var.node_provisioning_mode

  # API server access
  private_cluster_enabled             = var.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled
  private_dns_zone_id                 = coalesce(var.private_dns_zone_id, local.network.private_dns_zone_ids["aks"])
  api_authorized_ip_ranges            = var.api_authorized_ip_ranges

  # Identity & auth
  admin_group_object_ids    = var.admin_group_object_ids
  tenant_id                 = var.tenant_id
  local_account_disabled    = var.local_account_disabled
  azure_rbac_enabled        = var.azure_rbac_enabled
  oidc_issuer_enabled       = var.oidc_issuer_enabled
  workload_identity_enabled = var.workload_identity_enabled

  # Networking
  node_subnet_id = local.network.subnet_ids["aks_nodes"]
  route_table_id = local.network.route_table_id
  network = merge(var.network, {
    # Firewall route table on the node subnet => egress must be userDefinedRouting
    outbound_type = local.network.route_table_id != null ? "userDefinedRouting" : "loadBalancer"
  })

  # Node pools & autoscaling
  zones               = var.zones
  max_surge           = var.max_surge
  system_pool         = var.system_pool
  user_pools          = var.user_pools
  auto_scaler_profile = var.auto_scaler_profile
  keda_enabled        = var.keda_enabled

  # Integrations & add-ons
  acr_id                     = local.shared.acr_id
  acr_pull_role              = var.acr_pull_role
  log_analytics_workspace_id = local.shared.log_analytics_workspace_id
  key_vault_secrets_provider = var.key_vault_secrets_provider
  azure_policy_enabled       = var.azure_policy_enabled
  image_cleaner              = var.image_cleaner

  # Maintenance
  maintenance_window_auto_upgrade = var.maintenance_window_auto_upgrade
  maintenance_window_node_os      = var.maintenance_window_node_os
}
