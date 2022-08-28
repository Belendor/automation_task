# -----------Provider-------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.72.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_security_group" "instances" {
  name   = "instance-security-group"
  vpc_id = data.aws_vpc.selected.id
}

resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_ssh_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.instances.id

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# -----------Instances---------
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  for_each = toset(["ec2-code-deploy1", "ec2-code-deploy2", "ec2-code-deploy3", "ec2-code-deploy4"])

  name = "instance-${each.key}"

  associate_public_ip_address = true
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = "artur-key"
  vpc_security_group_ids      = [aws_security_group.instances.id]
  subnet_id                   = data.aws_subnet.selected.id
  user_data                   = <<-EOF
              #!/bin/bash
              echo "Hello, World ${each.key}" > index.html
              python3 -m http.server 80 &
              EOF

  tags = {
    project = "deploy"
  }
}

# -----------Load Balancer---------
module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "3.17.0"
  name        = "lb-sg-project-alpha-dev"
  description = "Security group for load balancer with HTTP ports open within VPC"
  vpc_id      = data.aws_vpc.selected.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

resource "random_string" "lb_id" {
  length  = 3
  special = false
}

data "aws_instances" "ec2s" {

   depends_on = [
    module.ec2_instance
  ]

  filter {
    name   = "tag:project"
    values = ["deploy"]
  }
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "2.4.0"

  name = "lb-automation-project-alpha-dev"

  internal = false

  security_groups = [module.lb_security_group.this_security_group_id]
  subnets         = [data.aws_subnet.selected.id]

  number_of_instances = length(data.aws_instances.ec2s.ids)
  instances           = data.aws_instances.ec2s.ids

  listener = [{
    instance_port     = "80"
    instance_protocol = "HTTP"
    lb_port           = "80"
    lb_protocol       = "HTTP"
  }]

  health_check = {
    target              = "HTTP:80/index.html"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
  }
}