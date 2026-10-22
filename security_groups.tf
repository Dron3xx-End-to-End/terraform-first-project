resource "aws_security_group" "terraform-first-project-sg" {
  name        = "terraform-first-project-sg"
  description = "Allow HTTP inbound traffic to the EC2 instances"

  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.terraform-first-project-elb-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "terraform-first-project"
  }
}

resource "aws_security_group" "terraform-first-project-elb-sg" {
  name        = "terraform-first-project-elb-sg"
  description = "Allow HTTP traffic to the ELB"

  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "terraform-first-project"
  }
}