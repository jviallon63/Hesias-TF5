terraform {
  required_providers {
    random = {
      source = "hashicorp/random"
    }
  }
}

variable "suffix" {
  type = string
}

resource "random_pet" "main" {
  length    = 2
  separator = "-"
  prefix    = var.suffix
}

output "pet_name" {
  value = random_pet.main.id
}
