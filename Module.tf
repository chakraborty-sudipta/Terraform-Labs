# Define Provider
provider "aws" {
  region = "us-east-1"
}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "my-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

# Security Group Module
module "security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = "0.0.0.0/0" },
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = "0.0.0.0/0" }
  ]
}

# Launch Template
resource "aws_launch_template" "my_lt" {
  name_prefix   = "my-launch-template"
  image_id      = "ami-04b4f1a9cf54c11d0" # Replace with a valid AMI ID
  instance_type = "t2.micro"  # ✅ Ensures instance type is set
  key_name      = "my-key"  # Replace with your key pair name

  user_data     = base64encode(<<-EOT
    #!/bin/bash
    sudo apt update -y
    sudo apt install -y apache2
    sudo systemctl start apache2
    sudo systemctl enable apache2
    echo "<h1>Welcome to Apache Web Server on $(hostname)</h1>" | sudo tee /var/www/html/index.html
  EOT
  )

  vpc_security_group_ids = [module.security_group.security_group_id]
}

# Application Load Balancer (ALB)
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security_group.security_group_id]
  subnets            = module.vpc.public_subnets
}

# Target Group
resource "aws_lb_target_group" "my_tg" {
  name        = "my-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"
}

# ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "my_asg" {
  name                = "my-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2
  vpc_zone_identifier = module.vpc.public_subnets

  launch_template {
    id      = aws_launch_template.my_lt.id
    version = "$Latest"  # ✅ Ensures latest version of the launch template is used
  }
}

# Attach ASG to ALB Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.my_asg.id
  lb_target_group_arn    = aws_lb_target_group.my_tg.arn
}

# Output Load Balancer DNS
output "alb_dns" {
  value       = aws_lb.my_alb.dns_name
  description = "DNS name of the ALB"
}
