variable "rg_name" {
  type        = string
  description = "Resource group name where VNet is deployed."
}

variable "location" {
  type        = string
  description = "Azure location for module resources."
}

variable "vnet_name" {
  type        = string
  description = "Virtual network name."
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the virtual network."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to module resources."
}
