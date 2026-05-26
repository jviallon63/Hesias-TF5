data "azurerm_subnet" "snet_staging" {
  name                 = "snet-staging"
  virtual_network_name = "vnet-tp4"
  resource_group_name  = "rg-tp4-shared"
}

resource "azurerm_resource_group" "staging" {
  name     = "rg-tp4-staging"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_staging" {
  name                = "nsg-tp4-staging"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
}

resource "azurerm_subnet_network_security_group_association" "staging" {
  subnet_id                 = data.azurerm_subnet.snet_staging.id
  network_security_group_id = azurerm_network_security_group.nsg_staging.id
}