resource_group_name   = "RG-ARCHITECTURE-COMPLET-NORWAY"
location              = "norwayeast"
admin_password        = "VotreMotDePasseComplex2026!"
vm_size               = "Standard_B1s"
admin_username        = "azureadmin"
alert_email           = "votre.email@domaine.com"
fw_denial_threshold   = 100
log_retention_days    = 30

hub_address_space     = "10.0.0.0/16"
hub_firewall_subnet   = "10.0.1.0/24"
hub_bastion_subnet    = "10.0.2.0/24"
prod_address_space    = "192.168.0.0/16"
prod_subnet           = "192.168.1.0/24"
nonprod_address_space = "172.16.0.0/12"
nonprod_subnet        = "172.16.1.0/24"
firewall_private_ip   = "10.0.1.4"

tags = {
  Project     = "AZ-NOR-SECURE-HUB-SPOKE"
  Environment = "HubSpoke"
  ManagedBy   = "Terraform"
  Region      = "NorwayEast"
  CostCenter  = "INFRA-001"
}
