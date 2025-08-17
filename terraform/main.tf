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
  region  = "us-east-1"
  profile = var.aws_profile
}

variable "aws_profile" {
  description = "AWS profile name to use"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name used as prefix for all AWS resources"
  type        = string
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



variable "admin_password" {
  description = "Admin password for applications"
  type        = string
  sensitive   = true
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0de716d6197524dd9" # Amazon Linux 2023
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
  name_prefix = "${var.project_name}-sg"
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
    description = "For openhands"
    from_port   = 30000
    to_port     = 60000
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  ingress {
    description = "For Caddy"
    from_port   = 5000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }



}

resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.main.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.main.private_key_pem
  filename = "key.pem"
}

resource "aws_instance" "main" {
  ami                    = var.ami_id
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
    aws_s3_object.source
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-instance"
    ProjectName = var.project_name
  }
}

resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }
}

resource "aws_iam_role" "main" {
  name = "${var.project_name}-instance-role"

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

resource "aws_iam_role_policy" "s3_access" {
  name = "s3-access"
  role = aws_iam_role.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.source.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.main.name
}

resource "aws_ssm_parameter" "openhands_litellm_key" {
  name  = "/${var.project_name}/litellm-key"
  type  = "SecureString"
  value = var.openhands_litellm_key

  tags = {
    Name = "${var.project_name} LiteLLM Key"
  }
}



resource "aws_ssm_parameter" "openhands_elastic_ip" {
  name  = "/${var.project_name}/elastic-ip"
  type  = "String"
  value = aws_eip.main.public_ip

  tags = {
    Name = "${var.project_name} Elastic IP"
  }
}

resource "aws_ssm_parameter" "source_zip_location" {
  name  = "/${var.project_name}/source-zip-location"
  type  = "String"
  value = "s3://${aws_s3_bucket.source.id}/${aws_s3_object.source.key}"

  tags = {
    Name = "${var.project_name} Source Zip Location"
  }
}

resource "aws_ssm_parameter" "project_name" {
  name  = "/${var.project_name}/project-name"
  type  = "String"
  value = var.project_name

  tags = {
    Name = "OH Setup Project Name"
  }
}

resource "aws_ssm_parameter" "admin_password" {
  name  = "/${var.project_name}/admin-password"
  type  = "SecureString"
  value = var.admin_password

  tags = {
    Name = "${var.project_name} Admin Password"
  }
}

resource "aws_ssm_parameter" "apps_config" {
  name  = "/${var.project_name}/apps-config"
  type  = "String"
  value = jsonencode([
    {name = "OpenHands", port = 5000, description = "AI Coding Assistant", protocol = "https"},
    {name = "VSCode", port = 5002, description = "Browser IDE", protocol = "https"},
    {name = "Portainer", port = 5003, description = "Docker Management", protocol = "https"},
    {name = "Open WebUI", port = 5004, description = "LLM Interface", protocol = "https"},
    {name = "SearXNG", port = 5005, description = "Search Engine", protocol = "https"},
    {name = "Jupyter", port = 5006, description = "Jupyter Notebook", protocol = "https"},
    {name = "LiteLLM", port = 5001, description = "Lite LLM", protocol = "http"}
  ])

  tags = {
    Name = "${var.project_name} Apps Configuration"
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
    S3_BUCKET_ID=${aws_s3_bucket.source.id}
    IAM_ROLE_ARN=${aws_iam_role.main.arn}
    IAM_INSTANCE_PROFILE_ARN=${aws_iam_instance_profile.main.arn}
    INTERNET_GATEWAY_ID=${data.aws_internet_gateway.main.id}
    ROUTE_TABLE_ID=${data.aws_route_table.subnet_rt.id}
    CONTROLLER_URL=${aws_lambda_function_url.controller.function_url}

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

output "s3_bucket_id" {
  value = aws_s3_bucket.source.id
}

output "iam_role_arn" {
  value = aws_iam_role.main.arn
}

output "iam_instance_profile_arn" {
  value = aws_iam_instance_profile.main.arn
}

output "internet_gateway_id" {
  value = data.aws_internet_gateway.main.id
}

output "route_table_id" {
  value = data.aws_route_table.subnet_rt.id
}

resource "aws_s3_bucket" "source" {
  bucket = "${var.project_name}-source-bucket"
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/.."
  output_path = "${path.module}/../temp/${var.project_name}-source.zip"
  excludes    = ["temp", ".git", "terraform/.terraform", "terraform/terraform.tfstate*"]
}

resource "aws_s3_object" "source" {
  bucket = aws_s3_bucket.source.id
  key    = "${var.project_name}/source/${var.project_name}-source.zip"
  source = data.archive_file.source.output_path
  etag   = data.archive_file.source.output_md5
}

# Lambda Controller
data "archive_file" "controller_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../controller"
  output_path = "${path.module}/../temp/controller.zip"
}

resource "aws_iam_role" "controller_lambda_role" {
  name = "${var.project_name}-controller-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "controller_lambda_policy" {
  name = "${var.project_name}-controller-lambda-policy"
  role = aws_iam_role.controller_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["ec2:DescribeInstances", "ec2:StartInstances", "ec2:StopInstances", "ec2:AuthorizeSecurityGroupIngress"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "controller" {
  filename         = data.archive_file.controller_zip.output_path
  function_name    = "${var.project_name}-controller"
  role            = aws_iam_role.controller_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  source_code_hash = data.archive_file.controller_zip.output_base64sha256
}

resource "aws_lambda_function_url" "controller" {
  function_name      = aws_lambda_function.controller.function_name
  authorization_type = "NONE"
}

output "controller_url" {
  value = aws_lambda_function_url.controller.function_url
}