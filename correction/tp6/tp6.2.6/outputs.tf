output "vnet_name" {
  value       = module.network.vnet_name
  description = "Virtual network name created by the module."
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Main resource group name."
}
