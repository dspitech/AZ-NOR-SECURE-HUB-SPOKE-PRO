# AZ-NOR-SECURE-HUB-SPOKEL

<div align="center">

![Azure](https://img.shields.io/badge/Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Infrastructure as Code](https://img.shields.io/badge/IaC-Infrastructure%20as%20Code-blue?style=for-the-badge)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white)
![Security](https://img.shields.io/badge/Security-Checkov_Scan-brightgreen?style=for-the-badge)

**Architecture Hub-and-Spoke sécurisée avec inspection de flux centralisée**

*Version 2.1 - Terraform · NSG · Monitoring · CI/CD*

[Architecture](#-architecture) • [Composants](#-composants) • [Déploiement](#-déploiement) • [Sécurité](#-sécurité) • [CI/CD](#-cicd-github-actions)


</div>

---

## Table des matières

1. [Introduction](#1-introduction)
2. [Concepts fondamentaux](#2-concepts-fondamentaux)
3. [Glossaire technique](#3-glossaire-technique)
4. [Architecture](#4-architecture)
5. [Composants déployés](#5-composants-déployés)
6. [Segmentation réseau et règles de sécurité](#6-segmentation-réseau-et-règles-de-sécurité)
7. [Structure du projet](#7-structure-du-projet)
8. [Code source Terraform](#8-code-source-terraform)
9. [Prérequis](#9-prérequis)
10. [Déploiement](#10-déploiement)
11. [CI/CD GitHub Actions](#11-cicd-github-actions)
12. [Sécurité](#12-sécurité)
13. [Monitoring et alertes](#13-monitoring-et-alertes)
14. [Gestion des coûts](#14-gestion-des-coûts)
15. [Bonnes pratiques Terraform](#15-bonnes-pratiques-terraform)
16. [Dépannage](#16-dépannage)
17. [Exercices pratiques](#17-exercices-pratiques)
18. [FAQ](#18-faq)
19. [Ressources d'apprentissage](#19-ressources-dapprentissage)

---

## 1. Introduction

Ce projet déploie une architecture réseau Hub-and-Spoke sécurisée sur Microsoft Azure, entièrement pilotée par Terraform, dans la région Norway East. Il est conçu à la fois comme une référence d'architecture production et comme un support pédagogique pour apprendre les fondamentaux du cloud networking, de l'Infrastructure as Code et de la sécurité réseau.

### À qui s'adresse ce projet

- Étudiants en informatique, cloud ou cybersécurité
- Ingénieurs découvrant Azure ou Terraform
- Équipes souhaitant une base solide pour une architecture multi-environnements

### Parcours d'apprentissage recommandé

| Étape | Durée estimée | Objectif |
|-------|--------------|---------|
| Lire la section Concepts | 30 min | Comprendre le modèle Hub-and-Spoke |
| Étudier le Glossaire | 20 min | Maîtriser le vocabulaire Azure |
| Analyser l'Architecture | 30 min | Visualiser les connexions entre composants |
| Déployer le projet | 45 min | Exécuter et observer le résultat |
| Explorer le code | 1h+ | Modifier et comprendre les effets |

---

## 2. Concepts fondamentaux

### 2.1 Qu'est-ce qu'une architecture Hub-and-Spoke

Une architecture Hub-and-Spoke est un modèle réseau dans lequel un nœud central, appelé Hub, sert de point de passage obligatoire pour tout le trafic entre les branches périphériques, appelées Spokes. Chaque Spoke est un réseau isolé qui ne peut communiquer avec les autres Spokes qu'en transitant par le Hub.

Analogie : imaginez un aéroport international (le Hub) avec des lignes aériennes vers différentes villes (les Spokes). Pour aller de la ville A à la ville B, tous les passagers transitent par l'aéroport. De la même façon, tout paquet réseau transite par le Firewall du Hub, ce qui permet une inspection et un contrôle centralisés.

Avantages principaux :
- Inspection centralisée : un seul point de contrôle pour tout le trafic
- Contrôle granulaire : les règles sont définies une fois et s'appliquent partout
- Isolation stricte : les Spokes ne communiquent jamais directement entre eux

### 2.2 Les trois environnements de ce projet

```
HUB (Cœur du réseau) - 10.0.0.0/16
  Azure Firewall : inspecte tout le trafic
  Azure Bastion : accès SSH/RDP sécurisé sans IP publique
  Log Analytics : centralisation des journaux
        |                          |
        v                          v
PRODUCTION                   NON-PRODUCTION
192.168.0.0/16               172.16.0.0/12
Données réelles               Tests et développement
NSG strict                   NSG modéré
```

### 2.3 La défense en profondeur

La défense en profondeur est une stratégie de sécurité qui consiste à empiler plusieurs couches de protection indépendantes. Si une couche est contournée ou compromise, les autres restent actives et continuent de protéger le système.

```
Couche 1 : Azure Firewall (L4 et L7)
  Inspecte chaque paquet, bloque les menaces connues

Couche 2 : UDR - Routage forcé
  Rend impossible tout contournement du Firewall

Couche 3 : NSG - Network Security Groups
  Filtrage secondaire directement attaché à chaque subnet

Couche 4 : VMs sans adresse IP publique
  Aucune machine n'est accessible directement depuis Internet

Couche 5 : Azure Bastion
  Seule porte d'entrée pour l'administration, connexion chiffrée SSL/TLS
```

### 2.4 Cycle de vie d'un paquet réseau

Voici ce qui se passe lorsqu'une VM de production tente de contacter une VM de non-production :

```
VM Production (192.168.1.4) envoie un paquet vers VM Non-Prod (172.16.1.4)

Étape 1 : La VM consulte sa table de routage (UDR)
  -> Règle : tout trafic externe va vers 10.0.1.4 (Firewall)

Étape 2 : Le Firewall reçoit le paquet
  -> Vérifie la règle Allow-Spoke-to-Spoke
  -> Source 192.168.0.0/16 : autorisé
  -> Destination 172.16.0.0/12 : autorisé
  -> Action : transfert vers le subnet non-prod

Étape 3 : Le NSG du subnet non-prod analyse le paquet
  -> Vérifie toutes les règles dans l'ordre de priorité
  -> Si aucune règle Allow ne correspond : Deny-All s'applique

Étape 4 : La VM Non-Prod reçoit le paquet ou le rejette
```

### 2.5 Pourquoi des plages IP distinctes

Chaque environnement utilise une plage d'adresses IP entièrement séparée. Cette segmentation est fondamentale : un attaquant qui compromet un environnement ne peut pas atteindre un autre environnement via une simple communication réseau, car les plages ne se chevauchent pas et le routage entre elles est strictement contrôlé.

| Environnement | Plage IP | Rôle |
|--------------|---------|------|
| Hub | 10.0.0.0/16 | Réseau central, services partagés |
| Production | 192.168.0.0/16 | Données réelles, clients |
| Non-Production | 172.16.0.0/12 | Tests, développement |

---

## 3. Glossaire technique

### A

**Azure Bastion** : Service Azure qui fournit un accès SSH et RDP sécurisé aux machines virtuelles sans qu'elles aient besoin d'une adresse IP publique. La connexion transite par le portail Azure via un tunnel HTTPS chiffré. Cela supprime l'exposition directe des VMs sur Internet.

**Azure Firewall** : Pare-feu cloud managé par Azure, capable d'inspecter le trafic aux couches 4 (transport : TCP/UDP) et 7 (application : HTTP, DNS). Il offre une journalisation complète et une gestion centralisée des règles.

### B

**Backend Terraform** : Emplacement de stockage du fichier d'état Terraform (terraform.tfstate). Peut être local ou distant (Azure Storage, Terraform Cloud). Un backend distant est essentiel pour le travail en équipe et la CI/CD.

### D

**Défense en profondeur** : Approche de sécurité qui empile plusieurs mécanismes de protection indépendants. Si un mécanisme échoue, les autres continuent d'assurer la protection. Voir section 2.3.

### I

**IaC - Infrastructure as Code** : Pratique consistant à définir et gérer l'infrastructure (serveurs, réseaux, bases de données) sous forme de fichiers de code, plutôt qu'en cliquant dans une interface graphique. L'IaC permet la reproductibilité, la versionnabilité et l'automatisation.

**IP privée** : Adresse IP non routable sur Internet (plages 10.x.x.x, 172.16.x.x, 192.168.x.x). Utilisée pour la communication interne entre ressources dans un réseau privé.

**IP publique** : Adresse IP routable sur Internet, accessible depuis n'importe où dans le monde. Dans ce projet, seuls le Firewall et Bastion en possèdent une.

### K

**KQL - Kusto Query Language** : Langage de requête utilisé dans Azure Monitor et Log Analytics pour interroger les journaux et métriques. Syntaxe similaire à SQL mais orientée flux de données et séries temporelles.

### N

**NIC - Network Interface Card** : Interface réseau virtuelle associée à une VM. C'est à elle que sont attachés l'adresse IP privée et le NSG au niveau de l'interface.

**NSG - Network Security Group** : Ensemble de règles de filtrage réseau appliqué à un subnet ou une interface réseau. Chaque règle définit une action (Allow ou Deny) pour une combinaison source/destination/port/protocole. Les règles sont évaluées par ordre de priorité croissant (100 avant 200, etc.).

### P

**Peering VNet** : Connexion directe et privée entre deux réseaux virtuels Azure. Le trafic entre les deux VNets transite par le backbone Microsoft, sans passer par Internet. Dans ce projet, quatre peerings sont créés : Hub vers Prod, Prod vers Hub, Hub vers NonProd, NonProd vers Hub.

**Provider Terraform** : Plugin Terraform qui traduit le code HCL en appels API vers un fournisseur cloud (Azure, AWS, GCP, etc.). Le provider azurerm est utilisé dans ce projet.

### R

**Resource Group** : Conteneur logique Azure regroupant toutes les ressources d'un projet. Permet de les gérer, surveiller et facturer ensemble. La suppression du Resource Group supprime toutes les ressources qu'il contient.

**Route Table - UDR (User Defined Route)** : Table de routage personnalisée qui remplace ou complète le routage par défaut d'Azure. Dans ce projet, une UDR force tout le trafic sortant des Spokes vers le Firewall, rendant impossible de le contourner.

### S

**Service Principal** : Identité de service dans Azure Active Directory, équivalente à un compte technique. Utilisé pour l'automatisation et la CI/CD afin d'éviter d'utiliser des identifiants personnels.

**SKU** : Référence de niveau de service (Basic, Standard, Premium) pour une ressource Azure. Le SKU détermine les fonctionnalités disponibles et le tarif. Par exemple, Azure Firewall Standard supporte les règles L7, contrairement au Basic.

**Subnet** : Subdivision d'un VNet avec sa propre plage d'adresses IP. Permet d'organiser les ressources et d'appliquer des politiques de sécurité différentes selon les groupes.

### T

**Terraform** : Outil d'IaC open source édité par HashiCorp. Il permet de décrire une infrastructure dans des fichiers HCL, puis de la créer, modifier ou détruire de façon idempotente.

**Terraform State** : Fichier JSON (terraform.tfstate) dans lequel Terraform mémorise l'état réel de l'infrastructure déployée. Il sert à comparer l'état désiré (code) avec l'état réel (cloud) pour déterminer quelles modifications appliquer.

### V

**VNet - Virtual Network** : Réseau privé isolé dans Azure, équivalent du VPC (Virtual Private Cloud) dans AWS. Un VNet contient des subnets et peut être connecté à d'autres VNets via le peering.

**VM - Virtual Machine** : Ordinateur virtuel exécutant un système d'exploitation complet (Linux ou Windows), hébergé sur l'infrastructure physique de Microsoft.

---

## 4. Architecture

### Topologie réseau

![Architecture](./Topologie_Reseau.jpg)

### Flux 1 : Communication entre Spokes (Prod vers NonProd)

```
VM Prod (192.168.1.4) -> VM NonProd (172.16.1.4)

1. VM Prod consulte l'UDR
   -> Règle 0.0.0.0/0 : next hop = 10.0.1.4 (Firewall)

2. Azure Firewall reçoit le paquet
   -> Règle Allow-Spoke-to-Spoke : source OK, destination OK
   -> Transfère vers le subnet nonprod

3. NSG nonprod évalue les règles
   -> Allow-SSH-From-Bastion : source = 10.0.2.0/24, ne correspond pas
   -> Allow-HTTP-HTTPS : ports 80/443 uniquement, si port 22 -> ne correspond pas
   -> Deny-All-Inbound : s'applique -> paquet rejeté

Résultat : BLOQUÉ (attendu et normal pour SSH prod->nonprod)
```

Ce comportement confirme que le NSG nonprod protège bien les VMs : seul le Bastion peut initier une session SSH, pas les autres VMs.

### Flux 2 : Accès administrateur via Bastion

```
Administrateur (Internet) -> VM via Bastion

1. Admin s'authentifie sur le portail Azure (Azure AD + MFA)
2. Bastion établit un tunnel HTTPS depuis 10.0.2.0/24
3. Paquet atteint le NSG du subnet cible
   -> Règle Allow-SSH-From-Bastion : source 10.0.2.0/24, port 22 -> ALLOW
4. Admin est connecté en SSH sans que la VM ait d'IP publique
```

### Flux 3 : Tentative d'accès SSH non autorisée (Prod vers NonProd port 22)

```
VM Prod (192.168.1.4) -> VM NonProd port 22

Étapes 1 et 2 : identiques au Flux 1 (Firewall laisse passer)

3. NSG nonprod :
   -> Allow-SSH-From-Bastion : source attendue = 10.0.2.0/24
      source réelle = 192.168.1.0/24 -> NE CORRESPOND PAS
   -> Deny-All-Inbound : s'applique

Résultat : CONNEXION REFUSÉE. La VM nonprod ne reçoit même pas le paquet.
```

---

## 5. Composants déployés

| Ressource | Nom dans Azure | Adresse / Détail |
|-----------|--------------|-----------------|
| Hub VNet | vnet-az-nor-hub-core | 10.0.0.0/16 |
| Spoke Prod VNet | vnet-az-nor-spoke-prod | 192.168.0.0/16 |
| Spoke NonProd VNet | vnet-az-nor-spoke-nonprod | 172.16.0.0/12 |
| Azure Firewall | fw-az-nor-hub-central | IP privée 10.0.1.4 - SKU Standard |
| Firewall Policy | fw-policy-az-nor-global | Règle Allow inter-spoke |
| Azure Bastion | bastion-az-nor-hub | SKU Standard |
| NSG Production | nsg-prod-resources | Filtrage L4 subnet prod |
| NSG Non-Production | nsg-nonprod-resources | Filtrage L4 subnet nonprod |
| Route Table UDR | rt-az-nor-forced-to-firewall | 0.0.0.0/0 -> 10.0.1.4 |
| Log Analytics | law-az-nor-hub-norway | 30 jours, PerGB2018 |
| VM Production | vm-prod-01 | Ubuntu 20.04, Standard_B1s |
| VM Non-Production | vm-nonprod-01 | Ubuntu 20.04, Standard_B1s |
| Action Group alertes | ag-az-nor-security-alerts | Notifications email |

---

## 6. Segmentation réseau et règles de sécurité

### Subnets

| Environnement | Plage VNet | Subnet ressources | NSG attaché |
|--------------|-----------|-------------------|------------|
| Hub | 10.0.0.0/16 | FW: 10.0.1.0/24 / Bastion: 10.0.2.0/24 | Aucun (géré par Azure) |
| Production | 192.168.0.0/16 | 192.168.1.0/24 | nsg-prod-resources |
| Non-Production | 172.16.0.0/12 | 172.16.1.0/24 | nsg-nonprod-resources |

### Règles de sécurité

| Couche | Nom de la règle | Source | Destination | Protocole/Port | Action |
|--------|----------------|--------|-------------|---------------|--------|
| Firewall | Allow-Spoke-to-Spoke | 192.168.0.0/16 et 172.16.0.0/12 | 192.168.0.0/16 et 172.16.0.0/12 | Tous | Allow |
| NSG Prod - Entrant | Allow-SSH-From-Bastion | 10.0.2.0/24 | 192.168.1.0/24 - port 22 | TCP | Allow |
| NSG Prod - Entrant | Allow-Internal-From-Nonprod | 172.16.0.0/12 | 192.168.1.0/24 | Tous | Allow |
| NSG Prod - Entrant | Deny-All-Inbound | Tous | Tous | Tous | Deny |
| NSG Prod - Sortant | Allow-Outbound-To-Nonprod | 192.168.1.0/24 | 172.16.0.0/12 | Tous | Allow |
| NSG Prod - Sortant | Deny-All-Outbound | Tous | Tous | Tous | Deny |
| NSG NonProd - Entrant | Allow-SSH-From-Bastion | 10.0.2.0/24 | 172.16.1.0/24 - port 22 | TCP | Allow |
| NSG NonProd - Entrant | Allow-HTTP-HTTPS | 192.168.0.0/16 | 172.16.1.0/24 - ports 80/443 | TCP | Allow |
| NSG NonProd - Entrant | Deny-All-Inbound | Tous | Tous | Tous | Deny |
| NSG NonProd - Sortant | Deny-All-Outbound | Tous | Tous | Tous | Deny |

---

## 7. Structure du projet

```
az-nor-secure-hub-spoke/
|-- .github/
|   `-- workflows/
|       `-- terraform.yml       Pipeline CI/CD GitHub Actions
|-- backend.tf                  Provider Terraform et configuration backend distant
|-- locals.tf                   Nommage centralisé de toutes les ressources
|-- main.tf                     Firewall, Bastion, VMs, UDR, Log Analytics
|-- network.tf                  VNets, Subnets, VNet Peerings
|-- nsg.tf                      Network Security Groups et règles de filtrage
|-- monitoring.tf               Action Group et 5 alertes Azure Monitor
|-- variables.tf                Variables avec validations intégrées
|-- outputs.tf                  Sorties post-déploiement
|-- terraform.tfvars.modele     Modèle de configuration à copier
|-- Makefile                    Commandes simplifiées
|-- CHANGELOG.md                Historique des versions
|-- .gitignore                  Protection des fichiers sensibles
`-- README.md                   Ce fichier
```

---

## 8. Code source Terraform

### backend.tf

Ce fichier configure deux choses : la version minimale de Terraform requise, les providers nécessaires (azurerm et random), et optionnellement le backend distant pour stocker l'état Terraform dans Azure Storage.

```hcl
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
```

**Explication ligne par ligne**

`required_version = ">= 1.5.0"` : Garantit que la personne qui exécute ce code dispose d'une version de Terraform suffisamment récente. Cela évite des comportements inattendus dus à des différences entre versions.

`version = "~> 3.100"` : Le symbole `~>` signifie "toute version compatible avec 3.100", c'est-à-dire 3.100, 3.101, 3.102, etc., mais pas 4.x. C'est une contrainte de version permissive pour les mises à jour mineures mais stricte pour les majeures.

`prevent_deletion_if_contains_resources = true` : Empêche Terraform de supprimer accidentellement un Resource Group qui contient encore des ressources. Protection contre les suppressions involontaires.

`delete_os_disk_on_deletion = true` : Quand Terraform supprime une VM, le disque OS est aussi supprimé automatiquement. Sans cette option, les disques orphelins continueraient à générer des frais.

**Bootstrap du backend distant** (à exécuter une seule fois avant `terraform init`) :
```powershell
az group create --name rg-terraform-state-norway --location norwayeast

az storage account create --name sttfstatenorway001 `
  --resource-group rg-terraform-state-norway `
  --location norwayeast `
  --sku Standard_LRS `
  --allow-blob-public-access false

az storage container create --name tfstate --account-name sttfstatenorway001
```

---

### locals.tf

Ce fichier centralise tous les noms de ressources du projet en un seul endroit. Modifier le prefix ou un nom ici se répercute automatiquement sur l'ensemble des autres fichiers Terraform.

```hcl
locals {
  prefix   = "az-nor"
  env_hub  = "hub"
  env_prod = "prod"
  env_dev  = "nonprod"

  # Nommage réseau
  vnet_hub_name     = "vnet-${local.prefix}-${local.env_hub}-core"
  vnet_prod_name    = "vnet-${local.prefix}-spoke-${local.env_prod}"
  vnet_nonprod_name = "vnet-${local.prefix}-spoke-${local.env_dev}"

  snet_fw_name      = "AzureFirewallSubnet"
  snet_bastion_name = "AzureBastionSubnet"
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
    LastUpdated  = timestamp()
  })
}
```

**Explication**

`locals {}` : Bloc Terraform permettant de définir des valeurs locales calculées, non modifiables depuis l'extérieur. Contrairement aux variables, les locals ne peuvent pas être surchargés par l'utilisateur.

`prefix = "az-nor"` : Convention de nommage indiquant le fournisseur cloud (az = Azure) et la région (nor = Norway). Toutes les ressources héritent de ce préfixe pour être identifiables dans un portail Azure ou une facturation.

`"vnet-${local.prefix}-${local.env_hub}-core"` : Interpolation de chaînes en HCL. La valeur résultante sera `vnet-az-nor-hub-core`. Utiliser des références locales plutôt que des chaînes en dur garantit la cohérence : si le prefix change, tous les noms changent en même temps.

`snet_fw_name = "AzureFirewallSubnet"` : Azure impose ce nom exact pour le subnet du Firewall. Si ce nom est différent, le Firewall ne peut pas être déployé dans ce subnet.

`timestamp()` : Fonction Terraform qui retourne la date et l'heure courantes au format RFC3339. Attention : cette fonction est évaluée à chaque `terraform plan`, ce qui peut provoquer des différences perpétuelles dans le plan. Pour un environnement stable, remplacez par une date fixe en dur.

`merge(var.tags, {...})` : Fusionne deux maps de tags. Les tags définis dans var.tags sont complétés par les tags locaux. Si une clé existe dans les deux, la valeur du second map écrase la première.

---

### main.tf

Ressources principales : Resource Group, Log Analytics, Firewall, Bastion, Route Table, Machines Virtuelles.

```hcl
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.law_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_firewall_policy" "main" {
  name                = local.firewall_policy_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "rcg-internal-traffic"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100

  network_rule_collection {
    name     = "Allow-Internal-Traffic"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "Allow-Spoke-to-Spoke"
      protocols             = ["ICMP", "TCP", "UDP"]
      source_addresses      = [var.prod_address_space, var.nonprod_address_space]
      destination_addresses = [var.prod_address_space, var.nonprod_address_space]
      destination_ports     = ["*"]
    }
  }
}

resource "azurerm_public_ip" "firewall" {
  name                = local.pip_firewall_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "main" {
  name                = local.firewall_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig-fw"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-fw-${local.prefix}"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallApplicationRule" }
  metric { category = "AllMetrics" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_public_ip" "bastion" {
  name                = local.pip_bastion_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = local.bastion_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig-bastion"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_route_table" "forced_firewall" {
  name                          = local.route_table_name
  resource_group_name           = azurerm_resource_group.main.name
  location                      = azurerm_resource_group.main.location
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "route-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "prod" {
  subnet_id      = azurerm_subnet.prod_resources.id
  route_table_id = azurerm_route_table.forced_firewall.id
}

resource "azurerm_subnet_route_table_association" "nonprod" {
  subnet_id      = azurerm_subnet.nonprod_resources.id
  route_table_id = azurerm_route_table.forced_firewall.id
}

resource "azurerm_network_interface" "prod" {
  name                = local.nic_prod_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig-prod"
    subnet_id                     = azurerm_subnet.prod_resources.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "prod" {
  name                            = local.vm_prod_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.prod.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "nonprod" {
  name                = local.nic_nonprod_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig-nonprod"
    subnet_id                     = azurerm_subnet.nonprod_resources.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "nonprod" {
  name                            = local.vm_nonprod_name
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.nonprod.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}
```

**Explication**

`azurerm_resource_group.main` : Point de départ de toute l'infrastructure. Toutes les autres ressources référencent ce bloc via `azurerm_resource_group.main.name` et `.location`, ce qui garantit la cohérence et évite les erreurs de frappe.

`azurerm_log_analytics_workspace.main` : Crée l'espace de travail dans lequel tous les journaux (Firewall, NSG) seront envoyés. Le SKU `PerGB2018` signifie que la facturation se fait au volume de données ingérées. `retention_in_days` contrôle combien de temps les logs sont conservés avant d'être automatiquement supprimés.

`azurerm_firewall_policy.main` et `azurerm_firewall_policy_rule_collection_group.main` : La politique est le conteneur de règles, et le groupe de collections est l'organisation interne de ces règles. Une politique peut être partagée entre plusieurs Firewalls. La `priority = 100` sur le groupe signifie qu'il est évalué en premier si d'autres groupes existent.

`source_addresses` et `destination_addresses` dans la règle Allow-Spoke-to-Spoke : En listant les deux plages dans les deux champs, on autorise le trafic dans les deux sens (Prod vers NonProd et NonProd vers Prod) avec une seule règle. Sans cela, il faudrait deux règles distinctes.

`azurerm_public_ip.firewall` avec `allocation_method = "Static"` : Une IP statique ne change pas si la ressource est arrêtée puis redémarrée. Le Firewall exige une IP publique Standard statique. Une IP dynamique changerait à chaque redémarrage, ce qui casserait les configurations DNS ou les listes blanches externes.

`azurerm_monitor_diagnostic_setting.firewall` : Connecte les journaux du Firewall vers Log Analytics. Sans ce bloc, le Firewall génère des logs mais ils ne sont envoyés nulle part. `lifecycle { create_before_destroy = true }` évite une erreur 409 (conflit) lors de la recréation du paramétrage diagnostique.

`bgp_route_propagation_enabled = false` dans la Route Table : BGP (Border Gateway Protocol) permet à Azure de propager automatiquement des routes depuis des passerelles VPN. En le désactivant, on empêche ces routes auto-propagées d'entrer en conflit avec la route forcée vers le Firewall. La route manuelle 0.0.0.0/0 -> Firewall doit être la seule qui s'applique.

`address_prefix = "0.0.0.0/0"` avec `next_hop_type = "VirtualAppliance"` : La notation 0.0.0.0/0 signifie "toutes les destinations". Ainsi, peu importe où la VM veut envoyer son trafic, il transitera systématiquement par l'appliance virtuelle (le Firewall) à l'adresse `next_hop_in_ip_address`.

`disable_password_authentication = false` : Par défaut Azure recommande les clés SSH pour Linux. Ce projet utilise un mot de passe pour simplifier l'accès pédagogique. En production, préférez les clés SSH et passez cette valeur à `true`.

---

### network.tf

VNets, Subnets et quatre VNet Peerings bidirectionnels.

```hcl
resource "azurerm_virtual_network" "hub" {
  name                = local.vnet_hub_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = local.snet_fw_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet]
}

resource "azurerm_subnet" "bastion" {
  name                 = local.snet_bastion_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_bastion_subnet]
}

resource "azurerm_virtual_network" "prod" {
  name                = local.vnet_prod_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.prod_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "prod_resources" {
  name                 = local.snet_prod_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.prod.name
  address_prefixes     = [var.prod_subnet]
}

resource "azurerm_virtual_network" "nonprod" {
  name                = local.vnet_nonprod_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.nonprod_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "nonprod_resources" {
  name                 = local.snet_nonprod_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.nonprod.name
  address_prefixes     = [var.nonprod_subnet]
}

# Peerings Hub <-> Prod
resource "azurerm_virtual_network_peering" "hub_to_prod" {
  name                         = "peer-hub-to-prod"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.prod.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "prod_to_hub" {
  name                         = "peer-prod-to-hub"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.prod.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# Peerings Hub <-> Non-Prod
resource "azurerm_virtual_network_peering" "hub_to_nonprod" {
  name                         = "peer-hub-to-nonprod"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.nonprod.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "nonprod_to_hub" {
  name                         = "peer-nonprod-to-hub"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.nonprod.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}
```

**Explication**

`address_space = [var.hub_address_space]` : La valeur est une liste même si elle ne contient qu'un seul élément, car Azure supporte plusieurs plages d'adresses par VNet. Utiliser une variable plutôt qu'une valeur en dur permet de modifier la plage dans terraform.tfvars sans toucher au code.

Pourquoi les noms de subnets Firewall et Bastion sont imposés : Azure identifie les subnets dédiés aux services managés par leur nom exact. `AzureFirewallSubnet` et `AzureBastionSubnet` sont des noms réservés. Si vous les modifiez, le déploiement du Firewall ou du Bastion échouera avec une erreur de validation.

`allow_forwarded_traffic = true` dans les peerings : Sans cette option, un VNet peeré refuse les paquets dont l'adresse source n'appartient pas à ce VNet. Puisque les paquets transitent par le Firewall du Hub avant d'arriver dans les Spokes, leur adresse source est celle du Hub, pas du Spoke émetteur. Cette option est donc indispensable au bon fonctionnement du routage forcé.

Pourquoi quatre peerings pour deux connexions : Le peering VNet n'est pas bidirectionnel par défaut. Il faut créer explicitement un peering dans chaque sens. `hub_to_prod` permet au Hub d'envoyer des paquets vers Prod, et `prod_to_hub` permet à Prod d'envoyer des paquets vers le Hub. Sans les deux, la communication ne fonctionne que dans un sens.

---

### nsg.tf

Network Security Groups avec règles de filtrage L4 et envoi des journaux vers Log Analytics.

```hcl
resource "azurerm_network_security_group" "prod" {
  name                = local.nsg_prod_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-From-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.hub_bastion_subnet
    destination_address_prefix = var.prod_subnet
  }

  security_rule {
    name                       = "Allow-Internal-From-Nonprod"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.nonprod_address_space
    destination_address_prefix = var.prod_subnet
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Outbound-To-Nonprod"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.prod_subnet
    destination_address_prefix = var.nonprod_address_space
  }

  security_rule {
    name                       = "Deny-All-Outbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "prod" {
  subnet_id                 = azurerm_subnet.prod_resources.id
  network_security_group_id = azurerm_network_security_group.prod.id
}

resource "azurerm_network_security_group" "nonprod" {
  name                = local.nsg_nonprod_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-From-Bastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.hub_bastion_subnet
    destination_address_prefix = var.nonprod_subnet
  }

  security_rule {
    name                       = "Allow-HTTP-HTTPS-Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = var.prod_address_space
    destination_address_prefix = var.nonprod_subnet
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Outbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nonprod" {
  subnet_id                 = azurerm_subnet.nonprod_resources.id
  network_security_group_id = azurerm_network_security_group.nonprod.id
}

resource "azurerm_monitor_diagnostic_setting" "nsg_prod" {
  name                       = "diag-nsg-prod"
  target_resource_id         = azurerm_network_security_group.prod.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "NetworkSecurityGroupEvent" }
  enabled_log { category = "NetworkSecurityGroupRuleCounter" }
}

resource "azurerm_monitor_diagnostic_setting" "nsg_nonprod" {
  name                       = "diag-nsg-nonprod"
  target_resource_id         = azurerm_network_security_group.nonprod.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "NetworkSecurityGroupEvent" }
  enabled_log { category = "NetworkSecurityGroupRuleCounter" }
}
```

**Explication**

`priority` : Les règles NSG sont évaluées dans l'ordre croissant des priorités. La priorité 100 est évaluée avant la 110, qui est évaluée avant la 4096. Dès que le paquet correspond à une règle (Allow ou Deny), l'évaluation s'arrête. La plage valide est de 100 à 4096. Deux règles ne peuvent pas avoir la même priorité dans le même NSG.

`source_port_range = "*"` : Le port source est le port éphémère utilisé par l'émetteur pour initier une connexion (généralement un port aléatoire au-dessus de 1024). Il est presque toujours défini comme `*` car on ne peut pas prédire quel port l'OS émetteur va choisir. C'est le port de destination qui identifie le service (22 = SSH, 80 = HTTP, 443 = HTTPS).

`Deny-All-Inbound` à la priorité 4096 : C'est une "règle de base" ou "default deny". Tout trafic qui ne correspond à aucune règle Allow précédente est bloqué. Azure applique également ses propres règles par défaut (nommées 65000, 65001, 65500), mais les positionner à 4096 garantit que les règles explicites sont toujours évaluées en premier.

`azurerm_subnet_network_security_group_association` : Créer un NSG ne suffit pas - il faut l'associer explicitement au subnet. Sans ce bloc d'association, le NSG existe dans Azure mais n'est appliqué à aucune interface réseau et n'a aucun effet.

`NetworkSecurityGroupEvent` vs `NetworkSecurityGroupRuleCounter` : Le premier log enregistre chaque événement (connexion acceptée ou refusée), le second comptabilise le nombre de fois que chaque règle a été évaluée sur une période. Les deux sont complémentaires pour le diagnostic et la conformité.

---

### monitoring.tf

Action Group de notification email et cinq alertes Azure Monitor couvrant les scénarios critiques.

```hcl
resource "azurerm_monitor_action_group" "security" {
  name                = local.action_group_name
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "sec-alerts"
  tags                = var.tags

  email_receiver {
    name                    = "admin-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

# Alerte 1 : Volume de refus Firewall élevé (tentative d'intrusion)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "fw_high_denials" {
  name                = local.alert_fw_denial_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]
  severity             = 2
  enabled              = true
  description          = "Alerte si le Firewall refuse plus de ${var.fw_denial_threshold} connexions en 5 minutes"

  criteria {
    query = <<-QUERY
      AZFWNetworkRule
      | where Action == "Deny"
      | summarize DenialCount = count() by bin(TimeGenerated, 5m)
      | where DenialCount > ${var.fw_denial_threshold}
    QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action { action_groups = [azurerm_monitor_action_group.security.id] }
}

# Alerte 2 : Disponibilité Firewall < 95%
resource "azurerm_monitor_metric_alert" "fw_health" {
  name                = local.alert_fw_health_name
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_firewall.main.id]
  description         = "Disponibilité Firewall < 95%"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Network/azureFirewalls"
    metric_name      = "FirewallHealth"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 95
  }

  action { action_group_id = azurerm_monitor_action_group.security.id }
}

# Alerte 3 : CPU VM Prod > 85%
resource "azurerm_monitor_metric_alert" "vm_prod_cpu" {
  name                = "alert-cpu-vm-prod"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.prod.id]
  description         = "CPU vm-prod-01 > 85%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action { action_group_id = azurerm_monitor_action_group.security.id }
}

# Alerte 4 : CPU VM Non-Prod > 85%
resource "azurerm_monitor_metric_alert" "vm_nonprod_cpu" {
  name                = "alert-cpu-vm-nonprod"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_virtual_machine.nonprod.id]
  description         = "CPU vm-nonprod-01 > 85%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action { action_group_id = azurerm_monitor_action_group.security.id }
}
```

**Explication**

`azurerm_monitor_action_group` : Un Action Group est un ensemble de destinataires et d'actions à déclencher quand une alerte se déclenche. Il peut inclure des emails, des SMS, des webhooks, des runbooks Azure Automation, etc. Le `short_name` (12 caractères max) est utilisé dans les notifications SMS.

`use_common_alert_schema = true` : Standardise le format JSON des notifications. Toutes les alertes utilisent le même schéma, ce qui simplifie le traitement automatisé (par exemple, un webhook qui parse les alertes).

`evaluation_frequency = "PT5M"` et `window_duration = "PT5M"` : Le format PT5M signifie "période de 5 minutes" (ISO 8601). `evaluation_frequency` définit à quelle fréquence la requête est exécutée. `window_duration` définit la fenêtre de temps sur laquelle les données sont analysées. Ici, toutes les 5 minutes, on analyse les 5 dernières minutes de logs.

Requête KQL dans l'alerte Firewall : La table `AZFWNetworkRule` contient les événements de règles réseau du Firewall. La requête filtre les événements `Deny`, les groupe par tranches de 5 minutes, compte les occurrences et ne retient que les tranches dépassant le seuil. Si au moins une tranche dépasse le seuil pendant la fenêtre d'évaluation, l'alerte se déclenche.

`severity` : Niveaux de 0 (Critical) à 4 (Verbose). Sévérité 1 = Error, sévérité 2 = Warning. La santé du Firewall (severity 1) est plus critique qu'une surcharge CPU (severity 2), ce qui se reflète dans la couleur et la priorité des alertes dans le portail Azure Monitor.

`frequency = "PT1M"` vs `window_size = "PT5M"` pour les alertes métriques : Azure Monitor évalue la métrique toutes les minutes (`PT1M`), mais calcule la moyenne sur les 5 dernières minutes (`PT5M`). Une moyenne lissée sur 5 minutes évite les fausses alertes dues à un pic très court et isolé.

---

### variables.tf

Variables Terraform typées avec contraintes de validation intégrées.

```hcl
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

variable "hub_address_space"    { type = string; default = "10.0.0.0/16" }
variable "hub_firewall_subnet"  { type = string; default = "10.0.1.0/24" }
variable "hub_bastion_subnet"   { type = string; default = "10.0.2.0/24" }
variable "prod_address_space"   { type = string; default = "192.168.0.0/16" }
variable "prod_subnet"          { type = string; default = "192.168.1.0/24" }
variable "nonprod_address_space"{ type = string; default = "172.16.0.0/12" }
variable "nonprod_subnet"       { type = string; default = "172.16.1.0/24" }
variable "firewall_private_ip"  { type = string; default = "10.0.1.4" }

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
  validation {
    condition     = contains(["Standard_B1s", "Standard_B1ms", "Standard_B2s", "Standard_D2s_v3"], var.vm_size)
    error_message = "Taille de VM non autorisée. Choisir parmi : Standard_B1s, Standard_B1ms, Standard_B2s, Standard_D2s_v3."
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
    error_message = "Adresse email invalide."
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
    error_message = "La rétention doit être l'une des valeurs suivantes : 30, 60, 90, 120, 180 ou 365 jours."
  }
}
```

**Explication**

`type = string` / `type = number` / `type = map(string)` : Terraform est un langage typé. Spécifier le type évite les erreurs de conversion implicite. Par exemple, passer `"30"` (chaîne) à une variable de type `number` déclenchera une erreur claire plutôt qu'un comportement inattendu.

`sensitive = true` sur `admin_password` : Masque la valeur dans toutes les sorties Terraform (`terraform plan`, `terraform output`, journaux CI/CD). La valeur reste lisible dans le fichier d'état, d'où l'importance de protéger l'accès au backend.

`validation {}` : Bloc de validation exécuté lors de chaque `terraform plan`. Si la condition est fausse, Terraform affiche le message `error_message` et arrête le plan avant de contacter Azure. C'est une protection en amont qui évite les erreurs de déploiement coûteuses (ressource créée à moitié, frais engagés).

`contains([...], var.vm_size)` : La fonction `contains` retourne `true` si la valeur de `var.vm_size` est dans la liste. Cela restreint les tailles de VM déployables, utile pour contrôler les coûts sur un compte Students ou respecter une politique d'entreprise.

`can(regex(...))` sur `alert_email` : `can()` retourne `true` si la fonction imbriquée ne génère pas d'erreur. `regex()` génère une erreur si le pattern ne correspond pas. Combinées, elles forment une validation de format d'email sans faire planter Terraform.

---

### outputs.tf

Sorties affichées après le déploiement.

```hcl
output "resource_group_name"         { value = azurerm_resource_group.main.name }
output "hub_vnet_id"                 { value = azurerm_virtual_network.hub.id }
output "prod_vnet_id"                { value = azurerm_virtual_network.prod.id }
output "nonprod_vnet_id"             { value = azurerm_virtual_network.nonprod.id }
output "firewall_private_ip"         { value = azurerm_firewall.main.ip_configuration[0].private_ip_address }
output "firewall_public_ip"          { value = azurerm_public_ip.firewall.ip_address }
output "bastion_public_ip"           { value = azurerm_public_ip.bastion.ip_address }
output "vm_prod_private_ip"          { value = azurerm_network_interface.prod.private_ip_address }
output "vm_nonprod_private_ip"       { value = azurerm_network_interface.nonprod.private_ip_address }
output "nsg_prod_id"                 { value = azurerm_network_security_group.prod.id }
output "nsg_nonprod_id"              { value = azurerm_network_security_group.nonprod.id }
output "log_analytics_workspace_id"  { value = azurerm_log_analytics_workspace.main.id }
output "log_analytics_workspace_key" { value = azurerm_log_analytics_workspace.main.primary_shared_key; sensitive = true }
```

**Explication**

Les outputs sont affichées dans le terminal après `terraform apply` et consultables à tout moment avec `terraform output`. Elles servent de référence rapide et peuvent être consommées par d'autres configurations Terraform via `terraform_remote_state`.

`ip_configuration[0].private_ip_address` : Le Firewall peut avoir plusieurs configurations IP. L'index `[0]` désigne la première. Dans ce projet, une seule configuration IP est définie, donc l'index 0 est toujours correct.

`sensitive = true` sur la clé Log Analytics : La clé primaire est un secret d'authentification. La marquer sensible évite qu'elle soit affichée en clair dans les logs de la pipeline CI/CD.

---

### terraform.tfvars.modele

Modèle de fichier de configuration à copier et adapter.

```hcl
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
```

Ce fichier ne doit jamais être commité dans Git car il contient des secrets (`admin_password`). Il est listé dans `.gitignore`. Copiez-le sous le nom `terraform.tfvars` et renseignez vos valeurs.

---

## 9. Prérequis

### Outils à installer

| Outil | Version minimale | Installation |
|-------|-----------------|-------------|
| Terraform | >= 1.5.0 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | >= 2.50.0 | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Make | Toute version | apt-get install make / brew install make |
| Checkov | Toute version | pip install checkov |

### Accès Azure requis

- Abonnement Azure actif (compte Students, payant ou trial)
- Rôle Contributor ou Owner sur l'abonnement

### Connaissances recommandées

| Niveau | Prérequis |
|--------|---------|
| Débutant | Notions de réseau : IP, subnet, port, protocole |
| Intermédiaire | Bases HCL/Terraform |
| Avancé | Linux, SSH, Git |

---

## 10. Déploiement

### Vue d'ensemble

Le déploiement suit trois étapes dans cet ordre immuable :
1. `make init` : Terraform télécharge les plugins Azure et configure le backend
2. `make plan` : Terraform calcule les changements à apporter sans rien modifier dans Azure
3. `make apply` : Terraform crée les ressources dans Azure (durée : 15 à 20 minutes)

### Déploiement rapide

```powershell
# Cloner le projet
git clone https://github.com/dspitech/AZ-NOR-SECURE-HUB-SPOKE-PRO.git
cd AZ-NOR-SECURE-HUB-SPOKE-PRO

# Configurer les variables
nano terraform.tfvars   # Renseigner admin_password et alert_email

# Déployer
make init
make plan
make apply
```

### Déploiement détaillé

# Étape 1 : Authentification Azure

Connectez-vous à Azure en utilisant l'une des méthodes suivantes :

- **Cloud Shell Azure** : connectez-vous au portail Azure et ouvrez le Cloud Shell (PowerShell).
- **Environnement local** : ouvrez un terminal sur votre poste de travail disposant de l'Azure CLI.

Exécutez ensuite les commandes suivantes :

```powershell
az login
az account set --subscription "<NOM_OU_ID_ABONNEMENT>"
az account show
```

#### Étape 2 : Initialisation du backend distant (optionnel)

Si vous souhaitez utiliser un backend distant pour stocker l’état Terraform, exécutez la commande suivante :

```powershell
make bootstrap-backend
```
Puis décommenter le bloc backend dans backend.tf

#### Étape 3 : Initialisation

```powershell
make init
```
#### Étape 4 : Scan de sécurité

```powershell
make security-scan
```


#### Étape 5 : Plan

```powershell
make plan
```

#### Étape 6 : Déploiement

```powershell
make apply
```

#### Étape 7 : Vérification

```powershell
make output
```

#### Étape 8 : Installer l'extension Network Watcher sur les VMs 

**Azure Network Watcher** est un service de supervision et de diagnostic réseau qui permet d'analyser, surveiller et dépanner les ressources réseau dans Azure.

Il permet notamment de :

- Vérifier la connectivité entre des ressources Azure.
- Diagnostiquer les problèmes de routage et de filtrage réseau.
- Analyser les flux de trafic à travers les groupes de sécurité réseau (NSG Flow Logs).
- Capturer des paquets réseau pour faciliter le dépannage.
- Surveiller les performances et la latence du réseau.
- Visualiser la topologie des ressources réseau Azure.

> Dans ce projet, Network Watcher est généralement utilisé pour faciliter le diagnostic et l'observabilité du réseau.


```powershell
az vm extension set `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --vm-name vm-prod-01 `
  --name NetworkWatcherAgentLinux `
  --publisher Microsoft.Azure.NetworkWatcher `
  --version 1.4

az vm extension set `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --vm-name vm-nonprod-01 `
  --name NetworkWatcherAgentLinux `
  --publisher Microsoft.Azure.NetworkWatcher `
  --version 1.4
```

#### Étape 9 : Test

#### Test 1 : test de connectivité inter-Spoke (SSH, port 22, Prod vers NonProd)

```powershell
az network watcher test-connectivity `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --source-resource vm-prod-01 `
  --dest-resource vm-nonprod-01 `
  --dest-port 22
```
#### Résultat attendu du test de connectivité (port 22, Prod vers NonProd)

Le test retournera `Unreachable`. C'est le comportement attendu et correct.

```
vm-prod-01 (192.168.1.4)
    |  OK - sort du VNet prod via l'UDR
    v
Azure Firewall (10.0.1.0/24)
    |  OK - règle Allow-Spoke-to-Spoke active
    v
vm-nonprod-01 (172.16.1.4)
    |  BLOQUÉ par NSG nsg-nonprod-resources
    x  Règle Deny-All-Inbound (source prod ne correspond pas à Allow-SSH-From-Bastion)
```

Ce résultat confirme que les deux premiers niveaux de sécurité (UDR et Firewall) fonctionnent, et que le troisième niveau (NSG) bloque correctement SSH depuis un subnet non autorisé.

#### Test 2 : Connectivité HTTP/HTTPS autorisée (Prod vers NonProd, ports 80/443)

```powershell
az network watcher test-connectivity `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --source-resource vm-prod-01 `
  --dest-resource vm-nonprod-01 `
  --dest-port 80
```

**Résultat attendu : `Reachable`**

```
vm-prod-01 (192.168.1.4)
    |  OK - sort du VNet prod via l'UDR
    v
Azure Firewall (10.0.1.0/24)
    |  OK - règle Allow-Spoke-to-Spoke active
    v
vm-nonprod-01 (172.16.1.4)
    |  AUTORISÉ par NSG nsg-nonprod-resources
    ok Règle Allow-HTTP-HTTPS-Inbound (source 192.168.0.0/16, port 80 -> ALLOW)
```

Ce résultat confirme que la règle applicative ouverte volontairement (HTTP/HTTPS depuis Prod) fonctionne comme prévu, contrairement au SSH qui reste bloqué.


Ce résultat confirme que le Bastion reste le seul chemin autorisé pour l'administration SSH, conformément au modèle de défense en profondeur.

#### Test 3 : Tentative NonProd vers Prod sur un port non listé (ex. port 3389 RDP)

```powershell
az network watcher test-connectivity  `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY  `
  --source-resource vm-nonprod-01  `
  --dest-resource vm-prod-01  `
  --dest-port 3389
```

**Résultat attendu : `Reachable` au niveau Firewall, puis dépendant du NSG Prod**

```
vm-nonprod-01 (172.16.1.4)
    |  OK - sort du VNet nonprod via l'UDR
    v
Azure Firewall (10.0.1.0/24)
    |  OK - règle Allow-Spoke-to-Spoke autorise tous les ports entre spokes
    v
vm-prod-01 (192.168.1.4)
    |  AUTORISÉ par NSG nsg-prod-resources
    ok Règle Allow-Internal-From-Nonprod (source 172.16.0.0/12, tous ports -> ALLOW)
```

Ce résultat illustre que la règle `Allow-Internal-From-Nonprod` est volontairement large (tous ports/protocoles depuis NonProd vers Prod) ; à surveiller ou restreindre en production si ce niveau d'ouverture n'est pas souhaité.

#### Test 4 : Connectivité depuis Internet vers une VM (vérification de l'absence d'IP publique)

```powershell
az network watcher test-connectivity `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --source-resource vm-prod-01 `
  --dest-address 8.8.8.8 `
  --dest-port 443
```

**Résultat attendu : dépend de `Deny-All-Outbound`, donc `Unreachable` pour un flux non explicitement autorisé**

```
vm-prod-01 (192.168.1.4)
    |  Sortant vers Internet (8.8.8.8:443)
    v
NSG nsg-prod-resources (Sortant)
    |  Aucune règle Allow ne correspond a une destination Internet
    x  Règle Deny-All-Outbound s'applique
```

Ce résultat confirme qu'aucune VM ne peut initier de connexion sortante vers Internet sans une règle Allow explicite, renforçant le principe de moindre privilège du modèle Zero Trust appliqué ici.

### Destruction

```powershell
make destroy
```

---

## 11. CI/CD GitHub Actions (optionnel)

### Vue d'ensemble du pipeline

```
git push / pull_request
    |
    +-- validate : terraform fmt + init + validate + commentaire PR
    |
    +-- security : Checkov scan + upload SARIF vers GitHub Security
    |
    +-- plan : terraform plan + upload artefact + résumé en commentaire PR
    |
    `-- apply : terraform apply (après approbation manuelle)
                Nécessite l'environnement GitHub "production"
```

### Configuration étape par étape

**Étape 1 : Récupérer le Subscription ID**

```powershell
$SUBSCRIPTION_ID = az account show --query id -o tsv
Write-Host "Subscription ID : $SUBSCRIPTION_ID"
```

**Étape 2 : Créer le Service Principal**

```powershell
az ad sp create-for-rbac `
  --name "sp-terraform-hub-spoke" `
  --role Contributor `
  --scopes /subscriptions/$SUBSCRIPTION_ID `
  --output json
```

Le résultat est un JSON contenant trois valeurs à noter immédiatement, elles ne seront plus affichées :

```json
{
  "appId":    "aaa-bbb-ccc",
  "password": "xxx-yyy-zzz",
  "tenant":   "111-222-333"
}
```

**Étape 3 : Ajouter les secrets dans GitHub**

Accéder à : Settings > Secrets and variables > Actions > New repository secret

| Nom du secret | Valeur |
|--------------|--------|
| ARM_CLIENT_ID | valeur de appId |
| ARM_CLIENT_SECRET | valeur de password |
| ARM_TENANT_ID | valeur de tenant |
| ARM_SUBSCRIPTION_ID | résultat de `az account show --query id -o tsv` |
| TF_VAR_admin_password | mot de passe des VMs |
| ALERT_EMAIL | adresse email pour les alertes |

**Étape 4 : Créer l'environnement de production**

Accéder à : Settings > Environments > New environment > Nommer "production"

Puis activer : Environment protection rules > Required reviewers > Ajouter votre nom GitHub.

**Étape 5 : Déclencher le pipeline**

```powershell
git add .
git commit -m "ci: configuration GitHub Actions"
git push origin main
```

Puis sur GitHub : Actions > Terraform CI/CD > job Apply > Review deployments > Approve.

---

## 12. Sécurité

### Modèle de sécurité en cinq couches

| Couche | Mécanisme | Rôle |
|--------|---------|------|
| 1 | Azure Firewall (L4/L7) | Inspection et journalisation de tout le trafic inter-spoke |
| 2 | UDR - Routage forcé | Impossible de contourner le Firewall |
| 3 | NSG par subnet (L4) | Filtrage granulaire, Deny-All par défaut |
| 4 | VMs sans IP publique | Surface d'attaque minimale, aucune exposition directe |
| 5 | Azure Bastion | Seul accès admin autorisé, connexion chiffrée SSL/TLS |

### Recommandations complémentaires pour la production

- Utiliser Azure Key Vault pour stocker `admin_password` au lieu de terraform.tfvars
- Activer Azure Defender for Servers pour la détection d'intrusion comportementale
- Configurer Just-in-Time VM Access pour réduire la fenêtre d'exposition administrateur
- Activer l'authentification par clé SSH et désactiver l'authentification par mot de passe

---

## 13. Monitoring et alertes

### Alertes configurées

| Alerte | Condition de déclenchement | Sévérité |
|--------|--------------------------|---------|
| alert-fw-high-denials | Plus de 100 refus Firewall en 5 minutes | 2 - Warning |
| alert-fw-health | Disponibilité Firewall inférieure à 95% | 1 - Error |
| alert-cpu-vm-prod | CPU vm-prod-01 supérieur à 85% sur 5 minutes | 2 - Warning |
| alert-cpu-vm-nonprod | CPU vm-nonprod-01 supérieur à 85% sur 5 minutes | 2 - Warning |

### Requêtes KQL utiles

Trafic bloqué par le Firewall (dernières 24 heures) :
```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| where TimeGenerated > ago(24h)
| project TimeGenerated, srcIp_s, destIp_s, msg_s
| order by TimeGenerated desc
```

Top 10 des sources de trafic bloqué :
```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| summarize count() by srcIp_s
| top 10 by count_ desc
```

Règles NSG les plus déclenchées :
```kusto
AzureDiagnostics
| where Category == "NetworkSecurityGroupRuleCounter"
| summarize count() by ruleName_s, direction_s
| order by count_ desc
```

---

## 14. Gestion des coûts

### Coûts estimés

| Ressource | SKU | Coût mensuel | Coût journalier |
|-----------|-----|-------------|----------------|
| Azure Firewall | Standard | ~1 250 USD | ~41 USD |
| Azure Bastion | Standard | ~140 USD | ~4.70 USD |
| Log Analytics | PerGB2018 | ~2.30 USD/Go | variable |
| VMs (x2) | Standard_B1s | ~15 USD | ~0.50 USD |
| VNets et Peerings | - | Gratuit | - |
| Storage tfstate | LRS | ~0.05 USD | - |

Total estimé : 1 405 à 1 500 USD par mois hors trafic sortant.

### Pour les comptes Students (crédit de 100 USD)

Le crédit s'épuise en 2 à 3 jours avec le Firewall Standard allumé en permanence. Commandes d'économie :

```powershell
make vm-stop          # Arrêt des VMs (économie ~0.50 USD/jour)
make vm-start         # Démarrage des VMs
make costs            # Résumé des ressources facturables
make destroy          # Destruction totale après les tests (économie ~41 USD/jour)
```

Option Firewall Basic pour réduire les coûts d'environ 950 USD/mois : modifier `sku_tier = "Standard"` en `sku_tier = "Basic"` dans main.tf et firewall_policy. Attention : le tier Basic ne supporte pas les règles de couche applicative (L7).

---

## 15. Bonnes pratiques Terraform

### Commandes Make disponibles

```powershell
make help            # Liste toutes les commandes disponibles
make init            # terraform init
make validate        # terraform validate
make lint            # terraform fmt -recursive
make security-scan   # checkov scan
make plan            # terraform plan -out=tfplan
make apply           # terraform apply tfplan
make output          # terraform output
make vm-stop         # Arrêt des VMs
make vm-start        # Démarrage des VMs
make costs           # Résumé des ressources facturables
make clean           # Suppression des fichiers temporaires
make destroy          # Destruction totale avec confirmation
```

### Règles à respecter

Ne jamais commiter dans Git : `terraform.tfvars`, `terraform.tfstate`, `terraform.tfstate.backup`, le répertoire `.terraform/`.

Utiliser un backend distant dès que le travail se fait en équipe. L'état local ne peut pas être partagé sans risque de corruption.

Utiliser des variables d'environnement pour les secrets en CI/CD :
```powershell
export TF_VAR_admin_password="MonMotDePasse2026!"
```

---

## 16. Dépannage

### Erreur : Cannot access Backend State

```
Error: Error acquiring the lock
Code="RequestDisallowedByPolicy"
```

Solution : Commenter le bloc backend dans `backend.tf`, puis relancer `terraform init`. Ou réinitialiser complètement :
```powershell
rm -rf .terraform*
terraform init
```

### Erreur : QuotaExceeded

```
Code="QuotaExceeded"
Details=Cores subscription... quota exceeded
```

Solution : Arrêter les VMs existantes (`make vm-stop`) ou détruire l'infrastructure (`make destroy`) pour libérer les quotas.

### Erreur : InvalidAuthenticationToken

```
Code="InvalidAuthenticationToken"
```

Solution : Le token Azure a expiré. Se reconnecter :
```powershell
az login
az account set --subscription "<ID>"
make plan
```

### Erreur : NSG rule priority conflict

Deux règles NSG ont la même valeur de priorité dans le même NSG.

Solution : Changer l'une des deux priorités. Les priorités doivent être uniques entre 100 et 4096 dans chaque NSG.

### Erreur : Terraform plan montre toujours des changements

Cause probable : la fonction `timestamp()` dans `locals.tf` est évaluée à chaque plan.

Solution : Remplacer `timestamp()` par une date fixe :
```hcl
LastUpdated = "2026-06-14"
```

### Les VMs ne communiquent pas

```powershell
# Vérifier les peerings
az network vnet peering list `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --vnet-name vnet-az-nor-hub-core `
  --output table

# Vérifier les routes effectives sur la NIC
az network nic show-effective-route-table `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --name nic-vm-prod-01 `
  --output table

# Vérifier les règles NSG effectives
az network nic list-effective-nsg `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --name nic-vm-prod-01 `
  --output table
```

---

## 17. Exercices pratiques

### Exercice 1 : Modifier une variable (30 minutes)

Objectif : comprendre comment Terraform met à jour l'infrastructure sans tout recréer.

1. Ouvrir `terraform.tfvars`
2. Changer `vm_size = "Standard_B1s"` en `vm_size = "Standard_B2s"`
3. Exécuter `make plan` et observer quelles ressources seront modifiées
4. Exécuter `make apply`
5. Vérifier dans le portail Azure que la taille a changé

Question : les VMs ont-elles été recréées (avec downtime) ou simplement modifiées ?

---

### Exercice 2 : Ajouter une règle NSG (1 heure)

Objectif : autoriser un port applicatif personnalisé depuis Prod vers NonProd.

Ajouter dans le NSG nonprod dans `nsg.tf` :

```hcl
security_rule {
  name                       = "Allow-Custom-App-From-Prod"
  priority                   = 130
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_ranges    = ["8080", "9000"]
  source_address_prefix      = var.prod_address_space
  destination_address_prefix = var.nonprod_subnet
}
```

Exécuter `make plan`, vérifier le changement, puis `make apply`.

Question : que se passe-t-il si vous utilisez la priorité 120 qui est déjà prise ?

---

### Exercice 3 : Interroger les logs Firewall avec KQL (45 minutes)

Objectif : analyser le trafic réseau via Log Analytics.

1. Ouvrir Log Analytics Workspace dans le portail Azure
2. Aller dans l'onglet Logs
3. Exécuter la requête suivante :

```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where TimeGenerated > ago(1h)
| project TimeGenerated, srcIp_s, destIp_s, Protocol=protocol_s, Action=msg_s
| order by TimeGenerated desc
```

Questions : quelle est la source IP la plus active ? Quelle proportion du trafic est bloquée ?

---

### Exercice 4 : Ajouter un troisième Spoke QA (3 heures)

Objectif : reproduire le modèle Spoke pour un environnement QA supplémentaire.

Dans `variables.tf`, ajouter :
```hcl
variable "qa_address_space" { type = string; default = "10.100.0.0/16" }
variable "qa_subnet"        { type = string; default = "10.100.1.0/24" }
```

Dans `locals.tf`, ajouter :
```hcl
vnet_qa_name = "vnet-${local.prefix}-spoke-qa"
snet_qa_name = "snet-qa-resources"
nsg_qa_name  = "nsg-qa-resources"
vm_qa_name   = "vm-qa-01"
```

Dupliquer ensuite dans `network.tf` les blocs VNet, Subnet et Peerings pour QA, dans `nsg.tf` le NSG, et dans `main.tf` la VM. Exécuter `make plan` et vérifier que 12 à 15 nouvelles ressources sont prévues.

---

## 18. FAQ

**Comment ajouter un troisième Spoke ?**
Dupliquer les blocs VNet, Subnet, Peerings, NSG et VM dans les fichiers correspondants. Ajouter les variables IP dans `variables.tf` et les noms dans `locals.tf`. Voir exercice 4.

**Puis-je déployer dans une autre région ?**
Oui. Modifier `location` dans `terraform.tfvars`. Si vous utilisez le backend distant, le nom du Storage Account doit être unique globalement et peut nécessiter d'être adapté.

**Le compte Students peut-il déployer cette architecture ?**
Oui, mais le crédit s'épuise rapidement. Utiliser `make vm-stop` et `make destroy` systématiquement après les tests. Envisager le tier Firewall Basic pour économiser ~950 USD/mois.

**Pourquoi le plan montre-t-il des changements à chaque exécution ?**
Vérifier si `timestamp()` est utilisé dans `locals.tf`. Remplacer par une date fixe.

---

## 19. Ressources d'apprentissage

### Réseaux et cloud

- Azure Fundamentals - Microsoft Learn : https://docs.microsoft.com/learn/paths/az-900-describe-cloud-concepts/
- CIDR Notation et subnetting : https://www.youtube.com/watch?v=z07HTSzzp3o
- Modèle OSI expliqué : https://en.wikipedia.org/wiki/OSI_model

### Architecture Hub-and-Spoke

- Référence architecture Azure : https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
- Well-Architected Framework : https://docs.microsoft.com/azure/architecture/framework/

### Sécurité réseau

- Azure Firewall vs NSG : https://docs.microsoft.com/azure/architecture/example-scenario/network/secure-hybrid-network
- Network Security Best Practices : https://docs.microsoft.com/azure/security/fundamentals/network-best-practices

### Terraform

- Terraform Fundamentals - HashiCorp Learn : https://learn.hashicorp.com/collections/terraform/aws-get-started
- Provider azurerm - documentation officielle : https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- Terraform Best Practices : https://www.terraform.io/docs/cloud/guides/recommended-practices.html

### Monitoring et KQL

- KQL Tutorial : https://docs.microsoft.com/azure/data-explorer/kusto/query/tutorial
- Azure Monitor Alerts : https://docs.microsoft.com/azure/azure-monitor/alerts/alerts-overview

### CI/CD

- GitHub Actions pour débutants : https://www.youtube.com/watch?v=TLB5My32To8
- Azure CLI Basics : https://docs.microsoft.com/cli/azure/get-started-with-azure-cli

### Certifications Azure

- AZ-900 Azure Fundamentals : https://docs.microsoft.com/learn/certifications/azure-fundamentals/
- AZ-104 Azure Administrator : https://docs.microsoft.com/learn/certifications/azure-administrator/
- AZ-305 Azure Solutions Architect : https://docs.microsoft.com/learn/certifications/azure-solutions-architect/

### Documentation de référence

- Azure Firewall : https://docs.microsoft.com/azure/firewall/
- NSG Azure : https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview
- Azure Bastion : https://docs.microsoft.com/azure/bastion/
- Checkov : https://www.checkov.io/

---

*Version 2.1 - Terraform >= 1.5.0 - Provider azurerm ~> 3.100 - Région Norway East*
