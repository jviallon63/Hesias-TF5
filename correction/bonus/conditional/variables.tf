variable "resource_group_name" {
  description = "Nom du Resource Group"
  type        = string
  default     = "rg-tp7-simple"
}

variable "location" {
  description = "Region Azure"
  type        = string
  default     = "westeurope"
}

variable "storage_account_prefix" {
  description = "Prefixe du Storage Account (sera complete par un suffixe aleatoire)"
  type        = string
  default     = "sttp7simple"
}

variable "environment" {
  description = "Environnement cible (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment doit etre dev, staging ou prod."
  }
}