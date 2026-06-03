variable "location" {
  type        = string
  description = "Azure region used by stable resources."
  default     = "westeurope"
}

variable "project_name" {
  type        = string
  description = "Project prefix used in resource names."
  default     = "tp6"
}

variable "environment" {
  type        = string
  description = "Environment name used in naming and tagging."
  default     = "lab"
}

variable "base_tags" {
  type        = map(string)
  description = "Base tags applied to all resources."
  default = {
    owner     = "formation"
    managedBy = "terraform"
  }
}

variable "enable_storage_lock" {
  type        = bool
  description = "Enable deletion lock on storage account."
  default     = true
}
