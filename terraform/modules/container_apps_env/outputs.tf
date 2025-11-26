output "environment_id" {
  description = "ID of the Container Apps environment"
  value       = azurerm_container_app_environment.env.id
}

output "environment_name" {
  description = "Name of the Container Apps environment"
  value       = azurerm_container_app_environment.env.name
}

output "default_domain" {
  description = "Default domain of the Container Apps environment"
  value       = azurerm_container_app_environment.env.default_domain
}