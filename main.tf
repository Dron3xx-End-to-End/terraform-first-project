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