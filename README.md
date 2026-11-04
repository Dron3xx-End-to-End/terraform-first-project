# Terraform First Project

## Overview

This repository provisions a small AWS web stack in Terraform. It creates a VPC with public and private subnets, a public Classic Elastic Load Balancer (ELB), and two Amazon Linux 2 EC2 web servers in private subnets. The EC2 instances have no public IP addresses. The ELB accepts HTTP traffic from the internet and forwards it to the instances; their security group permits HTTP only from the ELB's security group.

An Internet Gateway provides internet connectivity for the public subnets. A single NAT Gateway provides outbound internet access for resources in the private subnets. Each EC2 instance installs Apache through `user_data`, and the ELB checks the web root for instance health.

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
├── outputs.tf
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

- a VPC (`10.0.0.0/16`) with two public and two private subnets across `eu-central-1a` and `eu-central-1b`
- an Internet Gateway for internet connectivity in the public subnets
- one NAT Gateway for outbound internet traffic from the private subnets
- two `t3.micro` EC2 instances using the latest matching Amazon Linux 2 AMI, each in a private subnet and without a public IP address
- an EC2 security group that allows inbound HTTP on port 80 only from the ELB security group; no SSH ingress rule is configured
- an ELB security group that allows inbound HTTP on port 80 from `0.0.0.0/0`
- a public Classic ELB in the public subnets, forwarding HTTP on port 80 to the EC2 instances and checking `HTTP:80/`

This is a straightforward two-server web deployment. It does not define autoscaling or an application tier beyond the EC2 instances.

## Terraform outputs

After applying the configuration, Terraform exposes:

- `private_ips` — private IP addresses of both EC2 instances
- `ec2_instance_ids` — IDs of both EC2 instances
- `ec2_availability_zones` — availability zones of both EC2 instances
- `vpc_id` — ID of the VPC
- `security_group_id` — ID of the EC2 security group
- `elb_security_group_id` — ID of the ELB security group
- `elb_dns` — DNS name of the ELB
- `private_subnet_ids` — IDs of the private subnets

## Notes

- **Cost warning:** Deploying this infrastructure may incur AWS charges, particularly for the NAT Gateway and Classic ELB. Review current AWS pricing and remove resources when they are no longer needed.
- The EC2 `user_data` script installs Apache and writes a minimal home page to `/var/www/html/index.html`.
- The ELB checks each instance on port 80 and routes traffic only to healthy targets.
- The instances are not directly reachable from the internet. Internet-facing HTTP traffic enters through the ELB; outbound internet access from private subnets uses the NAT Gateway.
- The project is intentionally minimal and centered on a private web tier behind a public load balancer.
