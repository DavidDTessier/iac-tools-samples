import { Stack, StackProps } from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { readFileSync } from 'fs';

export class AwsCdkStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    // The code that defines your stack goes here
    const vpc = ec2.Vpc.fromLookup(this, id = 'VPC',  {isDefault: true})

    const webserverSG = new ec2.SecurityGroup(this, 'webserver-sg', {
      vpc : vpc,
      allowAllOutbound: true
    })

    webserverSG.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(22),
      'allow SSH access from anywhere'
    );

    webserverSG.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(80),
      'allow HTTP traffic from anywhere.'
    );

    webserverSG.addIngressRule(
      ec2.Peer.anyIpv4(),
      ec2.Port.tcp(443),
      'allow HTTPS traffic from anywhere.'
    );


    // create a role for the EC2 instanceType
    const webserverRole = new iam.Role(this,'webserver-role', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
      managedPolicies: [
        iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonS3ReadOnlyAccess'),
      ]
    });


    const ec2Instance = new ec2.Instance(this,'ec2Instance', {
        instanceType: ec2.InstanceType.of(
          ec2.InstanceClass.T3,
          ec2.InstanceSize.MICRO),
        machineImage: new ec2.AmazonLinuxImage({
          generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2
        }),
        keyName: 'ec2-key-pair',
        vpc: vpc,
        vpcSubnets: {
          subnetType: ec2.SubnetType.PUBLIC
        },
        role: webserverRole,
        securityGroup: webserverSG
    });

    // load contents of script
    const userDataScript = readFileSync('./lib/user-data.sh', 'utf8');

    // add the User Data script to the Instance
    ec2Instance.addUserData(userDataScript);
  }

}
