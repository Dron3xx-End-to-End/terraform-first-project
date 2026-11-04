# Terraform First Project - Technical Explanation

## Architecture

This project demonstrates a small AWS web stack split across public and private network tiers. A public Classic Elastic Load Balancer (ELB) receives HTTP requests from the internet and distributes them to two EC2 web servers in private subnets. The instances have private IP addresses only and accept HTTP from the ELB security group, not directly from the internet.

The VPC module also provides an Internet Gateway for the public subnets and one shared NAT Gateway for outbound internet access from the private subnets. The NAT Gateway allows private instances to reach external services (for example, to download operating system packages) without assigning them public IP addresses.

## 1) Terraform and AWS provider

`providers.tf` requires Terraform 1.2 or newer and AWS provider `~> 6.28.0`. It configures the provider for `eu-central-1` (Frankfurt) and the local AWS profile `terraform-first-project`.

## 2) VPC, subnets, and internet connectivity

The VPC module in `vpc.tf` defines a VPC with CIDR `10.0.0.0/16` across two availability zones:

| Network | CIDR | Purpose |
|---|---|---|
| Public subnet 1 | `10.0.101.0/24` | ELB and public network resources |
| Public subnet 2 | `10.0.102.0/24` | ELB and public network resources |
| Private subnet 1 | `10.0.1.0/24` | EC2 web server |
| Private subnet 2 | `10.0.2.0/24` | EC2 web server |

The module is configured with `enable_nat_gateway = true` and `single_nat_gateway = true`, so there is one NAT Gateway shared by the private subnets for outbound traffic. The module creates an Internet Gateway to provide internet connectivity to the public subnets. Private instances use the NAT Gateway for outbound internet access; they do not get public addresses.

## 3) EC2 web servers

`ec2.tf` looks up the most recent Amazon Linux 2 AMI matching the configured owner, name, and architecture filters rather than hardcoding an AMI ID. It creates two `t3.micro` instances, placing each in one of the private subnets:

```hcl
count                       = 2
associate_public_ip_address = false
subnet_id                   = module.vpc.private_subnets[count.index]
```

The `user_data` startup script updates the system, installs and enables Apache (`httpd`), and writes a simple page to `/var/www/html/index.html`. The instances are registered with the ELB, which sends HTTP requests to them over their private network addresses.

## 4) Security groups

`security_groups.tf` defines separate security groups for the ELB and the EC2 instances.

### ELB security group

The ELB security group allows inbound TCP traffic on port 80 from `0.0.0.0/0`, making the load balancer's HTTP listener reachable from the internet. Its egress rule allows outbound traffic.

### EC2 security group

The instance security group allows inbound TCP traffic on port 80 only when it originates from the ELB security group. It has no SSH ingress rule and does not allow direct HTTP ingress from internet CIDR ranges. Its egress rule permits outbound traffic, with the private subnet's NAT route providing internet access.

This creates a controlled path for web requests:

```text
Internet --HTTP:80--> ELB --HTTP:80--> EC2 instances
```

## 5) Classic Elastic Load Balancer

`elb.tf` defines an `aws_elb` Classic ELB in the VPC's public subnets. It uses the ELB security group, listens for HTTP on port 80, and forwards requests to the two EC2 instances on port 80. Its health check probes `HTTP:80/` every 30 seconds; the ELB routes requests to healthy instances.

## 6) Request and outbound traffic flow

1. A client on the internet sends an HTTP request to the public ELB on port 80.
2. The ELB security group allows the request, and the ELB forwards it to a healthy EC2 instance.
3. The EC2 security group allows that inbound HTTP connection because it comes from the ELB security group.
4. If an instance needs outbound internet access, its private subnet uses the shared NAT Gateway; responses return through the established connection.

The Internet Gateway supports the public subnets and the public ELB. It does not give the private EC2 instances public IP addresses.

## 7) Terraform outputs

`outputs.tf` exposes the following values:

| Output | Value |
|---|---|
| `private_ips` | Private IP addresses of the two EC2 instances |
| `ec2_instance_ids` | IDs of the two EC2 instances |
| `ec2_availability_zones` | Availability zones of the two EC2 instances |
| `vpc_id` | ID of the VPC created by the module |
| `ec2_security_group_id` | ID of the EC2 security group |
| `elb_security_group_id` | ID of the ELB security group |
| `elb_dns` | DNS name of the ELB |
| `private_subnet_ids` | IDs of the private subnets |
