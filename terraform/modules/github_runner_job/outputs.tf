output "job_id" {
  description = "ID of the Container Apps job"
  value       = azurerm_container_app_job.github_runner.id
}

output "job_name" {
  description = "Name of the Container Apps job"
  value       = azurerm_container_app_job.github_runner.name
}

output "managed_identity_id" {
  description = "ID of the managed identity"
  value       = azurerm_user_assigned_identity.runner_identity.id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the managed identity"
  value       = azurerm_user_assigned_identity.runner_identity.principal_id
}

output "runner_name" {
  description = "Generated runner name"
  value       = "aca-runner-${random_id.runner_suffix.hex}"
}