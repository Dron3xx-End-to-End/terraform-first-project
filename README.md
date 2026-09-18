# Terraform First Project

## Overview

This repository provisions a small AWS web stack in Terraform. It creates a VPC, public and private subnets, two Amazon Linux EC2 instances in the public subnets, and a classic Elastic Load Balancer that fronts the web servers on port 80. Each EC2 instance installs Apache through `user_data`, and the load balancer performs a health check against the web root.

## Technologies Used

- Terraform
- AWS
- EC2
- ELB
- Apache

## Requirements

- Terraform 1.2 or newer
- AWS CLI configured with the `terraform-first-project` profile
- An AWS account with permissions to create VPCs, EC2 instances, and ELBs

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

## Repository Structure

```text
terraform-first-project/
├── ec2.tf
├── elb.tf
├── providers.tf
├── README.md
├── explained.md
├── security_groups.tf
├── vpc.tf
├── .gitignore
└── .terraform.lock.hcl
```

The tracked project files are a small Terraform configuration for a single-tier AWS web environment. Local state files and generated Terraform artifacts are not described as part of the repository structure.

## Current Infrastructure

The current configuration creates:

- a VPC with two public and two private subnets across two availability zones
- two EC2 instances in the public subnets using Amazon Linux 2 AMIs
- an EC2 security group permitting SSH from anywhere and HTTP only from the ELB
- an ELB security group permitting HTTP from the internet
- a classic ELB with a health check on `HTTP:80/`

This is a straightforward EC2 + ELB deployment; it does not define autoscaling or an application tier beyond the two web servers.

## Notes

- The EC2 `user_data` script installs Apache and writes a minimal home page to `/var/www/html/index.html`.
- The ELB checks each instance on port 80 and routes traffic only to healthy targets.
- The project is intentionally minimal and centered on a single public web tier.
