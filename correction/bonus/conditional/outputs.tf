output "storage_account_name" {
  description = "Nom du Storage Account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "ID du Storage Account"
  value       = azurerm_storage_account.main.id
}

output "app_container_name" {
  description = "Nom du container app"
  value       = azurerm_storage_container.app.name
}

output "logs_container_name" {
  description = "Nom du container logs (null hors prod)"
  value       = var.environment == "prod" ? azurerm_storage_container.logs[0].name : null
}
