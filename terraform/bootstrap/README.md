# Terraform Bootstrap

Creates the S3 bucket and DynamoDB table required for Terraform remote state and state locking. **Run this once** before using the main pipeline.

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5.0

## One-Time Setup

### 1. Run Bootstrap

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### 2. Update Backend Configs

Get your AWS account ID:

```bash
aws sts get-caller-identity --query Account --output text
```

Replace `ACCOUNT_ID` in both backend config files:

- `../backend-configs/staging.tfbackend`
- `../backend-configs/production.tfbackend`

Or use the bootstrap output:

```bash
terraform output backend_config
```

### 3. Verify Main Terraform

```bash
cd ..
terraform init -backend-config=backend-configs/staging.tfbackend
terraform validate
```

## Resources Created

| Resource | Name Pattern | Purpose |
|----------|--------------|---------|
| S3 Bucket | `rdi-terraform-state-{account_id}` | Stores Terraform state files |
| DynamoDB Table | `rdi-terraform-locks` | State locking to prevent concurrent applies |

The IAM user for GitHub Actions (`rdi-{env}-github-actions`) is created by the **main Terraform project**. After the first main apply, create access keys for that user and add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to GitHub Actions secrets.

## Pipeline Integration

The reusable pipeline in `RDI-Pipelines` expects:

- `terraform/` directory at repo root
- `backend-configs/{environment}.tfbackend` per environment
- `environments/{environment}.auto.tfvars` per environment

After bootstrap, the main pipeline will init with the correct backend automatically.
