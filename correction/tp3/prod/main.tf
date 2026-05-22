data "azurerm_subnet" "snet_prod" {
  name                 = "snet-prod"
  virtual_network_name = "vnet-tp3"
  resource_group_name  = "rg-tp3-shared"
}

resource "azurerm_resource_group" "prod" {
  name     = "rg-tp3-prod"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_prod" {
  name                = "nsg-tp3-prod"
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name

  security_rule {
    name                       = "deny-all"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "prod" {
  subnet_id                 = data.azurerm_subnet.snet_prod.id
  network_security_group_id = azurerm_network_security_group.nsg_prod.id
}