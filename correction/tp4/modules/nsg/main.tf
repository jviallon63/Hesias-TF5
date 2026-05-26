resource "azurerm_network_security_group" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = { for idx, rule in var.security_rules : rule.name => merge(rule, { priority = 100 + idx * 10 }) }
    iterator = rule
    content {
      name                       = rule.key
      priority                   = rule.value.priority
      direction                  = "Inbound"
      access                     = rule.value.access
      protocol                   = rule.value.protocol
      source_port_range          = "*"
      destination_port_range     = rule.value.port
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = var.subnet_id
  network_security_group_id = azurerm_network_security_group.main.id
}