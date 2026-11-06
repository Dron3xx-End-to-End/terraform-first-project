locals {
  project_tags = {
    Project     = "terraform-first-project"
    Environment = "dev"
    ManagedBy   = "terraform"
  }

  networking_tags = merge(local.project_tags, {
    Component = "networking"
  })

  compute_tags = merge(local.project_tags, {
    Component = "compute"
  })

  load_balancing_tags = merge(local.project_tags, {
    Component = "load-balancing"
  })
}
