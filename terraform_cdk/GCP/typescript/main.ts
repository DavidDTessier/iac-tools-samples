import { Construct } from 'constructs';
import { App, TerraformStack, TerraformOutput } from 'cdktf';
import { GoogleProvider, ComputeInstance } from './.gen/providers/google'
import * as path from 'path'
import * as fs from 'fs'

class MyStack extends TerraformStack {
  constructor(scope: Construct, name: string) {
    super(scope, name);

    const credentialsPath = path.join(process.cwd(), 'credentials.json')
    const credentials = fs.existsSync(credentialsPath) ? fs.readFileSync(credentialsPath).toString() : '{}'

    new GoogleProvider(this, 'google', {
      region: "us-central1",
      zone: "us-central1-c",
      project: "dtessier-hero-path-302118",
      credentials
    })

    const compute = new ComputeInstance(this, 'ComputeInstance', {
      name: 'cdktf-instance',
      machineType: 'f1-micro',
      bootDisk: [{
        initializeParams: [{
          image: 'ubuntu-os-cloud/ubuntu-1804-lts'
        }]
      }],
      networkInterface: [{
        network: "default",
        accessConfig: [{

        }]
      }],
      tags: ["web", "dev"]
    })

    let ip = "0"

  
    compute.networkInterfaceInput.forEach(net => net.accessConfig && net.accessConfig.forEach(a=> console.log(a.natIp)))
    
    new TerraformOutput(this, 'webserver_ip', {
      value: ip,
    })
  }
}

const app = new App();
new MyStack(app, 'typescript_gcp');
app.synth();
