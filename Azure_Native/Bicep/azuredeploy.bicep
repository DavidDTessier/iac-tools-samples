@allowed([
  'Dynamic'
  'Static'
])
@description('Allocation method for the Public IP used to access the Virtual Machine.')
param publicIPAllocationMethod string = 'Dynamic'

@description('Name for the Public IP used to access the Virtual Machine.')
param publicIpName string = 'myPublicIP'

@minLength(3)
@maxLength(12)
@description('Username for the Virtual Machine.')
param adminUser string

@minLength(3)
@maxLength(12)
@secure()
@description('Password for the Virtual Machine.')
param adminPassword string

@description('Name for the Virtual Machine.')
param vmName string = 'myVM'

@description('nique DNS Name for the Public IP used to access the Virtual Machine.')
param dnsLabelPrefix string = toLower(format('{0}-{1}', vmName, uniqueString(resourceGroup().id, vmName)))

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Size for the Virtual Machine.')
param vmSize string = 'Standard_D2_v3'

@allowed([
  'Basic'
  'Standard'
])
@description('SKU for the Public IP used to access the Virtual Machine.')
param publicIpSku string = 'Basic'

@allowed([
  '2008-R2-SP1'
  '2012-Datacenter'
  '2012-R2-Datacenter'
  '2016-Nano-Server'
  '2016-Datacenter-with-Containers'
  '2016-Datacenter'
  '2019-Datacenter'
  '2019-Datacenter-Core'
  '2019-Datacenter-Core-smalldisk'
  '2019-Datacenter-Core-with-Containers'
  '2019-Datacenter-Core-with-Containers-smalldisk'
  '2019-Datacenter-smalldisk'
  '2019-Datacenter-with-Containers'
  '2019-Datacenter-with-Containers-smalldisk'
])
@description('The Windows version for the VM. This will pick a fully patched image of this given Windows version.')
param osVersion string = '2019-Datacenter'


var storageAccountName = format('bootdiags{0}', uniqueString(resourceGroup().id))
var nicName = 'myVMNic'
var addressPrefix = '10.0.0.0/16'
var subnetName =  'Subnet'
var subnetPrefix = '10.0.0.0/24'
var virtualNetworkName = 'MyVNET'
var networkSecurityGroupName = 'default-NSG'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-03-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHTTPInBound'
        properties: {
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '80'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
         destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', networkSecurityGroupName)
          }
        }
      }
    ]
  }

  dependsOn: [
    networkSecurityGroup
  ]
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings:{
      domainNameLabel: dnsLabelPrefix
    } 
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
          }
        }
      }
    ]
  }

  dependsOn:[ 
    publicIp 
    virtualNetwork
  ]

}

resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminPassword: adminPassword
      adminUsername: adminUser
    }
    storageProfile: {
     imageReference: {
       publisher: 'MicrosoftWindowsServer'
       offer: 'WindowsServer'
       sku: osVersion
       version: 'latest'
     }
     osDisk: {
      createOption: 'FromImage'
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
     }
     dataDisks: [
      {
        diskSizeGB: 1023
        lun: 0
        createOption: 'Empty'
      }
    ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }

  dependsOn: [
    storageAccount
    nic
  ]
}

resource vmExtensions 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  name: '${vmName}/InstallWebServer'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.7'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/Azure/azure-docs-json-samples/master/tutorial-vm-extension/installWebServer.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File installWebServer.ps1'
    }
  }

  dependsOn: [
    vm
  ]
}

output hostname string =  publicIp.properties.dnsSettings.fqdn
