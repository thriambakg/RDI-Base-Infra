environment    = "staging"
region         = "us-east-1"
regions        = ["us-east-1"]
primary_region = "us-east-1"

# Custom domain for frontend (rdistaging.com). Route53 zone must exist (e.g. from RDI-1.0 domain module).
# CloudFront aliases + ACM cert + apex/www A records are created here.
frontend_custom_domain = "rdistaging.com"

# Cognito - callback/logout URLs for Hosted UI (email/password and Google). Base infra applies these + CloudFront domain.
cognito_callback_urls = [
  "http://localhost:5173/auth/callback",
  "https://rdistaging.com/auth/callback",
  "https://www.rdistaging.com/auth/callback"
]
cognito_logout_urls = [
  "http://localhost:5173",
  "https://rdistaging.com",
  "https://www.rdistaging.com"
]
# Google IdP: enable when Secrets Manager secret `${name_prefix}/oauth` has real
# google_client_id / google_client_secret (or set TF_VAR_google_client_*).
enable_google_auth = true
