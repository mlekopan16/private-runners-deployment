# Create resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Deploy ACR module
module "acr" {
  source = "./modules/acr"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  acr_name            = var.acr_name
  tags                = var.tags
}

# Deploy ACR Task module for cloud-based image builds (optional, only if Git trigger is enabled)
module "acr_task" {
  count  = var.enable_git_trigger ? 1 : 0
  source = "./modules/acr_task"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  acr_name            = var.acr_name
  acr_id              = module.acr.acr_id
  acr_login_server    = module.acr.acr_login_server

  task_name         = var.acr_task_name
  dockerfile_path   = var.dockerfile_path
  context_path      = var.context_path
  image_name        = var.runner_image_name
  default_image_tag = var.runner_image_tag

  git_repo_url       = var.git_repo_url
  git_branch         = var.git_branch
  enable_git_trigger = var.enable_git_trigger
  git_trigger_branch = var.git_trigger_branch

  cpu            = var.acr_task_cpu
  build_timeout  = var.acr_build_timeout
  base_image     = var.acr_base_image

  context_access_token = var.github_pat

  tags = var.tags
}


# Deploy Log Analytics workspace (conditionally)
module "log_analytics" {
  count = var.enable_monitoring ? 1 : 0
  source = "./modules/log_analytics"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_name      = var.log_analytics_workspace_name
  tags                = var.tags
}

# Deploy Container Apps environment module
module "container_apps_env" {
  source = "./modules/container_apps_env"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  environment_name    = var.container_app_environment_name
  tags                = var.tags

  # Optional monitoring - directly use the Log Analytics workspace
  enable_monitoring           = var.enable_monitoring
  log_analytics_workspace_id  = var.enable_monitoring ? module.log_analytics[0].workspace_id : null
}

# Deploy GitHub runner job module (conditional - only after image is built)
module "github_runner_job" {
  count  = var.deploy_runner_job ? 1 : 0
  source = "./modules/github_runner_job"

  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  container_app_environment_id = module.container_apps_env.environment_id
  acr_login_server             = module.acr.acr_login_server
  acr_id                       = module.acr.acr_id

  job_name          = var.github_runner_job_name
  runner_image_name = var.runner_image_name
  runner_image_tag  = var.runner_image_tag

  github_organization  = var.github_organization
  github_repository    = var.github_repository
  github_runner_labels = var.github_runner_labels
  github_runner_group  = var.github_runner_group
  github_pat           = var.github_pat

  cpu_allocation        = var.container_app_job_cpu
  memory_allocation     = var.container_app_job_memory
  job_execution_timeout = var.job_execution_timeout

  tags = var.tags
}