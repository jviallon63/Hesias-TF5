resource "azurerm_resource_group" "shared" {
  name     = "rg-tp4-shared"
  location = "West Europe"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-tp4"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "main" {
  count                = length(var.subnets)

  name                 = "snet-${var.subnets[count.index].name}"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnets[count.index].address_prefix]
}

#resource "azurerm_subnet" "main" {
#  for_each             = var.subnets

#  name                 = "snet-${each.key}"
#  resource_group_name  = azurerm_resource_group.shared.name
#  virtual_network_name = azurerm_virtual_network.vnet.name
#  address_prefixes     = [each.value.address_prefix]
#}