resource "azurerm_resource_group" "shared" {
  name     = "rg-tp3-shared"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-tp3"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet_staging" {
  name                 = "snet-staging"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "snet_prod" {
  name                 = "snet-prod"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}