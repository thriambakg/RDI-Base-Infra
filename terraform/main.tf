# RDI Base Infrastructure
# Uses remote state in S3 - run terraform/bootstrap first if not yet done

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
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

# Replica region provider for flight logs bucket (cross-region replication in prod)
provider "aws" {
  alias  = "flight_logs_replica"
  region = coalesce(var.flight_logs_replica_region, var.region)

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
# IAM - API Gateway CloudWatch Logs role (account-level; required for execution logging)
# -----------------------------------------------------------------------------
module "api_gateway_cloudwatch_role" {
  source = "./modules/iam-role"

  role_name   = "${local.name_prefix}-api-gateway-cloudwatch"
  description = "Allows API Gateway to push execution logs to CloudWatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  ]

  tags = {}
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

  user_profiles_table_name = module.user_profiles.table_name
  user_profiles_table_arn  = module.user_profiles.table_arn

  tags = {}

  depends_on = [module.user_profiles]
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
# DynamoDB - Connection pool table (session/slot management)
# PK: user_id, SK: session_id — user-centric access; region/wavelength_zone as attributes
# -----------------------------------------------------------------------------
module "connection_pool" {
  source = "./modules/dynamodb-table"

  project_name     = local.project_name
  environment      = var.environment
  table_name       = "connection-pool"
  hash_key         = "user_id"
  range_key        = "session_id"
  billing_mode     = "PAY_PER_REQUEST"
  kms_key_arn      = null
  table_type       = "ConnectionPool"
  table_purpose    = "SessionAndProxySlotManagement"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  replica_regions  = var.dynamodb_replica_regions

  # Only key attributes — region, status, wavelength_zone_id, etc. are regular item attrs (no index)
  attributes = [
    { name = "user_id", type = "S" },
    { name = "session_id", type = "S" },
    { name = "user_zone_sk", type = "S" }
  ]

  global_secondary_indexes = [
    {
      name            = "UserZoneIndex"
      hash_key        = "user_id"
      range_key       = "user_zone_sk"
      projection_type = "ALL"
    },
    {
      name            = "SessionIdIndex"
      hash_key        = "session_id"
      projection_type = "ALL"
    }
  ]

  ttl_enabled        = true
  ttl_attribute_name = "expires_at"

  tags = {}
}

# -----------------------------------------------------------------------------
# DynamoDB - Relay registry (relays per Wavelength zone)
# PK: wavelength_zone_id, SK: relay_id — zone-centric; same replica pattern as connection-pool
# -----------------------------------------------------------------------------
module "relay_registry" {
  source = "./modules/dynamodb-table"

  project_name     = local.project_name
  environment      = var.environment
  table_name       = "relay-registry"
  hash_key         = "wavelength_zone_id"
  range_key        = "relay_id"
  billing_mode     = "PAY_PER_REQUEST"
  kms_key_arn      = null
  table_type       = "RelayRegistry"
  table_purpose    = "RelaysPerWavelengthZone"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
  replica_regions  = var.dynamodb_replica_regions

  attributes = [
    { name = "wavelength_zone_id", type = "S" },
    { name = "relay_id", type = "S" },
    { name = "user_id", type = "S" },
    { name = "user_relay_sk", type = "S" },
    { name = "claim_code", type = "S" },
    { name = "device_serial", type = "S" }
  ]

  global_secondary_indexes = [
    {
      name            = "UserRelayIndex"
      hash_key        = "user_id"
      range_key       = "user_relay_sk"
      projection_type = "ALL"
    },
    {
      name            = "ClaimCodeIndex"
      hash_key        = "claim_code"
      projection_type = "ALL"
    },
    {
      name            = "DeviceSerialIndex"
      hash_key        = "device_serial"
      projection_type = "ALL"
    }
  ]

  tags = {}
}

# -----------------------------------------------------------------------------
# S3 - Flight logs bucket (EC2 writes logs on session close)
# Path: {user_id}/{wavelength_zone_id}/{drone_id}-{session_id}.log
# Replication: prod (2 regions), staging (single region)
# -----------------------------------------------------------------------------
module "flight_logs_s3" {
  source = "./modules/s3"
  count  = local.is_primary_region ? 1 : 0

  bucket_name   = "rdi-flight-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"
  environment   = var.environment
  purpose       = "flight-logs"
  kms_key_arn   = null
  force_destroy = var.environment != "production"

  enable_cross_region_replication = var.flight_logs_replica_region != "" && var.flight_logs_replica_region != var.region
  allow_cloudfront_oac            = false
  block_public_acls               = true
  block_public_policy             = true
  access_log_bucket               = ""
  tags                            = {}

  providers = {
    aws         = aws
    aws.replica = aws.flight_logs_replica
  }
}

# -----------------------------------------------------------------------------
# S3 - Frontend static assets bucket (generic module)
# -----------------------------------------------------------------------------
module "frontend_s3" {
  source = "./modules/s3"

  bucket_name   = "rdi-frontend-${var.environment}-${var.region}-${data.aws_caller_identity.current.account_id}"
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
# Frontend custom domain: ACM cert (CloudFront requires us-east-1; zone must exist, e.g. from RDI-1.0)
# -----------------------------------------------------------------------------
data "aws_route53_zone" "frontend" {
  count        = var.frontend_custom_domain != "" ? 1 : 0
  name         = "${var.frontend_custom_domain}."
  private_zone = false
}

resource "aws_acm_certificate" "frontend" {
  count             = var.frontend_custom_domain != "" ? 1 : 0
  domain_name       = var.frontend_custom_domain
  validation_method = "DNS"

  subject_alternative_names = ["www.${var.frontend_custom_domain}"]

  lifecycle { create_before_destroy = true }

  tags = { Name = "${local.name_prefix}-frontend-${var.frontend_custom_domain}" }
}

resource "aws_route53_record" "frontend_cert_validation" {
  for_each = var.frontend_custom_domain != "" && length(aws_acm_certificate.frontend) > 0 ? {
    for dvo in aws_acm_certificate.frontend[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.frontend[0].zone_id
}

resource "aws_acm_certificate_validation" "frontend" {
  count                   = var.frontend_custom_domain != "" && length(aws_acm_certificate.frontend) > 0 ? 1 : 0
  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [for r in aws_route53_record.frontend_cert_validation : r.fqdn]
}

# -----------------------------------------------------------------------------
# CloudFront - Global CDN for frontend (generic module)
# -----------------------------------------------------------------------------
module "frontend_cloudfront" {
  source = "./modules/cloudfront"

  project_name = local.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id

  s3_bucket_domain_name = module.frontend_s3.bucket_regional_domain_name
  s3_bucket_id          = module.frontend_s3.bucket_id
  s3_bucket_arn         = module.frontend_s3.bucket_arn

  aliases             = var.frontend_custom_domain != "" ? [var.frontend_custom_domain, "www.${var.frontend_custom_domain}"] : []
  acm_certificate_arn = var.frontend_custom_domain != "" && length(aws_acm_certificate_validation.frontend) > 0 ? aws_acm_certificate_validation.frontend[0].certificate_arn : null
  create_waf          = false
  enable_logging      = false
  default_root_object = "index.html"

  custom_error_responses = [
    { error_code = 404, response_code = 200, response_page_path = "/index.html", error_caching_min_ttl = 300 },
    { error_code = 403, response_code = 200, response_page_path = "/index.html", error_caching_min_ttl = 300 }
  ]

  tags = {}
}

# Route53 A (alias) for apex and www -> CloudFront (so rdistaging.com and www.rdistaging.com serve the frontend)
resource "aws_route53_record" "frontend_apex" {
  count   = var.frontend_custom_domain != "" ? 1 : 0
  zone_id = data.aws_route53_zone.frontend[0].zone_id
  name    = var.frontend_custom_domain
  type    = "A"

  alias {
    name                   = module.frontend_cloudfront.distribution_domain_name
    zone_id                = module.frontend_cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "frontend_www" {
  count   = var.frontend_custom_domain != "" ? 1 : 0
  zone_id = data.aws_route53_zone.frontend[0].zone_id
  name    = "www.${var.frontend_custom_domain}"
  type    = "A"

  alias {
    name                   = module.frontend_cloudfront.distribution_domain_name
    zone_id                = module.frontend_cloudfront.distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
