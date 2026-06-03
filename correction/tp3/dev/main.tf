resource "azurerm_resource_group" "dev" {
  name     = "rg-tp3-dev"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_dev" {
  name                = "nsg-tp3-dev"
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.resource_group_name
}
