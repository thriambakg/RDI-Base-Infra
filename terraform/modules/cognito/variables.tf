variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "cognito_domain" {
  type        = string
  description = "Globally unique domain prefix for Cognito hosted UI"
}

variable "callback_urls" {
  type        = list(string)
  description = "OAuth callback URLs (e.g. https://app.example.com/auth/callback)"
}

variable "logout_urls" {
  type        = list(string)
  description = "Logout redirect URLs"
}

variable "enable_google" {
  type        = bool
  default     = false
  description = "Enable Google identity provider (requires google_client_id and google_client_secret)"
}

variable "google_client_id" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Google OAuth client ID (from Google Cloud Console)"
}

variable "google_client_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Google OAuth client secret"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "user_profiles_table_name" {
  type        = string
  description = "DynamoDB user-profiles table for auth_session_epoch stamps"
}

variable "user_profiles_table_arn" {
  type        = string
  description = "ARN of the user-profiles table"
}
