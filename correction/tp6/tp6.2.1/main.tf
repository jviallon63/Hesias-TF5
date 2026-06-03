locals {
  suffix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.base_tags, {
    env = var.environment
    tp  = "cycle-lab"
  })
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.60.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-http-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(local.common_tags, {
    route_table_marker = azurerm_route_table.app.name
  })
}

resource "azurerm_route_table" "app" {
  name                = "rt-app-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name           = "internal-default"
    address_prefix = "10.60.0.0/16"
    next_hop_type  = "VnetLocal"
  }

  tags = merge(local.common_tags, {
    nsg_marker = azurerm_network_security_group.app.name
  })
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app-${local.suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.60.1.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_route_table_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  route_table_id = azurerm_route_table.app.id
}
