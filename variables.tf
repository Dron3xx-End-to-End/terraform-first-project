variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_scaling_config" {
  description = "Scaling configuration for EC2 instances"
  type = object({
    min_size         = number
    max_size         = number
    desired_capacity = number
  })
  default = {
    min_size         = 1,
    max_size         = 2,
    desired_capacity = 2
  }

  validation {
    condition     = var.ec2_scaling_config.min_size <= var.ec2_scaling_config.desired_capacity
    error_message = "The minimum size must be less than or equal to the desired capacity."
  }
  validation {
    condition     = var.ec2_scaling_config.desired_capacity <= var.ec2_scaling_config.max_size
    error_message = "The desired capacity must be less than or equal to the maximum size."
  }
  validation {
    condition     = var.ec2_scaling_config.desired_capacity <= 2
    error_message = "The desired capacity must be less than or equal to 2."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 0))
    error_message = "The VPC CIDR block must be a valid CIDR notation."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) > 0
    error_message = "The list of private subnet CIDRs must not be empty."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) > 0
    error_message = "The list of public subnet CIDRs must contain at least one CIDR block."
  }
}

variable "ssl_certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS"
  type        = string
  default     = ""
}