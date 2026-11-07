output "private_ips" {
  value = data.aws_instances.terraform-first-project-asg.private_ips
}

output "ec2_instance_ids" {
  value = data.aws_instances.terraform-first-project-asg.ids
}

output "ec2_availability_zones" {
  value = aws_autoscaling_group.terraform-first-project-asg.availability_zones
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "ec2_security_group_id" {
  value = aws_security_group.terraform-first-project-sg.id
}

output "alb_security_group_id" {
  value = aws_security_group.terraform-first-project-lb-sg.id
}

output "alb_dns" {
  value = aws_lb.terraform-first-project-lb.dns_name
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}