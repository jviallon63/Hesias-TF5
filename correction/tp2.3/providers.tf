terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Backend local explicite (par défaut, mais bonne pratique de le déclarer)
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}