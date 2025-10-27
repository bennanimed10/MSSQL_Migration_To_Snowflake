# DMS IAM outputs
output "dms_s3_role_arn" {
  description = "ARN of the DMS S3 access role"
  value       = aws_iam_role.dms_s3_role.arn
}

output "dms_s3_role_name" {
  description = "Name of the DMS S3 access role"
  value       = aws_iam_role.dms_s3_role.name
}

# Lambda IAM outputs
output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.name
}

# Snowflake IAM outputs
output "snowflake_role_arn" {
  description = "ARN of the Snowflake access role"
  value       = aws_iam_role.snowflake_role.arn
}

output "snowflake_role_name" {
  description = "Name of the Snowflake access role"
  value       = aws_iam_role.snowflake_role.name
}

# EventBridge IAM outputs
output "eventbridge_role_arn" {
  description = "ARN of the EventBridge role"
  value       = aws_iam_role.eventbridge_role.arn
}

output "eventbridge_role_name" {
  description = "Name of the EventBridge role"
  value       = aws_iam_role.eventbridge_role.name
}

# CloudWatch IAM outputs
output "cloudwatch_role_arn" {
  description = "ARN of the CloudWatch role"
  value       = aws_iam_role.cloudwatch_role.arn
}

output "cloudwatch_role_name" {
  description = "Name of the CloudWatch role"
  value       = aws_iam_role.cloudwatch_role.name
}

# Policy outputs
output "dms_s3_policy_arn" {
  description = "ARN of the DMS S3 access policy"
  value       = aws_iam_policy.dms_s3_policy.arn
}

output "lambda_execution_policy_arn" {
  description = "ARN of the Lambda execution policy"
  value       = aws_iam_policy.lambda_execution_policy.arn
}

output "snowflake_s3_policy_arn" {
  description = "ARN of the Snowflake S3 access policy"
  value       = aws_iam_policy.snowflake_s3_policy.arn
}

output "eventbridge_lambda_policy_arn" {
  description = "ARN of the EventBridge Lambda invoke policy"
  value       = aws_iam_policy.eventbridge_lambda_policy.arn
}

