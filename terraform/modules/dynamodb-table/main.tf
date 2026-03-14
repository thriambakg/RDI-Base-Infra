# Generic DynamoDB Table Module
# modules/dynamodb-table/main.tf

resource "aws_dynamodb_table" "this" {
  name                        = "${var.project_name}-${var.table_name}-${var.environment}"
  billing_mode                = var.billing_mode
  hash_key                    = var.hash_key
  range_key                   = var.range_key
  stream_enabled              = var.stream_enabled || length(var.replica_regions) > 0
  stream_view_type            = (var.stream_enabled || length(var.replica_regions) > 0) ? coalesce(var.stream_view_type, "NEW_AND_OLD_IMAGES") : null
  deletion_protection_enabled = var.deletion_protection_enabled

  dynamic "replica" {
    for_each = var.replica_regions
    content {
      region_name = replica.value
    }
  }

  # Capacity settings for provisioned mode
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null

  # Dynamic attributes
  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Dynamic global secondary indexes
  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = try(global_secondary_index.value.range_key, null)
      projection_type = global_secondary_index.value.projection_type
      read_capacity   = var.billing_mode == "PROVISIONED" ? try(global_secondary_index.value.read_capacity, null) : null
      write_capacity  = var.billing_mode == "PROVISIONED" ? try(global_secondary_index.value.write_capacity, null) : null
    }
  }

  # Server-side encryption (AWS-owned key when kms_key_arn is null)
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.point_in_time_recovery_enabled
  }

  # TTL configuration
  ttl {
    attribute_name = var.ttl_attribute_name
    enabled        = var.ttl_enabled
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.table_name}-${var.environment}"
    Type    = var.table_type
    Purpose = var.table_purpose
  })

  lifecycle {
    prevent_destroy = false
  }
}
