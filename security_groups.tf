resource "aws_security_group" "terraform-first-project-sg" {
  name        = "terraform-first-project-sg"
  description = "Allow HTTP inbound traffic to the EC2 instances"

  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.terraform-first-project-lb-sg.id]
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