
data "aws_ami" "terraform-first-project-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_launch_template" "terraform-first-project-lt" {
  name     = "terraform-first-project-lt"
  image_id = data.aws_ami.terraform-first-project-ami.id

  instance_type = var.ec2_instance_type

  network_interfaces {
    associate_public_ip_address = false
  }
  vpc_security_group_ids = [aws_security_group.terraform-first-project-sg.id]

  user_data = base64encode(<<-EOF
        #!/bin/bash
        dnf update -y
        dnf install -y httpd
        systemctl start httpd
        systemctl enable httpd
        echo "<h1>Terraform first project</h1>" > /var/www/html/index.html
        EOF
  )
}

resource "aws_autoscaling_group" "terraform-first-project-asg" {
  name                = "terraform-first-project-asg"
  max_size            = var.ec2_scaling_config.max_size
  min_size            = var.ec2_scaling_config.min_size
  desired_capacity    = var.ec2_scaling_config.desired_capacity
  vpc_zone_identifier = module.vpc.private_subnets

  launch_template {
    id      = aws_launch_template.terraform-first-project-lt.id
    version = "$Latest"
  }

  target_group_arns         = [aws_lb_target_group.terraform-first-project-tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "terraform-first-project-ec2"
    propagate_at_launch = true
  }
}

data "aws_instances" "terraform-first-project-asg" {
  instance_tags = {
    Name = "terraform-first-project-ec2"
  }

  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = ["terraform-first-project-asg"]
  }

  depends_on = [aws_autoscaling_group.terraform-first-project-asg]
}