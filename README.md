# 🔐 AZ-NOR-SECURE-HUB-SPOKE

<div align="center">

![Azure](https://img.shields.io/badge/Azure-0089D6?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![Bicep](https://img.shields.io/badge/Bicep-0075D6?style=for-the-badge&logo=azure-devops&logoColor=white)
![Infrastructure as Code](https://img.shields.io/badge/IaC-Infrastructure%20as%20Code-blue?style=for-the-badge)

**Architecture Hub-and-Spoke sécurisée avec inspection de flux centralisée**

*Version 1.1 - Monitoring & IP Segmentation Active*

[Architecture](#-architecture) • [Composants](#-composants) • [Déploiement](#-déploiement) • [Sécurité](#-sécurité)

</div>

---

## 📋 Table des matières

- [Vue d'ensemble](#-vue-densemble)
- [Avantages stratégiques](#-avantages-stratégiques)
- [Architecture](#-architecture)
- [Composants](#-composants)
- [Segmentation réseau](#-segmentation-réseau)
- [Cas d'usage](#-cas-dusage)
- [Prérequis](#-prérequis)
- [Déploiement](#-déploiement)
- [Sécurité](#-sécurité)
- [Monitoring](#-monitoring)
- [Configuration](#-configuration)
- [Bonnes pratiques](#-bonnes-pratiques)
- [Dépannage](#-dépannage)
- [FAQ](#-faq)
- [Coûts estimés](#-coûts-estimés)
- [Évolutions futures](#-évolutions-futures)
- [Support](#-support)

---

## 🎯 Vue d'ensemble

Ce projet implémente une architecture réseau **Hub-and-Spoke** sécurisée sur Microsoft Azure, conçue pour la région **Norway East**. L'architecture garantit une inspection centralisée de tout le trafic réseau via Azure Firewall, une segmentation claire entre les environnements de production et non-production, et un monitoring complet des flux réseau.

### ✨ Caractéristiques principales

- 🔒 **Inspection centralisée** : Tout le trafic passe par Azure Firewall
- 🌐 **Segmentation réseau** : Isolation complète entre Production et Non-Production
- 📊 **Monitoring intégré** : Log Analytics Workspace pour l'analyse des logs de sécurité
- 🛡️ **Accès sécurisé** : Azure Bastion pour l'accès aux machines virtuelles
- 🚦 **Routage forcé** : User Defined Routes (UDR) pour garantir le passage par le Firewall
- 🔄 **Peering bidirectionnel** : Communication sécurisée entre Hub et Spokes

---

## 💎 Avantages stratégiques

L'avantage de ce projet, baptisé **AZ-NOR-SECURE-HUB-SPOKE**, réside dans sa capacité à transformer une infrastructure cloud classique en une architecture de classe entreprise répondant aux exigences de sécurité et de conformité modernes.

### 🛡️ 1. Sécurité Périmétrique et Inspection Centrale

L'avantage majeur est l'utilisation d'un **Azure Firewall au centre du réseau** (le "Hub").

- **Inspection des flux** : Contrairement à un réseau simple où les ressources communiquent librement, ici, chaque paquet de données entre la Production (`192.168.x.x`) et la Non-Production (`172.16.x.x`) est analysé.
- **Blocage par défaut** : Le pare-feu applique une politique **"Zero Trust"**. Rien ne passe à moins d'une règle explicite (comme celle que nous avons créée pour le Ping/SSH).

### 🔐 2. Isolation Stricte des Environnements (Segmentation)

En utilisant des plages IP distinctes et des VNets séparés, vous éliminez les risques de **"mouvement latéral"** :

- **Étanchéité** : Une erreur de configuration en environnement Non-Prod ne peut pas affecter la Production grâce à l'isolation physique des réseaux.
- **Standardisation** : L'adressage en `192.168.x.x` et `172.16.x.x` permet une gestion d'inventaire claire et professionnelle.

### 🚦 3. Maîtrise Totale du Trafic (UDR)

Grâce aux **Tables de Routage (UDR)**, l'entreprise garde le contrôle sur la sortie des données :

- **Anti-Exfiltration** : Les serveurs ne peuvent pas envoyer de données vers Internet de manière autonome ; tout doit transiter par le Firewall qui agit comme une passerelle unique et surveillée.

### 📋 4. Auditabilité et Conformité (Log Analytics)

Le projet intègre nativement le monitoring avec **Log Analytics**.

- **Preuve de conformité** : En cas d'audit (ISO 27001, RGPD), vous pouvez prouver qui a accédé à quelle ressource et quand, grâce aux journaux d'activité du Firewall activés dans le fichier Bicep.

### 🔒 5. Réduction de la Surface d'Attaque (Bastion)

L'utilisation d'**Azure Bastion** supprime le besoin d'exposer des adresses IP publiques sur vos machines virtuelles.

- **Accès sécurisé** : Les administrateurs se connectent via SSL (HTTPS) directement depuis le portail Azure, rendant vos serveurs invisibles pour les scanners de vulnérabilités sur Internet.

### 📊 Résumé des avantages pour la direction IT

| Avantage | Impact Métier |
|----------|---------------|
| **Centralisation** | Gestion simplifiée de la sécurité sur un seul point (le Hub) |
| **Évolutivité** | Facilité d'ajouter un nouveau Spoke (ex: Marketing) sans redéployer le Hub |
| **Gouvernance** | Visibilité totale sur les coûts et les flux grâce au monitoring |

---

## 🏗️ Architecture

<div align="center">

![Architecture Hub-and-Spoke](hub-spoke.png)

*Diagramme d'architecture - Hub-and-Spoke avec inspection centralisée*

</div>

### Topologie réseau

L'architecture se compose de trois réseaux virtuels interconnectés :

1. **Hub (VNet Core)** : Réseau centralisé hébergeant les services partagés
2. **Spoke Production** : Environnement de production isolé
3. **Spoke Non-Production** : Environnement de développement et test

Tous les VNets sont connectés via des **Virtual Network Peerings** bidirectionnels, permettant une communication sécurisée tout en maintenant l'isolation logique.

---

## 🧩 Composants

### 1. **Hub VNet** (`vnet-hub-core`)
- **Adresse IP** : `10.0.0.0/16`
- **Rôle** : Réseau centralisé pour les services partagés
- **Subnets** :
  - `AzureFirewallSubnet` : `10.0.1.0/24`
  - `AzureBastionSubnet` : `10.0.2.0/24`

### 2. **Spoke Production** (`vnet-spoke-prod`)
- **Adresse IP** : `192.168.0.0/16`
- **Rôle** : Environnement de production
- **Subnets** :
  - `snet-prod-resources` : `192.168.1.0/24`

### 3. **Spoke Non-Production** (`vnet-spoke-nonprod`)
- **Adresse IP** : `172.16.0.0/12`
- **Rôle** : Environnement de développement et test
- **Subnets** :
  - `snet-nonprod-resources` : `172.16.1.0/24`

### 4. **Azure Firewall** (`fw-hub-central`)
- **Type** : Standard Tier
- **IP Privée** : `10.0.1.4`
- **Fonction** : Inspection et filtrage centralisé de tout le trafic
- **Politique** : `fw-policy-global` avec règles de trafic inter-spoke

### 5. **Azure Bastion** (`bastion-hub`)
- **Fonction** : Accès sécurisé aux machines virtuelles sans IP publique
- **Subnet dédié** : `10.0.2.0/24`

### 6. **Log Analytics Workspace** (`law-hub-norway`)
- **Rétention** : 30 jours
- **SKU** : PerGB2018
- **Fonction** : Centralisation des logs de sécurité et monitoring

### 7. **Machines Virtuelles**
- **VM Production** : `vm-prod-01` (Ubuntu 20.04 LTS, Standard_B1s)
- **VM Non-Production** : `vm-nonprod-01` (Ubuntu 20.04 LTS, Standard_B1s)

### 8. **User Defined Routes (UDR)**
- **Table de routage** : `rt-forced-to-firewall`
- **Fonction** : Force tout le trafic (`0.0.0.0/0`) à passer par le Firewall

---

## 🌐 Segmentation réseau

| Environnement | Plage d'adresses | Description |
|--------------|------------------|-------------|
| **Hub** | `10.0.0.0/16` | Services partagés (Firewall, Bastion) |
| **Production** | `192.168.0.0/16` | Environnement de production isolé |
| **Non-Production** | `172.16.0.0/12` | Environnement de développement/test |

### Règles de communication

- ✅ **Inter-Spoke autorisé** : Communication bidirectionnelle entre Production et Non-Production via le Firewall
- ✅ **Protocoles autorisés** : ICMP, TCP, UDP
- 🔒 **Inspection obligatoire** : Tout le trafic passe par Azure Firewall

---

## 🎯 Cas d'usage

Cette architecture est idéale pour les organisations qui nécessitent :

### Entreprises avec exigences de conformité
- **Secteurs réglementés** : Finance, Santé, Administration publique
- **Audits réguliers** : ISO 27001, RGPD, SOC 2
- **Traçabilité obligatoire** : Logs détaillés de tous les accès réseau

### Multi-environnements
- **Séparation Production/Non-Production** : Isolation stricte requise
- **Environnements multiples** : Dev, Test, Staging, Production
- **Gouvernance centralisée** : Contrôle unifié des politiques de sécurité

### Sécurité renforcée
- **Protection contre les menaces** : Inspection de tout le trafic
- **Prévention d'exfiltration** : Contrôle des sorties Internet
- **Réduction de la surface d'attaque** : Pas d'IP publiques sur les VMs

### Évolutivité
- **Ajout de nouveaux environnements** : Facilement extensible avec de nouveaux Spokes
- **Croissance progressive** : Architecture qui s'adapte à l'expansion
- **Gestion simplifiée** : Point de contrôle unique

---

## 📦 Prérequis

Avant de déployer cette infrastructure, assurez-vous d'avoir :

- ✅ Un abonnement Azure actif
- ✅ Azure CLI installé et configuré (version 2.50.0 ou supérieure)
- ✅ Permissions suffisantes pour créer des ressources (Contributor ou Owner)
- ✅ Quota suffisant pour les ressources suivantes :
  - 3 Virtual Networks
  - 1 Azure Firewall (Standard)
  - 1 Azure Bastion
  - 2 Virtual Machines (Standard_B1s)
  - 1 Log Analytics Workspace

---

## 🚀 Déploiement

### Option 1 : Déploiement via Azure CLI

```
# Définition des variables
$RG_NAME = "RG-ARCHITECTURE-COMPLET-NORWAY"
$LOCATION = "norwayeast"

# 1. Créer le groupe de ressources
az group create --name $RG_NAME --location $LOCATION

# 2. Lancer le déploiement (compter 15 minutes)
az deployment group create `
  --resource-group $RG_NAME `
  --template-file main.bicep `
  --parameters adminPassword='VotreMotDePasseComplex2026!' `
  --verbose
```

### Option 2 : Déploiement via Azure Portal

1. Connectez-vous au [Portail Azure](https://portal.azure.com)
2. Recherchez "Déploiements" dans la barre de recherche
3. Cliquez sur "Créer" > "Déployer un modèle personnalisé"
4. Sélectionnez "Créer votre propre modèle dans l'éditeur"
5. Collez le contenu du fichier `main.bicep`
6. Remplissez les paramètres requis
7. Cliquez sur "Vérifier + créer" puis "Créer"


## 🔒 Sécurité

### Mesures de sécurité implémentées

1. **Inspection centralisée**
   - Tout le trafic réseau passe par Azure Firewall
   - Règles de filtrage applicatives et réseau configurées

2. **Segmentation réseau**
   - Isolation complète entre environnements Production et Non-Production
   - Plages d'adresses IP distinctes pour chaque environnement

3. **Accès sécurisé**
   - Azure Bastion pour l'accès aux machines virtuelles (pas d'IP publiques)
   - Authentification via clés SSH ou Azure AD

4. **Monitoring et audit**
   - Logs de sécurité centralisés dans Log Analytics
   - Diagnostic activé sur Azure Firewall
   - Rétention des logs : 30 jours

5. **Routage forcé**
   - User Defined Routes (UDR) garantissent le passage par le Firewall
   - Impossible de contourner l'inspection

### Règles de pare-feu

| Règle | Source | Destination | Protocole | Action |
|-------|--------|-------------|-----------|--------|
| Allow-Internal-Traffic | 192.168.0.0/16<br>172.16.0.0/12 | 192.168.0.0/16<br>172.16.0.0/12 | ICMP, TCP, UDP | Allow |

> 💡 **Note** : Vous pouvez ajouter d'autres règles selon vos besoins spécifiques en modifiant la collection de règles dans `main.bicep`.

---

## 📊 Monitoring

### Log Analytics Workspace

Le workspace `law-hub-norway` collecte les logs suivants :

- **AzureFirewallNetworkRule** : Logs des règles réseau
- **AzureFirewallApplicationRule** : Logs des règles applicatives
- **Métriques** : Toutes les métriques du Firewall

### Requêtes KQL utiles

```kusto
// Trafic bloqué par le Firewall
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where msg_s contains "Deny"
| project TimeGenerated, msg_s, srcIp_s, destIp_s

// Top 10 des sources de trafic
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| summarize count() by srcIp_s
| top 10 by count_ desc
```

### Accès aux logs

1. Connectez-vous au [Portail Azure](https://portal.azure.com)
2. Naviguez vers **Log Analytics Workspaces** > `law-hub-norway`
3. Cliquez sur **Logs** pour exécuter des requêtes KQL

---

## ⚙️ Configuration

### Paramètres du déploiement

| Paramètre | Description | Valeur par défaut |
|-----------|-------------|-------------------|
| `location` | Région de déploiement | `norwayeast` |
| `adminUsername` | Nom d'utilisateur administrateur | `azureadmin` |
| `adminPassword` | Mot de passe administrateur (sécurisé) | *Requis* |

### Personnalisation

Pour personnaliser l'infrastructure, modifiez les variables dans `main.bicep` :

```bicep
// Adresse IP privée du Firewall
var fwPrivateIp = '10.0.1.4'

// Plages d'adresses réseau
// Hub: 10.0.0.0/16
// Prod: 192.168.0.0/16
// Non-Prod: 172.16.0.0/12
```

---

## ✅ Bonnes pratiques

### Sécurité

1. **Gestion des mots de passe**
   - Utilisez Azure Key Vault pour stocker les secrets
   - Activez la rotation automatique des mots de passe
   - Implémentez l'authentification multi-facteurs (MFA)

2. **Règles de pare-feu**
   - Principe du moindre privilège : Autorisez uniquement le trafic nécessaire
   - Révision régulière des règles (trimestrielle recommandée)
   - Documentation de chaque règle avec justification métier

3. **Monitoring proactif**
   - Configurez des alertes sur les événements de sécurité critiques
   - Définissez des seuils pour les tentatives d'accès suspectes
   - Automatisez les rapports de conformité

### Gestion opérationnelle

1. **Tags et organisation**
   - Appliquez des tags cohérents à toutes les ressources
   - Utilisez des conventions de nommage standardisées
   - Documentez l'objectif de chaque ressource

2. **Backup et récupération**
   - Planifiez des sauvegardes régulières des configurations
   - Testez les procédures de restauration
   - Documentez les procédures de disaster recovery

3. **Gestion des coûts**
   - Utilisez Azure Cost Management pour suivre les dépenses
   - Configurez des budgets et alertes de coûts
   - Réévaluez régulièrement la taille des ressources

### Évolutivité

1. **Ajout de nouveaux Spokes**
   - Suivez la même structure de nommage
   - Appliquez les mêmes UDR pour garantir l'inspection
   - Documentez les nouvelles plages d'adresses IP

2. **Automatisation**
   - Utilisez Infrastructure as Code (Bicep/ARM) pour tous les déploiements
   - Implémentez des pipelines CI/CD pour les changements
   - Automatisez les tests de validation post-déploiement

---

## 🔧 Dépannage

### Problèmes courants et solutions

#### ❌ Les machines virtuelles ne peuvent pas communiquer entre elles

**Symptômes** : Ping échoue entre les VMs des différents Spokes

**Solutions** :
1. Vérifiez que les peering sont bien établis (bidirectionnels)
   ```
   az network vnet peering list --resource-group RG-ARCHITECTURE-COMPLET-NORWAY --vnet-name vnet-hub-core
   ```

2. Vérifiez que les UDR sont bien associées aux subnets
   ```
   az network route-table show --resource-group RG-ARCHITECTURE-COMPLET-NORWAY --name rt-forced-to-firewall
   ```

3. Vérifiez les règles du Firewall dans le portail Azure
   - Naviguez vers Azure Firewall > Règles
   - Assurez-vous que la règle "Allow-Internal-Traffic" est active

#### ❌ Impossible de se connecter via Azure Bastion

**Symptômes** : La connexion Bastion échoue ou timeout

**Solutions** :
1. Vérifiez que le subnet Bastion a la taille minimale requise (`/26` ou plus grand)
2. Vérifiez que la VM est en cours d'exécution
3. Vérifiez les règles NSG si elles sont configurées
4. Vérifiez les logs de diagnostic de Bastion dans Log Analytics

#### ❌ Le trafic ne passe pas par le Firewall

**Symptômes** : Les logs du Firewall ne montrent aucun trafic

**Solutions** :
1. Vérifiez que les UDR sont correctement associées aux subnets des Spokes
2. Vérifiez que l'IP privée du Firewall (`10.0.1.4`) est correcte dans les UDR
3. Vérifiez l'état du Firewall (doit être "En cours d'exécution")
4. Testez avec un trafic simple (ping) et vérifiez les logs

#### ❌ Erreur lors du déploiement Bicep

**Symptômes** : Le déploiement échoue avec une erreur

**Solutions** :
1. Vérifiez que tous les prérequis sont remplis (quotas, permissions)
2. Validez le fichier Bicep avant le déploiement :
   ```bash
   az deployment group validate \
     --resource-group rg-hub-spoke-norway \
     --template-file main.bicep
   ```
3. Vérifiez les logs de déploiement détaillés dans le portail Azure
4. Assurez-vous que le mot de passe respecte les exigences de complexité

### Commandes de diagnostic utiles

##### 1. Vérifier l'état de santé du Firewall
```
az network firewall show `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --name fw-hub-central
```

##### 2. Vérifier les routes effectives de la VM Prod

```
# (Cela permet de confirmer que le trafic passe bien par 10.0.1.4)
az network nic show-effective-route-table `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --name nic-vm-prod-01 `
  --output table
```

##### 3. Tester la connectivité entre Prod et Non-Prod (Port SSH)

Avant de tester la connectivité il faut : **installer l'extension sur vos deux VMs**

```
# Installation sur la VM Prod
az vm extension set `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --vm-name vm-prod-01 `
  --name NetworkWatcherAgentLinux `
  --publisher Microsoft.Azure.NetworkWatcher `
  --version 1.4

# Installation sur la VM Non-Prod
az vm extension set `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --vm-name vm-nonprod-01 `
  --name NetworkWatcherAgentLinux `
  --publisher Microsoft.Azure.NetworkWatcher `
  --version 1.4
```

##### Tester la connectivité
```
az network watcher test-connectivity `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --source-resource vm-prod-01 `
  --dest-resource vm-nonprod-01 `
  --dest-port 22
```

---

## ❓ FAQ

### Questions générales

**Q : Puis-je ajouter un troisième Spoke (par exemple pour un environnement Marketing) ?**

R : Oui, absolument ! C'est l'un des avantages de l'architecture Hub-and-Spoke. Il suffit de :
1. Créer un nouveau VNet avec une plage IP distincte
2. Créer les peerings bidirectionnels avec le Hub
3. Associer les UDR aux subnets du nouveau Spoke
4. Ajouter les règles de pare-feu nécessaires

**Q : Combien de Spokes puis-je connecter au Hub ?**

R : Azure supporte jusqu'à 500 peerings par VNet. Cependant, pour des raisons de performance et de gestion, il est recommandé de ne pas dépasser 50-100 Spokes par Hub.

**Q : Puis-je utiliser cette architecture dans une autre région Azure ?**

R : Oui, modifiez simplement le paramètre `location` dans le fichier Bicep. Notez que certaines ressources (comme Azure Bastion) doivent être dans la même région que les VNets.

### Questions de sécurité

**Q : Le trafic entre les Spokes est-il chiffré ?**

R : Par défaut, le trafic entre les VNets via peering est chiffré au niveau de la couche réseau Azure. Pour un chiffrement de bout en bout, vous devrez implémenter des solutions supplémentaires (VPN, TLS, etc.).

**Q : Puis-je bloquer complètement la communication entre Production et Non-Production ?**

R : Oui, supprimez ou modifiez la règle "Allow-Internal-Traffic" dans la politique du Firewall pour bloquer le trafic inter-Spoke.

**Q : Comment puis-je sécuriser davantage l'accès aux machines virtuelles ?**

R : Plusieurs options :
- Utiliser Azure AD pour l'authentification SSH
- Implémenter Just-In-Time (JIT) VM Access
- Configurer des Network Security Groups (NSG) supplémentaires
- Utiliser Azure Private Link pour les services

### Questions de coûts

**Q : Y a-t-il des coûts cachés ?**

R : Les principaux coûts supplémentaires peuvent venir de :
- Le trafic sortant (egress) vers Internet
- L'ingestion de logs dans Log Analytics (au-delà de la rétention gratuite)
- Les snapshots et backups des machines virtuelles
- Les adresses IP publiques statiques

**Q : Puis-je réduire les coûts ?**

R : Oui, plusieurs options :
- Utiliser Azure Firewall Basic (au lieu de Standard) pour des besoins moins critiques
- Réduire la rétention des logs (actuellement 30 jours)
- Arrêter/désallouer les VMs de test lorsqu'elles ne sont pas utilisées
- Utiliser des réservations Azure pour les ressources à long terme

### Questions techniques

**Q : Puis-je utiliser des machines virtuelles Windows au lieu de Linux ?**

R : Oui, modifiez simplement la référence d'image dans le fichier Bicep :
```bicep
imageReference: { 
  publisher: 'MicrosoftWindowsServer', 
  offer: 'WindowsServer', 
  sku: '2022-Datacenter', 
  version: 'latest' 
}
```

**Q : Comment puis-je étendre cette architecture à un environnement hybride (on-premise) ?**

R : Ajoutez :
- Une passerelle VPN ou ExpressRoute dans le Hub
- Des routes supplémentaires dans les UDR pour diriger le trafic on-premise
- Des règles de pare-feu pour autoriser la communication hybride

**Q : Le Firewall peut-il gérer le trafic HTTPS/SSL ?**

R : Azure Firewall Standard supporte l'inspection SSL/TLS avec des certificats. Pour cela, vous devrez configurer des règles applicatives avec inspection SSL.

---

## 💰 Coûts estimés

> ⚠️ **Note** : Les coûts varient selon la région, l'utilisation et les tarifs Azure en vigueur.

### Ressources principales

| Ressource | SKU/Taille | Coût mensuel estimé (USD) |
|-----------|------------|---------------------------|
| Azure Firewall (Standard) | Standard | ~$1,250 |
| Azure Bastion | Standard | ~$140 |
| Log Analytics Workspace | PerGB2018 | ~$2.30/GB |
| Virtual Machines (x2) | Standard_B1s | ~$15 |
| Virtual Networks | - | Gratuit |
| Peering | - | Gratuit |

**Total estimé** : ~$1,400-1,500/mois (hors trafic et stockage)

> 💡 **Astuce** : Utilisez le [Calculateur de prix Azure](https://azure.microsoft.com/pricing/calculator/) pour une estimation précise.

---

## 🛠️ Maintenance

### Mises à jour recommandées

- **Règles de pare-feu** : Réviser régulièrement les règles selon les besoins métier
- **Logs** : Analyser les logs de sécurité hebdomadairement
- **Sécurité** : Appliquer les mises à jour de sécurité aux machines virtuelles
- **Monitoring** : Configurer des alertes sur les événements critiques

### Commandes utiles


#### 1. Vérifier l'état du déploiement
Note : Par défaut, le nom du déploiement est souvent le nom du fichier 'main'

```
az deployment group show `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --name main
```
#### 2. Lister toutes les ressources du projet

```
az resource list `
  --resource-group RG-ARCHITECTURE-COMPLET-NORWAY `
  --output table
```
#### 3. Supprimer tout le projet (Hub, Spokes, Firewall, VMs)
# Attention : Cette commande est irréversible.

```
az group delete `
  --name RG-ARCHITECTURE-COMPLET-NORWAY `
  --yes --no-wait
```

---

## 📚 Ressources supplémentaires

- [Documentation Azure Firewall](https://docs.microsoft.com/azure/firewall/)
- [Architecture Hub-and-Spoke](https://docs.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Bastion](https://docs.microsoft.com/azure/bastion/)
- [Log Analytics](https://docs.microsoft.com/azure/azure-monitor/logs/log-analytics-overview)
- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)

---

## 🚀 Évolutions futures

### Améliorations prévues (Roadmap)

#### Version 1.2 (Planifiée)
- [ ] Intégration d'Azure Key Vault pour la gestion des secrets
- [ ] Ajout de Network Security Groups (NSG) pour une sécurité renforcée
- [ ] Configuration d'alertes Azure Monitor pour les événements critiques
- [ ] Documentation des procédures de disaster recovery

#### Version 1.3 (Envisagée)
- [ ] Support multi-régions avec peering global
- [ ] Intégration d'Azure DDoS Protection
- [ ] Configuration de Private Endpoints pour les services Azure
- [ ] Automatisation complète via GitHub Actions / Azure DevOps

#### Version 2.0 (Future)
- [ ] Support d'ExpressRoute pour connectivité hybride
- [ ] Intégration d'Azure WAF (Web Application Firewall)
- [ ] Détection avancée des menaces avec Azure Sentinel
- [ ] Dashboard de monitoring personnalisé avec Azure Dashboards

### Contributions

Les suggestions d'amélioration sont les bienvenues ! N'hésitez pas à :
- Ouvrir une issue pour signaler un bug ou proposer une fonctionnalité
- Créer une pull request avec vos améliorations
- Partager vos retours d'expérience

---

## 🤝 Support

Pour toute question ou problème :

1. Consultez la [documentation Azure](https://docs.microsoft.com/azure/)
2. Ouvrez une issue sur ce repository
3. Contactez votre équipe d'infrastructure Azure

---

## 📄 Licence

Cette infrastructure Hub-and-Spoke automatisée sous Azure (via Bicep) est entièrement libre et open source. Le code source complet, incluant la segmentation réseau avancée, le filtrage par Azure Firewall et le monitoring centralisé, est mis à la disposition de tous gratuitement.

---



[⬆ Retour en haut](#-az-nor-secure-hub-spoke)

</div>
