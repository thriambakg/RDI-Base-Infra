# IAM Role Module

Generic IAM role module. Define the assume role policy and inline/managed policies in the caller's `main.tf` for flexibility.

## Usage

```hcl
module "example_role" {
  source = "./modules/iam-role"

  role_name    = "my-service-role"
  description  = "Role for my service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  # Inline policy - define in caller for flexibility
  inline_policies = {
    my_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::my-bucket/*"
      }]
    })
  }

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]

  tags = {}
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| role_name | Name of the IAM role | `string` | required |
| description | Description of the role | `string` | `""` |
| path | IAM path for the role | `string` | `"/"` |
| assume_role_policy | Assume role policy document (JSON string) | `string` | required |
| inline_policies | Map of policy name to policy document (JSON string) | `map(string)` | `{}` |
| managed_policy_arns | List of managed policy ARNs to attach | `list(string)` | `[]` |
| tags | Tags to apply | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| role_arn | ARN of the IAM role |
| role_name | Name of the IAM role |
| role_id | ID of the IAM role |
