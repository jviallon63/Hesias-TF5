#variable "subnets" {
#  type = list(object({
#    name             = string
#    address_prefix   = string
#  }))
#  description = "Liste des subnets à créer"
#
#  default = [
#    { name = "staging", address_prefix = "10.0.1.0/24" },
#    { name = "prod",    address_prefix = "10.0.2.0/24" },
#  ]
#}

variable "subnets" {
  type = map(object({
    address_prefix = string
  }))
  description = "Liste des subnets à créer"

  default = {
    staging = { address_prefix = "10.0.1.0/24" }
    prod    = { address_prefix = "10.0.2.0/24" }
  }
}