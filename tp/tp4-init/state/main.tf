

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate"
  location = "West Europe"
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "tfstatejulien"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = "West Europe"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      permanent_delete_enabled = true
      days = 14
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id  = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}