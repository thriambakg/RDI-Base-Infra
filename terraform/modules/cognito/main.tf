# Cognito User Pool - email/password + Google
# Google IdP requires COGNITO_GOOGLE_CLIENT_ID and COGNITO_GOOGLE_CLIENT_SECRET in AWS Secrets Manager or tfvars

resource "aws_cognito_user_pool" "main" {
  name = "${var.name_prefix}-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Signup verification: Cognito emails a clickable link (CONFIRM_WITH_LINK).
  # Branded HTML body comes from the CustomMessage Lambda trigger.
  # Default Cognito sender (no-reply@verificationemail.com) until SES DEVELOPER + from-address.
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_subject_by_link = "Confirm your RDI account"
    email_message_by_link = "Welcome to RDI. Confirm your email to finish setup: {##Verify Email##}"
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  # Required TOTP MFA for Cognito (email/password) users — Microsoft Authenticator,
  # Google Authenticator, Authy, etc. Federated Google users use Google's MFA instead.
  mfa_configuration = "ON"

  software_token_mfa_configuration {
    enabled = true
  }

  lambda_config {
    pre_authentication  = aws_lambda_function.cognito_auth_triggers.arn
    post_authentication = aws_lambda_function.cognito_auth_triggers.arn
    custom_message      = aws_lambda_function.cognito_auth_triggers.arn
  }

  tags = merge(var.tags, {
    Project     = "rdi"
    Environment = var.environment
  })

  lifecycle {
    ignore_changes = [schema]
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.cognito_domain
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.name_prefix}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  supported_identity_providers = concat(
    ["COGNITO"],
    var.enable_google ? ["Google"] : []
  )

  # App client must list Google only after the IdP exists.
  depends_on = [aws_cognito_identity_provider.google]

  read_attributes  = ["email", "email_verified", "name"]
  write_attributes = ["email", "name"]

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30
}

resource "aws_cognito_identity_provider" "google" {
  count = var.enable_google && var.google_client_id != "" ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    authorize_scopes = "email profile openid"
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
    name     = "name"
  }
}
