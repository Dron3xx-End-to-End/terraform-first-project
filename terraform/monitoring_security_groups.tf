resource "aws_security_group" "monitoring" {
  name        = "monitoring-sg"
  description = "Security group for monitoring"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group" "interface_endpoint" {
  name        = "interface-endpoint-sg"
  description = "Security group for interface endpoint"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }
}

resource "aws_vpc_security_group_egress_rule" "monitoring_to_app" {
  security_group_id            = aws_security_group.monitoring.id
  referenced_security_group_id = aws_security_group.terraform-first-project-sg.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  description                  = "Node Exporter to application EC2"
}

resource "aws_vpc_security_group_egress_rule" "monitoring_https" {
  security_group_id = aws_security_group.monitoring.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow outbound HTTPS traffic"
}