# ==============================================================================
# AZ-NOR-SECURE-HUB-SPOKE - Makefile
# ==============================================================================

FIREWALL_RESOURCE_ID = /subscriptions/0dcea6ca-643a-469f-bb07-a45737b65645/resourceGroups/RG-ARCHITECTURE-COMPLET-NORWAY/providers/Microsoft.Network/azureFirewalls/fw-hub-central
ORPHAN_DIAG_SETTING  = diag-fw-to-loganalytics
RG                   = RG-ARCHITECTURE-COMPLET-NORWAY
VM_PROD              = vm-prod-01
VM_NONPROD           = vm-nonprod-01

.PHONY: help init validate lint security-scan plan apply output \
        vm-stop vm-start costs clean destroy bootstrap-backend cleanup-diag-setting

# ------------------------------------------------------------------------------
help:
	@echo ""
	@echo "  AZ-NOR-SECURE-HUB-SPOKE — Commandes disponibles"
	@echo "  ================================================"
	@echo "  make init              → terraform init"
	@echo "  make validate          → terraform validate"
	@echo "  make lint              → terraform fmt -recursive"
	@echo "  make security-scan     → checkov scan"
	@echo "  make plan              → terraform plan -out=tfplan"
	@echo "  make apply             → cleanup orphelin + terraform apply"
	@echo "  make output            → terraform output"
	@echo "  make vm-stop           → arrêt des VMs (économie crédits)"
	@echo "  make vm-start          → démarrage des VMs"
	@echo "  make costs             → résumé des ressources facturables"
	@echo "  make clean             → suppression fichiers temporaires"
	@echo "  make destroy           → destruction totale (confirmation requise)"
	@echo "  make bootstrap-backend → création Storage Account pour tfstate"
	@echo ""

# ------------------------------------------------------------------------------
init:
	@echo " Initialisation Terraform..."
	terraform init -upgrade

# ------------------------------------------------------------------------------
validate:
	@echo " Validation Terraform..."
	terraform fmt -recursive
	terraform validate

# ------------------------------------------------------------------------------
lint:
	@echo " Formatage Terraform..."
	terraform fmt -recursive

# ------------------------------------------------------------------------------
security-scan:
	@echo " Scan sécurité Checkov..."
	checkov -d . --framework terraform --soft-fail

# ------------------------------------------------------------------------------
plan:
	@echo " Plan Terraform..."
	terraform plan -var-file=terraform.tfvars -out=tfplan

# ------------------------------------------------------------------------------
# FIX 2 : Suppression automatique du diagnostic setting orphelin avant apply
# Évite l'erreur 409 Conflict sur azurerm_monitor_diagnostic_setting.firewall
cleanup-diag-setting:
	@echo " Vérification du diagnostic setting orphelin..."
	@if az monitor diagnostic-settings show \
		--name "$(ORPHAN_DIAG_SETTING)" \
		--resource "$(FIREWALL_RESOURCE_ID)" \
		--output none 2>/dev/null; then \
		echo "  Setting orphelin détecté → suppression en cours..."; \
		az monitor diagnostic-settings delete \
			--name "$(ORPHAN_DIAG_SETTING)" \
			--resource "$(FIREWALL_RESOURCE_ID)" \
			--yes; \
		echo " Setting supprimé."; \
	else \
		echo " Aucun conflit détecté, on continue."; \
	fi

# ------------------------------------------------------------------------------
apply: cleanup-diag-setting
	@echo " Déploiement Terraform..."
	terraform apply tfplan

# ------------------------------------------------------------------------------
output:
	@echo " Sorties Terraform..."
	terraform output

# ------------------------------------------------------------------------------
vm-stop:
	@echo "  Arrêt des VMs..."
	az vm deallocate --resource-group $(RG) --name $(VM_PROD) --no-wait
	az vm deallocate --resource-group $(RG) --name $(VM_NONPROD) --no-wait
	@echo " VMs en cours d'arrêt."

# ------------------------------------------------------------------------------
vm-start:
	@echo "  Démarrage des VMs..."
	az vm start --resource-group $(RG) --name $(VM_PROD) --no-wait
	az vm start --resource-group $(RG) --name $(VM_NONPROD) --no-wait
	@echo " VMs en cours de démarrage."

# ------------------------------------------------------------------------------
costs:
	@echo " Ressources facturables actives..."
	az resource list --resource-group $(RG) \
		--query "[].{Nom:name, Type:type, SKU:sku.name}" \
		--output table

# ------------------------------------------------------------------------------
clean:
	@echo " Nettoyage des fichiers temporaires..."
	rm -f tfplan
	rm -f .terraform.lock.hcl
	rm -rf .terraform/
	@echo " Nettoyage terminé."

# ------------------------------------------------------------------------------
destroy:
	@echo " DESTRUCTION TOTALE de l'infrastructure"
	@read -p "Tapez 'destroy' pour confirmer : " confirm && [ "$$confirm" = "destroy" ]
	terraform destroy -var-file=terraform.tfvars -auto-approve

# ------------------------------------------------------------------------------
bootstrap-backend:
	@echo "  Création du backend distant Azure Storage..."
	az group create --name rg-terraform-state-norway --location norwayeast
	az storage account create \
		--name sttfstatenorway001 \
		--resource-group rg-terraform-state-norway \
		--location norwayeast \
		--sku Standard_LRS \
		--allow-blob-public-access false
	az storage container create \
		--name tfstate \
		--account-name sttfstatenorway001
	@echo " Backend prêt. Décommente le bloc backend dans backend.tf puis relance make init."
