resource "azurerm_network_security_group" "res-0" {
  location            = "westeurope"
  name                = "nsg-tp3-dev"
  resource_group_name = "rg-tp3-dev"
}
