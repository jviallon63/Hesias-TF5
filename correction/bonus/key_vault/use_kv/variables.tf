variable "key_vault_name" {
  description = "Nom du Key Vault cible"
  type        = string
  default     = "kv-demo-tf"
}

variable "resource_group_name" {
  description = "Nom du resource group contenant le Key Vault"
  type        = string
  default     = "rg-keyvault-demo"
}

variable "secret_name" {
  description = "Nom du secret a lire dans Key Vault"
  type        = string
  default     = "generated-password"
}
