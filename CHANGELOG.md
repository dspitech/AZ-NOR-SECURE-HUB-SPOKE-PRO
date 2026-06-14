# CHANGELOG

## [2.1.1] - 2026-06-14

### Fixed
- `main.tf` : `disable_bgp_route_propagation` remplacé par `bgp_route_propagation_enabled = false` (deprecated depuis azurerm v4)
- `main.tf` : Ajout de `lifecycle { create_before_destroy = true }` sur `azurerm_monitor_diagnostic_setting.firewall` pour éviter l'erreur 409 Conflict
- `locals.tf` : `timestamp()` remplacé par une date fixe dans les tags pour éviter un plan différent à chaque exécution
- `Makefile` : Ajout de `cleanup-diag-setting` appelé automatiquement avant `make apply`
- `.github/workflows/terraform.yml` : Étape de cleanup du diagnostic setting orphelin intégrée dans le job `apply`

## [2.1.0] - 2026-06-01

### Added
- Double couche de sécurité : Azure Firewall (L4/L7) + NSG par subnet (L4)
- 5 alertes Azure Monitor préconfigurées avec notifications email
- Nommage centralisé via `locals.tf`
- Pipeline CI/CD GitHub Actions (Validate → Checkov → Plan → Apply)
- Makefile avec commandes simplifiées

## [2.0.0] - 2026-01-01

### Added
- Architecture Hub-and-Spoke initiale sur Azure Norway East
- Azure Firewall Standard + Azure Bastion
- VNet Peering bidirectionnel Hub ↔ Spokes
- Log Analytics Workspace
- UDR forcé vers le Firewall
