data "azurerm_subnet" "snet_prod" {
  name                 = "snet-prod"
  virtual_network_name = "vnet-tp4"
  resource_group_name  = "rg-tp4-shared"
}

resource "azurerm_resource_group" "prod" {
  name     = "rg-tp4-prod"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_prod" {
  name                = "nsg-tp4-prod"
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
}

resource "azurerm_subnet_network_security_group_association" "prod" {
  subnet_id                 = data.azurerm_subnet.snet_prod.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}