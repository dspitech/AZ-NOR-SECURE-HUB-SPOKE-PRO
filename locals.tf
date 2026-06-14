###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE - locals.tf
###############################################################################

locals {
  prefix   = "az-nor"
  env_hub  = "hub"
  env_prod = "prod"
  env_dev  = "nonprod"

  # Nommage réseau
  vnet_hub_name     = "vnet-${local.prefix}-${local.env_hub}-core"
  vnet_prod_name    = "vnet-${local.prefix}-spoke-${local.env_prod}"
  vnet_nonprod_name = "vnet-${local.prefix}-spoke-${local.env_dev}"

  snet_fw_name      = "AzureFirewallSubnet"  # Imposé par Azure
  snet_bastion_name = "AzureBastionSubnet"   # Imposé par Azure
  snet_prod_name    = "snet-${local.env_prod}-resources"
  snet_nonprod_name = "snet-${local.env_dev}-resources"

  # Nommage sécurité
  firewall_name        = "fw-${local.prefix}-${local.env_hub}-central"
  firewall_policy_name = "fw-policy-${local.prefix}-global"
  bastion_name         = "bastion-${local.prefix}-${local.env_hub}"
  route_table_name     = "rt-${local.prefix}-forced-to-firewall"

  # IPs publiques
  pip_firewall_name = "pip-fw-${local.prefix}-${local.env_hub}"
  pip_bastion_name  = "pip-bastion-${local.prefix}-${local.env_hub}"

  # NSG
  nsg_prod_name    = "nsg-${local.env_prod}-resources"
  nsg_nonprod_name = "nsg-${local.env_dev}-resources"

  # VMs
  vm_prod_name     = "vm-${local.env_prod}-01"
  vm_nonprod_name  = "vm-${local.env_dev}-01"
  nic_prod_name    = "nic-vm-${local.env_prod}-01"
  nic_nonprod_name = "nic-vm-${local.env_dev}-01"

  # Monitoring
  law_name             = "law-${local.prefix}-${local.env_hub}-norway"
  action_group_name    = "ag-${local.prefix}-security-alerts"
  alert_fw_denial_name = "alert-fw-${local.prefix}-high-denials"
  alert_fw_health_name = "alert-fw-${local.prefix}-health"

  common_tags = merge(var.tags, {
    DeployedWith = "Terraform"
    LastUpdated  = "2026-06-14"  # timestamp() remplacé pour éviter un plan différent à chaque exécution
  })
}
