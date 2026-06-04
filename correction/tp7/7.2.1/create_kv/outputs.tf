output "key_vault_id" {
  description = "ID du Key Vault"
  value       = azurerm_key_vault.kv.id
}

output "key_vault_uri" {
  description = "URI du Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

output "secret_id" {
  description = "ID du secret (URL versionnée)"
  value       = azurerm_key_vault_secret.generated_password.id
}

output "secret_version" {
  description = "Version actuelle du secret"
  value       = azurerm_key_vault_secret.generated_password.version
}

# Le mot de passe lui-même est marqué sensitive — ne s'affiche pas en clair
output "generated_password" {
  description = "Mot de passe généré (sensitive)"
  value       = random_password.secret.result
  sensitive   = true
}
