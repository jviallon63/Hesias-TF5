output "snet_name" {
  description = "Noms des subnets créés"
  value       = azurerm_subnet.main[*].name
}

#output "snet_name" {
#  description = "Noms des subnets créés"
#  value = {
#    for k, v in azurerm_subnet.main :
#    k => v.name
#  }
#}