# Terraform First Project

## Overview

This repository contains two separate parts:

1.  **AWS infrastructure**, provisioned with Terraform: a public
    Application Load Balancer (ALB) forwards HTTP traffic to Apache web
    servers managed by an Auto Scaling Group (ASG) in private subnets.
2.  **Local monitoring**, started with Docker Compose: Prometheus
    scrapes Node Exporter metrics, evaluates alert rules, and forwards
    alerts to Alertmanager, while Grafana visualizes the data.

The local monitoring stack does not depend on deployed AWS resources.

## Technologies

-   Terraform, AWS VPC, EC2, Auto Scaling, Application Load Balancer
-   Apache HTTP Server
-   Docker, Docker Compose, Prometheus, Alertmanager, Grafana, Node
    Exporter

## Repository Structure

``` text
terraform-first-project/
├── .github/
│   └── workflows/
│       ├── portfolio-notify.yml
│       └── validate.yml
├── .vscode/
│   ├── schemas/
│   │   └── grafana-datasource.schema.json
│   └── settings.json
├── monitoring/
│   ├── alertmanager/
│   │   └── alertmanager.yml
│   ├── docker-compose.yml
│   ├── grafana/
│   │   └── provisioning/
│   │       ├── dashboards/
│   │       │   ├── dashboards.yml
│   │       │   └── system-monitoring.json
│   │       └── datasources/
│   │           └── prometheus.yml
│   └── prometheus/
│       ├── prometheus.yml
│       └── rules/
│           └── system-alerts.yml
├── policy/
│   ├── ASG.json
│   ├── EC2.json
│   └── ELB.json
├── terraform/
│   ├── alb.tf
│   ├── ec2.tf
│   ├── locals.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── security_groups.tf
│   ├── variables.tf
│   ├── vpc.tf
│   └── .terraform.lock.hcl
├── .gitignore
├── .gitattributes
├── README.md
├── explained.md
└── portfolio-update.md
```

## AWS Infrastructure

The Terraform configuration defines:

-   A VPC (default CIDR `10.0.0.0/16`) with public and private subnets.
-   An Internet Gateway and one NAT Gateway per selected Availability
    Zone.
-   A public ALB with an HTTP listener on port 80.
-   An ASG that launches EC2 instances in private subnets.
-   A launch template using the latest matching Amazon Linux 2023 x86_64
    AMI.
-   Apache installation and a sample homepage configured through
    `user_data`.

Defaults include EC2 instance type `t3.micro` and ASG capacities of
minimum 1, desired 2, maximum 2.

### Traffic flow

``` text
Internet --HTTP:80--> Public ALB --HTTP:80--> EC2 instances in private subnets
```

The ALB security group allows inbound HTTP from the internet. The EC2
security group allows inbound HTTP only from the ALB security group.
Instances have no public IP addresses and no inbound SSH rule is
configured.

## Requirements

### AWS / Terraform

-   Terraform 1.9.0 or newer.
-   AWS CLI configured with the `terraform-first-project` profile.
-   An AWS account with permissions to create the configured resources.

### Local monitoring

-   Docker Desktop or another Docker Engine installation.
-   Docker Compose v2.

## Deploying AWS Infrastructure

Run commands from the repository root using Terraform's `-chdir` option:

``` bash
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

To remove the infrastructure:

``` bash
terraform -chdir=terraform destroy
```

Review the plan before applying it. **AWS deployment can incur
charges**, particularly NAT Gateway and ALB charges. Check current AWS
pricing and destroy resources when they are no longer needed. Verify
that billable resources have been removed.

## Running Local Monitoring

From the repository root:

``` bash
cd monitoring
docker compose up -d
docker compose ps
```

  -------------------------------------------------------------------------------
  Service                 Local address                   Purpose
  ----------------------- ------------------------------- -----------------------
  Prometheus              http://localhost:9090           Scrapes and stores
                                                          metrics and evaluates
                                                          alert rules

  Grafana                 http://localhost:3000           Queries and visualizes
                                                          metrics

  Node Exporter           http://localhost:9100/metrics   Exposes system metrics

  Alertmanager            http://localhost:9093           Groups and routes
                                                          alerts
  -------------------------------------------------------------------------------

The current local development credentials for Grafana are `admin` /
`admin`. Do not use these credentials in a shared or production
environment.

### Metrics flow

``` text
Node Exporter --metrics--> Prometheus --alerts--> Alertmanager
                                ^
                                | PromQL queries
                                |
                             Grafana
```

Node Exporter exposes host metrics. Prometheus periodically scrapes
`node-exporter:9100`, stores the metrics, and evaluates its alert rules.
It sends firing alerts to Alertmanager, which groups and routes them by
the `severity` label. The `default` receiver is the fallback; `warning`
and `critical` receivers handle alerts with matching severity values.
These receivers do not yet have email or other external notification
channels configured.

Grafana queries Prometheus at `http://prometheus:9090` and visualizes
the metrics. The Compose file uses named volumes for Prometheus,
Alertmanager, and Grafana data.

### Alert rules

-   `HighCPUUsage` and `HighMemoryUsage` warn when usage exceeds 80%.
-   `HighSwapUsage` warns when swap usage exceeds 80%, if swap is present.
-   `InstanceDown` is critical when a monitored target is unreachable.
-   `LowMemoryAvailable` warns when less than 2 GiB of memory is
    available.

The Node Exporter container receives host paths through bind mounts. The
metrics visible depend on the Docker host and mounted paths. With Docker
Desktop and WSL2, do not assume these metrics fully represent the
Windows host or every WSL distribution without verifying the result.

To stop the stack:

``` bash
docker compose down
```

To also delete persistent Prometheus and Grafana data:

``` bash
docker compose down -v
```

**Warning:** `docker compose down -v` removes the named data volumes.

## Terraform Outputs

The Terraform configuration exposes:

-   `private_ips` --- private IP addresses returned by the EC2 instance
    lookup.
-   `ec2_instance_ids` --- instance IDs returned by the EC2 instance
    lookup.
-   `ec2_availability_zones` --- Availability Zones associated with the
    ASG.
-   `vpc_id` --- VPC ID.
-   `ec2_security_group_id` --- EC2 security group ID.
-   `alb_security_group_id` --- ALB security group ID.
-   `alb_dns` --- ALB DNS name.
-   `private_subnet_ids` --- private subnet IDs.

The EC2 lookup filters instances by VPC ID and Auto Scaling Group name.

## Current Scope and Future Work

The local monitoring stack is not integrated with AWS monitoring.
CloudWatch integration and AWS WAF are future extensions, not
implemented features.

The current ALB uses HTTP on port 80. HTTPS, access logging, WAF, and
additional production-hardening measures remain future work.
