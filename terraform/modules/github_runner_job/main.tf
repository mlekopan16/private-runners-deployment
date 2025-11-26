# Create a user-assigned managed identity for the Container App job
resource "azurerm_user_assigned_identity" "runner_identity" {
  name                = "${var.job_name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Assign ACR pull role to the managed identity
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.runner_identity.principal_id
}

# Generate a unique runner name using a random suffix
resource "random_id" "runner_suffix" {
  keepers = {
    # Generate a new suffix only when the job name changes
    job_name = var.job_name
  }

  byte_length = 4
}

# Container App Job for GitHub Runner
resource "azurerm_container_app_job" "github_runner" {
  name                         = var.job_name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = var.container_app_environment_id
  replica_timeout_in_seconds   = var.job_execution_timeout
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.runner_identity.id]
  }

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  # Managed identity with AcrPull role handles ACR authentication automatically
  # No explicit registry credentials needed
  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.runner_identity.id
  }

  template {
    container {
      name   = "github-runner"
      image  = "${var.acr_login_server}/${var.runner_image_name}:${var.runner_image_tag}"
      cpu    = var.cpu_allocation
      memory = var.memory_allocation

      # Environment variables for the GitHub runner
      env {
        name  = "GITHUB_OWNER"
        value = var.github_organization
      }

      env {
        name  = "GITHUB_REPOSITORY"
        value = var.github_repository
      }

      env {
        name  = "RUNNER_NAME"
        value = "aca-runner-${random_id.runner_suffix.hex}"
      }

      env {
        name  = "RUNNER_LABELS"
        value = join(",", var.github_runner_labels)
      }

      env {
        name  = "RUNNER_GROUP"
        value = var.github_runner_group
      }

      # Secret for GitHub token
      env {
        name        = "GITHUB_TOKEN"
        secret_name = "github-token-secret"
      }
    }
  }

  # Define secrets at the job level
  secret {
    name  = "github-token-secret"
    value = var.github_pat
  }

  depends_on = [
    azurerm_role_assignment.acr_pull
  ]
}