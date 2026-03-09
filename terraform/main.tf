# RDI Base Infrastructure
# Uses remote state in S3 - run terraform/bootstrap first if not yet done

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    # Values from backend-configs/{environment}.tfbackend
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "rdi"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  is_primary_region = var.primary_region != "" && var.region == var.primary_region
  region            = data.aws_region.current.name
  name_prefix       = "rdi-${var.environment}"
  # Cognito domain must be globally unique; use account ID suffix
  cognito_domain = "rdi-${var.environment}-${substr(data.aws_caller_identity.current.account_id, -6, 6)}"
}

module "cognito" {
  source = "./modules/cognito"

  name_prefix    = local.name_prefix
  cognito_domain = local.cognito_domain
  environment    = var.environment
  callback_urls  = length(var.cognito_callback_urls) > 0 ? var.cognito_callback_urls : ["http://localhost:5173/auth/callback", "https://localhost/auth/callback"]
  logout_urls    = length(var.cognito_logout_urls) > 0 ? var.cognito_logout_urls : ["http://localhost:5173", "https://localhost"]

  enable_google        = var.enable_google_auth
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret

  tags = {}
}

module "user_profiles" {
  source = "./modules/user-profiles"

  name_prefix = local.name_prefix
  tags        = {}
}
