# S3 Outputs
output "s3_staging_bucket_name" {
  description = "Name of the S3 staging bucket"
  value       = module.s3_staging.bucket_name
}

output "s3_staging_bucket_arn" {
  description = "ARN of the S3 staging bucket"
  value       = module.s3_staging.bucket_arn
}

output "s3_staging_bucket_domain_name" {
  description = "Domain name of the S3 staging bucket"
  value       = module.s3_staging.bucket_domain_name
}

# DMS Outputs
output "dms_replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "dms_replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "dms_source_endpoint_arn" {
  description = "ARN of the DMS source endpoint"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "dms_target_endpoint_arn" {
  description = "ARN of the DMS target endpoint"
  value       = aws_dms_endpoint.target.endpoint_arn
}

# IAM Outputs
output "dms_s3_role_arn" {
  description = "ARN of the DMS S3 access role"
  value       = module.iam.dms_s3_role_arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

output "snowflake_role_arn" {
  description = "ARN of the Snowflake access role"
  value       = module.iam.snowflake_role_arn
}

# Lambda Outputs
output "migration_orchestrator_function_name" {
  description = "Name of the migration orchestrator Lambda function"
  value       = aws_lambda_function.migration_orchestrator.function_name
}

output "migration_orchestrator_function_arn" {
  description = "ARN of the migration orchestrator Lambda function"
  value       = aws_lambda_function.migration_orchestrator.arn
}

output "data_validator_function_name" {
  description = "Name of the data validator Lambda function"
  value       = aws_lambda_function.data_validator.function_name
}

output "data_validator_function_arn" {
  description = "ARN of the data validator Lambda function"
  value       = aws_lambda_function.data_validator.arn
}

# SNS Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for notifications"
  value       = aws_sns_topic.migration_alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for notifications"
  value       = aws_sns_topic.migration_alerts.name
}

# CloudWatch Outputs
output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group names"
  value = {
    for k, v in aws_cloudwatch_log_group.lambda_logs : k => v.name
  }
}

# EventBridge Outputs
output "validation_schedule_rule_arn" {
  description = "ARN of the validation schedule EventBridge rule"
  value       = aws_cloudwatch_event_rule.validation_schedule.arn
}

# Connection Information
output "connection_info" {
  description = "Connection information for manual configuration"
  value = {
    aws_region           = var.aws_region
    environment          = var.environment
    s3_staging_bucket    = module.s3_staging.bucket_name
    dms_instance_id      = aws_dms_replication_instance.main.replication_instance_id
    sns_topic_arn        = aws_sns_topic.migration_alerts.arn
    lambda_functions = {
      orchestrator = aws_lambda_function.migration_orchestrator.function_name
      validator    = aws_lambda_function.data_validator.function_name
    }
  }
  sensitive = false
}

# Snowflake Integration Commands
output "snowflake_integration_commands" {
  description = "Commands to run in Snowflake for integration setup"
  value = [
    "-- Create storage integration",
    "CREATE STORAGE INTEGRATION ${var.project_name}_s3_integration",
    "  TYPE = EXTERNAL_STAGE",
    "  STORAGE_PROVIDER = S3",
    "  ENABLED = TRUE",
    "  STORAGE_AWS_ROLE_ARN = '${module.iam.snowflake_role_arn}'",
    "  STORAGE_ALLOWED_LOCATIONS = ('s3://${module.s3_staging.bucket_name}/')",
    "",
    "-- Grant usage on integration",
    "GRANT USAGE ON INTEGRATION ${var.project_name}_s3_integration TO ROLE ${var.snowflake_role};",
    "",
    "-- Describe integration to get external ID and IAM user",
    "DESC STORAGE INTEGRATION ${var.project_name}_s3_integration;"
  ]
}

# Next Steps
output "next_steps" {
  description = "Next steps to complete the setup"
  value = [
    "1. Update Snowflake trust policy with external ID from storage integration",
    "2. Create DMS migration tasks using the provided endpoints",
    "3. Deploy Lambda function code using the deployment script",
    "4. Configure Snowflake external stages and pipes",
    "5. Test the migration with a small dataset",
    "6. Set up monitoring dashboards in CloudWatch",
    "7. Configure additional SNS subscriptions if needed"
  ]
}

