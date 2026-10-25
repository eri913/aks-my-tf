# Inputs that have a default are `nullable = false`: passing null (e.g. an unset root variable)
# falls back to the default here, so callers can pass every input through without repeating defaults.

# ── Placement ────────────────────────────────────────────────────────────────

variable "name" {
  description = "Cluster name — also used in identity names"
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

variable "dns_prefix" {
  description = "API server DNS prefix. null = var.name"
  type        = string
  default     = null
}

variable "tags" {
  type     = map(string)
  default  = {}
  nullable = false
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
  nullable    = false
}

variable "automatic_upgrade_channel" {
  description = "none | patch | stable | rapid | node-image"
  type        = string
  default     = "patch"
  nullable    = false
}

variable "node_os_upgrade_channel" {
  description = "None | Unmanaged | SecurityPatch | NodeImage"
  type        = string
  default     = "NodeImage"
  nullable    = false
}

variable "node_provisioning_mode" {
  description = "Manual = node pools + Cluster Autoscaler. Auto = Node Auto Provisioning (Karpenter)."
  type        = string
  default     = "Manual"
  nullable    = false
}

# ── API server access ────────────────────────────────────────────────────────

variable "private_cluster_enabled" {
  type     = bool
  default  = true
  nullable = false
}

variable "private_cluster_public_fqdn_enabled" {
  description = "Also publish the API server name in public DNS (resolving to the private IP)"
  type        = bool
  default     = false
  nullable    = false
}

variable "private_dns_zone_id" {
  description = <<-EOT
    API server private DNS (private clusters only). "System" = AKS-managed zone linked to the cluster VNet only.
    "None" = public DNS only (needs private_cluster_public_fqdn_enabled). A zone ID (privatelink.<region>.azmk8s.io,
    usually central in the hub) = control plane gets Private DNS Zone Contributor on it and Network Contributor
    on the node VNet. Changing it recreates the cluster.
  EOT
  type        = string
  default     = "System"
  nullable    = false
}

variable "api_authorized_ip_ranges" {
  description = "Only used when private_cluster_enabled = false"
  type        = list(string)
  default     = []
  nullable    = false
}

# ── Identity & auth ──────────────────────────────────────────────────────────

variable "admin_group_object_ids" {
  description = "Entra ID groups granted cluster-admin"
  type        = list(string)
}

variable "tenant_id" {
  description = "Entra ID tenant for cluster auth. null = tenant of the deploying identity."
  type        = string
  default     = null
}

variable "local_account_disabled" {
  description = "Disable the static local admin kubeconfig (Entra ID only)"
  type        = bool
  default     = true
  nullable    = false
}

variable "azure_rbac_enabled" {
  description = "Authorize Kubernetes API calls with Azure RBAC role assignments"
  type        = bool
  default     = true
  nullable    = false
}

variable "oidc_issuer_enabled" {
  type     = bool
  default  = true
  nullable = false
}

variable "workload_identity_enabled" {
  description = "Requires oidc_issuer_enabled"
  type        = bool
  default     = true
  nullable    = false
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "node_subnet_id" {
  description = "Default subnet for all node pools (and internal LBs). Control plane gets Network Contributor on it."
  type        = string
}

variable "network" {
  description = "Cluster networking. CIDRs must not overlap the VNet, peered networks or on-prem."
  type = object({
    network_plugin      = optional(string, "azure")
    network_plugin_mode = optional(string, "overlay") # pods get IPs from pod_cidr, not the VNet
    network_data_plane  = optional(string, "cilium")  # eBPF dataplane (Azure CNI powered by Cilium)
    network_policy      = optional(string, "cilium")  # must be "cilium" when network_data_plane = "cilium"
    pod_cidr            = optional(string, "10.244.0.0/16")
    service_cidr        = optional(string, "172.16.0.0/16")
    dns_service_ip      = optional(string, "172.16.0.10")
    load_balancer_sku   = optional(string, "standard")
    outbound_type       = optional(string, "loadBalancer") # userAssignedNATGateway = NAT gateway on the node subnet; userDefinedRouting = firewall
  })
  default  = {}
  nullable = false

  validation {
    condition     = (var.network.network_data_plane == "cilium") == (var.network.network_policy == "cilium")
    error_message = "network_data_plane and network_policy must both be \"cilium\" (Cilium dataplane enforces policy itself)."
  }
}


variable "role_assignments" {
  description = <<-EOT
    Which control-plane role assignments this module creates on scopes owned by other teams. Set false when
    that team grants the role to the control-plane identity themselves (before the cluster is created).
      node_subnet      — Network Contributor on the node subnet
      vnet             — Network Contributor on the VNet (only with a custom private DNS zone)
      private_dns_zone — Private DNS Zone Contributor on the custom API server zone
  EOT
  type = object({
    node_subnet      = optional(bool, true)
    vnet             = optional(bool, true)
    private_dns_zone = optional(bool, true)
  })
  default  = {}
  nullable = false
}

# ── Node pools ───────────────────────────────────────────────────────────────

variable "zones" {
  description = "Default zones for every pool (a pool can override)"
  type        = list(string)
  default     = ["1", "2", "3"]
  nullable    = false
}

variable "max_surge" {
  description = "Default extra nodes per pool during upgrades (a pool can override)"
  type        = string
  default     = "1"
  nullable    = false
}

variable "system_pool" {
  description = "Default (system) node pool. Use a 'd' SKU for Ephemeral OS disks."
  type = object({
    system_pool_name                         = optional(string, "system")
    system_pool_vm_size                      = optional(string, "Standard_D4ds_v5")
    system_pool_only_critical_addons_enabled = optional(bool, true) # taint CriticalAddonsOnly — app pods go to user pools
    system_pool_auto_scaling_enabled         = optional(bool, true)
    system_pool_min_count                    = optional(number, 3)    # used when system_pool_auto_scaling_enabled = true
    system_pool_max_count                    = optional(number, 5)    # used when system_pool_auto_scaling_enabled = true
    system_pool_node_count                   = optional(number, 3)    # used when system_pool_auto_scaling_enabled = false
    system_pool_zones                        = optional(list(string)) # null = var.zones
    system_pool_os_sku                       = optional(string, "AzureLinux")
    system_pool_os_disk_type                 = optional(string, "Ephemeral")
    system_pool_os_disk_size_gb              = optional(number, 128)
    system_pool_max_pods                     = optional(number, 110)
    system_pool_max_surge                    = optional(string) # null = var.max_surge
    system_pool_temporary_name_for_rotation  = optional(string) # null = "<name>tmp"
    system_pool_node_labels                  = optional(map(string), {})
    system_pool_tags                         = optional(map(string), {}) # merged over var.tags
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      can(regex("^[a-z][a-z0-9]{0,11}$", var.system_pool.system_pool_name)) &&
      can(regex("^[a-z][a-z0-9]{0,11}$", coalesce(var.system_pool.system_pool_temporary_name_for_rotation, "${var.system_pool.system_pool_name}tmp")))
    )
    error_message = "system_pool_name and system_pool_temporary_name_for_rotation (default \"<name>tmp\") must be lowercase alphanumeric, max 12 chars."
  }
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
  default  = {}
  nullable = false

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
  description = "Cluster Autoscaler settings (cluster-wide, used when node_provisioning_mode = Manual)"
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
  default  = {}
  nullable = false
}

variable "keda_enabled" {
  type     = bool
  default  = true
  nullable = false
}

# ── Service mesh (AKS Istio add-on) ─────────────────────────────────────────

variable "service_mesh" {
  description = <<-EOT
    Microsoft-managed Istio. revisions = installed control planes (e.g. ["asm-1-30"]); list two during a
    canary upgrade. Check available revisions: az aks mesh get-revisions -l <region> -o table.
    Namespaces opt in with the label istio.io/rev=<revision>.
  EOT
  type = object({
    enabled                          = optional(bool, false)
    revisions                        = optional(list(string), [])
    internal_ingress_gateway_enabled = optional(bool, true) # internal LB in the node subnet
    external_ingress_gateway_enabled = optional(bool, false)
  })
  default  = {}
  nullable = false

  validation {
    condition     = !var.service_mesh.enabled || length(var.service_mesh.revisions) > 0
    error_message = "service_mesh.revisions must list at least one revision (e.g. [\"asm-1-30\"]) when service_mesh.enabled = true."
  }
}

# ── Integrations & add-ons ───────────────────────────────────────────────────

variable "acr_id" {
  description = "ACR the kubelet identity can pull from. null = no role assignment."
  type        = string
  default     = null
}

variable "acr_pull_role" {
  description = "AcrPull, or 'Container Registry Repository Reader' if the ACR uses ABAC repository permissions mode"
  type        = string
  default     = "AcrPull"
  nullable    = false
}

variable "log_analytics_workspace_id" {
  description = "Container Insights workspace. null = monitoring add-on disabled."
  type        = string
  default     = null
}

variable "key_vault_secrets_provider" {
  description = "Key Vault CSI driver add-on"
  type = object({
    enabled                  = optional(bool, true)
    secret_rotation_enabled  = optional(bool, true)
    secret_rotation_interval = optional(string, "2m")
  })
  default  = {}
  nullable = false
}

variable "azure_policy_enabled" {
  type     = bool
  default  = true
  nullable = false
}

variable "image_cleaner" {
  description = "Removes unused (incl. vulnerable) images from nodes"
  type = object({
    enabled        = optional(bool, true)
    interval_hours = optional(number, 48)
  })
  default  = {}
  nullable = false
}

# ── Maintenance windows ──────────────────────────────────────────────────────

variable "maintenance_window_auto_upgrade" {
  description = "Window for Kubernetes version auto-upgrades (automatic_upgrade_channel)"
  type = object({
    frequency   = optional(string, "Weekly") # Daily | Weekly | AbsoluteMonthly | RelativeMonthly
    interval    = optional(number, 1)
    duration    = optional(number, 4) # hours
    day_of_week = optional(string, "Sunday")
    start_time  = optional(string, "02:00")
    utc_offset  = optional(string, "+00:00")
  })
  default  = {}
  nullable = false
}

variable "maintenance_window_node_os" {
  description = "Window for node OS / node image upgrades (node_os_upgrade_channel)"
  type = object({
    frequency   = optional(string, "Weekly")
    interval    = optional(number, 1)
    duration    = optional(number, 4)
    day_of_week = optional(string, "Sunday")
    start_time  = optional(string, "02:00")
    utc_offset  = optional(string, "+00:00")
  })
  default  = {}
  nullable = false
}
