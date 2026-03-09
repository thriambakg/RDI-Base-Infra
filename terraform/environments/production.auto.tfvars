environment    = "production"
region         = "eu-central-1"
regions        = ["eu-central-1", "eu-west-2", "eu-west-3"]
primary_region = "eu-central-1"

# Cognito - update with your CloudFront URL after first deploy
cognito_callback_urls = ["https://your-domain.com/auth/callback"]
cognito_logout_urls   = ["https://your-domain.com"]
enable_google_auth    = false
