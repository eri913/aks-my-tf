# Inputs not passed here use the defaults in modules/aks/variables.tf.
module "aks" {
  source = "../modules/aks"

  # Placement
  name                = var.cluster_name
  resource_group_name = data.azurerm_resource_group.aks.name
  location            = data.azurerm_resource_group.aks.location
  node_resource_group = "rg-cuberai-aks-${var.environment}-nodes"
  tags                = var.tags

  # Cluster
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = var.sku_tier
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  # API server access
  private_cluster_enabled = var.private_cluster_enabled
  private_dns_zone_id     = var.private_dns_zone_id

  # Identity & auth
  admin_group_object_ids = var.admin_group_object_ids
  role_assignments = {
    node_subnet      = var.create_network_role_assignments
    vnet             = var.create_network_role_assignments
    private_dns_zone = var.create_private_dns_zone_role_assignment
  }

  # Networking
  node_subnet_id = data.azurerm_subnet.aks_nodes.id
  network        = merge(var.network, { outbound_type = var.outbound_type })

  # Node pools
  max_surge   = var.max_surge
  system_pool = var.system_pool
  user_pools  = var.user_pools

  # Service mesh — internal ingress gateway only (private cluster)
  service_mesh_profile = {
    mode      = istio
    revisions = var.istio_revisions
  }

  # Integrations
  acr_id                     = local.shared.acr_id
  log_analytics_workspace_id = local.shared.log_analytics_workspace_id
}
