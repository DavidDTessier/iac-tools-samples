import { Construct } from 'constructs';
import { App, TerraformOutput, TerraformStack, Token } from 'cdktf';
import { AwsProvider, Instance, SecurityGroup } from './.gen/providers/aws'

class MyStack extends TerraformStack {
  constructor(scope: Construct, name: string) {
    super(scope, name);

    let instanceUserData = '#!/bin/bash\r\n' +
    'echo "Hello, World From Typescript for Terraform CDK!" > index.html\r\n'+
    'nohup busybox httpd -f -p 80 &\r\n'

    new AwsProvider(this, "aws", {
      region: "us-east-1"
    })

    const secGroup = new SecurityGroup(this, 'web_server', {
      name: 'allow_web_traffic',
      ingress: [{
        protocol : 'tcp',
        fromPort : 80,
        toPort : 80,
        cidrBlocks : ["0.0.0.0/0"]
      }],
      egress : [{
        protocol: '-1',
        fromPort : 0,
        toPort: 0,
        cidrBlocks: ["0.0.0.0/0"]
      }]
    })

    const instance = new Instance(this, 'web_sever', {
      ami: 'ami-09e67e426f25ce0d7',
      instanceType: 't2.micro',
      vpcSecurityGroupIds: [Token.asString(secGroup.id)],
      userData: instanceUserData,
      tags: {
        Name: 'Terraform-CDK WebServer'
      },
    })

    new TerraformOutput(this, 'public_dns', {
      value: instance.publicDns,
    })

  }
}

const app = new App();
new MyStack(app, 'typescript-aws');
app.synth();
