data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "terraform-first-project-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, length(var.private_subnet_cidrs))
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  tags = local.networking_tags

  vpc_tags = {
    Role = "vpc"
  }

  public_subnet_tags = {
    Role = "public-subnet"
  }

  private_subnet_tags = {
    Role = "private-subnet"
  }

  igw_tags = {
    Role = "internet-gateway"
  }

  nat_gateway_tags = {
    Role = "nat-gateway"
  }

  nat_eip_tags = {
    Role = "elastic-ip"
  }

  public_route_table_tags = {
    Role = "route-table"
  }

  private_route_table_tags = {
    Role = "route-table"
  }

  default_route_table_tags = {
    Role = "route-table"
  }

  default_security_group_tags = {
    Role = "security-group"
  }

  default_network_acl_tags = {
    Role = "network-acl"
  }
}