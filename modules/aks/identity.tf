# Two identities:
#   control plane — manages Azure resources (LBs, disks, joins nodes to the subnet, API server DNS record)
#   kubelet       — used by nodes to pull images from ACR
# User-assigned so they (and their role assignments, incl. those granted by other teams) survive a rebuild.

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

# ── Always created by this module (scopes owned by this project) ──

# Control plane must be able to assign the kubelet identity to the node VMSS
resource "azurerm_role_assignment" "cp_managed_identity_operator" {
  scope                = azurerm_user_assigned_identity.kubelet.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Kubelet pulls images from ACR — no imagePullSecrets needed
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  count = var.acr_id != null ? 1 : 0

  scope                = var.acr_id
  role_definition_name = var.acr_pull_role
  principal_id         = azurerm_user_assigned_identity.kubelet.principal_id
}

# ── Scopes owned by other teams — skip with var.role_assignments when they grant them instead ──
# AKS still needs these permissions BEFORE the cluster is created; grant them to the control-plane
# principal ID (output control_plane_identity.principal_id).

# Join nodes and internal LBs (Istio internal gateway) to the node subnet
resource "azurerm_role_assignment" "cp_node_subnet" {
  count = var.role_assignments.node_subnet ? 1 : 0

  scope                = var.node_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Custom (hub) API server DNS zone: AKS writes the API server A record into the zone ...
resource "azurerm_role_assignment" "cp_private_dns_zone" {
  count = local.custom_private_dns_zone && var.role_assignments.private_dns_zone ? 1 : 0

  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# ... and needs Network Contributor on the cluster's VNet (also covers the node subnet)
resource "azurerm_role_assignment" "cp_vnet" {
  count = local.custom_private_dns_zone && var.role_assignments.vnet ? 1 : 0

  scope                = local.node_vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

# Renamed from cp_network_contributor (and now optional) — keeps an already-created assignment in state
moved {
  from = azurerm_role_assignment.cp_network_contributor
  to   = azurerm_role_assignment.cp_node_subnet[0]
}
