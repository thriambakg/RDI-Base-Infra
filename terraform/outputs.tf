output "account_id" {
  description = "Current AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "AWS region for this deployment"
  value       = local.region
}

output "is_primary_region" {
  description = "Whether this region is the primary (for replication sources)"
  value       = local.is_primary_region
}

output "all_regions" {
  description = "List of all deployment regions (for cross-region logic)"
  value       = var.regions
}
