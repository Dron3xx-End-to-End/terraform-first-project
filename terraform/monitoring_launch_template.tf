resource "aws_launch_template" "monitoring" {
  name_prefix   = "monitoring-"
  image_id = data.aws_ami.terraform-first-project-ami.id
  instance_type = "t3.small"
  vpc_security_group_ids = [aws_security_group.monitoring.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.monitoring-role-profile.name
  }

  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = data.aws_ami.terraform-first-project-ami.root_device_name
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<EOF
  #!/bin/bash
  set -e
  dnf update -y
  dnf install -y docker
  dnf install -y docker-compose-plugin
  systemctl enable --now docker
  usermod -aG docker ec2-user
  mkdir -p /opt/monitoring
  chown ec2-user:ec2-user /opt/monitoring
  echo "Monitoring instance setup"
  EOF
)
}