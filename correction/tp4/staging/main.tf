data "azurerm_subnet" "snet_staging" {
  name                 = "snet-staging"
  virtual_network_name = "vnet-tp4"
  resource_group_name  = "rg-tp4-shared"
}

locals {
  security_rules = [
    { name = "allow-http",  access = "Allow", protocol = "Tcp", port = "80" },
    { name = "allow-https", access = "Allow", protocol = "Tcp", port = "443" },
    { name = "allow-ssh",   access = "Allow", protocol = "Tcp", port = "22" },
  ]
}

resource "azurerm_resource_group" "staging" {
  name     = "rg-tp4-staging"
  location = "West Europe"
}

module "nsg" {
  source = "../modules/nsg"

  name                = "nsg-tp4-staging"
  location            = azurerm_resource_group.staging.location
  resource_group_name = azurerm_resource_group.staging.name
  subnet_id           = data.azurerm_subnet.snet_staging.id
  security_rules      = local.security_rules
}
