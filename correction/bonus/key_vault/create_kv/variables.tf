variable "resource_group_name" {
  description = "Nom du Resource Group Azure"
  type        = string
  default     = "rg-keyvault-demo"
}

variable "location" {
  description = "Région Azure"
  type        = string
  default     = "westeurope"
}

variable "key_vault_name" {
  description = "Nom du Key Vault (doit être globalement unique, 3-24 car.)"
  type        = string
  default     = "kv-demo-tf"
}

variable "secret_name" {
  description = "Nom du secret dans le Key Vault"
  type        = string
  default     = "generated-password"
}

variable "tags" {
  description = "Tags communs appliqués à toutes les ressources"
  type        = map(string)
  default = {
    environment = "demo"
    managed_by  = "terraform"
  }
}
