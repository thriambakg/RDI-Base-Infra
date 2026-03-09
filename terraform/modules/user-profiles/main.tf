# User profiles table - user_id (UUID) as partition key
# Stores pointers to user data; deeper data in S3/DynamoDB (flight logs etc)

resource "aws_dynamodb_table" "user_profiles" {
  name         = "${var.name_prefix}-user-profiles"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-user-profiles"
  })
}
