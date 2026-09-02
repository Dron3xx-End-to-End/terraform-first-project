module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "terraform-first-project-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  tags = {
    Project     = "terraform-first-project"
    Terraform   = "true"
    Environment = "dev"
  }
}