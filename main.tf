data "azurerm_client_config" "current" {}

locals {
  custom_private_dns_zone = var.private_cluster_enabled && !contains(["System", "None"], var.private_dns_zone_id)
  node_vnet_id            = regex("^(.+)/subnets/[^/]+$", var.node_subnet_id)[0]
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  node_resource_group = var.node_resource_group

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  # ── API server access ──
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_cluster_enabled ? var.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = false

  dynamic "api_server_access_profile" {
    for_each = !var.private_cluster_enabled && length(var.api_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_authorized_ip_ranges
    }
  }

  # ── Identity & auth: Entra ID + Azure RBAC, no local admin kubeconfig ──
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  local_account_disabled = true

  azure_active_directory_role_based_access_control {
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  # Workload Identity — for pods calling Azure APIs (Key Vault, Storage, Azure OpenAI)
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # ── System pool: critical add-ons only (CoreDNS, metrics-server, konnectivity) ──
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_pool.vm_size
    vnet_subnet_id               = var.node_subnet_id
    zones                        = var.zones
    auto_scaling_enabled         = true
    min_count                    = var.system_pool.min_count
    max_count                    = var.system_pool.max_count
    only_critical_addons_enabled = true
    os_sku                       = var.system_pool.os_sku
    os_disk_type                 = var.system_pool.os_disk_type
    os_disk_size_gb              = var.system_pool.os_disk_size_gb
    max_pods                     = var.system_pool.max_pods
    temporary_name_for_rotation  = "systemtmp"
    tags                         = var.tags

    upgrade_settings {
      max_surge = var.max_surge
    }
  }

  # ── Networking: Azure CNI Overlay + Cilium ──
  # Pod IPs come from pod_cidr (overlay), not the VNet — the subnet only holds nodes.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.network.pod_cidr
    service_cidr        = var.network.service_cidr
    dns_service_ip      = var.network.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = var.network.outbound_type
  }

  # Manual = classic node pools + Cluster Autoscaler (not Node Auto Provisioning / Karpenter)
  node_provisioning_profile {
    mode = "Manual"
  }

  # ── Cluster Autoscaler (applies to every pool with auto_scaling_enabled) ──
  auto_scaler_profile {
    balance_similar_node_groups      = var.auto_scaler_profile.balance_similar_node_groups
    expander                         = var.auto_scaler_profile.expander
    scale_down_delay_after_add       = var.auto_scaler_profile.scale_down_delay_after_add
    scale_down_unneeded              = var.auto_scaler_profile.scale_down_unneeded
    scale_down_utilization_threshold = var.auto_scaler_profile.scale_down_utilization_threshold
    max_graceful_termination_sec     = var.auto_scaler_profile.max_graceful_termination_sec
    skip_nodes_with_local_storage    = var.auto_scaler_profile.skip_nodes_with_local_storage
    skip_nodes_with_system_pods      = var.auto_scaler_profile.skip_nodes_with_system_pods
  }

  # KEDA — event/queue-driven pod scaling
  workload_autoscaler_profile {
    keda_enabled = var.keda_enabled
  }

  # ── Add-ons ──
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  azure_policy_enabled         = true
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  # ── Maintenance windows (UTC) ──
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = var.maintenance_window.duration
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    utc_offset  = "+00:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = var.maintenance_window.duration
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    utc_offset  = "+00:00"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }

  depends_on = [
    azurerm_role_assignment.cp_managed_identity_operator,
    azurerm_role_assignment.cp_network_contributor,
    azurerm_role_assignment.cp_route_table,
    azurerm_role_assignment.cp_private_dns_zone,
    azurerm_role_assignment.cp_vnet,
  ]
}
