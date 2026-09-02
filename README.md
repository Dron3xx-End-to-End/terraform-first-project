# Terraform First Project

This project deploys a simple highly available web infrastructure on AWS using Terraform.

## What this infrastructure creates

- A VPC with public and private subnets
- Two public subnets across two Availability Zones
- Two private subnets reserved for future infrastructure
- Two EC2 instances in public subnets
- An Apache HTTP server installed on each EC2 instance
- A classic Elastic Load Balancer (ELB) in front of the EC2 instances
- Security groups to control inbound traffic

## Architecture
```text
                Internet
                   │
                   ▼
          Elastic Load Balancer
                 Port 80
                   │
          ┌────────┴────────┐
          ▼                 ▼
       EC2 #1             EC2 #2
      Apache             Apache
      Port 80            Port 80
```
Traffic flow:

Internet → ELB → EC2 instances

The ELB distributes incoming HTTP traffic between the two EC2 instances and performs health checks to ensure traffic is routed only to healthy instances.

## Files

- `main.tf` - Terraform infrastructure configuration
- `terraform_explained.md` - detailed explanation of the infrastructure and implementation
- `.gitignore` - excludes Terraform state files and local configuration

## Prerequisites

- Terraform installed
- AWS CLI configured with a profile named `terraform-first-project`
- Access to an AWS account with permissions to create VPCs, EC2 instances, and ELBs

## AWS profile setup

Make sure your AWS credentials are configured:

```bash
aws configure --profile terraform-first-project
```

## Initialize Terraform

```bash
terraform init
```

## Validate the configuration

```bash
terraform validate
```

## Preview changes

```bash
terraform plan
```

## Deploy the infrastructure

```bash
terraform apply
```

## Destroy the infrastructure

```bash
terraform destroy
```

## Security notes

- The EC2 instances allow HTTP only from the ELB security group.
- SSH access should be restricted to a trusted admin IP using a CIDR block such as `YOUR_PUBLIC_IP/32`.
- The ELB accepts HTTP on port 80 from the internet.

## Notes

This project is a basic example of using Terraform to create a small web stack behind a load balancer. The user data installs Apache and serves a simple homepage.
