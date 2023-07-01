terraform {
  backend "s3" {
    bucket = "myapp"
    key = "myapp/state/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}

# VPC
resource "aws_vpc" "myapp_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

# Subnet
resource "aws_subnet" "myapp_subnet_1" {
  vpc_id = aws_vpc.myapp_vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone

  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "myapp_igw" {
  vpc_id = aws_vpc.myapp_vpc.id

  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

# Default Route Table
resource "aws_default_route_table" "main_rtb" {
  default_route_table_id = aws_vpc.myapp_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp_igw.id
  }

  tags = {
    Name: "${var.env_prefix}-main-rtb"
  }
}

# Security Group
resource "aws_default_security_group" "my_app_default_sg" {
  vpc_id = aws_vpc.myapp_vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks= ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name: "${var.env_prefix}-default-sg"
  }
}

# Data for AWS AMI
data "aws_ami" "amazon_linux_image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.amazon_linux_image.id
}

# EC2 Instance
resource "aws_instance" "myapp_server" {
  ami = data.aws_ami.amazon_linux_image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp_subnet_1.id
  vpc_security_group_ids = [aws_default_security_group.my_app_default_sg.id]
  availability_zone = var.avail_zone

  associate_public_ip_address = true
  key_name = "myapp-server-key"

  user_data = file("entry-script.sh")

  tags = {
    Name: "${var.env_prefix}-server"
  }
}

output "ec2_public_key" {
  value = aws_instance.myapp_server.public_ip
}

# SSH Key
resource "aws_key_pair" "ssh_key" {
  key_name = "myapp-server-key"
  public_key = file(var.public_key_location)
}

