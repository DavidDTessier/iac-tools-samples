terraform {
  required_version = ">= 0.12, <=0.15"
  required_providers {
      aws = {
          version = "~> 3.0",
          source="hashicorp/aws"
      }
  }
}

provider "aws" {
  region = "us-east-1"
}

// create micro ec2 instance
resource "aws_instance" "web_server" {
    // Amazon Machine Image ID of an Ubuntu 18.04 AMI  in us-east-1
    ami = "ami-09e67e426f25ce0d7" 
    vpc_security_group_ids = [aws_security_group.web_server.id]
    // EC2 Instance to run 
    instance_type = "t2.micro"    
    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p 80 &
              EOF
    tags = {
        Name = "terraform-webserver-example"
    }
}

# Create security group with web and ssh access
resource "aws_security_group" "web_server" {
  name = "allow_web_traffic"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "DNS" {
  value = aws_instance.web_server.public_dns
}