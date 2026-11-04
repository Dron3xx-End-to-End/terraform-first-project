# Terraform First Project - Technical Explanation

## Architecture

The project deploys a small web tier in AWS. A public Application Load Balancer (ALB) receives HTTP requests and forwards them to an Auto Scaling Group (ASG) in private subnets. The ASG launches EC2 instances from a launch template and registers them with the ALB target group. Instances have private addresses only.

The VPC module creates public and private subnets, an Internet Gateway for public connectivity, and a NAT Gateway in each Availability Zone for outbound connectivity from private subnets.

## 1. Terraform and AWS provider

`providers.tf` requires Terraform 1.9.0 or newer and AWS provider `~> 6.28.0`. The provider region is configurable through `aws_region`, which defaults to `eu-central-1`; credentials use the local AWS profile `terraform-first-project`.

## 2. Variables and network

`variables.tf` defines:

- `aws_region`, defaulting to `eu-central-1`
- `ec2_instance_type`, defaulting to `t3.micro`
- `ec2_scaling_config`, defaulting to minimum capacity 1, desired capacity 2, and maximum capacity 2
- the VPC CIDR and lists of public and private subnet CIDRs

Validations check the VPC CIDR, require non-empty subnet lists, and ensure the desired ASG capacity is within its configured limits and no greater than two.

In `vpc.tf`, available Availability Zones are discovered dynamically. The module uses as many zones as there are private subnet CIDRs and provisions the configured public and private subnets. NAT is enabled with `one_nat_gateway_per_az = true`, so each selected Availability Zone has its own NAT Gateway. The module also creates the Internet Gateway for the public subnets.

With the default variables, the VPC is `10.0.0.0/16`, with two public subnets (`10.0.101.0/24`, `10.0.102.0/24`) and two private subnets (`10.0.1.0/24`, `10.0.2.0/24`).

## 3. Launch template and Auto Scaling Group

`ec2.tf` looks up the latest Amazon-owned AMI matching `al2023-ami-*` and `x86_64`. The launch template configures the selected AMI, instance type, EC2 security group, and startup script. Its network interface does not associate a public IP address.

The startup script updates Amazon Linux 2023, installs and enables Apache (`httpd`), and writes a sample homepage to `/var/www/html/index.html`.

The Auto Scaling Group:

- launches instances into the private subnets
- uses the launch template's latest version
- takes minimum, desired, and maximum capacity from `ec2_scaling_config`
- registers instances with the ALB target group through `target_group_arns`
- uses ELB health checks with a 300-second grace period
- assigns launched instances the `Name` tag `terraform-first-project-ec2`

There is no standalone `aws_instance` resource: EC2 instances are created and managed by the ASG.

## 4. Load balancer and health checks

`alb.tf` defines a public ALB in the VPC's public subnets. Its target group forwards HTTP on port 80 to the EC2 instances and checks the `/` path every 30 seconds, expecting HTTP status `200`.

The current configuration defines a single listener: HTTP on port 80. It forwards requests to the target group.

## 5. Security groups and traffic flow

`security_groups.tf` defines two security groups:

- **ALB security group:** allows inbound TCP on port 80 from `0.0.0.0/0`, and allows outbound traffic.
- **EC2 security group:** allows inbound TCP on port 80 only from the ALB security group, and allows outbound traffic.

The web request path is:

```text
Internet --HTTP:80--> ALB --HTTP:80--> EC2 instances in private subnets
```

The instances do not have public IP addresses, and no SSH ingress rule is configured. For outbound internet access, the private subnets route traffic through NAT Gateways; the Internet Gateway serves public-subnet connectivity.

## 6. Terraform outputs

`outputs.tf` exposes:

| Output | Value |
|---|---|
| `private_ips` | Private IP addresses returned by the EC2 instance lookup |
| `ec2_instance_ids` | Instance IDs returned by the EC2 instance lookup |
| `ec2_availability_zones` | Availability Zones associated with the Auto Scaling Group |
| `vpc_id` | ID of the VPC |
| `ec2_security_group_id` | ID of the EC2 security group |
| `alb_security_group_id` | ID of the ALB security group |
| `alb_dns` | DNS name of the ALB |
| `private_subnet_ids` | IDs of the private subnets |

The EC2 instance lookup filters instances by the VPC ID (`module.vpc.vpc_id`) and the Auto Scaling Group name.

## 7. Cost considerations

AWS may charge for deployed resources. In particular, NAT Gateways are billed per gateway and for data processed, and the ALB also incurs charges. Check current AWS pricing before deployment and remove resources when they are no longer needed.
