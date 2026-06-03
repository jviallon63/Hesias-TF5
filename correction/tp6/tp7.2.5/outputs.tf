output "network_watcher_rg_name" {
  description = "Resource group expected for default Network Watcher."
  value       = azurerm_resource_group.network_watcher.name
}

output "network_watcher_name" {
  description = "Expected default Network Watcher name for selected region."
  value       = azurerm_network_watcher.default.name
}
