###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE - variables.tf
###############################################################################

variable "resource_group_name" {
  type    = string
  default = "RG-ARCHITECTURE-COMPLET-NORWAY"
}

variable "location" {
  type    = string
  default = "norwayeast"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "AZ-NOR-SECURE-HUB-SPOKE"
    Environment = "HubSpoke"
    ManagedBy   = "Terraform"
    Region      = "NorwayEast"
    Version     = "2.1"
  }
}

variable "hub_address_space" {
  type    = string
  default = "10.0.0.0/16"
}

variable "hub_firewall_subnet" {
  type    = string
  default = "10.0.1.0/24"
}

variable "hub_bastion_subnet" {
  type    = string
  default = "10.0.2.0/24"
}

variable "prod_address_space" {
  type    = string
  default = "192.168.0.0/16"
}

variable "prod_subnet" {
  type    = string
  default = "192.168.1.0/24"
}

variable "nonprod_address_space" {
  type    = string
  default = "172.16.0.0/12"
}

variable "nonprod_subnet" {
  type    = string
  default = "172.16.1.0/24"
}

variable "firewall_private_ip" {
  type    = string
  default = "10.0.1.4"
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
  validation {
    condition     = contains(["Standard_B1s", "Standard_B1ms", "Standard_B2s", "Standard_D2s_v3"], var.vm_size)
    error_message = "Taille de VM non autorisée."
  }
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.admin_password) >= 12
    error_message = "Le mot de passe doit avoir au moins 12 caractères."
  }
}

variable "alert_email" {
  type    = string
  default = "admin@example.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Email invalide."
  }
}

variable "fw_denial_threshold" {
  type    = number
  default = 100
}

variable "log_retention_days" {
  type    = number
  default = 30
  validation {
    condition     = contains([30, 60, 90, 120, 180, 365], var.log_retention_days)
    error_message = "Rétention doit être : 30, 60, 90, 120, 180 ou 365 jours."
  }
}
