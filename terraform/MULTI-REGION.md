# Multi-Region Deployment

## Overview

Resources are deployed per region with isolated state. Each region runs in parallel in the pipeline.

## Structure

```
terraform/
├── backend-configs/
│   ├── staging-us-east-2.tfbackend
│   ├── production-eu-central-1.tfbackend
│   ├── production-eu-west-2.tfbackend
│   └── production-eu-west-3.tfbackend
├── environments/
│   ├── staging.auto.tfvars      # Shared: environment, regions list, primary_region
│   ├── production.auto.tfvars
│   ├── staging/
│   │   └── us-east-2.tfvars     # Staging: us-east-2 only
│   └── production/
│       ├── eu-central-1.tfvars
│       ├── eu-west-2.tfvars
│       └── eu-west-3.tfvars
```

## Key Variables

| Variable | Purpose |
|----------|---------|
| `region` | Target region for this deployment (passed per run) |
| `regions` | List of all regions (for cross-region logic) |
| `primary_region` | Source for replication (S3 CRR, DynamoDB global tables) |
| `local.is_primary_region` | `true` when `region == primary_region` |

## Inherited Replication

Use `local.is_primary_region` to create replication sources only in the primary region:

- **S3**: Create bucket in primary; add Cross-Region Replication (CRR) to secondary regions
- **DynamoDB**: Use global tables—create in primary, add replicas in `var.regions`
- **RDS**: Primary in primary region; read replicas in secondaries
- **Compute** (Lambda, EC2): Create in each region—no replication

Example:

```hcl
# Only create S3 bucket in primary; use CRR for secondaries
resource "aws_s3_bucket" "data" {
  count  = local.is_primary_region ? 1 : 0
  bucket = "${var.environment}-data-${var.region}"
}
```

## Adding a Region

1. Add region to `regions` in `environments/{env}.auto.tfvars`
2. Create `environments/{env}/{region}.tfvars` with `region = "{region}"`
3. Create `backend-configs/{env}-{region}.tfbackend` (key: `base-infra/{env}/{region}/terraform.tfstate`)
4. Add `{region}` to the matrix in `.github/workflows/deploy-base-infrastructure.yml`

## Pipeline

The deploy workflow runs one job per region in parallel (`fail-fast: false`). Each job uses the reusable pipeline with `region` input.
