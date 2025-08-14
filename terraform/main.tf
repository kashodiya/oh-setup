terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "allowed_ip" {
  description = "IP address allowed for SSH and HTTP access"
  type        = string
}

data "aws_subnet" "main" {
  id = var.subnet_id
}

data "aws_route_table" "subnet_rt" {
  subnet_id = var.subnet_id
}

data "aws_internet_gateway" "main" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_subnet.main.vpc_id]
  }
}

locals {
  has_igw_route = length([
    for route in data.aws_route_table.subnet_rt.routes :
    route if route.cidr_block == "0.0.0.0/0" && route.gateway_id != null
  ]) > 0
}

resource "null_resource" "internet_check" {
  count = local.has_igw_route ? 0 : 1
  
  provisioner "local-exec" {
    command = "echo ERROR: Subnet lacks internet gateway route && exit 1"
  }
}

resource "aws_security_group" "main" {
  name_prefix = "main-sg"
  vpc_id      = data.aws_subnet.main.vpc_id

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "For apps"
    from_port   = 3000
    to_port     = 7000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "main-key"
  public_key = tls_private_key.main.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.main.private_key_pem
  filename = "key.pem"
}

resource "aws_instance" "main" {
  ami                    = "ami-08a0d1e16fc3f61ea" # Amazon Linux 2 AMI
  instance_type          = "m5.xlarge"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.main.id]
  key_name               = aws_key_pair.main.key_name
  user_data              = file("${path.module}/user-data.sh")

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "main-instance"
  }
}

resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"

  tags = {
    Name = "main-eip"
  }
}

resource "local_file" "outputs" {
  content = <<-EOT
    ELASTIC_IP=${aws_eip.main.public_ip}
    INSTANCE_ID=${aws_instance.main.id}
    SECURITY_GROUP_ID=${aws_security_group.main.id}
    KEY_PAIR_NAME=${aws_key_pair.main.key_name}
    SUBNET_ID=${var.subnet_id}
    VPC_ID=${data.aws_subnet.main.vpc_id}
  EOT
  filename = "outputs.env"
}

output "elastic_ip" {
  value = aws_eip.main.public_ip
}

output "subnet_id" {
  value = aws_instance.main.subnet_id
}

output "instance_id" {
  value = aws_instance.main.id
}

output "security_group_id" {
  value = aws_security_group.main.id
}

output "key_pair_name" {
  value = aws_key_pair.main.key_name
}

output "vpc_id" {
  value = data.aws_subnet.main.vpc_id
}