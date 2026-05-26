data "azurerm_subnet" "snet_prod" {
  name                 = "snet-prod"
  virtual_network_name = "vnet-tp4"
  resource_group_name  = "rg-tp4-shared"
}

locals {
  security_rules = [
    { name = "deny-all", access = "Deny", protocol = "*", port = "*" },
  ]
}

resource "azurerm_resource_group" "prod" {
  name     = "rg-tp4-prod"
  location = "West Europe"
}

module "nsg" {
  source = "../modules/nsg"

  name                = "nsg-tp4-prod"
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
  subnet_id           = data.azurerm_subnet.snet_prod.id
  security_rules      = local.security_rules
}
