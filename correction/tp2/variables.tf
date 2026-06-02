variable "location" {
  type        = string
  description = "Région Azure pour toutes les ressources"
  default     = "West Europe"
  
  validation {
    condition     = contains(["West Europe"], var.location)
    error_message = "La location ne peut être que 'West Europe'."
  }
}

variable "environment" {
  type        = string
  description = "Environnement de déploiement (dev, staging, prod)"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "La variable environment doit être 'dev', 'staging' ou 'prod'."
  }
}
/*
variable "vm_size" {
  type        = string
  description = "Taille de la machine virtuelle Azure"
  default     = "Standard_B2s_v2"
}

variable "admin_password" {
  type        = string
  description = "Mot de passe administrateur de la VM"
  sensitive   = true
}
*/