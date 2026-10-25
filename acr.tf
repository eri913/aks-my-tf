# ── Container Registry ───────────────────────────────────────────────────────
# Premium is required for private endpoints and zone redundancy.

resource "azurerm_container_registry" "main" {
  name                          = var.acr_name
  location                      = data.azurerm_resource_group.shared.location
  resource_group_name           = data.azurerm_resource_group.shared.name
  sku                           = "Premium"
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  zone_redundancy_enabled       = true
  public_network_access_enabled = var.acr_public_network_access_enabled
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${azurerm_container_registry.main.name}"
  location            = data.azurerm_resource_group.shared.location
  resource_group_name = data.azurerm_resource_group.shared.name
  subnet_id           = data.azurerm_subnet.private_endpoints.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${azurerm_container_registry.main.name}"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr"
    private_dns_zone_ids = [var.private_dns_zone_ids.acr]
  }
}

