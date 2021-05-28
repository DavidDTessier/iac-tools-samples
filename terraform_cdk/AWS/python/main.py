#!/usr/bin/env python
from constructs import Construct
from cdktf import App, TerraformStack, TerraformOutput, Token
from imports.aws import Instance, AwsProvider, SecurityGroup, SecurityGroupIngress, SecurityGroupEgress


class MyStack(TerraformStack):
    def __init__(self, scope: Construct, ns: str):
        super().__init__(scope, ns)

        # define resources here
        instanceUserData = '#!/bin/bash\r\n' \
                            'echo "Hello, World From Python Form Terraform CDK " > index.html\r\n'\
                            'nohup busybox httpd -f -p 80 &\r\n'

        AwsProvider(self, 'Aws', region='us-east-1')
        ingress_allow = SecurityGroupIngress(
                cidr_blocks=['0.0.0.0/0'],
                ipv6_cidr_blocks=[],
                protocol='tcp',
                from_port=80,
                to_port=80,
                description="Allow",
                prefix_list_ids=[],
                security_groups=[],
                self_attribute=False
                )

        egress_allow = SecurityGroupEgress(
                cidr_blocks=['0.0.0.0/0'],
                ipv6_cidr_blocks=[],
                protocol='-1',
                from_port=0,
                to_port=0,
                prefix_list_ids=[],
                security_groups=[],
                self_attribute=False
                )

        secGroup = SecurityGroup(self, 'web_server', name="allow_web_traffic", ingress= [ingress_allow], egress = [egress_allow])
        instance = Instance(self, "hello", ami="ami-2757f631", instance_type="t2.micro", vpc_security_group_ids=[Token.as_string(secGroup.id)], user_data=instanceUserData, tags=["Name","Terraform-CDK WebServer"])

        TerraformOutput(self, 'public_dns', value = instance.public_dns)

app = App()
MyStack(app, "python")

app.synth()
