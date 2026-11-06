resource "aws_lb" "terraform-first-project-lb" {
  name = "terraform-first-project-lb"

  #checkov:skip=CKV_AWS_52: "This is a test environment, so we can disable S3 deletion protection"
  #checkov:skip=CKV_AWS_150: "This is a test environment, so we can disable ALB deletion protection"
  #checkov:skip=CKV_AWS_91: "This is a test environment, so we can disable access logs"
  #checkov:skip=CKV2_AWS_20: "This is a test environment, so we can disable redirects"
  #checkov:skip=CKV2_AWS_28: "This is a test environment, so we can disable WAF - to be added in the future"

  drop_invalid_header_fields = true
  enable_deletion_protection = false
  enable_http2               = true

  subnets         = module.vpc.public_subnets
  security_groups = [aws_security_group.terraform-first-project-lb-sg.id]

  internal = false

  tags = merge(local.load_balancing_tags, {
    Role = "application-load-balancer"
  })
}

resource "aws_lb_target_group" "terraform-first-project-tg" {
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

  tags = merge(local.load_balancing_tags, {
    Role = "target-group"
  })
}

resource "aws_lb_listener" "http" {

  #checkov:skip=CKV_AWS_2: "This is a test environment, so we can disable HTTPS"
  #checkov:skip=CKV_AWS_103: "This is a test environment, so we can disable SSL certificate validation"

  load_balancer_arn = aws_lb.terraform-first-project-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.terraform-first-project-tg.arn
  }

  tags = merge(local.load_balancing_tags, {
    Role = "listener"
  })
}
