# Terraform First Project

## Overview

This repository provisions an AWS web application stack using Terraform. A public Application Load Balancer (ALB) sends HTTP traffic to web servers managed by an Auto Scaling Group (ASG) in private subnets. The instances are launched from a launch template, have no public IP addresses, and install Apache through `user_data`.

The VPC module creates public and private subnets, an Internet Gateway, and one NAT Gateway per Availability Zone for outbound connectivity from private subnets.

## Technologies

- Terraform
- AWS VPC, EC2, Auto Scaling, and Application Load Balancer
- Apache HTTP Server

## Requirements

- Terraform 1.9.0 or newer
- AWS CLI configured with the `terraform-first-project` profile
- An AWS account with permissions to create VPC, NAT Gateway, EC2, Auto Scaling, and ALB resources

## Deployment

From the project root:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

To tear the infrastructure down:

```bash
terraform destroy
```

Review the plan before applying it. **Deploying this infrastructure can incur AWS charges, particularly for NAT Gateways and the ALB.** Review current AWS pricing and destroy resources when they are no longer needed.

## Repository Structure

```text
terraform-first-project/
├── alb.tf
├── ec2.tf
├── outputs.tf
├── providers.tf
├── README.md
├── explained.md
├── security_groups.tf
├── variables.tf
├── vpc.tf
├── .gitignore
└── .terraform.lock.hcl
```

Terraform state and other generated local files are not included in this listing.

## Current Infrastructure

The configuration defines:

- A VPC with a default CIDR of `10.0.0.0/16`.
- Public and private subnet CIDRs configurable through input variables. The defaults provide two of each, in dynamically selected available Availability Zones.
- An Internet Gateway and a NAT Gateway in each Availability Zone. Private subnets use NAT for outbound internet access.
- A launch template using the latest matching Amazon Linux 2023 x86_64 AMI and the configurable EC2 instance type (default `t3.micro`).
- An Auto Scaling Group in the private subnets. Its default minimum, desired, and maximum capacities are 1, 2, and 2 instances.
- A public ALB with an HTTP listener on port 80, forwarding to an HTTP target group on port 80. The target group checks `/` and expects status `200`.
- An EC2 security group that allows inbound HTTP only from the ALB security group. The ALB security group allows inbound HTTP on port 80 from the internet.

The ASG registers its instances with the ALB target group. No standalone `aws_instance` resource is defined.

## Terraform Outputs

After applying the configuration, Terraform exposes:

- `private_ips` — private IP addresses returned by the EC2 instance lookup
- `ec2_instance_ids` — instance IDs returned by the EC2 instance lookup
- `ec2_availability_zones` — Availability Zones associated with the Auto Scaling Group
- `vpc_id` — ID of the VPC
- `ec2_security_group_id` — ID of the EC2 security group
- `alb_security_group_id` — ID of the ALB security group
- `alb_dns` — DNS name of the ALB
- `private_subnet_ids` — IDs of the private subnets

The EC2 lookup used for `private_ips` and `ec2_instance_ids` filters by the VPC ID (`module.vpc.vpc_id`) and the Auto Scaling Group name.

## Notes

- The launch template's startup script updates Amazon Linux, installs and enables Apache, and writes a sample page to `/var/www/html/index.html`.
- The EC2 instances have no public IP addresses and no inbound SSH rule is configured.
- The ALB health check routes traffic only to healthy targets.
- `variables.tf` contains configurable region, instance type, scaling limits, and subnet/VPC CIDRs, together with input validations.
