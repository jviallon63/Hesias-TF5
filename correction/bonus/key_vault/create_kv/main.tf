data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "random_password" "secret" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*()-_=+[]{}|;:,.<>?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  rbac_authorization_enabled   = false

  # Accès réseau (autoriser par défaut, à restreindre en prod)
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "Purge",
  ]
}

resource "azurerm_key_vault_secret" "generated_password" {
  name         = var.secret_name
  value        = random_password.secret.result
  key_vault_id = azurerm_key_vault.kv.id

  # Expiration dans 1 an (optionnel)
  expiration_date = timeadd(timestamp(), "8760h")

  content_type = "password"

  tags = var.tags

  # Attendre que l'access policy soit prête avant de créer le secret
  depends_on = [azurerm_key_vault_access_policy.deployer]
}
