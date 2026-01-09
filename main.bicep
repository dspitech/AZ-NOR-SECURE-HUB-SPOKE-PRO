/*
================================================================================
PROJET : AZ-NOR-SECURE-HUB-SPOKE
ARCHITECTURE : Hub-and-Spoke avec Inspection de Flux Centralisée
REGION : Norway East
VERSION : 1.1 (Monitoring & IP Segmentation Active)
--------------------------------------------------------------------------------
SEGMENTATION RÉSEAU :
- HUB (Management/Shared) : 10.0.0.0/16
- SPOKE PROD (Production) : 192.168.0.0/16
- SPOKE NON-PROD (Dev/Test) : 172.16.0.0/12
================================================================================
*/

@description('Région de déploiement des ressources')
param location string = 'norwayeast'

@description('Nom d\'utilisateur administrateur pour les instances Linux')
param adminUsername string = 'azureadmin'

@description('Mot de passe sécurisé pour l\'administration (Passé via CLI)')
@secure()
param adminPassword string

// --- VARIABLES TECHNIQUES ---
var fwPrivateIp = '10.0.1.4'

// ==========================================
// 1. MONITORING : LOG ANALYTICS WORKSPACE
// ==========================================
// Workspace centralisé pour la rétention et l'analyse des logs de sécurité
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'law-hub-norway'
  location: location
  properties: { 
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ==========================================
// 2. ROUTAGE : USER DEFINED ROUTES (UDR)
// ==========================================
// Force tout le trafic des Spokes à passer par l'IP privée du Firewall (Inspection)
resource routeTableSpoke 'Microsoft.Network/routeTables@2023-05-01' = {
  name: 'rt-forced-to-firewall'
  location: location
  properties: {
    routes: [
      {
        name: 'Default-Forced-Traffic'
        properties: {
          addressPrefix: '0.0.0.0/0' 
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fwPrivateIp
        }
      }
    ]
  }
}

// ==========================================
// 3. INFRASTRUCTURE RÉSEAU (VNETS)
// ==========================================

// HUB VNET : Héberge le Firewall et le Bastion
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-hub-core'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      { name: 'AzureFirewallSubnet', properties: { addressPrefix: '10.0.1.0/24' } }
      { name: 'AzureBastionSubnet', properties: { addressPrefix: '10.0.2.0/24' } }
    ]
  }
}

// SPOKE PROD : Réseau 192.168.x.x (Isolé)
resource prodVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-spoke-prod'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['192.168.0.0/16'] }
    subnets: [{ 
      name: 'snet-prod-resources'
      properties: { 
        addressPrefix: '192.168.1.0/24' 
        routeTable: { id: routeTableSpoke.id }
      } 
    }]
  }
}

// SPOKE NON-PROD : Réseau 172.16.x.x (Isolé)
resource nonProdVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-spoke-nonprod'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['172.16.0.0/12'] }
    subnets: [{ 
      name: 'snet-nonprod-resources'
      properties: { 
        addressPrefix: '172.16.1.0/24' 
        routeTable: { id: routeTableSpoke.id }
      } 
    }]
  }
}

// ==========================================
// 4. INTERCONNEXIONS (VNET PEERINGS)
// ==========================================
// Hub <-> Prod
resource h2p 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = { parent: hubVnet, name: 'hub-to-prod', properties: { remoteVirtualNetwork: { id: prodVnet.id }, allowVirtualNetworkAccess: true, allowForwardedTraffic: true } }
resource p2h 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = { parent: prodVnet, name: 'prod-to-hub', properties: { remoteVirtualNetwork: { id: hubVnet.id }, allowVirtualNetworkAccess: true, allowForwardedTraffic: true } }

// Hub <-> Non-Prod
resource h2np 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = { parent: hubVnet, name: 'hub-to-nonprod', properties: { remoteVirtualNetwork: { id: nonProdVnet.id }, allowVirtualNetworkAccess: true, allowForwardedTraffic: true } }
resource np2h 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = { parent: nonProdVnet, name: 'nonprod-to-hub', properties: { remoteVirtualNetwork: { id: hubVnet.id }, allowVirtualNetworkAccess: true, allowForwardedTraffic: true } }

// ==========================================
// 5. SÉCURITÉ : AZURE FIREWALL & POLITIQUES
// ==========================================
resource fwPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: 'fw-policy-global'
  location: location
  properties: { sku: { tier: 'Standard' } }
}

// Règles autorisant le trafic inter-spoke (Ping/SSH)
resource fwRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  parent: fwPolicy
  name: 'TrafficRuleCollection'
  properties: {
    priority: 1000
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'Allow-Internal-Traffic'
        priority: 1100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Prod-NonProd-Bidirectional'
            ipProtocols: ['ICMP', 'TCP', 'UDP']
            sourceAddresses: ['192.168.0.0/16', '172.16.0.0/12']
            destinationAddresses: ['192.168.0.0/16', '172.16.0.0/12']
            destinationPorts: ['*']
          }
        ]
      }
    ]
  }
}

// Instance Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: 'fw-hub-central'
  location: location
  properties: {
    sku: { name: 'AZFW_VNet', tier: 'Standard' }
    firewallPolicy: { id: fwPolicy.id }
    ipConfigurations: [{
      name: 'fwConfig'
      properties: {
        subnet: { id: hubVnet.properties.subnets[0].id }
        publicIPAddress: { id: fwIp.id }
      }
    }]
  }
}

resource fwIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-fw-central'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// --- ACTIVATION DU MONITORING DES FLUX ---
resource fwDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-fw-to-loganalytics'
  scope: firewall
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      { category: 'AzureFirewallNetworkRule', enabled: true }
      { category: 'AzureFirewallApplicationRule', enabled: true }
    ]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// ==========================================
// 6. ACCÈS : BASTION HOST
// ==========================================
resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: 'bastion-hub'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'BastionIpConf'
      properties: {
        subnet: { id: hubVnet.properties.subnets[1].id }
        publicIPAddress: { id: bastionIp.id }
      }
    }]
  }
}

resource bastionIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-bastion-hub'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// ==========================================
// 7. COMPUTE : VIRTUAL MACHINES
// ==========================================

// VM PRODUCTION
resource nicProd 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-vm-prod-01'
  location: location
  properties: {
    ipConfigurations: [{ 
      name: 'ipconfig1' 
      properties: { 
        subnet: { id: prodVnet.properties.subnets[0].id }
        privateIPAllocationMethod: 'Dynamic' 
      } 
    }]
  }
}

resource vmProd 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-prod-01'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: { computerName: 'vm-prod', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-focal', sku: '20_04-lts', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    networkProfile: { networkInterfaces: [{ id: nicProd.id }] }
  }
}

// VM NON-PROD
resource nicNonProd 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-vm-nonprod-01'
  location: location
  properties: {
    ipConfigurations: [{ 
      name: 'ipconfig1' 
      properties: { 
        subnet: { id: nonProdVnet.properties.subnets[0].id }
        privateIPAllocationMethod: 'Dynamic' 
      } 
    }]
  }
}

resource vmNonProd 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-nonprod-01'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: { computerName: 'vm-nonprod', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-focal', sku: '20_04-lts', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' } }
    }
    networkProfile: { networkInterfaces: [{ id: nicNonProd.id }] }
  }
}
