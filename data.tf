data "azurerm_client_config" "current" {}

# Pre-created by the platform/landing-zone team. The node RG is still created by AKS itself.
data "azurerm_resource_group" "aks" {
  name = var.resource_group_name
}

# Created by hand by the network team — looked up directly, not via remote state
data "azurerm_subnet" "aks_nodes" {
  name                 = var.node_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.network_resource_group_name
}

data "terraform_remote_state" "shared" {
  backend = "remote"
  config = {
    organization = var.tfe_organization
    workspaces = {
      name = var.shared_workspace
    }
  }
}

locals {
  shared = data.terraform_remote_state.shared.outputs
}
