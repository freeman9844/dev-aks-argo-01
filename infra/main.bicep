param location string = resourceGroup().location
param aksName string
param acrName string
param nodeVmSize string = 'Standard_D4s_v5'

resource aks 'Microsoft.ContainerService/managedClusters@2024-10-01' = {
  name: aksName
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    dnsPrefix: aksName
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        count: 2
        vmSize: nodeVmSize
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      loadBalancerSku: 'standard'
    }
  }
}

resource argocd 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
  name: 'argocd'
  scope: aks
  properties: {
    extensionType: 'Microsoft.ArgoCD'
    autoUpgradeMinorVersion: true
    scope: { cluster: { releaseNamespace: 'argocd' } }
    configurationSettings: {
      'redis-ha.enabled': 'false'
      'server.service.type': 'ClusterIP'
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
    roleAssignmentMode: 'LegacyRegistryPermissions'
  }
}

var pullRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
resource pull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aks.id, pullRole)
  scope: acr
  properties: {
    roleDefinitionId: pullRole
    principalType: 'ServicePrincipal'
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
  }
}

output aksName string = aks.name
output acrLoginServer string = acr.properties.loginServer
output acrId string = acr.id
