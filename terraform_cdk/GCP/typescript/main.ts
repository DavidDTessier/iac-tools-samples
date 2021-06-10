import { Construct } from 'constructs';
import { App, TerraformStack, TerraformOutput } from 'cdktf';
import { GoogleProvider, ComputeInstance, ComputeFirewall, DataGoogleComputeNetwork } from './.gen/providers/google'
import * as path from 'path'
import * as fs from 'fs'

class MyStack extends TerraformStack {
  constructor(scope: Construct, name: string) {
    super(scope, name);

    const credentialsPath = path.join(process.cwd(), 'credentials.json')
    const credentials = fs.existsSync(credentialsPath) ? fs.readFileSync(credentialsPath).toString() : '{}'
    const template = `#!/bin/bash
    set -e
    echo "*****    Installing Nginx    *****"
    apt update
    apt install -y nginx
    ufw allow 'Nginx HTTP'
    systemctl enable nginx
    systemctl restart nginx
    
    echo "*****   Installation Complteted!!   *****"
    
    echo "Welcome to Google Compute VM Instance deployed using Terraform!!!" > /var/www/html
    
    echo "*****   Startup script completes!!    *****"`

    new GoogleProvider(this, 'google', {
      region: "us-central1",
      zone: "us-central1-c",
      project: "dtessier-hero-path-302118",
      credentials
    })

    const data_net = new DataGoogleComputeNetwork(this, "default", {
      name : "default"
    })

    new ComputeFirewall(this, "default_fw_ts", {
      network: data_net.name,
      name: "allow",
      allow: [{ 
        ports: ["80", "8080"],
        protocol: "tcp"
      }]
    })

    const compute = new ComputeInstance(this, 'ComputeInstance', {
      name: 'cdktf-instance-ts',
      machineType: 'f1-micro',
      bootDisk: [{
        initializeParams: [{
          image: 'ubuntu-os-cloud/ubuntu-1804-lts'
        }]
      }],
      
      metadataStartupScript: template,
      networkInterface: [{
        network: "default",
        accessConfig: [{
          // Ephemeral IP
        }]
      }],
      tags: ["http-server"]
    })

    let ac = compute.networkInterface[0].accessConfig
    let ip = (ac && ac.length > 0) ? ac[0].natIp : "0" 
    new TerraformOutput(this, 'webserver_ip', {
      value: ip
    })
  }
}

const app = new App();
new MyStack(app, 'typescript_gcp');
app.synth();
