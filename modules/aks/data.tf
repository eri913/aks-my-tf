data "azurerm_client_config" "current" {}

data "terraform_remote_state" "network" {
  backend = "remote"
  config = {
    organization = var.tfe_organization
    workspaces = {
      name = var.network_workspace
    }
  }
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
  network = data.terraform_remote_state.network.outputs
  shared  = data.terraform_remote_state.shared.outputs
}
