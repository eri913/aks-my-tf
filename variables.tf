# ── Placement ────────────────────────────────────────────────────────────────

variable "name" {
  description = "Cluster name — also used as dns_prefix and in identity names"
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group for the cluster and its identities"
  type        = string
}

variable "location" {
  type = string
}

variable "node_resource_group" {
  description = "Name for the AKS-managed node RG (must not exist). null = AKS default MC_* name. Changing it recreates the cluster."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ── Cluster ──────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Minor version only (e.g. 1.34) — patches come from automatic_upgrade_channel"
  type        = string
}

variable "sku_tier" {
  description = "Standard = uptime SLA. Free for dev."
  type        = string
  default     = "Standard"
}

variable "automatic_upgrade_channel" {
  type    = string
  default = "patch"
}

variable "node_os_upgrade_channel" {
  type    = string
  default = "NodeImage"
}

variable "private_cluster_enabled" {
  type    = bool
  default = true
}

variable "api_authorized_ip_ranges" {
  description = "Only used when private_cluster_enabled = false"
  type        = list(string)
  default     = []
}

variable "private_dns_zone_id" {
  description = <<-EOT
    API server private DNS (private clusters only). "System" = AKS-managed zone linked to the cluster VNet only.
    A zone ID (privatelink.<region>.azmk8s.io, usually central in the hub) = control plane gets
    Private DNS Zone Contributor on it and Network Contributor on the node VNet. Changing it recreates the cluster.
  EOT
  type        = string
  default     = "System"
}

variable "admin_group_object_ids" {
  description = "Entra ID groups granted cluster-admin"
  type        = list(string)
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "node_subnet_id" {
  description = "Subnet for all node pools (and internal LBs). Control plane gets Network Contributor on it."
  type        = string
}

variable "network" {
  description = "Azure CNI Overlay + Cilium. CIDRs must not overlap the VNet, peered networks or on-prem."
  type = object({
    network_plugin      = optional(string, "azure")
    network_plugin_mode = optional(string, "overlay") # pods get IPs from pod_cidr, not the VNet
    network_data_plane  = optional(string, "cilium")  # eBPF dataplane (Azure CNI powered by Cilium)
    network_policy      = optional(string, "cilium")  # must be "cilium" when network_data_plane = "cilium"
    pod_cidr            = optional(string, "10.244.0.0/16")
    service_cidr        = optional(string, "172.16.0.0/16")
    dns_service_ip      = optional(string, "172.16.0.10")
    load_balancer_sku   = optional(string, "standard")
    outbound_type       = optional(string, "loadBalancer") # userDefinedRouting if egress goes via a hub firewall
  })
  default = {}
}

variable "route_table_id" {
  description = "Route table on the node subnet (egress via firewall). Control plane gets Network Contributor on it."
  type        = string
  default     = null
}

# ── Node pools ───────────────────────────────────────────────────────────────

variable "zones" {
  description = "Default zones for every pool (a pool can override)"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "max_surge" {
  description = "Default extra nodes per pool during upgrades"
  type        = string
  default     = "1"
}

variable "system_pool" {
  description = "Default node pool — critical add-ons only. Use a 'd' SKU for Ephemeral OS disks."
  type = object({
    vm_size         = optional(string, "Standard_D4ds_v5")
    min_count       = optional(number, 3)
    max_count       = optional(number, 5)
    os_sku          = optional(string, "AzureLinux")
    os_disk_type    = optional(string, "Ephemeral")
    os_disk_size_gb = optional(number, 128)
    max_pods        = optional(number, 110)
  })
  default = {}
}

variable "user_pools" {
  description = "User node pools keyed by pool name (lowercase alphanumeric, max 12 chars)"
  type = map(object({
    worker_pool_vm_size                     = string
    worker_pool_mode                        = optional(string, "User") # "System" adds another system-capable pool
    worker_pool_auto_scaling_enabled        = optional(bool, true)
    worker_pool_min_count                   = optional(number)       # required when worker_pool_auto_scaling_enabled = true
    worker_pool_max_count                   = optional(number)       # required when worker_pool_auto_scaling_enabled = true
    worker_pool_node_count                  = optional(number)       # required when worker_pool_auto_scaling_enabled = false
    worker_pool_vnet_subnet_id              = optional(string)       # null = var.node_subnet_id
    worker_pool_zones                       = optional(list(string)) # null = var.zones
    worker_pool_os_sku                      = optional(string, "AzureLinux")
    worker_pool_os_disk_type                = optional(string, "Ephemeral")
    worker_pool_os_disk_size_gb             = optional(number, 128)
    worker_pool_max_pods                    = optional(number, 110)
    worker_pool_max_surge                   = optional(string) # null = var.max_surge
    worker_pool_temporary_name_for_rotation = optional(string) # null = "<name>tmp"
    worker_pool_node_labels                 = optional(map(string), {})
    worker_pool_node_taints                 = optional(list(string), [])
    worker_pool_tags                        = optional(map(string), {}) # merged over var.tags
  }))
  default = {}

  validation {
    condition     = alltrue([for k in keys(var.user_pools) : can(regex("^[a-z][a-z0-9]{0,11}$", k))])
    error_message = "Pool names must be lowercase alphanumeric, start with a letter, max 12 chars."
  }

  validation {
    condition = alltrue([
      for k, p in var.user_pools : can(regex("^[a-z][a-z0-9]{0,11}$", coalesce(p.worker_pool_temporary_name_for_rotation, "${k}tmp")))
    ])
    error_message = "worker_pool_temporary_name_for_rotation (default \"<name>tmp\") must be lowercase alphanumeric, max 12 chars — set it explicitly for pool names longer than 9 chars."
  }

  validation {
    condition = alltrue([
      for p in values(var.user_pools) :
      p.worker_pool_auto_scaling_enabled ? (p.worker_pool_min_count != null && p.worker_pool_max_count != null) : p.worker_pool_node_count != null
    ])
    error_message = "Autoscaled pools need worker_pool_min_count and worker_pool_max_count; fixed pools (worker_pool_auto_scaling_enabled = false) need worker_pool_node_count."
  }

  validation {
    condition     = alltrue([for p in values(var.user_pools) : contains(["User", "System"], p.worker_pool_mode)])
    error_message = "worker_pool_mode must be \"User\" or \"System\"."
  }
}

variable "auto_scaler_profile" {
  type = object({
    expander                         = optional(string, "least-waste")
    balance_similar_node_groups      = optional(bool, true)
    scale_down_delay_after_add       = optional(string, "10m")
    scale_down_unneeded              = optional(string, "10m")
    scale_down_utilization_threshold = optional(string, "0.5")
    max_graceful_termination_sec     = optional(string, "600")
    skip_nodes_with_local_storage    = optional(bool, false)
    skip_nodes_with_system_pods      = optional(bool, true)
  })
  default = {}
}

# ── Integrations ─────────────────────────────────────────────────────────────

variable "acr_id" {
  description = "ACR the kubelet identity can pull from. null = no role assignment."
  type        = string
  default     = null
}

variable "acr_pull_role" {
  description = "AcrPull, or 'Container Registry Repository Reader' if the ACR uses ABAC repository permissions mode"
  type        = string
  default     = "AcrPull"
}

variable "log_analytics_workspace_id" {
  description = "Container Insights workspace. null = monitoring add-on disabled."
  type        = string
  default     = null
}

variable "keda_enabled" {
  type    = bool
  default = true
}

variable "maintenance_window" {
  description = "Weekly window (UTC) for both cluster auto-upgrade and node OS upgrades"
  type = object({
    day_of_week = optional(string, "Sunday")
    start_time  = optional(string, "02:00")
    duration    = optional(number, 4)
  })
  default = {}
}

variable "node_provisioning_mode" {
  description = "Manual = node pools + Cluster Autoscaler. Auto = Node Auto Provisioning (Karpenter)."
  type        = string
  default     = "Manual"
  nullable    = false
}
