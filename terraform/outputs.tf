output "resource_group_id" {
  description = "ID of the created resource group"
  value       = azurerm_resource_group.main.id
}

output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = module.acr.acr_id
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = module.acr.acr_login_server
}

output "container_app_environment_id" {
  description = "ID of the Container Apps environment"
  value       = module.container_apps_env.environment_id
}

output "github_runner_job_id" {
  description = "ID of the GitHub runner Container Apps job"
  value       = var.deploy_runner_job ? module.github_runner_job[0].job_id : "Not deployed - set deploy_runner_job=true after building image"
}

output "managed_identity_id" {
  description = "ID of the managed identity for the Container Apps job"
  value       = var.deploy_runner_job ? module.github_runner_job[0].managed_identity_id : "Not deployed - set deploy_runner_job=true after building image"
}

output "runner_image_reference" {
  description = "Full image reference for the GitHub runner"
  value       = "${module.acr.acr_login_server}/${var.runner_image_name}:${var.runner_image_tag}"
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = var.enable_monitoring ? (var.log_analytics_workspace_id != "" ? var.log_analytics_workspace_id : module.log_analytics[0].workspace_id) : ""
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = var.enable_monitoring ? (var.log_analytics_workspace_id != "" ? split("/", var.log_analytics_workspace_id)[8] : var.log_analytics_workspace_name) : ""
}

output "acr_build_instructions" {
  description = "Instructions for building the runner image using cloud-based ACR build"
  value = {
    "step1" = "Build image in Azure (no local Docker needed): ./scripts/run-acr-build.sh --acr-name ${module.acr.acr_name}"
    "step2" = "Or use Azure CLI directly: az acr build --registry ${module.acr.acr_name} --image ${var.runner_image_name}:${var.runner_image_tag} --file docker/Dockerfile ./docker"
    "step3" = "Verify image: az acr repository show-tags --name ${module.acr.acr_name} --repository ${var.runner_image_name} --output table"
  }
}

output "runner_job_trigger_command" {
  description = "Command to manually trigger the Container Apps Job"
  value       = "az containerapp job start --name ${var.github_runner_job_name} --resource-group ${var.resource_group_name}"
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = var.deploy_runner_job ? {
    "1_trigger_job"    = "Run: az containerapp job start --name ${var.github_runner_job_name} --resource-group ${var.resource_group_name}"
    "2_view_logs"      = "Check logs in Azure Portal: Container Apps Job → Log stream"
    "3_verify_github"  = "Verify runner in GitHub: Settings → Actions → Runners"
  } : {
    "1_build_image"    = "Run: ./scripts/run-acr-build.sh --acr-name ${module.acr.acr_name}"
    "2_deploy_job"     = "After image is built, run: terraform apply -var='deploy_runner_job=true' (and provide github_pat)"
    "3_verify_image"   = "Verify image: az acr repository show-tags --name ${module.acr.acr_name} --repository ${var.runner_image_name} --output table"
  }
}