# Google OAuth credentials for Cognito IdP.
# Secret JSON shape:
#   { "google_client_id": "...apps.googleusercontent.com", "google_client_secret": "..." }
#
# After first apply, put real values (Terraform re-reads via data source on next plan):
#   aws secretsmanager put-secret-value \
#     --secret-id rdi-staging/oauth \
#     --secret-string '{"google_client_id":"...","google_client_secret":"..."}' \
#     --region us-east-1
#
# Authorized redirect URI in Google Cloud Console:
#   https://<cognito-domain>.auth.<region>.amazoncognito.com/oauth2/idpresponse

resource "aws_secretsmanager_secret" "oauth" {
  name                    = "${local.name_prefix}/oauth"
  description             = "OAuth IdP credentials (Google) for Cognito"
  recovery_window_in_days = 0

  tags = {
    Project     = "rdi"
    Environment = var.environment
    Purpose     = "cognito-oauth"
  }
}

resource "aws_secretsmanager_secret_version" "oauth_seed" {
  secret_id = aws_secretsmanager_secret.oauth.id
  secret_string = jsonencode({
    google_client_id     = var.google_client_id != "" ? var.google_client_id : "REPLACE_ME"
    google_client_secret = var.google_client_secret != "" ? var.google_client_secret : "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

data "aws_secretsmanager_secret_version" "oauth" {
  secret_id  = aws_secretsmanager_secret.oauth.id
  depends_on = [aws_secretsmanager_secret_version.oauth_seed]
}

locals {
  oauth_secret = jsondecode(data.aws_secretsmanager_secret_version.oauth.secret_string)
  google_client_id_effective = (
    var.google_client_id != "" ? var.google_client_id : try(local.oauth_secret.google_client_id, "")
  )
  google_client_secret_effective = (
    var.google_client_secret != "" ? var.google_client_secret : try(local.oauth_secret.google_client_secret, "")
  )
  google_credentials_ready = (
    local.google_client_id_effective != "" &&
    local.google_client_id_effective != "REPLACE_ME" &&
    local.google_client_secret_effective != "" &&
    local.google_client_secret_effective != "REPLACE_ME"
  )
  enable_google_effective = var.enable_google_auth && local.google_credentials_ready
}
