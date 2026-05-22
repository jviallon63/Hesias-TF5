data "azurerm_subnet" "snet_staging" {
  name                 = "snet-staging"
  virtual_network_name = "vnet-tp3"
  resource_group_name  = "rg-tp3-shared"
}

resource "azurerm_resource_group" "staging" {
  name     = "rg-tp3-staging"
  location = "West Europe"
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-tp3-staging"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-rdp"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}
