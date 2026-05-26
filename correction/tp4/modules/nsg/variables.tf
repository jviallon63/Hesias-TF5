variable "name" {
  type        = string
  description = "Nom du Network Security Group"
}

variable "location" {
  type        = string
  description = "Région Azure"

  validation {
    condition = contains(
      ["westeurope"],
      var.location
    )
    error_message = "Location doit être : westeurope."
  }

}

variable "resource_group_name" {
  type        = string
  description = "Nom du Resource Group"
}

variable "subnet_id" {
  type        = string
  description = "ID du subnet auquel associer le NSG"
}

variable "security_rules" {
  type = list(object({
    name     = string
    access   = string
    protocol = string
    port     = string
  }))
  description = "Liste des règles NSG à créer"

  validation {
    condition     = alltrue([for r in var.security_rules : contains(["Allow", "Deny"], r.access)])
    error_message = "Chaque règle doit avoir access = \"Allow\" ou \"Deny\"."
  }

  validation {
    condition     = alltrue([for r in var.security_rules : contains(["Tcp", "Udp", "Icmp", "*"], r.protocol)])
    error_message = "Chaque règle doit avoir protocol = \"Tcp\", \"Udp\", \"Icmp\" ou \"*\"."
  }
}