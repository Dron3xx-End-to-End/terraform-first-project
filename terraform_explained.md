# Terraform project explanation

This file explains every change made in the Terraform configuration and what the final code does now.

## 1) Terraform provider and version

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
```

What this does:
- tells Terraform to use the AWS provider
- pins the provider version to a compatible AWS plugin version
- requires a Terraform CLI version of at least 1.2

Why this matters:
- ensures the configuration works with a supported AWS provider version
- avoids compatibility issues between Terraform and AWS resources

## 2) AWS region and profile

```hcl
provider "aws" {
  region  = "eu-central-1"
  profile = "terraform-first-project"
}
```

What this does:
- deploys all AWS resources in the Frankfurt region (`eu-central-1`)
- uses the local AWS CLI profile named `terraform-first-project`

Why this matters:
- keeps the infrastructure in one region
- ensures Terraform authenticates with the correct AWS account/profile

## 3) VPC module

```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "terraform-first-project-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  tags = {
    Project     = "terraform-first-project"
    Terraform   = "true"
    Environment = "dev"
  }
}
```

What this does:
- creates a VPC with a CIDR block of `10.0.0.0/16`
- creates 2 public subnets and 2 private subnets
- spreads them across 2 availability zones in Frankfurt

Why this matters:
- gives the EC2 instances a network to run in
- allows the ELB to sit in public subnets while app instances can be placed there as well
- creates a structured network for a small dev environment

## 4) Amazon Linux AMI lookup

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

What this does:
- looks up the newest Amazon Linux 2 AMI owned by Amazon
- filters for x86_64, HVM, and a standard Amazon Linux 2 name pattern

Why this matters:
- avoids hardcoding a specific AMI ID that might change or become outdated
- ensures the instance uses a Linux image that supports `yum` and `systemctl`

This was one of the key fixes. The original setup used a mismatched AMI and DNF commands, which caused the web server not to be installed correctly.

## 5) Security groups

```hcl
resource "aws_security_group" "terraform-first-project-sg" {
  name        = "terraform-first-project-sg"
  description = "Allow HTTP inbound traffic to the EC2 instances"

  vpc_id = module.vpc.vpc_id

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "terraform-first-project"
  }
}
```

What this does:
- allows inbound HTTP on port 80 only from the ELB security group
- currently allows SSH port 22 from anywhere for admin access
- allows outbound internet access for package installs and general service communication

Why this matters:
- the ELB health checks must reach the EC2 instances on port 80
- direct HTTP access to the instances is blocked; requests should enter through the ELB
- the instances need outbound access to install software and reach the internet

The SSH rule currently uses `0.0.0.0/0` and should be restricted to a trusted administrator IP before production use.

### Security group for the ELB

```hcl
resource "aws_security_group" "terraform-first-project-elb-sg" {
  name        = "terraform-first-project-elb-sg"
  description = "Allow HTTP traffic to the ELB"

  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "terraform-first-project"
  }
}
```

What this does:
- lets users access the load balancer over HTTP on port 80
- allows the ELB to send outbound traffic to the EC2 instances

Why this matters:
- an ELB needs its own security group so the internet can reach it without exposing the backend infrastructure unnecessarily

## 6) EC2 instances

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

  tags = {
    Name    = "terraform-first-project-EC2-${count.index + 1}"
    Project = "terraform-first-project"
  }
}
```

What this does:
- creates 2 EC2 instances
- uses a `t3.micro` instance type
- places one in each public subnet
- gives them public IP addresses
- assigns the EC2 security group
- runs a startup script when each instance boots

The startup script does:
- `yum update -y` → updates the OS packages
- `yum install -y httpd` → installs Apache HTTP server
- `systemctl start httpd` → starts the web server
- `systemctl enable httpd` → ensures it starts automatically after reboot
- `echo "<h1>Terraform first project</h1>" > /var/www/html/index.html` → creates a simple homepage

Why this matters:
- this is what makes the ELB health check pass
- the ELB expects an HTTP response on port 80
- without the web server, the instance would remain unhealthy

This was the main root-cause fix. The original user data used `dnf`, which is used on Amazon Linux 2023 and some Fedora-based images, but not on Amazon Linux 2.

## 7) ELB configuration

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

  tags = {
    Project = "terraform-first-project"
  }
}
```

What this does:
- creates a classic Elastic Load Balancer named `terraform-first-project-elb`
- puts it in the public subnets
- attaches both EC2 instances
- listens for HTTP traffic on port 80
- checks the root page `/` every 30 seconds
- marks an instance unhealthy if it fails 2 checks in a row

The health check block:
- `target = "HTTP:80/"` → sends an HTTP request to the root page on port 80
- `interval = 30` → checks every 30 seconds
- `timeout = 5` → waits 5 seconds for a response
- `healthy_threshold = 2` → needs 2 successful checks before being considered healthy
- `unhealthy_threshold = 2` → needs 2 failed checks before being marked unhealthy

Why this matters:
- ensures traffic is routed only to working instances
- allows failed nodes to be removed from rotation automatically
- prevents the load balancer from sending requests to dead instances

## 8) What the whole code does now

The final project does this:

1. Creates a VPC with public/private subnets in two availability zones.
2. Creates two EC2 instances in the public subnets.
3. Installs Apache on both EC2 instances during startup.
4. Creates a simple HTML page on each instance.
5. Creates a public ELB in front of both EC2 instances.
6. Uses health checks to make sure each instance answers on port 80.
7. Only sends traffic to healthy instances.

So the final architecture is:

Internet -> ELB -> EC2 instance 1
                 -> EC2 instance 2

The ELB acts as the public entry point, and the EC2 web servers serve the web page.

## 9) Why the health check issue happened before

The old configuration used:
- an AMI that did not match the bootstrap commands
- `dnf` commands on an Amazon Linux 2 image
- no dedicated ELB security group

Because the web server was not installed correctly or because the load balancer could not consistently reach the app, the load balancer repeatedly marked the EC2 instances unhealthy.

The fix was to align the OS, package manager, application startup, and ELB networking so the port 80 health check succeeds.

## 10) Final status

The project has been validated with Terraform and the configuration is currently clean:

- `terraform validate` → passes
- `terraform plan -detailed-exitcode` → reports no differences
- `PLAN_NO_CHANGES`

This means the infrastructure matches the configuration and the Terraform setup is stable.
