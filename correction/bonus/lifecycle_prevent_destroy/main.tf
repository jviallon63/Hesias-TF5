resource "random_string" "postgres_suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "random_password" "admin" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location_rg

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.postgres_name_prefix}${random_string.postgres_suffix.result}"
  resource_group_name    = azurerm_resource_group.main.name
  location               = var.location_db
  version                = "16"
  administrator_login    = var.admin_login
  administrator_password = random_password.admin.result
  zone                   = "3"

  storage_mb = 32768
  sku_name   = "B_Standard_B1ms"

  lifecycle {
    prevent_destroy = true
  }
}
