output "secret_value" {
  description = "Valeur du secret recuperee directement depuis Azure Key Vault"
  value       = data.azurerm_key_vault_secret.password.value
  sensitive   = true
}
