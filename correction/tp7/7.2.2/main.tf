resource "azurerm_resource_group" "rg" {
  name     = "rg-bonus-moved"
  location = "westeurope"

  tags = {
    environment = "demo"
    managed_by  = "terraform"
  }
}

#moved {
#  from = azurerm_resource_group.rg
#  to   = azurerm_resource_group.main
#}

#module "rg" {
#  source = "./modules/rg"
#}

#moved {
#  from = azurerm_resource_group.main
#  to   = module.rg.azurerm_resource_group.main
#}