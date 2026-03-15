output "account_id" {
  description = "Current AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "api_gateway_cloudwatch_role_arn" {
  description = "ARN of IAM role for API Gateway CloudWatch execution logging"
  value       = module.api_gateway_cloudwatch_role.role_arn
}

output "region" {
  description = "AWS region for this deployment"
  value       = local.region
}

output "is_primary_region" {
  description = "Whether this region is the primary (for replication sources)"
  value       = local.is_primary_region
}

output "all_regions" {
  description = "List of all deployment regions (for cross-region logic)"
  value       = var.regions
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = module.cognito.client_id
}

output "cognito_domain" {
  description = "Cognito hosted UI domain prefix"
  value       = module.cognito.domain
}

output "cognito_domain_url" {
  description = "Cognito domain URL for hosted UI"
  value       = module.cognito.domain_url
}

output "user_profiles_table_name" {
  description = "DynamoDB user profiles table name"
  value       = module.user_profiles.table_name
}

output "connection_pool_table_name" {
  description = "DynamoDB connection pool table name"
  value       = module.connection_pool.table_name
}

output "connection_pool_table_arn" {
  description = "DynamoDB connection pool table ARN"
  value       = module.connection_pool.table_arn
}

output "flight_logs_bucket_name" {
  description = "S3 bucket for flight logs (EC2 uploads on session close)"
  value       = length(module.flight_logs_s3) > 0 ? module.flight_logs_s3[0].bucket_id : null
}

output "flight_logs_bucket_arn" {
  description = "S3 bucket ARN for flight logs"
  value       = length(module.flight_logs_s3) > 0 ? module.flight_logs_s3[0].bucket_arn : null
}

output "frontend_s3_bucket_name" {
  description = "S3 bucket for frontend static hosting"
  value       = module.frontend_s3.bucket_id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for frontend"
  value       = module.frontend_cloudfront.distribution_id
}

output "frontend_url" {
  description = "Frontend URL (CloudFront)"
  value       = "https://${module.frontend_cloudfront.distribution_domain_name}"
}

output "build_environment_variables" {
  description = "JSON object of build env vars for frontend"
  value = jsonencode({
    NEXT_PUBLIC_AWS_REGION                  = local.region
    NEXT_PUBLIC_COGNITO_USER_POOL_ID        = module.cognito.user_pool_id
    NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID = module.cognito.client_id
    NEXT_PUBLIC_COGNITO_DOMAIN              = "${module.cognito.domain}.auth.${local.region}.amazoncognito.com"
    NEXT_PUBLIC_REDIRECT_SIGN_IN            = "https://${module.frontend_cloudfront.distribution_domain_name}/auth/callback"
    NEXT_PUBLIC_REDIRECT_SIGN_OUT           = "https://${module.frontend_cloudfront.distribution_domain_name}"
    NEXT_PUBLIC_API_GATEWAY_URL             = ""
    ENABLE_GOOGLE_AUTH                      = tostring(var.enable_google_auth)
  })
}
