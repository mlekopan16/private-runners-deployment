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

variable "tags" {
  description = "Tags to apply to the resource"
  type        = map(string)
  default     = {}
}

variable "sku" {
  description = "SKU of the Azure Container Registry"
  type        = string
  default     = "Standard"
}

variable "admin_enabled" {
  description = "Whether admin user is enabled"
  type        = bool
  default     = false
}