output "nsg_id" {
  description = "ID du Network Security Group créé"
  value       = azurerm_network_security_group.main.id
}

output "nsg_name" {
  description = "Nom du Network Security Group créé"
  value       = azurerm_network_security_group.main.name
}