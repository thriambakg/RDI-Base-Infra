output "account_id" {
  description = "Current AWS account ID"
  value       = data.aws_caller_identity.current.account_id
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

output "build_environment_variables" {
  description = "JSON object of build env vars for frontend"
  value = jsonencode({
    NEXT_PUBLIC_AWS_REGION                  = local.region
    NEXT_PUBLIC_COGNITO_USER_POOL_ID        = module.cognito.user_pool_id
    NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID = module.cognito.client_id
    NEXT_PUBLIC_COGNITO_DOMAIN              = "${module.cognito.domain}.auth.${local.region}.amazoncognito.com"
    NEXT_PUBLIC_REDIRECT_SIGN_IN            = length(var.cognito_callback_urls) > 0 ? var.cognito_callback_urls[0] : "http://localhost:5173/auth/callback"
    NEXT_PUBLIC_REDIRECT_SIGN_OUT           = length(var.cognito_logout_urls) > 0 ? var.cognito_logout_urls[0] : "http://localhost:5173"
    NEXT_PUBLIC_API_GATEWAY_URL             = ""
  })
}
