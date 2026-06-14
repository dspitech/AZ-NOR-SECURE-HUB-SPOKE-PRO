###############################################################################
# AZ-NOR-SECURE-HUB-SPOKE - backend.tf
###############################################################################

terraform {
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state-norway"
  #   storage_account_name = "sttfstatenorway001"
  #   container_name       = "tfstate"
  #   key                  = "hub-spoke/norway.terraform.tfstate"
  # }

  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}
