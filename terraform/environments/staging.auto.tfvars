environment    = "staging"
region         = "us-east-2"
regions        = ["us-east-2"]
primary_region = "us-east-2"

# Cognito - update with your frontend URL after first deploy
cognito_callback_urls = ["http://localhost:5173/auth/callback"]
cognito_logout_urls   = ["http://localhost:5173"]
enable_google_auth    = false
