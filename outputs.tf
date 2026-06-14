###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE — outputs.tf
###############################################################################

output "resource_group_name" {
  description = "Nom du groupe de ressources"
  value       = azurerm_resource_group.main.name
}

output "hub_vnet_id" {
  description = "ID du Hub VNet"
  value       = azurerm_virtual_network.hub.id
}

output "prod_vnet_id" {
  description = "ID du Spoke Production VNet"
  value       = azurerm_virtual_network.prod.id
}

output "nonprod_vnet_id" {
  description = "ID du Spoke Non-Production VNet"
  value       = azurerm_virtual_network.nonprod.id
}

output "firewall_private_ip" {
  description = "IP privée du Azure Firewall"
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "IP publique du Azure Firewall"
  value       = azurerm_public_ip.firewall.ip_address
}

output "bastion_public_ip" {
  description = "IP publique du Azure Bastion"
  value       = azurerm_public_ip.bastion.ip_address
}

output "vm_prod_private_ip" {
  description = "IP privée de la VM Production"
  value       = azurerm_network_interface.prod.private_ip_address
}

output "vm_nonprod_private_ip" {
  description = "IP privée de la VM Non-Production"
  value       = azurerm_network_interface.nonprod.private_ip_address
}

output "log_analytics_workspace_id" {
  description = "ID du Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_key" {
  description = "Clé primaire du Log Analytics Workspace (sensible)"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}
