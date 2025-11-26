# Create ACR Task for building the GitHub runner image
resource "azurerm_container_registry_task" "build_runner" {
  name                  = var.task_name
  container_registry_id = var.acr_id
  tags                  = var.tags

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # Platform configuration
  platform {
    os = "Linux"
  }

  # Base image for caching
  base_image_trigger {
    name                        = var.base_image
    update_trigger_payload_type = "Default"
    type                        = "Runtime"
  }

  # Build context and Dockerfile
  docker_step {
    context_path         = var.context_path
    dockerfile_path      = var.dockerfile_path
    image_names          = ["${var.image_name}:{{.Run.ID}}", "${var.image_name}:${var.default_image_tag}"]
    context_access_token = var.context_access_token
  }

  # Timeout configuration
  timeout_in_seconds = var.build_timeout

  # Logging configuration
  log_template = "acr/tasks/{{.Run.ID}}/logs/{{.Step.ID}}"

  # Caching configuration for faster builds
  is_system_task = false
}