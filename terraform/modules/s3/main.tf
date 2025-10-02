# S3 bucket for staging data
resource "aws_s3_bucket" "staging" {
  bucket = var.bucket_name
  
  tags = merge(
    {
      Name        = var.bucket_name
      Environment = var.environment
      Purpose     = "Data Migration Staging"
    },
    var.additional_tags
  )
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "staging" {
  bucket = aws_s3_bucket.staging.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0
  
  bucket = aws_s3_bucket.staging.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      dynamic "filter" {
        for_each = rule.value.filter != null ? [rule.value.filter] : []
        content {
          prefix = lookup(filter.value, "prefix", null)
          
          dynamic "tag" {
            for_each = lookup(filter.value, "tags", {})
            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []
        content {
          days = expiration.value.days
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? [rule.value.noncurrent_version_expiration] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value.days
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions != null ? rule.value.transitions : []
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }
}

# S3 bucket notification configuration (placeholder - will be configured in main.tf)
resource "aws_s3_bucket_notification" "staging" {
  bucket = aws_s3_bucket.staging.id
  # Notifications will be configured in the main terraform configuration
}

# S3 bucket CORS configuration for web access if needed
resource "aws_s3_bucket_cors_configuration" "staging" {
  count = var.enable_cors ? 1 : 0
  
  bucket = aws_s3_bucket.staging.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 bucket logging configuration
resource "aws_s3_bucket_logging" "staging" {
  count = var.access_logging_bucket != null ? 1 : 0
  
  bucket = aws_s3_bucket.staging.id

  target_bucket = var.access_logging_bucket
  target_prefix = "access-logs/${var.bucket_name}/"
}

# S3 bucket intelligent tiering configuration
resource "aws_s3_bucket_intelligent_tiering_configuration" "staging" {
  count = var.enable_intelligent_tiering ? 1 : 0
  
  bucket = aws_s3_bucket.staging.id
  name   = "EntireBucket"

  status = "Enabled"

  dynamic "filter" {
    for_each = var.intelligent_tiering_filter != null ? [var.intelligent_tiering_filter] : []
    content {
      prefix = filter.value.prefix
      
      dynamic "tags" {
        for_each = lookup(filter.value, "tags", {})
        content {
          key   = tags.key
          value = tags.value
        }
      }
    }
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

# Create folder structure in S3
resource "aws_s3_object" "folder_structure" {
  for_each = toset([
    "full-load/",
    "cdc/",
    "dms-output/",
    "logs/",
    "archive/"
  ])
  
  bucket = aws_s3_bucket.staging.id
  key    = each.value
  
  tags = {
    Name        = "Folder: ${each.value}"
    Environment = var.environment
  }
}

