resource "aws_elb" "terraform-first-project-elb" {
  name            = "terraform-first-project-elb"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.terraform-first-project-elb-sg.id]

  instances = aws_instance.terraform-first-project-ec2[*].id

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:80/"
    interval            = 30
  }

  tags = {
    Project = "terraform-first-project"
  }
}