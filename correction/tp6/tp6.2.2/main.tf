locals {
  suffix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.base_tags, {
    env = var.environment
    tp  = "invalid-count-advanced"
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
  address_space       = ["10.72.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app-${local.suffix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.72.1.0/24"]
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-https-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "random_id" "sa" {
  byte_length = 2
}

resource "azurerm_storage_account" "logs" {
  name                     = "sttp7${random_id.sa.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.common_tags
}

resource "azurerm_management_lock" "storage_delete_protection" {
  count = var.enable_storage_lock && azurerm_storage_account.logs.primary_blob_endpoint != "" ? 1 : 0

  name       = "lock-sa-${local.suffix}"
  scope      = azurerm_storage_account.logs.id
  lock_level = "CanNotDelete"
  notes      = "Protection anti-suppression activee via Terraform"
}
