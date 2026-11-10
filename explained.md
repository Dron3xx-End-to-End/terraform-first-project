# Terraform First Project --- Technical Explanation

This document describes the AWS infrastructure in `terraform/` and the
local monitoring stack in `monitoring/`. They are separate environments:
Terraform provisions AWS resources, while Docker Compose runs monitoring
services locally.

# Part 1 --- AWS Infrastructure

## 1. Terraform and AWS provider

`terraform/providers.tf` requires Terraform 1.9.0 or newer and AWS
provider `~> 6.28.0`. The AWS provider uses the local profile
`terraform-first-project`. The region is controlled by `aws_region`,
defaulting to `eu-central-1`.

Run Terraform from the repository root with `-chdir=terraform`, for
example:

``` bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
```

## 2. Variables and network

`terraform/variables.tf` defines the AWS region, EC2 instance type, ASG
scaling configuration, VPC CIDR, and public/private subnet CIDRs.
Defaults include `eu-central-1`, `t3.micro`, VPC CIDR `10.0.0.0/16`, and
ASG capacities min 1, desired 2, max 2.

Input validations check the VPC CIDR, require non-empty subnet lists,
and constrain desired capacity to the configured limits and a maximum of
two.

`terraform/vpc.tf` discovers available standard Availability Zones and
configures the VPC module. With the defaults, the public subnet CIDRs
are `10.0.101.0/24` and `10.0.102.0/24`; private subnet CIDRs are
`10.0.1.0/24` and `10.0.2.0/24`.

The module creates the VPC, public/private subnets, Internet Gateway,
and NAT Gateways. `one_nat_gateway_per_az = true` provisions a NAT
Gateway in each selected AZ. This supports outbound access from private
subnets but increases AWS cost.

## 3. Launch template and Auto Scaling Group

`terraform/ec2.tf` looks up the latest Amazon-owned Amazon Linux 2023
x86_64 AMI. The launch template configures the AMI, instance type, EC2
security group, and startup script. Its network interface does not
associate a public IP address, and instance metadata access requires
IMDSv2.

The startup script updates the operating system, installs and enables
Apache (`httpd`), and writes a sample page to
`/var/www/html/index.html`.

The ASG launches instances in private subnets, uses the latest
launch-template version, takes its min/desired/max values from
`ec2_scaling_config`, and registers instances with the ALB target group.
It uses ELB health checks with a 300-second grace period and applies the
`Name` tag `terraform-first-project-ec2`.

There is no standalone `aws_instance` resource: EC2 instances are
created and managed by the ASG.

## 4. Load balancer and health checks

`terraform/alb.tf` defines a public ALB in the public subnets. Its
target group forwards HTTP on port 80 to the EC2 instances. The health
check requests `/` every 30 seconds and expects status `200`.

The current configuration has one listener: HTTP on port 80, forwarding
requests to the target group.

## 5. Security groups and traffic flow

`terraform/security_groups.tf` defines two security groups:

-   **ALB security group:** allows inbound TCP port 80 from `0.0.0.0/0`
    and allows outbound traffic.
-   **EC2 security group:** allows inbound TCP port 80 only from the ALB
    security group and allows outbound traffic.

``` text
Internet --HTTP:80--> ALB --HTTP:80--> EC2 instances in private subnets
```

The EC2 instances have no public IP addresses and no inbound SSH rule is
configured. Private-subnet instances use NAT Gateways for outbound
internet access. The Internet Gateway provides connectivity for
public-subnet resources such as the ALB.

## 6. Terraform outputs

`terraform/outputs.tf` exposes:

  -----------------------------------------------------------------------
  Output                              Meaning
  ----------------------------------- -----------------------------------
  `private_ips`                       Private IP addresses returned by
                                      the EC2 instance lookup

  `ec2_instance_ids`                  Instance IDs returned by the EC2
                                      instance lookup

  `ec2_availability_zones`            Availability Zones associated with
                                      the ASG

  `vpc_id`                            VPC ID

  `ec2_security_group_id`             EC2 security group ID

  `alb_security_group_id`             ALB security group ID

  `alb_dns`                           ALB DNS name

  `private_subnet_ids`                Private subnet IDs
  -----------------------------------------------------------------------

The EC2 lookup filters by VPC ID (`module.vpc.vpc_id`) and ASG name.
These outputs describe resources represented in the Terraform state;
they do not mean the AWS resources are always running.

## 7. AWS cost and security considerations

NAT Gateways and the ALB can incur charges; EC2, data transfer, and
public IPv4 addresses may also contribute depending on deployment and
current pricing. Review `terraform plan` before applying and destroy the
lab when it is no longer needed. Verify that billable resources have
been removed.

The current ALB listener uses HTTP, not HTTPS. HTTPS, access logs, AWS
WAF, and further production hardening are future improvements, not
implemented features.

# Part 2 --- Local Monitoring Stack

## 8. Components and responsibilities

The local stack is defined in `monitoring/docker-compose.yml` and
contains four services:

**Node Exporter** - Collects and exposes system metrics over HTTP on
port `9100`, making metrics available at `/metrics`.

**Prometheus** - Periodically scrapes configured targets, stores
collected time-series data, provides a query interface using PromQL, and
evaluates alert rules. Its configuration is in
`monitoring/prometheus/prometheus.yml`.

**Alertmanager** - Receives alerts from Prometheus, groups related
alerts, and routes them according to their labels. Its configuration is
in `monitoring/alertmanager/alertmanager.yml`.

**Grafana** - Queries Prometheus as a data source and visualizes metrics
in dashboards and panels. Provisioning files configure its Prometheus
data source and load dashboard files.

## 9. Monitoring data flow

``` text
Node Exporter --HTTP scrape--> Prometheus --alerts--> Alertmanager
                                  ^
                                  | PromQL queries
                                  |
                               Grafana
```

The current Prometheus configuration uses a global scrape interval of 15
seconds and targets `node-exporter:9100`.

The target uses the Docker Compose service name. Services on the Compose
network can resolve one another through Docker's internal DNS.
`localhost` inside the Prometheus container would refer to that
Prometheus container, not the Node Exporter container.

Prometheus evaluates its configured alert rules and sends resulting
alerts to Alertmanager. Grafana uses `http://prometheus:9090` to query
Prometheus; it does not scrape Node Exporter directly.

## 10. Alert rules

The alert rules are in
`monitoring/prometheus/rules/system-alerts.yml`. Prometheus loads this
file through the `rule_files` entry in
`monitoring/prometheus/prometheus.yml`.

The five rules are:

-   **HighCPUUsage** - Fires when average CPU usage exceeds 80% for
    5 minutes.
-   **HighMemoryUsage** - Fires when memory usage exceeds 80% for
    5 minutes.
-   **HighSwapUsage** - Fires when swap usage exceeds 80% for 5 minutes.
    The expression also requires `node_memory_SwapTotal_bytes > 0`, so
    it does not divide by zero or report swap usage when no swap exists.
-   **InstanceDown** - Fires when `up == 0` remains true for 1 minute.
    Prometheus sets `up` to 0 when a target scrape fails.
-   **LowMemoryAvailable** - Fires when available memory is below
    2 GiB for 5 minutes.

The `for` field requires the condition to remain true for the specified
duration before the alert fires; this avoids firing on brief spikes.
`labels` attach metadata such as `severity`, which Alertmanager uses for
routing. `annotations` provide human-readable details such as summaries
and descriptions; their templates can use labels like
`{{ $labels.instance }}`.

## 11. Alertmanager

`monitoring/alertmanager/alertmanager.yml` configures Alertmanager,
which receives alerts from Prometheus, groups related alerts, and routes
them to receivers. The main route uses the `default` receiver as a
fallback. Child routes match the `severity` label and send `warning`
alerts to the `warning` receiver and `critical` alerts to the
`critical` receiver.

A route is the rule that determines where an alert goes; a receiver is
the destination configuration selected by that route. The current file
defines the `default`, `warning`, and `critical` receivers, but none has
an email or other notification channel configured yet.

Alerts are grouped by `alertname` and `instance`. `group_wait: 30s`
delays the first notification for a new group so related alerts can
arrive together. `group_interval: 5m` sets the wait between
notifications when a group changes, and `repeat_interval: 4h` sets how
long to wait before repeating an unchanged alert group.

## 12. Prometheus integration

`monitoring/prometheus/prometheus.yml` includes `rule_files` pointing to
`rules/system-alerts.yml`, relative to the Prometheus configuration
file. Its `alerting` section configures the Alertmanager target as
`alertmanager:9093`.

The Compose service name `alertmanager` resolves through Docker's
internal DNS on the shared network. Prometheus runs in its own
container, so `localhost:9093` would refer to the Prometheus container
itself, not the Alertmanager container.

## 13. Grafana

The current provisioned dashboard is **System Monitoring**, stored in
`monitoring/grafana/provisioning/dashboards/system-monitoring.json`. It
has panels for CPU, RAM Usage, RAM Available, and SWAP.

The provisioning file
`monitoring/grafana/provisioning/datasources/prometheus.yml` adds
Prometheus at `http://prometheus:9090` as Grafana's default data source.
`monitoring/grafana/provisioning/dashboards/dashboards.yml` tells Grafana
to load dashboard files from the provisioning dashboards directory.

## 14. Networking, ports, and storage

All four services join the Compose network named `monitoring`. The
Compose file publishes:

  Service           Container port   Host port
  --------------- ---------------- -----------
  Prometheus                  9090        9090
  Grafana                     3000        3000
  Node Exporter               9100        9100
  Alertmanager                9093        9093

Named volumes store Prometheus, Grafana, and Alertmanager data so it can
survive ordinary container recreation.

Node Exporter receives host paths through bind mounts. The metrics
visible depend on the host paths and Docker environment. With Docker
Desktop using WSL2, do not assume the metrics provide a complete view of
Windows or every WSL distribution without checking.

## 15. Starting and stopping the stack

From the repository root:

``` bash
cd monitoring
docker compose up -d
docker compose ps
```

Local endpoints:

-   Prometheus: `http://localhost:9090`
-   Prometheus targets: `http://localhost:9090/targets`
-   Node Exporter metrics: `http://localhost:9100/metrics`
-   Grafana: `http://localhost:3000`
-   Alertmanager: `http://localhost:9093`

The current development credentials are `admin` / `admin`. They are not
appropriate for a shared or production environment.

Stop and remove containers and the network:

``` bash
docker compose down
```

Also remove named data volumes:

``` bash
docker compose down -v
```

The `-v` option deletes persistent Prometheus, Grafana, and Alertmanager
data.

## 16. The Prometheus `up` metric

The `up` metric reports the result of the latest scrape for each target:

-   `1` means the scrape succeeded.
-   `0` means the scrape failed.

For this setup, a successful target series should identify the job and
instance, for example `job="Node Exporter"` and
`instance="node-exporter:9100"`.

`up` reports scrape connectivity. It is not a CPU, memory, or
application-health measurement.

## 17. Current scope and future work

The monitoring environment is currently a local learning stack and is
not integrated with AWS monitoring.

Potential future extensions include CloudWatch metrics and alarms,
secured connectivity to AWS-hosted workloads, additional dashboards for
filesystem and network metrics, and hardening credentials, published
ports, and image versions.

AWS WAF is also future infrastructure work. Neither WAF nor CloudWatch
integration should be understood as implemented by the current project.
