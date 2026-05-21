output "vm_private_ip" {
  description = "Adresse IP privée de la VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "resource_group_name" {
  description = "Nom du Resource Group"
  value       = azurerm_resource_group.rg.name
}

output "vm_id" {
  description = "ID Azure de la VM"
  value       = azurerm_linux_virtual_machine.vm.id
}