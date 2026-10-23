# User node pools. Every attribute is set per pool in var.user_pools (worker_pool_*); unset ones fall back
# to the defaults in variables.tf or to the module-wide inputs (node_subnet_id, zones, max_surge, tags).
# Taint a pool to reserve it, e.g. worker_pool_node_taints = ["workload=data:NoSchedule"],
# and give its pods a matching toleration.

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.user_pools

  name                        = each.key
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.this.id
  mode                        = each.value.worker_pool_mode
  vm_size                     = each.value.worker_pool_vm_size
  vnet_subnet_id              = coalesce(each.value.worker_pool_vnet_subnet_id, var.node_subnet_id)
  zones                       = coalesce(each.value.worker_pool_zones, var.zones)
  auto_scaling_enabled        = each.value.worker_pool_auto_scaling_enabled
  min_count                   = each.value.worker_pool_auto_scaling_enabled ? each.value.worker_pool_min_count : null
  max_count                   = each.value.worker_pool_auto_scaling_enabled ? each.value.worker_pool_max_count : null
  node_count                  = each.value.worker_pool_auto_scaling_enabled ? null : each.value.worker_pool_node_count # null = autoscaler owns it
  os_sku                      = each.value.worker_pool_os_sku
  os_disk_type                = each.value.worker_pool_os_disk_type
  os_disk_size_gb             = each.value.worker_pool_os_disk_size_gb
  max_pods                    = each.value.worker_pool_max_pods
  temporary_name_for_rotation = coalesce(each.value.worker_pool_temporary_name_for_rotation, "${each.key}tmp")
  node_labels                 = each.value.worker_pool_node_labels
  node_taints                 = each.value.worker_pool_node_taints
  tags                        = merge(var.tags, each.value.worker_pool_tags)

  upgrade_settings {
    max_surge = coalesce(each.value.worker_pool_max_surge, var.max_surge)
  }

  depends_on = [azurerm_role_assignment.cp_pool_subnets]
}
