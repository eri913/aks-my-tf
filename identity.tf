# Two identities:
#   control plane — manages Azure resources (LBs, disks, joins nodes to subnets)
#   kubelet       — used by nodes to pull images from ACR
# User-assigned so they (and their role assignments) survive a cluster rebuild.

resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "id-${var.name}-kubelet"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Control plane must be able to assign the kubelet identity to the node VMSS
resource "azurerm_role_assignment" "cp_managed_identity_operator" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Control plane joins nodes and internal LBs to the node subnet
resource "azurerm_role_assignment" "cp_network_contributor" {
  scope                = var.node_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Pools placed on a subnet other than node_subnet_id need the same permission there
resource "azurerm_role_assignment" "cp_pool_subnets" {
  for_each = toset([
    for p in values(var.user_pools) : p.worker_pool_vnet_subnet_id
    if p.worker_pool_vnet_subnet_id != null && p.worker_pool_vnet_subnet_id != var.node_subnet_id
  ])

  scope                = each.value
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Egress via firewall: AKS reads/joins the route table on the node subnet
resource "azurerm_role_assignment" "cp_route_table" {
  count = var.route_table_id != null ? 1 : 0

  scope                = var.route_table_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Custom (hub) API server DNS zone: AKS writes the A record into the zone
# and needs Network Contributor on the VNet the cluster lives in.
resource "azurerm_role_assignment" "cp_private_dns_zone" {
  count = local.custom_private_dns_zone ? 1 : 0

  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_role_assignment" "cp_vnet" {
  count = local.custom_private_dns_zone ? 1 : 0

  scope                = local.node_vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Kubelet pulls images from ACR — no imagePullSecrets needed
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.acr_id != null ? 1 : 0

  scope                = var.acr_id
  role_definition_name = var.acr_pull_role
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
}
