variable "name_prefix" {
  description = "Prefix for resource names (e.g. rdi, project-name)"
  type        = string
  default     = "rdi"
}

variable "region" {
  description = "AWS region for bootstrap resources (S3 state bucket, DynamoDB). Must match where the state bucket lives (eu-central-1)."
  type        = string
  default     = "eu-central-1"
}
