environment    = "staging"
region         = "us-east-1"
regions        = ["us-east-1"]
primary_region = "us-east-1"

# Cognito - update with your frontend URL after first deploy
cognito_callback_urls = ["http://localhost:5173/auth/callback"]
cognito_logout_urls   = ["http://localhost:5173"]
enable_google_auth    = false
