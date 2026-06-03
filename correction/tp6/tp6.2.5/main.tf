locals {
  suffix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.base_tags, {
    env = var.environment
  })
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.suffix}-f5"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  address_space            = ["10.95.0.0/16"]
  tags                     = local.common_tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app-${local.suffix}-f5"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.95.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.suffix}-f5"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

resource "azurerm_network_interface" "app" {
  count               = var.nic_count
  name                = "nic-app-${count.index}-${local.suffix}-f5"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "app" {
  for_each = toset(azurerm_network_interface.app[*].id)

  network_interface_id      = each.value
  network_security_group_id = azurerm_network_security_group.app.id
}
