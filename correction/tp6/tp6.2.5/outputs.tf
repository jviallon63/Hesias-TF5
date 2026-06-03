output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Main resource group name."
}

output "vnet_name" {
  value       = azurerm_virtual_network.main.name
  description = "Virtual network name."
}

output "nic_names" {
  value       = azurerm_network_interface.app[*].name
  description = "NIC names created by the lab."
}
