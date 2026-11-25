resource "aws_iam_role" "terraform-first-project-monitoring-role" {
    name = "terraform-first-project-monitoring-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })

    tags = {
        Project = "terraform-first-project"
        ManagedBy = "Terraform"
        Environment = "Monitoring"
        Component = "IAM"
        Purpose = "SSM-Access"
    }
}

resource "aws_iam_role_policy_attachment" "monitoring-role-attachment" {
    role       = aws_iam_role.terraform-first-project-monitoring-role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "monitoring-role-profile" {
    name = "monitoring-role-profile"
    role = aws_iam_role.terraform-first-project-monitoring-role.name

    tags = {
        Project = "terraform-first-project"
        ManagedBy = "Terraform"
        Environment = "Monitoring"
        Component = "IAM"
        Purpose = "SSM-Access"
    }
}