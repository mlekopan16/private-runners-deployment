resource "azurerm_container_app_environment" "env" {
  name                       = var.environment_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = var.enable_monitoring ? var.log_analytics_workspace_id : null
  tags                       = var.tags
}