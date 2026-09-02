
data "aws_ami" "terraform-first-project-ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "terraform-first-project-ec2" {
  ami = data.aws_ami.terraform-first-project-ami.id

  count         = 2
  instance_type = "t3.micro"

  associate_public_ip_address = true
  subnet_id                   = module.vpc.public_subnets[count.index]
  vpc_security_group_ids      = [aws_security_group.terraform-first-project-sg.id]

  user_data = <<-EOF
            #!/bin/bash
            yum update -y
            yum install -y httpd
            systemctl start httpd
            systemctl enable httpd
            echo "<h1>Terraform first project</h1>" > /var/www/html/index.html
            EOF

  tags = {
    Name    = "terraform-first-project-EC2-${count.index + 1}"
    Project = "terraform-first-project"
  }
}