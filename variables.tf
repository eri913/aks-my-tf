# Only the inputs this layer sets are exposed here. Everything else uses the defaults in
# modules/aks/variables.tf (auth flags, add-ons, autoscaler profile, maintenance windows, zones, ...).

# ── Remote state ─────────────────────────────────────────────────────────────

variable "tfe_organization" {
  type = string
}

variable "shared_workspace" {
  description = "TFE workspace name of the 200-shared layer"
  type        = string
}

# ── Existing network (created by hand by the network team) ──────────────────

variable "network_resource_group_name" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "node_subnet_name" {
  description = "Existing subnet for all node pools (/26 minimum, /25 recommended)"
  type        = string
}

# ── Permissions granted by other teams ──────────────────────────────────────

variable "create_network_role_assignments" {
  description = "true = Terraform grants the control-plane identity Network Contributor on the node subnet and VNet. false = the network team grants it."
  type        = bool
  default     = true
}

variable "create_private_dns_zone_role_assignment" {
  description = "true = Terraform grants Private DNS Zone Contributor on the hub zone. false = the DNS team grants it (no permission on the zone)."
  type        = bool
  default     = false
}

# ── Placement ────────────────────────────────────────────────────────────────

variable "environment" {
  type = string
}

variable "resource_group_name" {
  description = "Existing resource group for the cluster and its identities"
  type        = string
}

variable "cluster_name" {
  type = string
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
  description = "Standard = uptime SLA. Free for dev."
  type        = string
  default     = "Standard"
}

variable "automatic_upgrade_channel" {
  description = "none | patch | stable | rapid | node-image"
  type        = string
  default     = "patch"
}

variable "node_os_upgrade_channel" {
  description = "None | Unmanaged | SecurityPatch | NodeImage"
  type        = string
  default     = "NodeImage"
}

# ── API server access ────────────────────────────────────────────────────────

variable "private_cluster_enabled" {
  type    = bool
  default = true
}

variable "private_dns_zone_id" {
  description = "Hub privatelink.<region>.azmk8s.io zone ID (centralized DNS)"
  type        = string
}

# ── Identity & auth ──────────────────────────────────────────────────────────

variable "admin_group_object_ids" {
  description = "Entra ID groups granted cluster-admin"
  type        = list(string)
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "network" {
  description = "Azure CNI Overlay + Cilium. CIDRs must not overlap the VNet, peered networks or on-prem."
  type = object({
    network_plugin      = optional(string, "azure")
    network_plugin_mode = optional(string, "overlay")
    network_data_plane  = optional(string, "cilium")
    network_policy      = optional(string, "cilium")
    pod_cidr            = optional(string, "10.244.0.0/16")
    service_cidr        = optional(string, "172.16.0.0/16")
    dns_service_ip      = optional(string, "172.16.0.10")
  })
  default  = {}
  nullable = false
}

variable "outbound_type" {
  description = <<-EOT
    Cluster egress. userAssignedNATGateway = the NAT gateway already associated with the node subnet
    (owned by the network team). The node subnet must not route 0.0.0.0/0 elsewhere (e.g. to a firewall).
  EOT
  type        = string
  default     = "userAssignedNATGateway"

  validation {
    condition     = contains(["userAssignedNATGateway", "userDefinedRouting", "loadBalancer", "managedNATGateway"], var.outbound_type)
    error_message = "outbound_type must be userAssignedNATGateway, userDefinedRouting, loadBalancer or managedNATGateway."
  }
}

# ── Node pools ───────────────────────────────────────────────────────────────

variable "max_surge" {
  description = "Extra nodes per pool during upgrades — counts toward node subnet IPs"
  type        = string
  default     = "1"
}

variable "system_pool" {
  description = "System pool — attributes not listed here use the defaults in modules/aks/variables.tf"
  type = object({
    system_pool_vm_size   = optional(string, "Standard_D4ds_v5")
    system_pool_min_count = optional(number, 3)
    system_pool_max_count = optional(number, 5)
  })
  default  = {}
  nullable = false
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
  default  = {}
  nullable = false
}

# ── Subscription ─────────────────────────────────────────────────────────────

variable "resource_providers_to_register" {
  description = "Resource provider namespaces this layer needs (AKS, identities, Container Insights (oms_agent), Azure Policy add-on)"
  type        = list(string)
  default = [
    "Microsoft.ContainerService",
    "Microsoft.ManagedIdentity",
    "Microsoft.Compute",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.OperationsManagement",
    "Microsoft.Insights",
    "Microsoft.PolicyInsights",
  ]
}

# ── Service mesh ─────────────────────────────────────────────────────────────

variable "istio_revisions" {
  description = "AKS Istio add-on revisions (az aks mesh get-revisions -l <region> -o table). Two entries only during a canary upgrade. Must match istio.io/rev in cuber-ai-platform."
  type        = list(string)
}

# ── External Secrets Operator ────────────────────────────────────────────────

variable "external_secrets" {
  description = "Must match the namespace/service account ESO is installed with (cuber-ai-platform: operators/external-secrets)"
  type = object({
    namespace       = optional(string, "external-secrets")
    service_account = optional(string, "external-secrets")
    key_vault_role  = optional(string, "Key Vault Secrets User") # read-only; "Key Vault Secrets Officer" if ESO must push secrets
  })
  default  = {}
  nullable = false
}
