# Terraform First Project - Technical Explanation

## Architecture

This repository defines a minimal AWS web stack in Terraform. It creates a VPC, public and private subnets, security groups, two EC2 instances, and a classic Elastic Load Balancer that distributes traffic across the HTTP servers.

## 1) Terraform setup

The configuration declares the AWS provider and the required Terraform version in `providers.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region  = "eu-central-1"
  profile = "terraform-first-project"
}
```

This tells Terraform to deploy the stack in Frankfurt and to authenticate using the local AWS profile named `terraform-first-project`.

## 2) VPC and subnets

The VPC module in `vpc.tf` creates the network foundation:

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "terraform-first-project-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
}
```

The result is:

- one VPC in `10.0.0.0/16`
- two public subnets
- two private subnets
- a multi-AZ layout for the demo environment

## 3) AMI lookup and web servers

The project does not hardcode an image ID. Instead, `ec2.tf` discovers the current Amazon Linux 2 AMI with a data source:

```hcl
data "aws_ami" "terraform-first-project-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
```

The EC2 resource then creates two `t3.micro` servers in the public subnets:

```hcl
resource "aws_instance" "terraform-first-project-ec2" {
  ami = data.aws_ami.terraform-first-project-ami.id

  count         = 2
  instance_type = "t3.micro"

  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[count.index]
  vpc_security_group_ids      = [aws_security_group.terraform-first-project-sg.id]

  user_data = <<-EOF
            #!/bin/bash
            yum update -y
            yum install -y httpd
            systemctl start httpd
            systemctl enable httpd
            echo "<h1>Terraform first project</h1>" > /var/www/html/index.html
            EOF
}
```

What this does:
- creates two web servers in different public subnets
- assigns public IPs so the instances are reachable from the ELB
- boots Apache on each host with a minimal homepage

Why this matters:
- it creates a working web tier without additional application orchestration
- the instances become the backend targets for the load balancer

## 4) Security groups

The configuration defines two security groups in `security_groups.tf`.

### EC2 security group

```hcl
resource "aws_security_group" "terraform-first-project-sg" {
  name        = "terraform-first-project-sg"
  description = "Allow HTTP inbound traffic to the EC2 instances"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.terraform-first-project-elb-sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

This allows:

- HTTP traffic from the ELB security group only
- SSH access from anywhere

### ELB security group

```hcl
resource "aws_security_group" "terraform-first-project-elb-sg" {
  name        = "terraform-first-project-elb-sg"
  description = "Allow HTTP traffic to the ELB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

This exposes the classic ELB to internet traffic while keeping direct HTTP access off the instance security group.

## 5) Elastic Load Balancer

`elb.tf` defines a classic AWS ELB:

```hcl
resource "aws_elb" "terraform-first-project-elb" {
  name            = "terraform-first-project-elb"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.terraform-first-project-elb-sg.id]

  instances = aws_instance.terraform-first-project-ec2[*].id

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:80/"
    interval            = 30
  }
}
```

The ELB does the following:

- listens on public port 80
- forwards requests to the EC2 instances on port 80
- performs a health check against `/`
- routes traffic only to healthy instances

## 6) Current end-to-end behavior

The project currently behaves as follows:

1. Terraform creates the VPC and subnet layout.
2. Terraform creates two EC2 instances in the public subnets.
3. The EC2 `user_data` script installs Apache and writes the sample homepage.
4. The ELB checks the instance health on port 80.
5. HTTP traffic is routed across the healthy web servers.

This results in a simple AWS web-tier demo with a classic load balancer in front of two EC2 instances.

## 7) Final status

The current implementation is a single-tier AWS architecture:

- VPC and subnets are provisioned in two availability zones
- two Amazon Linux 2 EC2 instances are created in public subnets
- Apache is installed by `user_data`
- a classic ELB sits in front of the instances and distributes HTTP traffic
- health checks target the web root on port 80

This is the implementation currently present in the Terraform files and is the source of truth for this repository.
