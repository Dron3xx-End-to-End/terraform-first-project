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
    http_put_response_hop_limit = 2
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

  user_data = base64encode(<<-EOF
  #!/bin/bash
  set -e

  install_dependencies() {
    dnf update -y || return 1
    dnf install -y docker curl awscli || return 1
    aws --version || return 1
    return 0
  }

  get_instance_metadata() {
    TOKEN=$(curl -fsS \
      http://169.254.169.254/latest/api/token \
      -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 21600") || return 1

    INSTANCE_ID=$(curl -fsS \
      http://169.254.169.254/latest/meta-data/instance-id \
      -H "X-aws-ec2-metadata-token: $TOKEN") || return 1
    [ -n "$INSTANCE_ID" ] || return 1
    echo "Instance ID: $INSTANCE_ID"
    return 0
  }

  prepare_monitoring() {

  # Install Docker Compose plugin
  COMPOSE_VERSION="v5.6.0"

  mkdir -p /usr/local/lib/docker/cli-plugins || return 1

  curl -fSL \
    "https://github.com/docker/compose/releases/download/$${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose || return 1

  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose || return 1

  systemctl enable --now docker || return 1
  docker compose version || return 1

  usermod -aG docker ec2-user || return 1
  mkdir -p /opt/monitoring || return 1
  chown ec2-user:ec2-user /opt/monitoring || return 1
  echo "Monitoring instance setup"
  return 0
  }

  report_instance_failure() {
    aws autoscaling set-instance-health \
    --instance-id "$INSTANCE_ID" \
    --health-status Unhealthy \
    --no-should-respect-grace-period || return 1
    echo "Reporting instance failure"
    return 0
  }

  for i in {1..3}; do
    if install_dependencies; then
      echo "Dependencies installation succeeded"
      break
    else
      echo "Dependencies installation failed, attempt $i"
      if [ $i -eq 3 ]; then
        echo "Dependencies installation failed all 3 attempts"
        exit 1
      fi
      sleep 15
      continue
    fi
  done

  for i in {1..3}; do
    if get_instance_metadata; then
      echo "Instance metadata retrieval succeeded"
      break
    else
      echo "Instance metadata retrieval failed, attempt $i"
      if [ $i -eq 3 ]; then
        echo "Instance metadata retrieval failed all 3 attempts"
        exit 1
      fi
      sleep 15
      continue
    fi
  done

  for i in {1..3}; do
    if prepare_monitoring; then
      echo "Monitoring preparation succeeded"
      break
    else
      echo "Monitoring preparation failed, attempt $i"
      if [ $i -eq 3 ]; then
        echo "Monitoring preparation failed all 3 attempts"
        report_instance_failure || exit 1
        exit 1
      fi
      sleep 15
      continue
    fi
  done

  EOF
  )
}