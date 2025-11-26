variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    "Project"     = "GitHub-Runner-ACA"
    "Environment" = "Production"
    "ManagedBy"   = "Terraform"
  }
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "container_app_environment_name" {
  description = "Name of the Container Apps environment"
  type        = string
}

variable "github_runner_job_name" {
  description = "Name of the GitHub runner Container Apps job"
  type        = string
}

variable "github_organization" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name (leave empty for organization-level runners)"
  type        = string
  default     = ""
}

variable "github_runner_labels" {
  description = "Labels for the GitHub runner"
  type        = list(string)
  default     = ["aca-self-hosted"]
}

variable "github_runner_group" {
  description = "Runner group for the GitHub runner"
  type        = string
  default     = "default"
}

variable "runner_image_name" {
  description = "Name of the runner container image"
  type        = string
  default     = "github-runner"
}

variable "runner_image_tag" {
  description = "Tag of the runner container image"
  type        = string
  default     = "latest"
}

variable "github_pat" {
  description = "GitHub Personal Access Token for runner registration"
  type        = string
  sensitive   = true
}

variable "deploy_runner_job" {
  description = "Deploy the GitHub runner job (set to false for initial deployment before image is built)"
  type        = bool
  default     = false
}


variable "container_app_job_cpu" {
  description = "CPU allocation for the container app job"
  type        = string
  default     = "1.0"
}

variable "container_app_job_memory" {
  description = "Memory allocation for the container app job"
  type        = string
  default     = "2Gi"
}

variable "job_execution_timeout" {
  description = "Job execution timeout in seconds"
  type        = number
  default     = 3600
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor for the Container Apps environment"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for monitoring"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace to create"
  type        = string
  default     = "law-github-runner-aca"
}

# ACR Task Configuration Variables
variable "acr_task_name" {
  description = "Name of the ACR Task for building the runner image"
  type        = string
  default     = "build-github-runner"
}

variable "dockerfile_path" {
  description = "Path to the Dockerfile relative to repository root"
  type        = string
  default     = "docker/Dockerfile"
}

variable "context_path" {
  description = "Path to the build context relative to repository root"
  type        = string
  default     = "docker"
}

variable "git_repo_url" {
  description = "Git repository URL for ACR Task source (optional)"
  type        = string
  default     = ""
}

variable "git_branch" {
  description = "Git branch to build from"
  type        = string
  default     = "main"
}

variable "enable_git_trigger" {
  description = "Enable automatic trigger on Git commits"
  type        = bool
  default     = false
}

variable "git_trigger_branch" {
  description = "Git branch that triggers automatic builds"
  type        = string
  default     = "main"
}

variable "acr_task_cpu" {
  description = "CPU cores for ACR Task build"
  type        = number
  default     = 2
}

variable "acr_build_timeout" {
  description = "ACR Task build timeout in seconds"
  type        = number
  default     = 3600
}

variable "acr_base_image" {
  description = "Base image for build caching optimization"
  type        = string
  default     = "ubuntu:22.04"
}