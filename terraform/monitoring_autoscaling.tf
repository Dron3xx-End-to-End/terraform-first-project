resource "aws_autoscaling_group" "monitoring" {
  name = "terraform-first-project-monitoring-asg"
  launch_template {
    id      = aws_launch_template.monitoring.id
    version = "$Latest"
  }

  min_size = 1
  desired_capacity = 1
  max_size = 1

  health_check_type         = "EC2"
  health_check_grace_period = 300

  vpc_zone_identifier = [aws_subnet.monitoring.id]
}