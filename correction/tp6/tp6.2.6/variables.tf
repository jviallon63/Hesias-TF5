variable "location" {
  type        = string
  description = "Azure region used by this lab."
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
    tp        = "unsupported-argument-lab"
  }
}

variable "vnet_cidr" {
  type        = string
  description = "CIDR used by the module-managed virtual network."
  default     = "10.86.0.0/16"
}
