resource "aws_lb" "terraform-first-project-lb" {
  name            = "terraform-first-project-lb"
  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.terraform-first-project-lb-sg.id]

  internal = false

  tags = {
    Project = "terraform-first-project"
  }
}

resource "aws_lb_target_group" "terraform-first-project-tg" { #
  name     = "terraform-first-project-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Project = "terraform-first-project"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.terraform-first-project-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-first-project-tg.arn
  }

  tags = {
    Project = "terraform-first-project"
  }
}
