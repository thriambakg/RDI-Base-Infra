output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "lock_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "region" {
  description = "AWS region where resources were created"
  value       = local.region
}

output "backend_config" {
  description = "Backend configuration for use in main terraform"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    region         = local.region
    encrypt        = true
  }
}

output "github_actions_user_arn" {
  description = "ARN of the IAM user for GitHub Actions"
  value       = aws_iam_user.github_actions.arn
}

output "github_actions_user_name" {
  description = "Name of the IAM user for GitHub Actions - create access keys in console for AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
  value       = aws_iam_user.github_actions.name
}
