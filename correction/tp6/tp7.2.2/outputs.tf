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
  value       = azurerm_subnet.app.name
}

output "storage_account_name" {
  description = "Storage account name for logs."
  value       = azurerm_storage_account.logs.name
}
