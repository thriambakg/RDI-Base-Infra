# Generic IAM User module
# Supports managed policy attachments and inline policies

resource "aws_iam_user" "this" {
  name = var.user_name
  path = var.path

  tags = merge(var.tags, {
    Name = var.user_name
  })
}

# Attach managed policies
resource "aws_iam_user_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  user       = aws_iam_user.this.name
  policy_arn = each.value
}

# Inline policies
resource "aws_iam_user_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  user   = aws_iam_user.this.name
  policy = each.value
}
