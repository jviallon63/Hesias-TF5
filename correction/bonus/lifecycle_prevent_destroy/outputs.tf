output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "postgres_server_name" {
  description = "PostgreSQL Flexible Server name"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgres_admin_password" {
  description = "Generated admin password"
  value       = random_password.admin.result
  sensitive   = true
}
