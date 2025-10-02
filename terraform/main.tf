terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "SQL-Server-Snowflake-Migration"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Module for staging bucket
module "s3_staging" {
  source = "./modules/s3"
  
  bucket_name = "${var.project_name}-staging-${var.environment}-${random_id.bucket_suffix.hex}"
  environment = var.environment
  
  lifecycle_rules = [
    {
      id     = "full_load_cleanup"
      status = "Enabled"
      filter = {
        prefix = "full-load/"
      }
      expiration = {
        days = var.s3_full_load_retention_days
      }
    },
    {
      id     = "cdc_cleanup"
      status = "Enabled"
      filter = {
        prefix = "cdc/"
      }
      expiration = {
        days = var.s3_cdc_retention_days
      }
    }
  ]
}

# IAM Module for roles and policies
module "iam" {
  source = "./modules/iam"
  
  project_name        = var.project_name
  environment         = var.environment
  s3_staging_bucket   = module.s3_staging.bucket_name
  snowflake_account   = var.snowflake_account
  snowflake_role      = var.snowflake_role
}

# Random ID for unique resource naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# DMS Subnet Group
resource "aws_dms_subnet_group" "main" {
  count = var.create_vpc ? 1 : 0
  
  subnet_group_id = "${var.project_name}-dms-subnet-group-${var.environment}"
  subnet_ids      = var.subnet_ids
  
  tags = {
    Name = "${var.project_name}-dms-subnet-group-${var.environment}"
  }
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "main" {
  allocated_storage            = var.dms_allocated_storage
  apply_immediately           = true
  auto_minor_version_upgrade  = true
  availability_zone           = var.dms_availability_zone
  engine_version              = var.dms_engine_version
  multi_az                    = var.dms_multi_az
  publicly_accessible         = false
  replication_instance_class  = var.dms_instance_class
  replication_instance_id     = "${var.project_name}-replication-instance-${var.environment}"
  replication_subnet_group_id = var.create_vpc ? aws_dms_subnet_group.main[0].subnet_group_id : null
  vpc_security_group_ids      = var.security_group_ids
  
  tags = {
    Name = "${var.project_name}-replication-instance-${var.environment}"
  }
  
  depends_on = [
    aws_dms_subnet_group.main
  ]
}

# DMS Source Endpoint (SQL Server)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.project_name}-source-${var.environment}"
  endpoint_type = "source"
  engine_name   = "sqlserver"
  
  server_name = var.sql_server_host
  port        = var.sql_server_port
  database_name = var.sql_server_database
  username    = var.sql_server_username
  password    = var.sql_server_password
  
  ssl_mode = "require"
  
  tags = {
    Name = "${var.project_name}-source-endpoint-${var.environment}"
  }
}

# DMS Target Endpoint (S3)
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${var.project_name}-target-${var.environment}"
  endpoint_type = "target"
  engine_name   = "s3"
  
  s3_settings {
    bucket_name             = module.s3_staging.bucket_name
    bucket_folder           = "dms-output"
    compression_type        = "GZIP"
    data_format             = "parquet"
    date_partition_enabled  = true
    date_partition_sequence = "YYYYMMDD"
    parquet_timestamp_in_millisecond = true
    parquet_version         = "parquet-2-0"
    service_access_role_arn = module.iam.dms_s3_role_arn
  }
  
  tags = {
    Name = "${var.project_name}-target-endpoint-${var.environment}"
  }
}

# SNS Topic for notifications
resource "aws_sns_topic" "migration_alerts" {
  name = "${var.project_name}-migration-alerts-${var.environment}"
  
  tags = {
    Name = "${var.project_name}-migration-alerts-${var.environment}"
  }
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  count = length(var.notification_emails) > 0 ? length(var.notification_emails) : 0
  
  topic_arn = aws_sns_topic.migration_alerts.arn
  protocol  = "email"
  endpoint  = var.notification_emails[count.index]
}

# CloudWatch Log Group for Lambda functions
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = toset(["migration-orchestrator", "data-validator", "notification-handler"])
  
  name              = "/aws/lambda/${var.project_name}-${each.key}-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days
  
  tags = {
    Name = "${var.project_name}-${each.key}-logs-${var.environment}"
  }
}

# Lambda function for migration orchestrator
resource "aws_lambda_function" "migration_orchestrator" {
  filename         = "lambda/migration-orchestrator.zip"
  function_name    = "${var.project_name}-migration-orchestrator-${var.environment}"
  role            = module.iam.lambda_execution_role_arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300
  memory_size     = 512
  
  environment {
    variables = {
      ENVIRONMENT           = var.environment
      S3_STAGING_BUCKET    = module.s3_staging.bucket_name
      SNS_TOPIC_ARN        = aws_sns_topic.migration_alerts.arn
      SNOWFLAKE_ACCOUNT    = var.snowflake_account
      SNOWFLAKE_USER       = var.snowflake_user
      SNOWFLAKE_ROLE       = var.snowflake_role
      SNOWFLAKE_WAREHOUSE  = var.snowflake_warehouse
      SNOWFLAKE_DATABASE   = var.snowflake_database
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]
  
  tags = {
    Name = "${var.project_name}-migration-orchestrator-${var.environment}"
  }
}

# Lambda function for data validator
resource "aws_lambda_function" "data_validator" {
  filename         = "lambda/data-validator.zip"
  function_name    = "${var.project_name}-data-validator-${var.environment}"
  role            = module.iam.lambda_execution_role_arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 900
  memory_size     = 1024
  
  environment {
    variables = {
      ENVIRONMENT           = var.environment
      S3_STAGING_BUCKET    = module.s3_staging.bucket_name
      SNS_TOPIC_ARN        = aws_sns_topic.migration_alerts.arn
      SQL_SERVER_HOST      = var.sql_server_host
      SQL_SERVER_DATABASE  = var.sql_server_database
      SNOWFLAKE_ACCOUNT    = var.snowflake_account
      SNOWFLAKE_DATABASE   = var.snowflake_database
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.lambda_logs
  ]
  
  tags = {
    Name = "${var.project_name}-data-validator-${var.environment}"
  }
}

# S3 Event Notification to trigger Lambda
resource "aws_s3_bucket_notification" "staging_bucket_notification" {
  bucket = module.s3_staging.bucket_id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.migration_orchestrator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "dms-output/"
    filter_suffix       = ".parquet"
  }
  
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Lambda permission for S3 to invoke function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.migration_orchestrator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3_staging.bucket_arn
}

# EventBridge rule for scheduled validation
resource "aws_cloudwatch_event_rule" "validation_schedule" {
  name                = "${var.project_name}-validation-schedule-${var.environment}"
  description         = "Trigger data validation on schedule"
  schedule_expression = var.validation_schedule
  
  tags = {
    Name = "${var.project_name}-validation-schedule-${var.environment}"
  }
}

# EventBridge target for validation Lambda
resource "aws_cloudwatch_event_target" "validation_target" {
  rule      = aws_cloudwatch_event_rule.validation_schedule.name
  target_id = "ValidationLambdaTarget"
  arn       = aws_lambda_function.data_validator.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_validator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.validation_schedule.arn
}

