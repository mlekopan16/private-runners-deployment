variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "acr_id" {
  description = "Resource ID of the Azure Container Registry"
  type        = string
}

variable "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  type        = string
}

variable "task_name" {
  description = "Name of the ACR Task"
  type        = string
}

variable "dockerfile_path" {
  description = "Path to the Dockerfile"
  type        = string
  default     = "docker/Dockerfile"
}

variable "context_path" {
  description = "Path to the build context"
  type        = string
  default     = "docker"
}

variable "image_name" {
  description = "Name of the image to build"
  type        = string
}

variable "default_image_tag" {
  description = "Default tag for the image"
  type        = string
  default     = "latest"
}

variable "git_repo_url" {
  description = "Git repository URL for context (optional)"
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
  description = "Git branch to trigger builds from"
  type        = string
  default     = "main"
}

variable "cpu" {
  description = "CPU cores for the build task"
  type        = number
  default     = 2
}

variable "build_timeout" {
  description = "Build timeout in seconds"
  type        = number
  default     = 3600
}

variable "base_image" {
  description = "Base image for the build (for caching optimization)"
  type        = string
  default     = "ubuntu:22.04"
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}

variable "context_access_token" {
  description = "Context access token for ACR Task (empty string for managed identity)"
  type        = string
  default     = ""
}