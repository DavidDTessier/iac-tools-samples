import { Construct } from 'constructs';
import { Base64 } from 'js-base64';
import { App, TerraformStack, TerraformOutput } from 'cdktf';
import { RandomProvider, Password } from './.gen/providers/random'
import { AzurermProvider, ResourceGroup, VirtualNetwork, Subnet, NetworkSecurityGroup, SubnetNetworkSecurityGroupAssociation, NetworkInterface, PublicIp , LinuxVirtualMachine, VirtualMachineExtension} from './.gen/providers/azurerm'

class AzureWebAppStack extends TerraformStack {
  constructor(scope: Construct, name: string) {
    super(scope, name);

    let instanceUserData = `#! /bin/bash
            sudo apt-get update
            sudo apt-get install -y apache2
            sudo systemctl start apache2
            sudo systemctl enable apache2
            echo "<h1>Azure Linux VM with Web Server</h1>" | sudo tee /var/www/html/index.html`;

    let script = '{ "script" : "' +  Base64.encode(instanceUserData) + '" }'

    // define resources here
    new AzurermProvider(this, "azurerm",{
        features: [{}],
        subscriptionId : "00000000-0000-0000-0000-000000000000",
        clientId : "00000000-0000-0000-0000-000000000000",
        clientSecret  : "",
        tenantId  :"00000000-0000-0000-0000-000000000000"
    }
    )

    new RandomProvider(this, "rnd", {})

    const rnd_pass = new Password(this, "rnd_pass", {
      length:16,
      minUpper:2,
      minLower:2,
      minSpecial:2,
      number:true,
      special:true,
      overrideSpecial:"!@#$%&"
    })

    const rg = new ResourceGroup(this, "group", {
      name: "rg-terraform-cdk-ts",
      location: "eastus"
    })

    const vnet = new VirtualNetwork(this, 'TfVnet', {
      location: rg.location,
      addressSpace: ['10.0.0.0/16'],
      name: 'terraform-cdk-ts-vnet',
      resourceGroupName: rg.name
    })

    const subnet = new Subnet(this, 'TfVnetSubNet', {
      virtualNetworkName: vnet.name,
      addressPrefixes: ['10.0.0.0/24'],
      name: 'terraform-cdk-ts-sub',
      resourceGroupName: rg.name
    })

    const nsg = new NetworkSecurityGroup(this, "TfVnetSecurityGroup", {
      location: rg.location,
      name: 'terraform-cdk-ts-nsg',
      resourceGroupName: rg.name,
      securityRule: [{
          name : "AllowWEB",
          description :"Allow web",
          priority  :1000,
          direction  :"Inbound",
          access    : "Allow",
          protocol :"Tcp",
          sourcePortRange :"*",
          destinationPortRange  : "80",
          sourceAddressPrefix  : "Internet",
          destinationAddressPrefix :"*"
        },
        {
          name : "SSH",
          priority : 1001,
          direction : "Inbound",
          access : "Allow",
          protocol  : "Tcp",
          sourcePortRange  :  "*",
          destinationPortRange : "22",
          sourceAddressPrefix : "*",
          destinationAddressPrefix : "*"
       }
      ]
    })


    new SubnetNetworkSecurityGroupAssociation(this, "TfVNetSecGrpAssc",
    {
      subnetId: subnet.id,
      networkSecurityGroupId: nsg.id,
    })

    const web_vm_ip = new PublicIp(this, "TfWebVmIp", {
      location : rg.location,
      resourceGroupName : rg.name,
      allocationMethod: "Static",
      name : "terragorm-cdk-ts-web-ip"
    })

    const nic = new NetworkInterface(this, "TfNic", {
      location: rg.location,
      name: "terraform-cdk-ts-nic",
      resourceGroupName: rg.name,
      ipConfiguration: [{
        name  : "internal",
        subnetId : subnet.id,
        privateIpAddressAllocation : "Dynamic",
        publicIpAddressId : web_vm_ip.id
      }]
    })

    const webvm = new LinuxVirtualMachine(this, "TfWebVM", {
      location: rg.location,
      name: "terraform-cdk-ts-web-vm",
      resourceGroupName: rg.name,

      networkInterfaceIds : [nic.id],
      adminUsername: "adminUser",
      size : "Standard_B2s",
      computerName : "web-tfcdk-ts-vm",
      adminPassword : rnd_pass.result,

      sourceImageReference: [{
        offer  : "UbuntuServer",
        publisher : "Canonical",
        sku      : "18.04-LTS",
        version  : "latest"
      }],

      osDisk: [{
        caching  : "ReadWrite",
        storageAccountType : "Standard_LRS"
      }],
      
      disablePasswordAuthentication : false

    })

    new VirtualMachineExtension(this, "TfWebVMExt", {
      virtualMachineId: webvm.id,
      name: "webvmext",
      publisher : "Microsoft.Azure.Extensions",
      type : "CustomScript",
      typeHandlerVersion: "2.0",
      settings:script
    })


    new TerraformOutput(this, 'webserver_ip', {
      value: web_vm_ip
    })

  }
}

const app = new App();
new AzureWebAppStack(app, 'typescript');
app.synth();
