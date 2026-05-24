terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "tfstatejulien"
    container_name       = "tfstate"
    key                  = "shared.tfstate"
  }

}

provider "azurerm" {
  features {}
}