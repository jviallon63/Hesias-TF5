resource "azurerm_resource_group" "main" {
  name     = "rg-bonus-moved"
  location = "westeurope"

  tags = {
    environment = "demo"
    managed_by  = "terraform"
  }
}