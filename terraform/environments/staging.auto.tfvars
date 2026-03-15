environment    = "staging"
region         = "us-east-1"
regions        = ["us-east-1"]
primary_region = "us-east-1"

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
enable_google_auth = false # Set true and provide google_client_id / google_client_secret for Google login
