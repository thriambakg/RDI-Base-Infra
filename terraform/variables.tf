variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "region" {
  description = "AWS region for this deployment (each region gets its own state and resources)"
  type        = string
  default     = "eu-central-1"
}

variable "regions" {
  description = "List of all regions to deploy to (for resources that need cross-region awareness)"
  type        = list(string)
  default     = []
}

variable "primary_region" {
  description = "Primary region for replication sources (S3, DynamoDB global tables, etc.)"
  type        = string
  default     = ""
}

variable "dynamodb_replica_regions" {
  description = "Regions for DynamoDB global table replicas (e.g. eu-west-2, eu-west-3). Empty for staging."
  type        = list(string)
  default     = []
}

variable "cognito_callback_urls" {
  description = "Cognito OAuth callback URLs"
  type        = list(string)
  default     = []
}

variable "cognito_logout_urls" {
  description = "Cognito logout redirect URLs"
  type        = list(string)
  default     = []
}

variable "enable_google_auth" {
  description = "Enable Google identity provider"
  type        = bool
  default     = false
}

variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "flight_logs_replica_region" {
  description = "Region for flight logs bucket replica (enables cross-region replication). Set for prod with 2+ regions."
  type        = string
  default     = ""
}

variable "frontend_custom_domain" {
  description = "Custom domain for the frontend (e.g. rdistaging.com). Route53 zone must exist (e.g. created by RDI-1.0 domain module). CloudFront will be given this alias and an ACM cert; apex and www A records point to CloudFront."
  type        = string
  default     = ""
}
