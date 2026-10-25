# ── Key Vault (app secrets via CSI driver + Workload Identity) ───────────────

resource "azurerm_key_vault" "main" {
  name                          = var.key_vault_name
  location                      = data.azurerm_resource_group.shared.location
  resource_group_name           = data.azurerm_resource_group.shared.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = var.key_vault_public_network_access_enabled
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-${azurerm_key_vault.main.name}"
  location            = data.azurerm_resource_group.shared.location
  resource_group_name = data.azurerm_resource_group.shared.name
  subnet_id           = data.azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.main.name}"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault"
    private_dns_zone_ids = [var.private_dns_zone_ids.keyvault]
  }
}
