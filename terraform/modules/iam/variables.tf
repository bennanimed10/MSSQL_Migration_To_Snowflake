# Required variables
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "s3_staging_bucket" {
  description = "Name of the S3 staging bucket"
  type        = string
}

# Snowflake configuration
variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
}

variable "snowflake_role" {
  description = "Snowflake role name"
  type        = string
  default     = "SYSADMIN"
}

variable "snowflake_account_id" {
  description = "Snowflake AWS account ID for cross-account access"
  type        = string
  default     = "123456789012" # This will be updated after Snowflake integration setup
}

variable "snowflake_external_id" {
  description = "External ID for Snowflake cross-account access"
  type        = string
  default     = "placeholder" # This will be updated after Snowflake integration setup
}

# Optional variables
variable "additional_tags" {
  description = "Additional tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}

variable "lambda_function_names" {
  description = "List of Lambda function names that need permissions"
  type        = list(string)
  default     = []
}

variable "enable_cross_account_access" {
  description = "Enable cross-account access for external services"
  type        = bool
  default     = false
}

variable "trusted_account_ids" {
  description = "List of AWS account IDs that can assume roles"
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption/decryption permissions"
  type        = list(string)
  default     = []
}

