# Generic IAM Role Module
# Role with assume policy; inline/managed policies defined by caller for flexibility

resource "aws_iam_role" "this" {
  name               = var.role_name
  description        = var.description
  path               = var.path
  assume_role_policy = var.assume_role_policy

  tags = merge(var.tags, {
    Name = var.role_name
  })
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.this.id
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
