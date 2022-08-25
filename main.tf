# -----------Provider-------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.16.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# -----------VPC-------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"

  cidr = var.vpc_cidr_block

  azs             = data.aws_availability_zones.available.names
  private_subnets = slice(var.private_subnet_cidr_blocks, 0, 1)
  public_subnets  = slice(var.public_subnet_cidr_blocks, 0, 1)

  enable_nat_gateway = true
  enable_vpn_gateway = false
}

# -----------Security Group---------
module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "3.17.0"

  name        = "web-server-sg"
  description = "Security group for web-servers with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = module.vpc.public_subnets_cidr_blocks
}

# -----------Load Balancer---------
module "lb_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "3.17.0"

  name        = "lb-sg-project-alpha-dev"
  description = "Security group for load balancer with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
}

resource "random_string" "lb_id" {
  length  = 3
  special = false
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "2.4.0"

  # Ensure load balancer name is unique
  name = "lb-${random_string.lb_id.result}-project-alpha-dev"

  internal = false

  security_groups = [module.lb_security_group.this_security_group_id]
  subnets         = module.vpc.public_subnets

  number_of_instances = length(module.ec2_instances.instance_ids)
  instances           = module.ec2_instances.instance_ids

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

# -----------Instances---------
module "ec2_instances" {
  source = "./modules/aws-instance"

  instance_count     = var.instances_per_subnet * length(module.vpc.private_subnets)
  instance_type      = var.instance_type
  subnet_ids         = module.vpc.private_subnets[*]
  security_group_ids = [module.app_security_group.this_security_group_id]
}


# resource "aws_vpc" "my_vpc" {
#   cidr_block = "172.16.0.0/16"
# }

# data "aws_region" "current" {}

# resource "aws_vpc_ipam" "test" {
#   operating_regions {
#     region_name = data.aws_region.current.name
#   }
# }

# resource "aws_vpc_ipam_pool" "test" {
#   address_family = "ipv4"
#   ipam_scope_id  = aws_vpc_ipam.test.private_default_scope_id
#   locale         = data.aws_region.current.name
# }

# resource "aws_vpc_ipam_pool_cidr" "test" {
#   ipam_pool_id = aws_vpc_ipam_pool.test.id
#   cidr         = "172.16.0.0/16"
# }

# resource "aws_vpc" "test" {
#   ipv4_ipam_pool_id   = aws_vpc_ipam_pool.test.id
#   ipv4_netmask_length = 28
#   depends_on = [
#     aws_vpc_ipam_pool_cidr.test
#   ]
# }

# -----------Security Group--------

# resource "aws_security_group" "allow_tls" {
#   name        = "allow_tls"
#   description = "Allow TLS inbound traffic"
#   vpc_id      = aws_vpc.my_vpc.id

#   ingress {
#     description = "Allow ssh connections from VMs in Public Subnet"
#     protocol    = "tcp"
#     from_port   = 0
#     to_port     = 22
#     # cidr_blocks      = [aws_vpc.test.cidr_block]
#     # ipv6_cidr_blocks = [aws_vpc.test.ipv6_cidr_block]
#   }

#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }
# }

# resource "aws_security_group_rule" "example" {
#   type              = "ingress"
#   from_port         = 0
#   to_port           = 65535
#   protocol          = "tcp"
#   cidr_blocks       = ["172.16.0.0/16"]
#   # ipv6_cidr_blocks  = [aws_vpc.test.ipv6_cidr_block]
#   security_group_id = aws_security_group.allow_tls.id
# }

# resource "aws_security_group_rule" "second" {
#   type              = "ingress"
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = ["172.16.0.0/16"]
#   # ipv6_cidr_blocks  = [aws_vpc.test.ipv6_cidr_block]
#   security_group_id = aws_security_group.allow_tls.id
# }


# resource "aws_security_group" "allow_ssh" {
#   name        = "allow_ssh"
#   description = "Allow ssh inbound traffic"
#   vpc_id      = aws_vpc.my_vpc.id

#   ingress {
#     description      = "ssh"
#     from_port        = 22
#     to_port          = 22
#     protocol         = "tcp"
#     # cidr_blocks      = [aws_vpc.my_vpc.cidr_block]
#     # ipv6_cidr_blocks = [aws_vpc.my_vpc.ipv6_cidr_block]
#   }

#   egress {
#     from_port        = 0
#     to_port          = 0
#     protocol         = "-1"
#     cidr_blocks      = ["0.0.0.0/0"]
#     ipv6_cidr_blocks = ["::/0"]
#   }
# }

# resource "aws_security_group" "server_fw" {
#   vpc_id = aws_vpc.my_vpc.id
#   name   = "artur-server-fw"
#   ingress {
#     description = "ssh"
#     protocol    = "tcp"
#     from_port   = 22
#     to_port     = 22
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "http"
#     protocol    = "tcp"
#     from_port   = 80
#     to_port     = 80
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     protocol    = "icmp"
#     from_port   = -1
#     to_port     = -1
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     protocol    = "tcp"
#     from_port   = 22
#     to_port     = 22
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     protocol    = "-1"
#     from_port   = 0
#     to_port     = 0
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_subnet" "my_subnet" {
#   vpc_id                  = aws_vpc.my_vpc.id
#   cidr_block              = "172.16.10.0/24"
#   availability_zone       = "eu-central-1a"
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "tf-example"
#   }
# }

# resource "aws_network_interface" "foo" {
#   subnet_id   = aws_subnet.my_subnet.id
#   private_ips = ["172.16.10.100"]

#   tags = {
#     Name = "primary_network_interface"
#   }
# }

# resource "aws_instance" "foo" {
#   ami           = "ami-0e2031728ef69a466"
#   instance_type = "t2.micro"
#   # vpc_security_group_ids = [aws_security_group.allow_tls.id]
#   network_interface {
#     network_interface_id = aws_network_interface.foo.id
#     device_index         = 0
#   }

  # credit_specification {
  #   cpu_credits = "unlimited"
  # }
# }

# resource "aws_vpc" "my_vpc" {
#   cidr_block = "172.16.0.0/16"
# }



# resource "aws_subnet" "my_subnet" {
#   vpc_id            = aws_vpc.my_vpc.id
#   cidr_block        = "172.16.10.0/24"
#   availability_zone = "eu-central-1"

#   map_public_ip_on_launch = true
# }

# resource "aws_network_interface" "foo" {
#   subnet_id   = aws_subnet.my_subnet.id
#   private_ips = ["172.16.10.100"]
# }

# resource "aws_instance" "server" {
#   count           = 4
#   ami             = "ami-0e2031728ef69a466"
#   instance_type   = "t2.micro"
#   key_name        = "keypair"
#   # subnet_id       = "subnet-00c5ce3183084d233"
#   vpc_security_group_ids = [aws_security_group.server_fw.id]
#   user_data       = <<EOT
#                     #!/bin/bash 
#                     sudo yum -y update
#                     sudo yum -y install ruby
#                     sudo yum -y install wget
#                     cd /home/ec2-user
#                     Wget
#                     https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/l
#                     atest/install
#                     sudo chmod +x ./install
#                     sudo ./install auto
#                     sudo yum install -y python-pip
#                     sudo pip install awscli
#                     EOT

#   tags = {
#     Name = "artur-jenkins-terraform"
#   }
# }

# resource "aws_key_pair" "keypair" {
#   key_name   = "artur-keypair"
#   public_key = file("artur-keypair.pub")
# }



# resource "aws_instance" "artur_ec2" {
#   ami           = "ami-065deacbcaac64cf2"
#   instance_type = "t2.micro"
# }

# resource "aws_subnet" "artur-subnet" {
#   vpc_id     = "vpc-0c978c7db11ae32e9"
#   cidr_block = "172.31.60.0/24"
#   map_public_ip_on_launch = true
# }

# data "aws_route_table" "rtb" {
#   route_table_id = "rtb-09788c316efa0013b"
# }

# resource "aws_route_table_association" "artur-rtb" {
#   subnet_id      = aws_subnet.artur-subnet.id
#   route_table_id = data.aws_route_table.rtb.id
# }

# # resource "aws_route_table_association" "private_network_rt_a" {
# #   subnet_id = data.aws_subnet.artur-subnet.id
# #   route_table_id = data.aws_route_table.rtb.id
# # }

# data "aws_vpc" "private_cloud" {
#   id = "vpc-0c978c7db11ae32e9"
# }
# # data "aws_caller_identity" "current" {}
