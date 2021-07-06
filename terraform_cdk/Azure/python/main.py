#!/usr/bin/env python
from constructs import Construct
from cdktf import App, TerraformStack, TerraformOutput
from imports.azurerm import AzurermProvider, NetworkInterface, NetworkInterfaceIpConfiguration, VirtualMachineExtension, LinuxVirtualMachineOsDisk, LinuxVirtualMachineSourceImageReference, NetworkSecurityGroupSecurityRule, PublicIp, ResourceGroup, Subnet, SubnetNetworkSecurityGroupAssociation, VirtualNetwork, NetworkSecurityGroup, LinuxVirtualMachine
from imports.random import RandomProvider, Password
import base64


class AzureWebStack(TerraformStack):
    def __init__(self, scope: Construct, ns: str):
        super().__init__(scope, ns)
        
        f = open("webext.sh", "r")
        scriptStr = f.read()
        instanceUserData = '#! /bin/bash\r\n' \
            'sudo apt-get update\r\n' \
            'sudo apt-get install -y apache2\r\r' \
            'sudo systemctl start apache2 ' \
            'sudo systemctl enable apache2 ' \
            'echo "<h1>Azure Linux VM with Web Server</h1>" | sudo tee /var/www/html/index.html'

        scriptStr_string_bytes = scriptStr.encode("ascii")
  
        base64_bytes = base64.b64encode(scriptStr_string_bytes)
        base64_string = base64_bytes.decode("ascii")
    
        script = '{ "script" : "' + base64_string + '" }'
        AzurermProvider(self, 'AzureRm', features=[{}],
            subscription_id = "00000000-0000-0000-0000-000000000000",
            tenant_id= "00000000-0000-0000-0000-000000000000",
            client_secret = "00000000-0000-0000-0000-000000000000",
            client_id = "00000000-0000-0000-0000-000000000000") 

        RandomProvider(self, "rnd")

        rnd_pass = Password(self, "rnd_pass",
                    length=16,
                    min_upper=2,
                    min_lower=2,
                    min_special=2,
                    number=True,
                    special=True,
                    override_special="!@#$%&"
                )

        rg = ResourceGroup(self, "group", 
                name= "rg-terraform-cdk-py",
                location= "eastus")

        vnet = VirtualNetwork(self, 'TfVnet',
                location= rg.location,
                address_space=['10.0.0.0/16'],
                name = 'terraform-cdk-ts-vnet',
                resource_group_name= rg.name
            )

        subnet = Subnet(self, 'TfVnetSubNet', 
                    virtual_network_name= vnet.name,
                    address_prefix= '10.0.0.0/24',
                    name= 'terraform-cdk-ts-sub',
                    resource_group_name= rg.name
                )

        nsg = NetworkSecurityGroup(self, "TfVnetSecurityGroup",
            location= rg.location,
            name= 'terraform-cdk-ts-nsg',
            resource_group_name= rg.name,
            security_rule= [
                NetworkSecurityGroupSecurityRule(
                name= "AllowWEB",
                description="Allow web",
                priority=1000,
                direction="Inbound",
                access= "Allow",
                protocol="Tcp",
                source_port_range="*",
                destination_port_range= "80",
                source_address_prefix= "Internet",
                destination_address_prefix="*")
            ,
            
                NetworkSecurityGroupSecurityRule(
                name= "SSH",
                priority= 1001,
                direction= "Inbound",
                access= "Allow",
                protocol= "Tcp",
                source_port_range= "*",
                destination_port_range= "22",
                source_address_prefix= "*",
                destination_address_prefix= "*")
            ]
        )

        SubnetNetworkSecurityGroupAssociation(self, "TfVNetSecGrpAssc",
            subnet_id= subnet.id, network_security_group_id= nsg.id,)

        web_vm_ip = PublicIp(self, "TfWebVmIp", 
                        location= rg.location,
                        resource_group_name= rg.name,
                        allocation_method="Static",
                        name= "terragorm-cdk-ts-web-ip")

        nic = NetworkInterface(self, "TfNic", 
                location=rg.location,
                name="terraform-cdk-ts-nic",
                resource_group_name= rg.name,
                ip_configuration=[
                    NetworkInterfaceIpConfiguration(
                        name="internal",
                        private_ip_address_allocation="Dynamic",
                        public_ip_address_id=web_vm_ip.id,
                        subnet_id=subnet.id)
                ])

        webvm = LinuxVirtualMachine(self, "TfWebVM",
                        location=rg.location,
                        name="terraform-cdk-ts-web-vm",
                        resource_group_name=rg.name,
                        network_interface_ids=[nic.id],
                        admin_username="adminUser",
                        size="Standard_B2s",
                        computer_name="web-tfcdk-ts-vm",
                        admin_password=rnd_pass.result,
                        source_image_reference=[LinuxVirtualMachineSourceImageReference(offer="UbuntuServer", 
                            publisher="Canonical", sku="18.04-LTS", version="latest")],
                        os_disk=[LinuxVirtualMachineOsDisk(
                            caching="ReadWrite",
                            storage_account_type="Standard_LRS"
                        )],
      
                        disable_password_authentication=False
                    )

        VirtualMachineExtension(self, "TfWebVMExt",
                        virtual_machine_id=webvm.id,
                        name="webvmext",
                        publisher="Microsoft.Azure.Extensions",
                        type="CustomScript",
                        type_handler_version="2.0",
                        settings=script
                        )


        TerraformOutput(self, 'webserver_ip', value=web_vm_ip)

app = App()
AzureWebStack(app, "python")

app.synth()
