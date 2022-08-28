variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI for EC2 instances. Amazon Linux 2, Kernel 5.10"
  type        = string
  default     = "ami-0e2031728ef69a466"
}

variable "vpc_id" {
  description = "VPC which you want to use"
  type        = string
  default     = "vpc-0c978c7db11ae32e9"
}

variable "subnet_id" {
  description = "Subnet in which you want to create instances"
  type        = string
  default     = "subnet-01e63460073970f31"
}