data "azurerm_resource_group" "rg" {
  name = "rg-tp2-dev"
}

data "azurerm_virtual_machine" "vm" {
  name                = "vm-tp2-dev"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_virtual_machine_extension" "nginx" {
  name                 = "install-nginx"
  virtual_machine_id   = data.azurerm_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = jsonencode({
    commandToExecute = "apt-get update && apt-get install -y nginx && systemctl enable nginx && systemctl start nginx"
  })
}