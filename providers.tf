terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.10"
    }
  }
}

provider "azurerm" {
  features {}
  # ARM_SUBSCRIPTION_ID env var

  # Registers these namespaces on the subscription if they aren't already (needs */register/action,
  # e.g. Contributor, on the subscription for the Terraform identity). Already registered = no-op.
  resource_providers_to_register = var.resource_providers_to_register
}
