output "resource_group_name" {
  description = "Main resource group name."
  value       = azurerm_resource_group.main.name
}

output "vnet_name" {
  description = "Virtual network name."
  value       = azurerm_virtual_network.main.name
}

output "subnet_name" {
  description = "Application subnet name."
  value       = azurerm_subnet.web.name
}
