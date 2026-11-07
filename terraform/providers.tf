terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }

  required_version = ">= 1.9.0"
}

provider "aws" {
  region  = var.aws_region
  profile = "terraform-first-project"
}