terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "local" {
    path = "shared.tfstate"
  }

}

provider "azurerm" {
  features {}
}