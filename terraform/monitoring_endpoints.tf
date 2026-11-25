resource "aws_vpc_endpoint" "monitoring" {
  vpc_id            = module.vpc.vpc_id
  vpc_endpoint_type = "Interface"
  security_group_ids = [aws_security_group.interface_endpoint.id]
  subnet_ids        = module.vpc.private_subnets
  private_dns_enabled = true

  for_each = local.monitoring_endpoint_services
  service_name = "com.amazonaws.${var.aws_region}.${each.key}"
}