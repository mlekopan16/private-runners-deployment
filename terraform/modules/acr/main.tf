resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled
  tags                = var.tags
}

# Create a role assignment for the managed identity to pull images from ACR
# This will be created after the managed identity is created in the github_runner_job module