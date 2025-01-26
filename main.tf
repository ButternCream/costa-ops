# Main terraform file
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.region
  profile = "terraform"
}

data "aws_caller_identity" "current" {}

resource "aws_ssm_parameter" "app_secrets" {
  for_each = {
    POSTGRES_USER     = var.postgres_user
    POSTGRES_DB       = var.postgres_db
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_PORT     = var.postgres_port
    COSTA_API_PORT    = var.costa_api_port
  }

  name  = "/app/${each.key}"
  type  = "SecureString"
  value = each.value
}

resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2_ecr_role"

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

resource "aws_iam_role_policy" "ssm_policy" {
  role = aws_iam_role.ec2_ecr_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter"
      ]
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/app/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_ecr_profile"
  role = aws_iam_role.ec2_ecr_role.name
}

resource "aws_instance" "costa-dash" {
  ami                    = "ami-0fa40e25bf4dda1f6"
  instance_type          = "t2.micro"
  user_data              = file("setup.sh")
  key_name               = "aws-key"
  vpc_security_group_ids = [aws_security_group.main.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "costa-dash-ec2"
  }
}

resource "aws_security_group" "main" {
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.postgres_port
    to_port     = var.postgres_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.costa_api_port
    to_port     = var.costa_api_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# My key pair for ssh into EC2 instance 
resource "aws_key_pair" "deployer" {
  key_name   = "aws-key"
  public_key = file("~/.ssh/aws-key.pub")
}

locals {
  services = ["api", "liquibase"] # Only custom services that need ECR
}

resource "aws_ecr_repository" "costa-docker-images" {
  for_each             = toset(local.services)
  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}