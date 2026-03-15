environment    = "production"
region         = "eu-central-1"
regions        = ["eu-central-1", "eu-west-2", "eu-west-3"]
primary_region = "eu-central-1"

# DynamoDB connection pool: replicas for cross-region read locality
dynamodb_replica_regions = ["eu-west-2", "eu-west-3"]

# Flight logs S3: replicate to secondary region for multi-region access
flight_logs_replica_region = "eu-west-2"

# Cognito - update with your CloudFront URL; localhost for local dev
cognito_callback_urls = ["http://localhost:5173/auth/callback", "https://localhost/auth/callback", "https://your-domain.com/auth/callback"]
cognito_logout_urls   = ["http://localhost:5173", "https://localhost", "https://your-domain.com"]
enable_google_auth    = false
