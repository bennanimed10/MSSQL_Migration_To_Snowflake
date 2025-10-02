# General Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "sql-snowflake-migration"
}

# Networking Configuration
variable "create_vpc" {
  description = "Whether to create VPC resources"
  type        = bool
  default     = false
}

variable "subnet_ids" {
  description = "List of subnet IDs for DMS replication instance"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for DMS replication instance"
  type        = list(string)
  default     = []
}

# DMS Configuration
variable "dms_instance_class" {
  description = "DMS replication instance class"
  type        = string
  default     = "dms.t3.micro"
}

variable "dms_allocated_storage" {
  description = "Allocated storage for DMS replication instance (GB)"
  type        = number
  default     = 100
}

variable "dms_engine_version" {
  description = "DMS engine version"
  type        = string
  default     = "3.5.2"
}

variable "dms_multi_az" {
  description = "Enable Multi-AZ for DMS replication instance"
  type        = bool
  default     = false
}

variable "dms_availability_zone" {
  description = "Availability zone for DMS replication instance"
  type        = string
  default     = null
}

# SQL Server Configuration
variable "sql_server_host" {
  description = "SQL Server hostname or IP address"
  type        = string
}

variable "sql_server_port" {
  description = "SQL Server port"
  type        = number
  default     = 1433
}

variable "sql_server_database" {
  description = "SQL Server database name"
  type        = string
}

variable "sql_server_username" {
  description = "SQL Server username"
  type        = string
}

variable "sql_server_password" {
  description = "SQL Server password"
  type        = string
  sensitive   = true
}

# Snowflake Configuration
variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
}

variable "snowflake_user" {
  description = "Snowflake username"
  type        = string
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
}

variable "snowflake_role" {
  description = "Snowflake role"
  type        = string
  default     = "SYSADMIN"
}

variable "snowflake_warehouse" {
  description = "Snowflake warehouse name"
  type        = string
  default     = "COMPUTE_WH"
}

variable "snowflake_database" {
  description = "Snowflake database name"
  type        = string
  default     = "MIGRATION_DB"
}

# S3 Configuration
variable "s3_full_load_retention_days" {
  description = "Number of days to retain full load files in S3"
  type        = number
  default     = 30
}

variable "s3_cdc_retention_days" {
  description = "Number of days to retain CDC files in S3"
  type        = number
  default     = 7
}

# Notification Configuration
variable "notification_emails" {
  description = "List of email addresses for notifications"
  type        = list(string)
  default     = []
}

# CloudWatch Configuration
variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# Scheduling Configuration
variable "validation_schedule" {
  description = "Schedule expression for data validation (cron or rate)"
  type        = string
  default     = "rate(6 hours)"
}

# Lambda Configuration
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

