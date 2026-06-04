output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "resource_group_tags" {
  description = "Resource Group tags"
  value       = azurerm_resource_group.main.tags
}
