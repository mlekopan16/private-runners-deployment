variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "container_app_environment_id" {
  description = "ID of the Container Apps environment"
  type        = string
}

variable "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  type        = string
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
  type        = string
}



variable "job_name" {
  description = "Name of the Container Apps job"
  type        = string
}

variable "runner_image_name" {
  description = "Name of the runner container image"
  type        = string
}

variable "runner_image_tag" {
  description = "Tag of the runner container image"
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
}

variable "github_runner_group" {
  description = "Runner group for the GitHub runner"
  type        = string
}

variable "github_pat" {
  description = "GitHub Personal Access Token for runner registration"
  type        = string
  sensitive   = true
}



variable "cpu_allocation" {
  description = "CPU allocation for the container app job"
  type        = string
}

variable "memory_allocation" {
  description = "Memory allocation for the container app job"
  type        = string
}

variable "job_execution_timeout" {
  description = "Job execution timeout in seconds"
  type        = number
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}