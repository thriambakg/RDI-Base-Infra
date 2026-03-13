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

# Replica provider (required by S3 module; unused when replication disabled)
provider "aws" {
  alias  = "replica"
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
  project_name      = "rdi"
  # Cognito domain must be globally unique; use account ID suffix
  cognito_domain = "rdi-${var.environment}-${substr(data.aws_caller_identity.current.account_id, -6, 6)}"
}

# -----------------------------------------------------------------------------
# Cognito - User Pool, Client, Domain (RDI-specific, minimal)
# -----------------------------------------------------------------------------
module "cognito" {
  source = "./modules/cognito"

  name_prefix    = local.name_prefix
  cognito_domain = local.cognito_domain
  environment    = var.environment
  callback_urls = distinct(concat(
    length(var.cognito_callback_urls) > 0 ? var.cognito_callback_urls : ["http://localhost:5173/auth/callback", "https://localhost/auth/callback"],
    ["https://${module.frontend_cloudfront.distribution_domain_name}/auth/callback"]
  ))
  logout_urls = distinct(concat(
    length(var.cognito_logout_urls) > 0 ? var.cognito_logout_urls : ["http://localhost:5173", "https://localhost"],
    ["https://${module.frontend_cloudfront.distribution_domain_name}"]
  ))

  enable_google        = var.enable_google_auth
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret

  tags = {}
}

# -----------------------------------------------------------------------------
# DynamoDB - User profiles table (generic module)
# -----------------------------------------------------------------------------
module "user_profiles" {
  source = "./modules/dynamodb-table"

  project_name  = local.project_name
  environment   = var.environment
  table_name    = "user-profiles"
  hash_key      = "user_id"
  range_key     = null
  billing_mode  = "PAY_PER_REQUEST"
  kms_key_arn   = null
  table_type    = "UserProfiles"
  table_purpose = "UserProfileStorage"

  attributes = [
    { name = "user_id", type = "S" },
    { name = "email", type = "S" }
  ]

  global_secondary_indexes = [
    {
      name            = "email-index"
      hash_key        = "email"
      projection_type = "ALL"
    }
  ]

  tags = {}
}

# -----------------------------------------------------------------------------
# S3 - Frontend static assets bucket (generic module)
# -----------------------------------------------------------------------------
module "frontend_s3" {
  source = "./modules/s3"

  bucket_name   = "rdi-frontend-${var.environment}-${data.aws_caller_identity.current.account_id}"
  environment   = var.environment
  purpose       = "frontend"
  kms_key_arn   = null
  force_destroy = var.environment != "production"

  allow_cloudfront_oac = true
  access_log_bucket    = ""
  tags                 = {}

  providers = {
    aws         = aws
    aws.replica = aws.replica
  }
}

# -----------------------------------------------------------------------------
# CloudFront - Global CDN for frontend (generic module)
# -----------------------------------------------------------------------------
module "frontend_cloudfront" {
  source = "./modules/cloudfront"

  project_name = local.project_name
  environment  = var.environment

  s3_bucket_domain_name = module.frontend_s3.bucket_regional_domain_name
  s3_bucket_id          = module.frontend_s3.bucket_id
  s3_bucket_arn         = module.frontend_s3.bucket_arn

  aliases             = []
  acm_certificate_arn = null
  create_waf          = false
  enable_logging      = false
  default_root_object = "index.html"

  custom_error_responses = [
    { error_code = 404, response_code = 200, response_page_path = "/index.html", error_caching_min_ttl = 300 },
    { error_code = 403, response_code = 200, response_page_path = "/index.html", error_caching_min_ttl = 300 }
  ]

  tags = {}
}
