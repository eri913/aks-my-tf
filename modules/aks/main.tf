data "azurerm_client_config" "current" {}

locals {
  custom_private_dns_zone = var.private_cluster_enabled && !contains(["System", "None"], var.private_dns_zone_id)
  node_vnet_id            = regex("^(.+)/subnets/[^/]+$", var.node_subnet_id)[0]
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = coalesce(var.dns_prefix, var.name)
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  node_resource_group = var.node_resource_group

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = var.node_os_upgrade_channel

  # ── API server access ──
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_cluster_enabled ? var.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled

  dynamic "api_server_access_profile" {
    for_each = !var.private_cluster_enabled && length(var.api_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_authorized_ip_ranges
    }
  }

  # ── Identity & auth ──
  # The module always creates user-assigned control-plane and kubelet identities (identity.tf).
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  local_account_disabled = var.local_account_disabled

  azure_active_directory_role_based_access_control {
    tenant_id              = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = var.azure_rbac_enabled
  }

  # Workload Identity — for pods calling Azure APIs (Key Vault, Storage, Azure OpenAI)
  oidc_issuer_enabled       = var.oidc_issuer_enabled
  workload_identity_enabled = var.workload_identity_enabled

  # ── System pool ──
  default_node_pool {
    name                         = var.system_pool.system_pool_name
    vm_size                      = var.system_pool.system_pool_vm_size
    vnet_subnet_id               = var.node_subnet_id
    zones                        = coalesce(var.system_pool.system_pool_zones, var.zones)
    auto_scaling_enabled         = var.system_pool.system_pool_auto_scaling_enabled
    min_count                    = var.system_pool.system_pool_auto_scaling_enabled ? var.system_pool.system_pool_min_count : null
    max_count                    = var.system_pool.system_pool_auto_scaling_enabled ? var.system_pool.system_pool_max_count : null
    node_count                   = var.system_pool.system_pool_auto_scaling_enabled ? null : var.system_pool.system_pool_node_count # null = autoscaler owns it
    only_critical_addons_enabled = var.system_pool.system_pool_only_critical_addons_enabled
    os_sku                       = var.system_pool.system_pool_os_sku
    os_disk_type                 = var.system_pool.system_pool_os_disk_type
    os_disk_size_gb              = var.system_pool.system_pool_os_disk_size_gb
    max_pods                     = var.system_pool.system_pool_max_pods
    temporary_name_for_rotation  = coalesce(var.system_pool.system_pool_temporary_name_for_rotation, "${var.system_pool.system_pool_name}tmp")
    node_labels                  = var.system_pool.system_pool_node_labels
    tags                         = merge(var.tags, var.system_pool.system_pool_tags)

    upgrade_settings {
      max_surge = coalesce(var.system_pool.system_pool_max_surge, var.max_surge)
    }
  }

  # ── Networking: Azure CNI Overlay powered by Cilium ──
  # Pod IPs come from pod_cidr (overlay), not the VNet — the subnet only holds nodes; no pod routes
  # in any route table. Cilium (eBPF) is the dataplane and enforces NetworkPolicy / CiliumNetworkPolicy.
  network_profile {
    network_plugin      = var.network.network_plugin
    network_plugin_mode = var.network.network_plugin_mode
    network_data_plane  = var.network.network_data_plane
    network_policy      = var.network.network_policy
    pod_cidr            = var.network.pod_cidr
    service_cidr        = var.network.service_cidr
    dns_service_ip      = var.network.dns_service_ip
    load_balancer_sku   = var.network.load_balancer_sku
    outbound_type       = var.network.outbound_type
  }

  # Manual = node pools + Cluster Autoscaler; Auto = Node Auto Provisioning (Karpenter)
  node_provisioning_profile {
    mode = var.node_provisioning_mode
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

  # ── Service mesh: AKS Istio add-on (istiod in aks-istio-system, gateways in aks-istio-ingress) ──
  dynamic "service_mesh_profile" {
    for_each = var.service_mesh.enabled ? [1] : []
    content {
      mode                             = "Istio"
      revisions                        = var.service_mesh.revisions
      internal_ingress_gateway_enabled = var.service_mesh.internal_ingress_gateway_enabled
      external_ingress_gateway_enabled = var.service_mesh.external_ingress_gateway_enabled
    }
  }

  # ── Add-ons ──
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider.enabled ? [1] : []
    content {
      secret_rotation_enabled  = var.key_vault_secrets_provider.secret_rotation_enabled
      secret_rotation_interval = var.key_vault_secrets_provider.secret_rotation_interval
    }
  }

  azure_policy_enabled         = var.azure_policy_enabled
  image_cleaner_enabled        = var.image_cleaner.enabled
  image_cleaner_interval_hours = var.image_cleaner.enabled ? var.image_cleaner.interval_hours : null

  # ── Maintenance windows ──
  maintenance_window_auto_upgrade {
    frequency   = var.maintenance_window_auto_upgrade.frequency
    interval    = var.maintenance_window_auto_upgrade.interval
    duration    = var.maintenance_window_auto_upgrade.duration
    day_of_week = var.maintenance_window_auto_upgrade.day_of_week
    start_time  = var.maintenance_window_auto_upgrade.start_time
    utc_offset  = var.maintenance_window_auto_upgrade.utc_offset
  }

  maintenance_window_node_os {
    frequency   = var.maintenance_window_node_os.frequency
    interval    = var.maintenance_window_node_os.interval
    duration    = var.maintenance_window_node_os.duration
    day_of_week = var.maintenance_window_node_os.day_of_week
    start_time  = var.maintenance_window_node_os.start_time
    utc_offset  = var.maintenance_window_node_os.utc_offset
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.cp_managed_identity_operator,
    azurerm_role_assignment.cp_node_subnet,
    azurerm_role_assignment.cp_private_dns_zone,
    azurerm_role_assignment.cp_vnet,
  ]
}
