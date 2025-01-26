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
  region  = "us-west-2"
  profile = "terraform"
}

resource "aws_instance" "costa-dash" {
  ami           = "ami-0fa40e25bf4dda1f6"
  instance_type = "t2.micro"
  user_data     = file("setup.sh")

  tags = {
    Name = "CostaDashServer"
  }
}

resource "aws_ecr_repository" "costa-docker-images" {
  name                 = "costa-docker-images"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}