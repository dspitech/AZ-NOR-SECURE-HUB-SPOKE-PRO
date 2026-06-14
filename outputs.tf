###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE - outputs.tf
###############################################################################

output "resource_group_name"        { value = azurerm_resource_group.main.name }
output "hub_vnet_id"                { value = azurerm_virtual_network.hub.id }
output "prod_vnet_id"               { value = azurerm_virtual_network.prod.id }
output "nonprod_vnet_id"            { value = azurerm_virtual_network.nonprod.id }
output "firewall_private_ip"        { value = azurerm_firewall.main.ip_configuration[0].private_ip_address }
output "firewall_public_ip"         { value = azurerm_public_ip.firewall.ip_address }
output "bastion_public_ip"          { value = azurerm_public_ip.bastion.ip_address }
output "vm_prod_private_ip"         { value = azurerm_network_interface.prod.private_ip_address }
output "vm_nonprod_private_ip"      { value = azurerm_network_interface.nonprod.private_ip_address }
output "nsg_prod_id"                { value = azurerm_network_security_group.prod.id }
output "nsg_nonprod_id"             { value = azurerm_network_security_group.nonprod.id }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.main.id }
output "log_analytics_workspace_key" {
  value     = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive = true
}
