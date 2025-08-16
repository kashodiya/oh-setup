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

variable "allowed_ips" {
  description = "List of IP addresses allowed for SSH and HTTP access"
  type        = list(string)
}

variable "openhands_litellm_key" {
  description = "LiteLLM API key for OpenHands"
  type        = string
  sensitive   = true
}

variable "openhands_vscode_token" {
  description = "VSCode connection token for OpenHands"
  type        = string
  sensitive   = true
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
    cidr_blocks = var.allowed_ips
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
    cidr_blocks = var.allowed_ips
  }

  ingress {
    description = "For openhands"
    from_port   = 30000
    to_port     = 60000
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }


  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
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
  
  iam_instance_profile   = aws_iam_instance_profile.main.name

  root_block_device {
    volume_size = 80
    volume_type = "gp3"
  }

  depends_on = [
    aws_ssm_parameter.openhands_litellm_key,
    aws_ssm_parameter.openhands_vscode_token
  ]

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

resource "aws_iam_role" "main" {
  name = "main-instance-role"

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
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "bedrock" {
  name = "bedrock-access"
  role = aws_iam_role.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "main" {
  name = "main-instance-profile"
  role = aws_iam_role.main.name
}

resource "aws_ssm_parameter" "openhands_litellm_key" {
  name  = "/openhands/litellm-key"
  type  = "SecureString"
  value = var.openhands_litellm_key

  tags = {
    Name = "OpenHands LiteLLM Key"
  }
}

resource "aws_ssm_parameter" "openhands_vscode_token" {
  name  = "/openhands/vscode-token"
  type  = "SecureString"
  value = var.openhands_vscode_token

  tags = {
    Name = "OpenHands VSCode Token"
  }
}

resource "aws_ssm_parameter" "openhands_elastic_ip" {
  name  = "openhands_elastic_ip"
  type  = "String"
  value = aws_eip.main.public_ip

  tags = {
    Name = "OpenHands Elastic IP"
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