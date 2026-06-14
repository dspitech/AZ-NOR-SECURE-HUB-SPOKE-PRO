###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE — variables.tf
###############################################################################

# ─── Général ──────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Nom du groupe de ressources Azure"
  type        = string
  default     = "RG-ARCHITECTURE-COMPLET-NORWAY"
}

variable "location" {
  description = "Région Azure de déploiement"
  type        = string
  default     = "norwayeast"
}

variable "tags" {
  description = "Tags appliqués à toutes les ressources"
  type        = map(string)
  default = {
    Project     = "AZ-NOR-SECURE-HUB-SPOKE"
    Environment = "HubSpoke"
    ManagedBy   = "Terraform"
    Region      = "NorwayEast"
  }
}

# ─── Réseau — Espaces d'adressage ─────────────────────────────────────────────

variable "hub_address_space" {
  description = "Espace d'adressage du Hub VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "hub_firewall_subnet" {
  description = "Subnet pour Azure Firewall (doit s'appeler AzureFirewallSubnet)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "hub_bastion_subnet" {
  description = "Subnet pour Azure Bastion (doit s'appeler AzureBastionSubnet)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "prod_address_space" {
  description = "Espace d'adressage du Spoke Production"
  type        = string
  default     = "192.168.0.0/16"
}

variable "prod_subnet" {
  description = "Subnet des ressources de production"
  type        = string
  default     = "192.168.1.0/24"
}

variable "nonprod_address_space" {
  description = "Espace d'adressage du Spoke Non-Production"
  type        = string
  default     = "172.16.0.0/12"
}

variable "nonprod_subnet" {
  description = "Subnet des ressources non-production"
  type        = string
  default     = "172.16.1.0/24"
}

variable "firewall_private_ip" {
  description = "Adresse IP privée statique du Azure Firewall (dans AzureFirewallSubnet)"
  type        = string
  default     = "10.0.1.4"
}

# ─── Machines Virtuelles ──────────────────────────────────────────────────────

variable "vm_size" {
  description = "Taille des machines virtuelles"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Nom d'utilisateur administrateur des VMs"
  type        = string
  default     = "azureadmin"
}

variable "admin_password" {
  description = "Mot de passe administrateur des VMs (sensible)"
  type        = string
  sensitive   = true
}
