terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # Backend opcional S3 - descomentar y configurar si se quiere estado remoto.
  # En AWS Learner Lab el bucket debe existir antes (no se puede crear con LabRole limitado).
  # backend "s3" {
  #   bucket = "tienda-tech-tfstate-XXXX"
  #   key    = "tienda-tech/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
