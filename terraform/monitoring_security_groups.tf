resource "aws_security_group" "monitoring" {
  name        = "monitoring-sg"
  description = "Security group for monitoring"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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