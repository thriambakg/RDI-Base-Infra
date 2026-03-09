output "table_name" {
  value = aws_dynamodb_table.user_profiles.name
}

output "table_arn" {
  value = aws_dynamodb_table.user_profiles.arn
}
