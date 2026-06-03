locals {
  suffix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.base_tags, {
    env = var.environment
  })
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.suffix}-mod"
  location = var.location
  tags     = local.common_tags
}

module "network" {
  source = "./modules/network"

  rg_name       = azurerm_resource_group.main.name
  location      = azurerm_resource_group.main.location
  vnet_name     = "vnet-${local.suffix}-mod"
  address_space = [var.vnet_cidr]
  enable_ddos = true
  tags          = local.common_tags

}
