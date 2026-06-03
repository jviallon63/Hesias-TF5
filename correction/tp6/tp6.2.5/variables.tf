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

variable "nic_count" {
  type        = number
  description = "Number of NICs to create for the lab scenario."
  default     = 2
}

variable "base_tags" {
  type        = map(string)
  description = "Base tags applied to all resources."
  default = {
    owner     = "formation"
    managedBy = "terraform"
    tp        = "invalid-foreach-lab"
  }
}
