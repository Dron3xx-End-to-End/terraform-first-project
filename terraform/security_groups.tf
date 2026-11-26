resource "aws_security_group" "terraform-first-project-sg" {
  name        = "terraform-first-project-sg"
  description = "Allow HTTP inbound traffic to the EC2 instances"

  vpc_id = module.vpc.vpc_id

  tags = merge(local.networking_tags, {
    Role = "security-group"
  })
}

resource "aws_security_group" "terraform-first-project-lb-sg" {
  name        = "terraform-first-project-lb-sg"
  description = "Allow HTTP traffic to the ALB"

  vpc_id = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.networking_tags, {
    Role = "security-group"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.terraform-first-project-sg.id
  referenced_security_group_id = aws_security_group.terraform-first-project-lb-sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "HTTP from ALB"
}

resource "aws_vpc_security_group_ingress_rule" "monitoring_to_app" {
  security_group_id            = aws_security_group.terraform-first-project-sg.id
  referenced_security_group_id = aws_security_group.monitoring.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  description                  = "Node Exporter from monitoring"
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.terraform-first-project-sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic"
}