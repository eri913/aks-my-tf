# ── Log Analytics (Container Insights) ───────────────────────────────────────

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-cuberai-${var.environment}"
  location            = data.azurerm_resource_group.shared.location
  resource_group_name = data.azurerm_resource_group.shared.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}
