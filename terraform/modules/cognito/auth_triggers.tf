# PostAuthentication stamp for single-login enforcement (see src/cognito-auth-triggers).

data "archive_file" "cognito_auth_triggers" {
  type        = "zip"
  source_dir  = "${path.module}/../../../src/cognito-auth-triggers"
  output_path = "${path.module}/../../../src/cognito-auth-triggers/deployment.zip"
  excludes    = ["deployment.zip", "__pycache__", "*.pyc"]
}

resource "aws_iam_role" "cognito_auth_triggers" {
  name = "${var.name_prefix}-cognito-auth-triggers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cognito_auth_triggers_logs" {
  role       = aws_iam_role.cognito_auth_triggers.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "cognito_auth_triggers_dynamo" {
  name = "${var.name_prefix}-cognito-auth-triggers-dynamo"
  role = aws_iam_role.cognito_auth_triggers.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem", "dynamodb:GetItem"]
      Resource = [var.user_profiles_table_arn]
    }]
  })
}

resource "aws_lambda_function" "cognito_auth_triggers" {
  function_name = "${var.name_prefix}-cognito-auth-triggers"
  description   = "Cognito PostAuthentication: stamp auth_session_epoch for single-login"
  role          = aws_iam_role.cognito_auth_triggers.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 10
  memory_size   = 128

  filename         = data.archive_file.cognito_auth_triggers.output_path
  source_code_hash = data.archive_file.cognito_auth_triggers.output_base64sha256

  environment {
    variables = {
      USER_PROFILES_TABLE = var.user_profiles_table_name
    }
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cognito_auth_triggers_logs]
}

resource "aws_lambda_permission" "cognito_post_auth" {
  statement_id   = "AllowCognitoPostAuth"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.cognito_auth_triggers.function_name
  principal      = "cognito-idp.amazonaws.com"
  source_arn     = aws_cognito_user_pool.main.arn
  source_account = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}
