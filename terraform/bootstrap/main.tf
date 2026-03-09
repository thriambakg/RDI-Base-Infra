# Bootstrap Terraform - Creates S3 bucket and DynamoDB table for remote state
# Run this ONCE with local backend before using the main terraform pipeline
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  name_prefix = var.name_prefix
  bucket_name = "${local.name_prefix}-terraform-state-${local.account_id}"
  table_name  = "${local.name_prefix}-terraform-locks"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# trivy:ignore:AVD-AWS-0132
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = local.table_name
    Environment = "bootstrap"
    ManagedBy   = "terraform"
  }
}

# IAM user for GitHub Actions - generate access keys after apply
resource "aws_iam_user" "github_actions" {
  name = "${local.name_prefix}-github-actions"
  path = "/"

  tags = {
    Name      = "${local.name_prefix}-github-actions"
    Purpose   = "Terraform CI/CD via GitHub Actions"
    ManagedBy = "terraform"
  }
}

# PowerUserAccess: full access to AWS services except IAM/Organizations
# Sufficient for Terraform to manage EC2, Lambda, S3, DynamoDB, etc.
resource "aws_iam_user_policy_attachment" "github_actions_power_user" {
  user       = aws_iam_user.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Allow IAM read + limited write for Terraform-managed IAM resources
resource "aws_iam_user_policy" "github_actions_iam" {
  name = "${local.name_prefix}-github-actions-iam"
  user = aws_iam_user.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowIAMForTerraform"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:PassRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:GetUser",
          "iam:ListAttachedUserPolicies",
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:TagPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}
