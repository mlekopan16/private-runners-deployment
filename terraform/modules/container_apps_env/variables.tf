variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment_name" {
  description = "Name of the Container Apps environment"
  type        = string
}

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}

variable "enable_monitoring" {
  description = "Enable Azure Monitor for the Container Apps environment"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for monitoring"
  type        = string
  default     = ""
}