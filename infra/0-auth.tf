terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-aaronmcd"
    key    = "go-app-040726.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "jenkins-multienv-demo"
      ManagedBy = "Terraform"
    }
  }
}
