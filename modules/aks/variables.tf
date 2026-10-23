# Variables with default = null fall back to the defaults in modules/aks/variables.tf.

# ── Remote state ─────────────────────────────────────────────────────────────

variable "tfe_organization" {
  type = string
}

variable "network_workspace" {
  description = "TFE workspace name of the 100-network layer"
  type        = string
}

variable "shared_workspace" {
  description = "TFE workspace name of the 200-shared layer"
  type        = string
}

# ── Placement ────────────────────────────────────────────────────────────────

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "node_resource_group" {
  description = "null = rg-cuberai-aks-<env>-nodes"
  type        = string
  default     = null
}

variable "dns_prefix" {
  description = "null = cluster_name"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ── Cluster ──────────────────────────────────────────────────────────────────

variable "kubernetes_version" {
  description = "Minor version only (e.g. 1.34). Check: az aks get-versions -l <region> -o table"
  type        = string
}

variable "sku_tier" {
  type    = string
  default = null
}

variable "automatic_upgrade_channel" {
  type    = string
  default = null
}

variable "node_os_upgrade_channel" {
  type    = string
  default = null
}

variable "node_provisioning_mode" {
  type    = string
  default = null
}

# ── API server access ────────────────────────────────────────────────────────

variable "private_cluster_enabled" {
  type    = bool
  default = null
}

variable "private_cluster_public_fqdn_enabled" {
  type    = bool
  default = null
}

variable "private_dns_zone_id" {
  description = "null = hub AKS zone from 100-network"
  type        = string
  default     = null
}

variable "api_authorized_ip_ranges" {
  type    = list(string)
  default = null
}

# ── Identity & auth ──────────────────────────────────────────────────────────

variable "admin_group_object_ids" {
  description = "Entra ID groups granted cluster-admin"
  type        = list(string)
}

variable "tenant_id" {
  type    = string
  default = null
}

variable "local_account_disabled" {
  type    = bool
  default = null
}

variable "azure_rbac_enabled" {
  type    = bool
  default = null
}

variable "oidc_issuer_enabled" {
  type    = bool
  default = null
}

variable "workload_identity_enabled" {
  type    = bool
  default = null
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "network" {
  description = "Plugin, policy and CIDRs — unset attributes use module defaults. outbound_type is derived from 100-network."
  type = object({
    network_plugin      = optional(string)
    network_plugin_mode = optional(string)
    network_policy      = optional(string)
    pod_cidr            = optional(string)
    service_cidr        = optional(string)
    dns_service_ip      = optional(string)
    load_balancer_sku   = optional(string)
  })
  default = {}
}

# ── Node pools & autoscaling ─────────────────────────────────────────────────

variable "zones" {
  type    = list(string)
  default = null
}

variable "max_surge" {
  type    = string
  default = null
}

variable "system_pool" {
  description = "System pool — unset attributes use the defaults in modules/aks/variables.tf"
  type = object({
    system_pool_name                         = optional(string)
    system_pool_vm_size                      = optional(string)
    system_pool_only_critical_addons_enabled = optional(bool)
    system_pool_auto_scaling_enabled         = optional(bool)
    system_pool_min_count                    = optional(number)
    system_pool_max_count                    = optional(number)
    system_pool_node_count                   = optional(number)
    system_pool_vnet_subnet_id               = optional(string)
    system_pool_zones                        = optional(list(string))
    system_pool_os_sku                       = optional(string)
    system_pool_os_disk_type                 = optional(string)
    system_pool_os_disk_size_gb              = optional(number)
    system_pool_max_pods                     = optional(number)
    system_pool_max_surge                    = optional(string)
    system_pool_temporary_name_for_rotation  = optional(string)
    system_pool_node_labels                  = optional(map(string))
    system_pool_tags                         = optional(map(string))
  })
  default = null
}

variable "user_pools" {
  description = "User node pools keyed by name — unset attributes use the defaults in modules/aks/variables.tf"
  type = map(object({
    worker_pool_vm_size                     = string
    worker_pool_mode                        = optional(string)
    worker_pool_auto_scaling_enabled        = optional(bool)
    worker_pool_min_count                   = optional(number)
    worker_pool_max_count                   = optional(number)
    worker_pool_node_count                  = optional(number)
    worker_pool_vnet_subnet_id              = optional(string)
    worker_pool_zones                       = optional(list(string))
    worker_pool_os_sku                      = optional(string)
    worker_pool_os_disk_type                = optional(string)
    worker_pool_os_disk_size_gb             = optional(number)
    worker_pool_max_pods                    = optional(number)
    worker_pool_max_surge                   = optional(string)
    worker_pool_temporary_name_for_rotation = optional(string)
    worker_pool_node_labels                 = optional(map(string))
    worker_pool_node_taints                 = optional(list(string))
    worker_pool_tags                        = optional(map(string))
  }))
  default = {}
}

variable "auto_scaler_profile" {
  type = object({
    expander                         = optional(string)
    balance_similar_node_groups      = optional(bool)
    scale_down_delay_after_add       = optional(string)
    scale_down_unneeded              = optional(string)
    scale_down_utilization_threshold = optional(string)
    max_graceful_termination_sec     = optional(string)
    skip_nodes_with_local_storage    = optional(bool)
    skip_nodes_with_system_pods      = optional(bool)
  })
  default = null
}

variable "keda_enabled" {
  type    = bool
  default = null
}

# ── Integrations & add-ons ───────────────────────────────────────────────────

variable "acr_pull_role" {
  description = "AcrPull, or 'Container Registry Repository Reader' if the ACR uses ABAC repository permissions mode"
  type        = string
  default     = null
}

variable "key_vault_secrets_provider" {
  type = object({
    enabled                  = optional(bool)
    secret_rotation_enabled  = optional(bool)
    secret_rotation_interval = optional(string)
  })
  default = null
}

variable "azure_policy_enabled" {
  type    = bool
  default = null
}

variable "image_cleaner" {
  type = object({
    enabled        = optional(bool)
    interval_hours = optional(number)
  })
  default = null
}

# ── Maintenance windows ──────────────────────────────────────────────────────

variable "maintenance_window_auto_upgrade" {
  type = object({
    frequency   = optional(string)
    interval    = optional(number)
    duration    = optional(number)
    day_of_week = optional(string)
    start_time  = optional(string)
    utc_offset  = optional(string)
  })
  default = null
}

variable "maintenance_window_node_os" {
  type = object({
    frequency   = optional(string)
    interval    = optional(number)
    duration    = optional(number)
    day_of_week = optional(string)
    start_time  = optional(string)
    utc_offset  = optional(string)
  })
  default = null
}
