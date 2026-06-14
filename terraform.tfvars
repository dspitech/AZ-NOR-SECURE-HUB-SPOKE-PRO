###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE — terraform.tfvars.example
# Copiez ce fichier en terraform.tfvars et adaptez les valeurs.
# ⚠️  Ne jamais committer terraform.tfvars en production (contient des secrets).
###############################################################################

resource_group_name = "RG-ARCHITECTURE-COMPLET-NORWAY"
location            = "norwayeast"

# Mot de passe administrateur — doit respecter la complexité Azure :
# min 12 caractères, maj + min + chiffre + caractère spécial
admin_password = "VotreMotDePasseComplex2026!"

# Taille des VMs — Standard_B1s pour les tests, ajuster pour la prod
vm_size        = "Standard_B1s"
admin_username = "azureadmin"

# Segmentation réseau (laisser les valeurs par défaut ou adapter)
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
