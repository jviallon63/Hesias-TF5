locals {
  network_watcher_name = "NetworkWatcher_${var.network_watcher_region}"
}

resource "azurerm_resource_group" "network_watcher" {
  name     = "NetworkWatcherRG"
  location = var.location
  tags     = var.base_tags
}

resource "azurerm_network_watcher" "default" {
  name                = local.network_watcher_name
  location            = var.network_watcher_region
  resource_group_name = azurerm_resource_group.network_watcher.name
  tags                = var.base_tags
}
