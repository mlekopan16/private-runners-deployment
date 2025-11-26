output "task_id" {
  description = "ID of the ACR Task"
  value       = azurerm_container_registry_task.build_runner.id
}

output "task_name" {
  description = "Name of the ACR Task"
  value       = azurerm_container_registry_task.build_runner.name
}

output "full_image_name" {
  description = "Full image reference including registry"
  value       = "${var.acr_login_server}/${var.image_name}:${var.default_image_tag}"
}

output "image_name" {
  description = "Image name without tag"
  value       = var.image_name
}

output "default_image_tag" {
  description = "Default image tag"
  value       = var.default_image_tag
}