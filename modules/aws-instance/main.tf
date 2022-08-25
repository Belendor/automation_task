data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app" {
  count = var.instance_count

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = var.security_group_ids

  user_data = <<EOT
                  #!/bin/bash 
                  sudo yum -y update
                  sudo yum -y install ruby
                  sudo yum -y install wget
                  cd /home/ec2-user
                  Wget
                  https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/l
                  atest/install
                  sudo chmod +x ./install
                  sudo ./install auto
                  sudo yum install -y python-pip
                  sudo pip install awscli
                EOT
}
