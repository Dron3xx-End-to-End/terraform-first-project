output "private_ips" {
    value = aws_instance.terraform-first-project-ec2[*].private_ip
}

output "ec2_instance_ids" {
    value = aws_instance.terraform-first-project-ec2[*].id
}

output "ec2_availability_zones" {
    value = aws_instance.terraform-first-project-ec2[*].availability_zone
}

output "vpc_id" {
    value = module.vpc.vpc_id
}

output "ec2_security_group_id" {
    value = aws_security_group.terraform-first-project-sg.id
}

output "elb_security_group_id" {
    value = aws_security_group.terraform-first-project-elb-sg.id
}

output "elb_dns" {
    value = aws_elb.terraform-first-project-elb.dns_name
}

output "private_subnet_ids" {
    value = module.vpc.private_subnets
}