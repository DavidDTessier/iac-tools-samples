#!/usr/bin/env python
from constructs import Construct
from cdktf import App, TerraformStack, TerraformOutput
import os
from imports.google import GoogleProvider, ComputeInstance, ComputeInstanceNetworkInterface,  ComputeInstanceNetworkInterfaceAccessConfig, ComputeInstanceBootDiskInitializeParams, ComputeInstanceBootDisk, ComputeFirewall, ComputeFirewallAllow, DataGoogleComputeNetwork


class MyStack(TerraformStack):
    def __init__(self, scope: Construct, ns: str):
        super().__init__(scope, ns)
        credentialsPath = os.path.join(os.getcwd(),'credentials.json')

        credentials = open(credentialsPath).read()

        template = """
        #!/bin/bash
        set -e
        echo "*****    Installing Nginx    *****"
        apt update
        apt install -y nginx
        ufw allow 'Nginx HTTP'
        systemctl enable nginx
        systemctl restart nginx
        
        echo "*****   Installation Complteted!!   *****"
        
        echo "Welcome to Google Compute VM Instance deployed using Terraform CDK and Python!!!" > /var/www/html
        
        echo "*****   Startup script completes!!    *****"
        """

        # define resources here
        GoogleProvider(self, "gcp_provider", region="us-central1",
            zone= "us-central1-c",
            project= "dtessier-hero-path-302118",
            credentials=credentials)
        
        data_net = DataGoogleComputeNetwork(self, "default", name="default")
        ComputeFirewall(self, "default_fw", 
            network= data_net.name,
            name="allow",
            allow=[ComputeFirewallAllow(protocol="tcp",ports=["80","8080"])])

        ComputeInstance(self, id='ComputeInstance', name='cdktf-instance-py',
            boot_disk=[ComputeInstanceBootDisk(auto_delete=True,
            initialize_params=[ComputeInstanceBootDiskInitializeParams(image="ubuntu-os-cloud/ubuntu-1804-lts")])],
            machine_type='f1-micro', metadata_startup_script= template,
            network_interface= [ComputeInstanceNetworkInterface(
                                network=data_net.name,
                                access_config=[ComputeInstanceNetworkInterfaceAccessConfig()])
                           ],
            tags= ["http-server"])


app = App()
MyStack(app, "python_cdktf_gcp")

app.synth()
