# AZ-NOR-SECURE-HUB-SPOKE

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

## Table des matieres

1. [Introduction](#1-introduction)
2. [Concepts fondamentaux](#2-concepts-fondamentaux)
3. [Glossaire technique](#3-glossaire-technique)
4. [Architecture](#4-architecture)
5. [Composants deployes](#5-composants-deployes)
6. [Segmentation reseau et regles de securite](#6-segmentation-reseau-et-regles-de-securite)
7. [Structure du projet](#7-structure-du-projet)
8. [Code source Terraform](#8-code-source-terraform)
9. [Prerequis](#9-prerequis)
10. [Deploiement](#10-deploiement)
11. [CI/CD GitHub Actions](#11-cicd-github-actions)
12. [Securite](#12-securite)
13. [Monitoring et alertes](#13-monitoring-et-alertes)
14. [Gestion des couts](#14-gestion-des-couts)
15. [Bonnes pratiques Terraform](#15-bonnes-pratiques-terraform)
16. [Depannage](#16-depannage)
17. [Exercices pratiques](#17-exercices-pratiques)
18. [FAQ](#18-faq)
19. [Ressources d'apprentissage](#19-ressources-dapprentissage)

---

## 1. Introduction

Ce projet deploie une architecture reseau Hub-and-Spoke securisee sur Microsoft Azure, entierement pilotee par Terraform, dans la region Norway East. Il est concu a la fois comme une reference d'architecture production et comme un support pedagogique pour apprendre les fondamentaux du cloud networking, de l'Infrastructure as Code et de la securite reseau.

### A qui s'adresse ce projet

- Etudiants en informatique, cloud ou cybersecurite
- Ingenieurs decouvrant Azure ou Terraform
- Equipes souhaitant une base solide pour une architecture multi-environnements

### Parcours d'apprentissage recommande

| Etape | Duree estimee | Objectif |
|-------|--------------|---------|
| Lire la section Concepts | 30 min | Comprendre le modele Hub-and-Spoke |
| Etudier le Glossaire | 20 min | Maitriser le vocabulaire Azure |
| Analyser l'Architecture | 30 min | Visualiser les connexions entre composants |
| Deployer le projet | 45 min | Executer et observer le resultat |
| Explorer le code | 1h+ | Modifier et comprendre les effets |

---

## 2. Concepts fondamentaux

### 2.1 Qu'est-ce qu'une architecture Hub-and-Spoke

Une architecture Hub-and-Spoke est un modele reseau dans lequel un noeud central, appele Hub, sert de point de passage obligatoire pour tout le trafic entre les branches peripheriques, appelees Spokes. Chaque Spoke est un reseau isole qui ne peut communiquer avec les autres Spokes qu'en transitant par le Hub.

Analogie : imaginez un aeroport international (le Hub) avec des lignes aeriennes vers differentes villes (les Spokes). Pour aller de la ville A a la ville B, tous les passagers transitent par l'aeroport. De la meme facon, tout paquet reseau transite par le Firewall du Hub, ce qui permet une inspection et un controle centralises.

Avantages principaux :
- Inspection centralisee : un seul point de controle pour tout le trafic
- Controle granulaire : les regles sont definies une fois et s'appliquent partout
- Isolation stricte : les Spokes ne communiquent jamais directement entre eux

### 2.2 Les trois environnements de ce projet

```
HUB (Coeur du reseau) - 10.0.0.0/16
  Azure Firewall : inspecte tout le trafic
  Azure Bastion : acces SSH/RDP securise sans IP publique
  Log Analytics : centralisation des journaux
        |                          |
        v                          v
PRODUCTION                   NON-PRODUCTION
192.168.0.0/16               172.16.0.0/12
Donnees reelles              Tests et developpement
NSG strict                   NSG modere
```

### 2.3 La defense en profondeur

La defense en profondeur est une strategie de securite qui consiste a empiler plusieurs couches de protection independantes. Si une couche est contournee ou compromise, les autres restent actives et continuent de proteger le systeme.

```
Couche 1 : Azure Firewall (L4 et L7)
  Inspecte chaque paquet, bloque les menaces connues

Couche 2 : UDR - Routage force
  Rend impossible tout contournement du Firewall

Couche 3 : NSG - Network Security Groups
  Filtrage secondaire directement attache a chaque subnet

Couche 4 : VMs sans adresse IP publique
  Aucune machine n'est accessible directement depuis Internet

Couche 5 : Azure Bastion
  Seule porte d'entree pour l'administration, connexion chiffree SSL/TLS
```

### 2.4 Cycle de vie d'un paquet reseau

Voici ce qui se passe lorsqu'une VM de production tente de contacter une VM de non-production :

```
VM Production (192.168.1.4) envoie un paquet vers VM Non-Prod (172.16.1.4)

Etape 1 : La VM consulte sa table de routage (UDR)
  -> Regle : tout trafic externe va vers 10.0.1.4 (Firewall)

Etape 2 : Le Firewall recoit le paquet
  -> Verifie la regle Allow-Spoke-to-Spoke
  -> Source 192.168.0.0/16 : autorise
  -> Destination 172.16.0.0/12 : autorise
  -> Action : transfert vers le subnet non-prod

Etape 3 : Le NSG du subnet non-prod analyse le paquet
  -> Verifie toutes les regles dans l'ordre de priorite
  -> Si aucune regle Allow ne correspond : Deny-All s'applique

Etape 4 : La VM Non-Prod recoit le paquet ou le rejette
```

### 2.5 Pourquoi des plages IP distinctes

Chaque environnement utilise une plage d'adresses IP entierement separee. Cette segmentation est fondamentale : un attaquant qui compromet un environnement ne peut pas atteindre un autre environnement via une simple communication reseau, car les plages ne se chevauchent pas et le routage entre elles est strictement controle.

| Environnement | Plage IP | Role |
|--------------|---------|------|
| Hub | 10.0.0.0/16 | Reseau central, services partages |
| Production | 192.168.0.0/16 | Donnees reelles, clients |
| Non-Production | 172.16.0.0/12 | Tests, developpement |

---

## 3. Glossaire technique

### A

**Azure Bastion** : Service Azure qui fournit un acces SSH et RDP securise aux machines virtuelles sans qu'elles aient besoin d'une adresse IP publique. La connexion transite par le portail Azure via un tunnel HTTPS chiffre. Cela supprime l'exposition directe des VMs sur Internet.

**Azure Firewall** : Pare-feu cloud manage par Azure, capable d'inspecter le trafic aux couches 4 (transport : TCP/UDP) et 7 (application : HTTP, DNS). Il offre une journalisation complete et une gestion centralisee des regles.

### B

**Backend Terraform** : Emplacement de stockage du fichier d'etat Terraform (terraform.tfstate). Peut etre local ou distant (Azure Storage, Terraform Cloud). Un backend distant est essentiel pour le travail en equipe et la CI/CD.

### D

**Defense en profondeur** : Approche de securite qui empile plusieurs mecanismes de protection independants. Si un mecanisme echoue, les autres continuent d'assurer la protection. Voir section 2.3.

### I

**IaC - Infrastructure as Code** : Pratique consistant a definir et gerer l'infrastructure (serveurs, reseaux, bases de donnees) sous forme de fichiers de code, plutot qu'en cliquant dans une interface graphique. L'IaC permet la reproductibilite, la versionnabilite et l'automatisation.

**IP privee** : Adresse IP non routable sur Internet (plages 10.x.x.x, 172.16.x.x, 192.168.x.x). Utilisee pour la communication interne entre ressources dans un reseau prive.

**IP publique** : Adresse IP routable sur Internet, accessible depuis n'importe ou dans le monde. Dans ce projet, seuls le Firewall et Bastion en possedent une.

### K

**KQL - Kusto Query Language** : Langage de requete utilise dans Azure Monitor et Log Analytics pour interroger les journaux et metriques. Syntaxe similaire a SQL mais orientee flux de donnees et series temporelles.

### N

**NIC - Network Interface Card** : Interface reseau virtuelle associee a une VM. C'est a elle que sont attaches l'adresse IP privee et le NSG au niveau de l'interface.

**NSG - Network Security Group** : Ensemble de regles de filtrage reseau applique a un subnet ou une interface reseau. Chaque regle definit une action (Allow ou Deny) pour une combinaison source/destination/port/protocole. Les regles sont evaluees par ordre de priorite croissant (100 avant 200, etc.).

### P

**Peering VNet** : Connexion directe et privee entre deux reseaux virtuels Azure. Le trafic entre les deux VNets transite par le backbone Microsoft, sans passer par Internet. Dans ce projet, quatre peerings sont crees : Hub vers Prod, Prod vers Hub, Hub vers NonProd, NonProd vers Hub.

**Provider Terraform** : Plugin Terraform qui traduit le code HCL en appels API vers un fournisseur cloud (Azure, AWS, GCP, etc.). Le provider azurerm est utilise dans ce projet.

### R

**Resource Group** : Conteneur logique Azure regroupant toutes les ressources d'un projet. Permet de les gerer, surveiller et facturer ensemble. La suppression du Resource Group supprime toutes les ressources qu'il contient.

**Route Table - UDR (User Defined Route)** : Table de routage personnalisee qui remplace ou complete le routage par defaut d'Azure. Dans ce projet, une UDR force tout le trafic sortant des Spokes vers le Firewall, rendant impossible de le contourner.

### S

**Service Principal** : Identite de service dans Azure Active Directory, equivalente a un compte technique. Utilise pour l'automatisation et la CI/CD afin d'eviter d'utiliser des identifiants personnels.

**SKU** : Reference de niveau de service (Basic, Standard, Premium) pour une ressource Azure. Le SKU determine les fonctionnalites disponibles et le tarif. Par exemple, Azure Firewall Standard supporte les regles L7, contrairement au Basic.

**Subnet** : Subdivision d'un VNet avec sa propre plage d'adresses IP. Permet d'organiser les ressources et d'appliquer des politiques de securite differentes selon les groupes.

### T

**Terraform** : Outil d'IaC open source edite par HashiCorp. Il permet de decrire une infrastructure dans des fichiers HCL, puis de la creer, modifier ou detruire de facon idempotente.

**Terraform State** : Fichier JSON (terraform.tfstate) dans lequel Terraform memorise l'etat reel de l'infrastructure deployee. Il sert a comparer l'etat desire (code) avec l'etat reel (cloud) pour determiner quelles modifications appliquer.

### V

**VNet - Virtual Network** : Reseau prive isole dans Azure, equivalent du VPC (Virtual Private Cloud) dans AWS. Un VNet contient des subnets et peut etre connecte a d'autres VNets via le peering.

**VM - Virtual Machine** : Ordinateur virtuel executant un systeme d'exploitation complet (Linux ou Windows), heberge sur l'infrastructure physique de Microsoft.

---

## 4. Architecture

### Topologie reseau

```
                         INTERNET
                             |
                    [IP Publique Firewall]
                             |
         +-------------------+-------------------+
         |           HUB VNet 10.0.0.0/16        |
         |                                       |
         |  [AzureFirewallSubnet 10.0.1.0/24]   |
         |       Azure Firewall 10.0.1.4         |
         |                                       |
         |  [AzureBastionSubnet 10.0.2.0/24]    |
         |       Azure Bastion                   |
         |                                       |
         |  [Log Analytics Workspace]            |
         +--------+---------+--------------------+
                  |         |
          Peering |         | Peering
           Hub<->Prod  Hub<->NonProd
                  |         |
    +-------------+     +---+-------------+
    | Spoke PROD        | Spoke NON-PROD  |
    | 192.168.0.0/16    | 172.16.0.0/12   |
    |                   |                 |
    | snet-prod-resources   snet-nonprod-resources
    | 192.168.1.0/24    | 172.16.1.0/24   |
    | NSG strict        | NSG modere      |
    | VM prod (B1s)     | VM nonprod (B1s)|
    | UDR -> Firewall   | UDR -> Firewall |
    +-------------------+-----------------+
```

### Flux 1 : Communication entre Spokes (Prod vers NonProd)

```
VM Prod (192.168.1.4) -> VM NonProd (172.16.1.4)

1. VM Prod consulte l'UDR
   -> Regle 0.0.0.0/0 : next hop = 10.0.1.4 (Firewall)

2. Azure Firewall recoit le paquet
   -> Regle Allow-Spoke-to-Spoke : source OK, destination OK
   -> Transfere vers le subnet nonprod

3. NSG nonprod evalue les regles
   -> Allow-SSH-From-Bastion : source = 10.0.2.0/24, ne correspond pas
   -> Allow-HTTP-HTTPS : ports 80/443 uniquement, si port 22 -> ne correspond pas
   -> Deny-All-Inbound : s'applique -> paquet rejete

Resultat : BLOQUE (attendu et normal pour SSH prod->nonprod)
```

Ce comportement confirme que le NSG nonprod protege bien les VMs : seul le Bastion peut initier une session SSH, pas les autres VMs.

### Flux 2 : Acces administrateur via Bastion

```
Administrateur (Internet) -> VM via Bastion

1. Admin s'authentifie sur le portail Azure (Azure AD + MFA)
2. Bastion etablit un tunnel HTTPS depuis 10.0.2.0/24
3. Paquet atteint le NSG du subnet cible
   -> Regle Allow-SSH-From-Bastion : source 10.0.2.0/24, port 22 -> ALLOW
4. Admin est connecte en SSH sans que la VM ait d'IP publique
```

### Flux 3 : Tentative d'acces SSH non autorisee (Prod vers NonProd port 22)

```
VM Prod (192.168.1.4) -> VM NonProd port 22

Etapes 1 et 2 : identiques au Flux 1 (Firewall laisse passer)

3. NSG nonprod :
   -> Allow-SSH-From-Bastion : source attendue = 10.0.2.0/24
      source reelle = 192.168.1.0/24 -> NE CORRESPOND PAS
   -> Deny-All-Inbound : s'applique

Resultat : CONNEXION REFUSEE. La VM nonprod ne recoit meme pas le paquet.
```

---

## 5. Composants deployes

| Ressource | Nom dans Azure | Adresse / Detail |
|-----------|--------------|-----------------|
| Hub VNet | vnet-az-nor-hub-core | 10.0.0.0/16 |
| Spoke Prod VNet | vnet-az-nor-spoke-prod | 192.168.0.0/16 |
| Spoke NonProd VNet | vnet-az-nor-spoke-nonprod | 172.16.0.0/12 |
| Azure Firewall | fw-az-nor-hub-central | IP privee 10.0.1.4 - SKU Standard |
| Firewall Policy | fw-policy-az-nor-global | Regle Allow inter-spoke |
| Azure Bastion | bastion-az-nor-hub | SKU Standard |
| NSG Production | nsg-prod-resources | Filtrage L4 subnet prod |
| NSG Non-Production | nsg-nonprod-resources | Filtrage L4 subnet nonprod |
| Route Table UDR | rt-az-nor-forced-to-firewall | 0.0.0.0/0 -> 10.0.1.4 |
| Log Analytics | law-az-nor-hub-norway | 30 jours, PerGB2018 |
| VM Production | vm-prod-01 | Ubuntu 20.04, Standard_B1s |
| VM Non-Production | vm-nonprod-01 | Ubuntu 20.04, Standard_B1s |
| Action Group alertes | ag-az-nor-security-alerts | Notifications email |

---

## 6. Segmentation reseau et regles de securite

### Subnets

| Environnement | Plage VNet | Subnet ressources | NSG attache |
|--------------|-----------|-------------------|------------|
| Hub | 10.0.0.0/16 | FW: 10.0.1.0/24 / Bastion: 10.0.2.0/24 | Aucun (gere par Azure) |
| Production | 192.168.0.0/16 | 192.168.1.0/24 | nsg-prod-resources |
| Non-Production | 172.16.0.0/12 | 172.16.1.0/24 | nsg-nonprod-resources |

### Regles de securite

| Couche | Nom de la regle | Source | Destination | Protocole/Port | Action |
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
|-- locals.tf                   Nommage centralise de toutes les ressources
|-- main.tf                     Firewall, Bastion, VMs, UDR, Log Analytics
|-- network.tf                  VNets, Subnets, VNet Peerings
|-- nsg.tf                      Network Security Groups et regles de filtrage
|-- monitoring.tf               Action Group et 5 alertes Azure Monitor
|-- variables.tf                Variables avec validations integrees
|-- outputs.tf                  Sorties post-deploiement
|-- terraform.tfvars.modele     Modele de configuration a copier
|-- Makefile                    Commandes simplifiees
|-- CHANGELOG.md                Historique des versions
|-- .gitignore                  Protection des fichiers sensibles
`-- README.md                   Ce fichier
```

---

## 8. Code source Terraform

### backend.tf

Ce fichier configure deux choses : la version minimale de Terraform requise, les providers necessaires (azurerm et random), et optionnellement le backend distant pour stocker l'etat Terraform dans Azure Storage.

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

`required_version = ">= 1.5.0"` : Garantit que la personne qui execute ce code dispose d'une version de Terraform suffisamment recente. Cela evite des comportements inattendus dus a des differences entre versions.

`version = "~> 3.100"` : Le symbole `~>` signifie "toute version compatible avec 3.100", c'est-a-dire 3.100, 3.101, 3.102, etc., mais pas 4.x. C'est une contrainte de version permissive pour les mises a jour mineures mais stricte pour les majeures.

`prevent_deletion_if_contains_resources = true` : Empeche Terraform de supprimer accidentellement un Resource Group qui contient encore des ressources. Protection contre les suppressions involontaires.

`delete_os_disk_on_deletion = true` : Quand Terraform supprime une VM, le disque OS est aussi supprime automatiquement. Sans cette option, les disques orphelins continueraient a generer des frais.

**Bootstrap du backend distant** (a executer une seule fois avant `terraform init`) :
```bash
az group create --name rg-terraform-state-norway --location norwayeast
az storage account create --name sttfstatenorway001 \
  --resource-group rg-terraform-state-norway --location norwayeast \
  --sku Standard_LRS --allow-blob-public-access false
az storage container create --name tfstate --account-name sttfstatenorway001
```

---

### locals.tf

Ce fichier centralise tous les noms de ressources du projet en un seul endroit. Modifier le prefix ou un nom ici se repercute automatiquement sur l'ensemble des autres fichiers Terraform.

```hcl
locals {
  prefix   = "az-nor"
  env_hub  = "hub"
  env_prod = "prod"
  env_dev  = "nonprod"

  # Nommage reseau
  vnet_hub_name     = "vnet-${local.prefix}-${local.env_hub}-core"
  vnet_prod_name    = "vnet-${local.prefix}-spoke-${local.env_prod}"
  vnet_nonprod_name = "vnet-${local.prefix}-spoke-${local.env_dev}"

  snet_fw_name      = "AzureFirewallSubnet"
  snet_bastion_name = "AzureBastionSubnet"
  snet_prod_name    = "snet-${local.env_prod}-resources"
  snet_nonprod_name = "snet-${local.env_dev}-resources"

  # Nommage securite
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

`locals {}` : Bloc Terraform permettant de definir des valeurs locales calculees, non modifiables depuis l'exterieur. Contrairement aux variables, les locals ne peuvent pas etre surcharges par l'utilisateur.

`prefix = "az-nor"` : Convention de nommage indiquant le fournisseur cloud (az = Azure) et la region (nor = Norway). Toutes les ressources heritent de ce prefixe pour etre identifiables dans un portail Azure ou une facturation.

`"vnet-${local.prefix}-${local.env_hub}-core"` : Interpolation de chaines en HCL. La valeur resultante sera `vnet-az-nor-hub-core`. Utiliser des references locales plutot que des chaines en dur garantit la coherence : si le prefix change, tous les noms changent en meme temps.

`snet_fw_name = "AzureFirewallSubnet"` : Azure impose ce nom exact pour le subnet du Firewall. Si ce nom est different, le Firewall ne peut pas etre deploye dans ce subnet.

`timestamp()` : Fonction Terraform qui retourne la date et l'heure courantes au format RFC3339. Attention : cette fonction est evaluee a chaque `terraform plan`, ce qui peut provoquer des differences perpetuelles dans le plan. Pour un environnement stable, remplacez par une date fixe en dur.

`merge(var.tags, {...})` : Fusionne deux maps de tags. Les tags definis dans var.tags sont completes par les tags locaux. Si une cle existe dans les deux, la valeur du second map ecrase la premiere.

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

`azurerm_resource_group.main` : Point de depart de toute l'infrastructure. Toutes les autres ressources referencent ce bloc via `azurerm_resource_group.main.name` et `.location`, ce qui garantit la coherence et evite les erreurs de frappe.

`azurerm_log_analytics_workspace.main` : Cree l'espace de travail dans lequel tous les journaux (Firewall, NSG) seront envoyes. Le SKU `PerGB2018` signifie que la facturation se fait au volume de donnees ingerees. `retention_in_days` controle combien de temps les logs sont conserves avant d'etre automatiquement supprimes.

`azurerm_firewall_policy.main` et `azurerm_firewall_policy_rule_collection_group.main` : La politique est le conteneur de regles, et le groupe de collections est l'organisation interne de ces regles. Une politique peut etre partagee entre plusieurs Firewalls. La `priority = 100` sur le groupe signifie qu'il est evalue en premier si d'autres groupes existent.

`source_addresses` et `destination_addresses` dans la regle Allow-Spoke-to-Spoke : En listant les deux plages dans les deux champs, on autorise le trafic dans les deux sens (Prod vers NonProd et NonProd vers Prod) avec une seule regle. Sans cela, il faudrait deux regles distinctes.

`azurerm_public_ip.firewall` avec `allocation_method = "Static"` : Une IP statique ne change pas si la ressource est arretee puis redemarree. Le Firewall exige une IP publique Standard statique. Une IP dynamique changerait a chaque redemarrage, ce qui casserait les configurations DNS ou les listes blanches externes.

`azurerm_monitor_diagnostic_setting.firewall` : Connecte les journaux du Firewall vers Log Analytics. Sans ce bloc, le Firewall genere des logs mais ils ne sont envoyes nulle part. `lifecycle { create_before_destroy = true }` evite une erreur 409 (conflit) lors de la recreation du parametrage diagnostique.

`bgp_route_propagation_enabled = false` dans la Route Table : BGP (Border Gateway Protocol) permet a Azure de propager automatiquement des routes depuis des passerelles VPN. En le desactivant, on empeche ces routes auto-propagees d'entrer en conflit avec la route forcee vers le Firewall. La route manuelle 0.0.0.0/0 -> Firewall doit etre la seule qui s'applique.

`address_prefix = "0.0.0.0/0"` avec `next_hop_type = "VirtualAppliance"` : La notation 0.0.0.0/0 signifie "toutes les destinations". Ainsi, peu importe ou la VM veut envoyer son trafic, il transitera systematiquement par l'appliance virtuelle (le Firewall) a l'adresse `next_hop_in_ip_address`.

`disable_password_authentication = false` : Par defaut Azure recommande les cles SSH pour Linux. Ce projet utilise un mot de passe pour simplifier l'acces pedagogique. En production, preferez les cles SSH et passez cette valeur a `true`.

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

`address_space = [var.hub_address_space]` : La valeur est une liste meme si elle ne contient qu'un seul element, car Azure supporte plusieurs plages d'adresses par VNet. Utiliser une variable plutot qu'une valeur en dur permet de modifier la plage dans terraform.tfvars sans toucher au code.

Pourquoi les noms de subnets Firewall et Bastion sont imposes : Azure identifie les subnets dedies aux services manages par leur nom exact. `AzureFirewallSubnet` et `AzureBastionSubnet` sont des noms reserves. Si vous les modifiez, le deploiement du Firewall ou du Bastion echouera avec une erreur de validation.

`allow_forwarded_traffic = true` dans les peerings : Sans cette option, un VNet peeree refuse les paquets dont l'adresse source n'appartient pas a ce VNet. Puisque les paquets transitent par le Firewall du Hub avant d'arriver dans les Spokes, leur adresse source est celle du Hub, pas du Spoke emetteur. Cette option est donc indispensable au bon fonctionnement du routage force.

Pourquoi quatre peerings pour deux connexions : Le peering VNet n'est pas bidirectionnel par defaut. Il faut creer explicitement un peering dans chaque sens. `hub_to_prod` permet au Hub d'envoyer des paquets vers Prod, et `prod_to_hub` permet a Prod d'envoyer des paquets vers le Hub. Sans les deux, la communication ne fonctionne que dans un sens.

---

### nsg.tf

Network Security Groups avec regles de filtrage L4 et envoi des journaux vers Log Analytics.

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

`priority` : Les regles NSG sont evaluees dans l'ordre croissant des priorites. La priorite 100 est evaluee avant la 110, qui est evaluee avant la 4096. Des que le paquet correspond a une regle (Allow ou Deny), l'evaluation s'arrete. La plage valide est de 100 a 4096. Deux regles ne peuvent pas avoir la meme priorite dans le meme NSG.

`source_port_range = "*"` : Le port source est le port ephemere utilise par l'emetteur pour initier une connexion (generalement un port aleatoire au-dessus de 1024). Il est presque toujours defini comme `*` car on ne peut pas predire quel port l'OS emetteur va choisir. C'est le port de destination qui identifie le service (22 = SSH, 80 = HTTP, 443 = HTTPS).

`Deny-All-Inbound` a la priorite 4096 : C'est une "regle de base" ou "default deny". Tout trafic qui n'a correspond a aucune regle Allow precedente est bloque. Azure applique egalement ses propres regles par defaut (nommees 65000, 65001, 65500), mais les positionner a 4096 garantit que les regles explicites sont toujours evaluees en premier.

`azurerm_subnet_network_security_group_association` : Creer un NSG ne suffit pas - il faut l'associer explicitement au subnet. Sans ce bloc d'association, le NSG existe dans Azure mais n'est applique a aucune interface reseau et n'a aucun effet.

`NetworkSecurityGroupEvent` vs `NetworkSecurityGroupRuleCounter` : Le premier log enregistre chaque evenement (connexion acceptee ou refusee), le second comptabilise le nombre de fois que chaque regle a ete evaluee sur une periode. Les deux sont complementaires pour le diagnostic et la conformite.

---

### monitoring.tf

Action Group de notification email et cinq alertes Azure Monitor couvrant les scenarios critiques.

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

# Alerte 1 : Volume de refus Firewall eleve (tentative d intrusion)
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

# Alerte 2 : Disponibilite Firewall < 95%
resource "azurerm_monitor_metric_alert" "fw_health" {
  name                = local.alert_fw_health_name
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_firewall.main.id]
  description         = "Disponibilite Firewall < 95%"
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

`azurerm_monitor_action_group` : Un Action Group est un ensemble de destinataires et d actions a declencher quand une alerte se declenche. Il peut inclure des emails, des SMS, des webhooks, des runbooks Azure Automation, etc. Le `short_name` (12 caracteres max) est utilise dans les notifications SMS.

`use_common_alert_schema = true` : Standardise le format JSON des notifications. Toutes les alertes utilisent le meme schema, ce qui simplifie le traitement automatise (par exemple, un webhook qui parse les alertes).

`evaluation_frequency = "PT5M"` et `window_duration = "PT5M"` : Le format PT5M signifie "periode de 5 minutes" (ISO 8601). `evaluation_frequency` definit a quelle frequence la requete est executee. `window_duration` definit la fenetre de temps sur laquelle les donnees sont analysees. Ici, tous les 5 minutes, on analyse les 5 dernieres minutes de logs.

Requete KQL dans l'alerte Firewall : La table `AZFWNetworkRule` contient les evenements de regles reseau du Firewall. La requete filtre les evenements `Deny`, les groupe par tranches de 5 minutes, compte les occurrences et ne retient que les tranches depassant le seuil. Si au moins une tranche depasse le seuil pendant la fenetre d evaluation, l alerte se declenche.

`severity` : Niveaux de 0 (Critical) a 4 (Verbose). Severite 1 = Error, severite 2 = Warning. La sante du Firewall (severity 1) est plus critique qu une surcharge CPU (severity 2), ce qui se reflete dans la couleur et la priorite des alertes dans le portail Azure Monitor.

`frequency = "PT1M"` vs `window_size = "PT5M"` pour les alertes metriques : Azure Monitor evalue la metrique toutes les minutes (`PT1M`), mais calcule la moyenne sur les 5 dernieres minutes (`PT5M`). Une moyenne lissee sur 5 minutes evite les fausses alertes dues a un pic tres court et isole.

---

### variables.tf

Variables Terraform typees avec contraintes de validation integrees.

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
    error_message = "Taille de VM non autorisee. Choisir parmi : Standard_B1s, Standard_B1ms, Standard_B2s, Standard_D2s_v3."
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
    error_message = "Le mot de passe doit avoir au moins 12 caracteres."
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
    error_message = "La retention doit etre l'une des valeurs suivantes : 30, 60, 90, 120, 180 ou 365 jours."
  }
}
```

**Explication**

`type = string` / `type = number` / `type = map(string)` : Terraform est un langage type. Specifier le type evite les erreurs de conversion implicite. Par exemple, passer `"30"` (chaine) a une variable de type `number` declenchera une erreur claire plutot qu'un comportement inattendu.

`sensitive = true` sur `admin_password` : Masque la valeur dans toutes les sorties Terraform (`terraform plan`, `terraform output`, journaux CI/CD). La valeur reste lisible dans le fichier d etat, d ou l importance de proteger l acces au backend.

`validation {}` : Bloc de validation execute lors de chaque `terraform plan`. Si la condition est fausse, Terraform affiche le message `error_message` et arrete le plan avant de contacter Azure. C'est une protection en amont qui evite les erreurs de deploiement coteuses (ressource cree a moitie, frais engages).

`contains([...], var.vm_size)` : La fonction `contains` retourne `true` si la valeur de `var.vm_size` est dans la liste. Cela restreint les tailles de VM deployables, utile pour controler les couts sur un compte Students ou respecter une politique d entreprise.

`can(regex(...))` sur `alert_email` : `can()` retourne `true` si la fonction imbriquee ne genere pas d erreur. `regex()` genere une erreur si le pattern ne correspond pas. Combinees, elles forment une validation de format d email sans faire planter Terraform.

---

### outputs.tf

Sorties affichees apres le deploiement.

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

Les outputs sont affichees dans le terminal apres `terraform apply` et consultables a tout moment avec `terraform output`. Elles servent de reference rapide et peuvent etre consommees par d autres configurations Terraform via `terraform_remote_state`.

`ip_configuration[0].private_ip_address` : Le Firewall peut avoir plusieurs configurations IP. L index `[0]` designe la premiere. Dans ce projet, une seule configuration IP est definie, donc l index 0 est toujours correct.

`sensitive = true` sur la cle Log Analytics : La cle primaire est un secret d authentification. La marquer sensible evite qu elle soit affichee en clair dans les logs de la pipeline CI/CD.

---

### terraform.tfvars.modele

Modele de fichier de configuration a copier et adapter.

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

Ce fichier ne doit jamais etre committe dans Git car il contient des secrets (`admin_password`). Il est liste dans `.gitignore`. Copiez-le sous le nom `terraform.tfvars` et renseignez vos valeurs.

---

## 9. Prerequis

### Outils a installer

| Outil | Version minimale | Installation |
|-------|-----------------|-------------|
| Terraform | >= 1.5.0 | https://developer.hashicorp.com/terraform/install |
| Azure CLI | >= 2.50.0 | https://learn.microsoft.com/cli/azure/install-azure-cli |
| Make | Toute version | apt-get install make / brew install make |
| Checkov | Toute version | pip install checkov |

### Acces Azure requis

- Abonnement Azure actif (compte Students, payant ou trial)
- Role Contributor ou Owner sur l'abonnement

### Connaissances recommandees

| Niveau | Prerequis |
|--------|---------|
| Debutant | Notions de reseau : IP, subnet, port, protocole |
| Intermediaire | Bases HCL/Terraform |
| Avance | Linux, SSH, Git |

---

## 10. Deploiement

### Vue d ensemble

Le deploiement suit trois etapes dans cet ordre immuable :
1. `make init` : Terraform telecharge les plugins Azure et configure le backend
2. `make plan` : Terraform calcule les changements a apporter sans rien modifier dans Azure
3. `make apply` : Terraform cree les ressources dans Azure (duree : 15 a 20 minutes)

### Deploiement rapide

```bash
# Cloner le projet
git clone https://github.com/dspitech/AZ-NOR-SECURE-HUB-SPOKE-PRO.git
cd AZ-NOR-SECURE-HUB-SPOKE-PRO

# Configurer les variables
cp terraform.tfvars.modele terraform.tfvars
nano terraform.tfvars   # Renseigner admin_password et alert_email

# Deployer
make init
make plan
make apply
```

### Deploiement detaille

```bash
# Etape 1 : Authentification Azure
az login
az account set --subscription "<NOM_OU_ID_ABONNEMENT>"
az account show

# Etape 2 : (Optionnel) Bootstrap du backend distant
make bootstrap-backend
# Puis decommenter le bloc backend dans backend.tf

# Etape 3 : Initialisation
make init

# Etape 4 : Scan de securite
make security-scan

# Etape 5 : Plan
make plan

# Etape 6 : Deploiement
make apply

# Etape 7 : Verification
make output

# Installer l'extension Network Watcher sur les VMs (PowerShell)
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

# Test de connectivite inter-Spoke
az network watcher test-connectivity \
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY \
  --source-resource vm-prod-01 \
  --dest-resource vm-nonprod-01 \
  --dest-port 22
```

### Resultat attendu du test de connectivite (port 22)

Le test retournera `Unreachable`. C'est le comportement attendu et correct.

```
vm-prod-01 (192.168.1.4)
    |  OK - sort du VNet prod via l UDR
    v
Azure Firewall (10.0.1.0/24)
    |  OK - regle Allow-Spoke-to-Spoke active
    v
vm-nonprod-01 (172.16.1.4)
    |  BLOQUE par NSG nsg-nonprod-resources
    x  Regle Deny-All-Inbound (source prod ne correspond pas a Allow-SSH-From-Bastion)
```

Ce resultat confirme que les deux premiers niveaux de securite (UDR et Firewall) fonctionnent, et que le troisieme niveau (NSG) bloque correctement SSH depuis un subnet non autorise.

### Destruction

```bash
make destroy
```

---

## 11. CI/CD GitHub Actions

### Vue d ensemble du pipeline

```
git push / pull_request
    |
    +-- validate : terraform fmt + init + validate + commentaire PR
    |
    +-- security : Checkov scan + upload SARIF vers GitHub Security
    |
    +-- plan : terraform plan + upload artefact + resume en commentaire PR
    |
    `-- apply : terraform apply (apres approbation manuelle)
                Necessite l environnement GitHub "production"
```

### Configuration etape par etape

**Etape 1 : Recuperer le Subscription ID**

```bash
$SUBSCRIPTION_ID = az account show --query id -o tsv
Write-Host "Subscription ID : $SUBSCRIPTION_ID"
```

**Etape 2 : Creer le Service Principal**

```bash
az ad sp create-for-rbac `
  --name "sp-terraform-hub-spoke" `
  --role Contributor `
  --scopes /subscriptions/$SUBSCRIPTION_ID `
  --output json
```

Le resultat est un JSON contenant trois valeurs a noter immediatement, elles ne seront plus affichees :

```json
{
  "appId":    "aaa-bbb-ccc",
  "password": "xxx-yyy-zzz",
  "tenant":   "111-222-333"
}
```

**Etape 3 : Ajouter les secrets dans GitHub**

Acceder a : Settings > Secrets and variables > Actions > New repository secret

| Nom du secret | Valeur |
|--------------|--------|
| ARM_CLIENT_ID | valeur de appId |
| ARM_CLIENT_SECRET | valeur de password |
| ARM_TENANT_ID | valeur de tenant |
| ARM_SUBSCRIPTION_ID | resultat de `az account show --query id -o tsv` |
| TF_VAR_admin_password | mot de passe des VMs |
| ALERT_EMAIL | adresse email pour les alertes |

**Etape 4 : Creer l environnement de production**

Acceder a : Settings > Environments > New environment > Nommer "production"

Puis activer : Environment protection rules > Required reviewers > Ajouter votre nom GitHub.

**Etape 5 : Declencher le pipeline**

```bash
git add .
git commit -m "ci: configuration GitHub Actions"
git push origin main
```

Puis sur GitHub : Actions > Terraform CI/CD > job Apply > Review deployments > Approve.

---

## 12. Securite

### Modele de securite en cinq couches

| Couche | Mecanisme | Role |
|--------|---------|------|
| 1 | Azure Firewall (L4/L7) | Inspection et journalisation de tout le trafic inter-spoke |
| 2 | UDR - Routage force | Impossible de contourner le Firewall |
| 3 | NSG par subnet (L4) | Filtrage granulaire, Deny-All par defaut |
| 4 | VMs sans IP publique | Surface d'attaque minimale, aucune exposition directe |
| 5 | Azure Bastion | Seul acces admin autorise, connexion chiffree SSL/TLS |

### Recommandations complementaires pour la production

- Utiliser Azure Key Vault pour stocker `admin_password` au lieu de terraform.tfvars
- Activer Azure Defender for Servers pour la detection d intrusion comportementale
- Configurer Just-in-Time VM Access pour reduire la fenetre d'exposition administrateur
- Activer l'authentification par cle SSH et desactiver l'authentification par mot de passe

---

## 13. Monitoring et alertes

### Alertes configurees

| Alerte | Condition de declenchement | Severite |
|--------|--------------------------|---------|
| alert-fw-high-denials | Plus de 100 refus Firewall en 5 minutes | 2 - Warning |
| alert-fw-health | Disponibilite Firewall inferieure a 95% | 1 - Error |
| alert-cpu-vm-prod | CPU vm-prod-01 superieur a 85% sur 5 minutes | 2 - Warning |
| alert-cpu-vm-nonprod | CPU vm-nonprod-01 superieur a 85% sur 5 minutes | 2 - Warning |

### Requetes KQL utiles

Trafic bloque par le Firewall (dernieres 24 heures) :
```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| where TimeGenerated > ago(24h)
| project TimeGenerated, srcIp_s, destIp_s, msg_s
| order by TimeGenerated desc
```

Top 10 des sources de trafic bloque :
```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| summarize count() by srcIp_s
| top 10 by count_ desc
```

Regles NSG les plus declenchees :
```kusto
AzureDiagnostics
| where Category == "NetworkSecurityGroupRuleCounter"
| summarize count() by ruleName_s, direction_s
| order by count_ desc
```

---

## 14. Gestion des couts

### Couts estimes

| Ressource | SKU | Cout mensuel | Cout journalier |
|-----------|-----|-------------|----------------|
| Azure Firewall | Standard | ~1 250 USD | ~41 USD |
| Azure Bastion | Standard | ~140 USD | ~4.70 USD |
| Log Analytics | PerGB2018 | ~2.30 USD/Go | variable |
| VMs (x2) | Standard_B1s | ~15 USD | ~0.50 USD |
| VNets et Peerings | - | Gratuit | - |
| Storage tfstate | LRS | ~0.05 USD | - |

Total estime : 1 405 a 1 500 USD par mois hors trafic sortant.

### Pour les comptes Students (credit de 100 USD)

Le credit s epuise en 2 a 3 jours avec le Firewall Standard allume en permanence. Commandes d economie :

```bash
make vm-stop          # Arret des VMs (economie ~0.50 USD/jour)
make vm-start         # Demarrage des VMs
make costs            # Resume des ressources facturables
make destroy          # Destruction totale apres les tests (economie ~41 USD/jour)
```

Option Firewall Basic pour reduire les couts d environ 950 USD/mois : modifier `sku_tier = "Standard"` en `sku_tier = "Basic"` dans main.tf et firewall_policy. Attention : le tier Basic ne supporte pas les regles de couche applicative (L7).

---

## 15. Bonnes pratiques Terraform

### Commandes Make disponibles

```bash
make help            # Liste toutes les commandes disponibles
make init            # terraform init
make validate        # terraform validate
make lint            # terraform fmt -recursive
make security-scan   # checkov scan
make plan            # terraform plan -out=tfplan
make apply           # terraform apply tfplan
make output          # terraform output
make vm-stop         # Arret des VMs
make vm-start        # Demarrage des VMs
make costs           # Resume des ressources facturables
make clean           # Suppression des fichiers temporaires
make destroy         # Destruction totale avec confirmation
```

### Regles a respecter

Ne jamais committer dans Git : `terraform.tfvars`, `terraform.tfstate`, `terraform.tfstate.backup`, le repertoire `.terraform/`.

Utiliser un backend distant des que le travail se fait en equipe. L etat local ne peut pas etre partage sans risque de corruption.

Utiliser des variables d environnement pour les secrets en CI/CD :
```bash
export TF_VAR_admin_password="MonMotDePasse2026!"
```

---

## 16. Depannage

### Erreur : Cannot access Backend State

```
Error: Error acquiring the lock
Code="RequestDisallowedByPolicy"
```

Solution : Commenter le bloc backend dans `backend.tf`, puis relancer `terraform init`. Ou reinitialiser completement :
```bash
rm -rf .terraform*
terraform init
```

### Erreur : QuotaExceeded

```
Code="QuotaExceeded"
Details=Cores subscription... quota exceeded
```

Solution : Arreter les VMs existantes (`make vm-stop`) ou detruire l infrastructure (`make destroy`) pour liberer les quotas.

### Erreur : InvalidAuthenticationToken

```
Code="InvalidAuthenticationToken"
```

Solution : Le token Azure a expire. Se reconnecter :
```bash
az login
az account set --subscription "<ID>"
make plan
```

### Erreur : NSG rule priority conflict

Deux regles NSG ont la meme valeur de priorite dans le meme NSG.

Solution : Changer l une des deux priorites. Les priorites doivent etre uniques entre 100 et 4096 dans chaque NSG.

### Erreur : Terraform plan montre toujours des changements

Cause probable : la fonction `timestamp()` dans `locals.tf` est evaluee a chaque plan.

Solution : Remplacer `timestamp()` par une date fixe :
```hcl
LastUpdated = "2026-06-14"
```

### Les VMs ne communiquent pas

```bash
# Verifier les peerings
az network vnet peering list \
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY \
  --vnet-name vnet-az-nor-hub-core --output table

# Verifier les routes effectives sur la NIC
az network nic show-effective-route-table \
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY \
  --name nic-vm-prod-01 --output table

# Verifier les regles NSG effectives
az network nic list-effective-nsg \
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY \
  --name nic-vm-prod-01 --output table
```

---

## 17. Exercices pratiques

### Exercice 1 : Modifier une variable (30 minutes)

Objectif : comprendre comment Terraform met a jour l infrastructure sans tout recreer.

1. Ouvrir `terraform.tfvars`
2. Changer `vm_size = "Standard_B1s"` en `vm_size = "Standard_B2s"`
3. Executer `make plan` et observer quelles ressources seront modifiees
4. Executer `make apply`
5. Verifier dans le portail Azure que la taille a change

Question : les VMs ont-elles ete recrees (avec downtime) ou simplement modifiees ?

---

### Exercice 2 : Ajouter une regle NSG (1 heure)

Objectif : autoriser un port applicatif personnalise depuis Prod vers NonProd.

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

Executer `make plan`, verifier le changement, puis `make apply`.

Question : que se passe-t-il si vous utilisez la priorite 120 qui est deja prise ?

---

### Exercice 3 : Interroger les logs Firewall avec KQL (45 minutes)

Objectif : analyser le trafic reseau via Log Analytics.

1. Ouvrir Log Analytics Workspace dans le portail Azure
2. Aller dans l onglet Logs
3. Executer la requete suivante :

```kusto
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where TimeGenerated > ago(1h)
| project TimeGenerated, srcIp_s, destIp_s, Protocol=protocol_s, Action=msg_s
| order by TimeGenerated desc
```

Questions : quelle est la source IP la plus active ? Quelle proportion du trafic est bloquee ?

---

### Exercice 4 : Ajouter un troisieme Spoke QA (3 heures)

Objectif : reproduire le modele Spoke pour un environnement QA supplementaire.

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

Dupliquer ensuite dans `network.tf` les blocs VNet, Subnet et Peerings pour QA, dans `nsg.tf` le NSG, et dans `main.tf` la VM. Executer `make plan` et verifier que 12 a 15 nouvelles ressources sont prevues.

---

## 18. FAQ

**Comment ajouter un troisieme Spoke ?**
Dupliquer les blocs VNet, Subnet, Peerings, NSG et VM dans les fichiers correspondants. Ajouter les variables IP dans `variables.tf` et les noms dans `locals.tf`. Voir exercice 4.

**Puis-je deployer dans une autre region ?**
Oui. Modifier `location` dans `terraform.tfvars`. Si vous utilisez le backend distant, le nom du Storage Account doit etre unique globalement et peut necessiter d etre adapte.

**Comment migrer depuis Bicep ?**
Utiliser `terraform import` pour rattacher les ressources existantes au state Terraform, ou detruire et redéployer entierement en Terraform.

**Le compte Students peut-il deployer cette architecture ?**
Oui, mais le credit s epuise rapidement. Utiliser `make vm-stop` et `make destroy` systematiquement apres les tests. Envisager le tier Firewall Basic pour economiser ~950 USD/mois.

**Pourquoi le plan montre-t-il des changements a chaque execution ?**
Verifier si `timestamp()` est utilise dans `locals.tf`. Remplacer par une date fixe.

---

## 19. Ressources d'apprentissage

### Reseaux et cloud

- Azure Fundamentals - Microsoft Learn : https://docs.microsoft.com/learn/paths/az-900-describe-cloud-concepts/
- CIDR Notation et subnetting : https://www.youtube.com/watch?v=z07HTSzzp3o
- Modele OSI explique : https://en.wikipedia.org/wiki/OSI_model

### Architecture Hub-and-Spoke

- Reference architecture Azure : https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
- Well-Architected Framework : https://docs.microsoft.com/azure/architecture/framework/

### Securite reseau

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

- GitHub Actions pour debutants : https://www.youtube.com/watch?v=TLB5My32To8
- Azure CLI Basics : https://docs.microsoft.com/cli/azure/get-started-with-azure-cli

### Certifications Azure

- AZ-900 Azure Fundamentals : https://docs.microsoft.com/learn/certifications/azure-fundamentals/
- AZ-104 Azure Administrator : https://docs.microsoft.com/learn/certifications/azure-administrator/
- AZ-305 Azure Solutions Architect : https://docs.microsoft.com/learn/certifications/azure-solutions-architect/

### Documentation de reference

- Azure Firewall : https://docs.microsoft.com/azure/firewall/
- NSG Azure : https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview
- Azure Bastion : https://docs.microsoft.com/azure/bastion/
- Checkov : https://www.checkov.io/

---

*Version 2.1 - Terraform >= 1.5.0 - Provider azurerm ~> 3.100 - Region Norway East*
