# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# DMS Service Role for S3 Access
resource "aws_iam_role" "dms_s3_role" {
  name = "${var.project_name}-dms-s3-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-dms-s3-role-${var.environment}"
    Environment = var.environment
  }
}

# DMS S3 Access Policy
resource "aws_iam_policy" "dms_s3_policy" {
  name        = "${var.project_name}-dms-s3-policy-${var.environment}"
  description = "Policy for DMS to access S3 staging bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions"
        ]
        Resource = "arn:aws:s3:::${var.s3_staging_bucket}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "arn:aws:s3:::${var.s3_staging_bucket}/*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-dms-s3-policy-${var.environment}"
    Environment = var.environment
  }
}

# Attach policy to DMS role
resource "aws_iam_role_policy_attachment" "dms_s3_policy_attachment" {
  role       = aws_iam_role.dms_s3_role.name
  policy_arn = aws_iam_policy.dms_s3_policy.arn
}

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-execution-role-${var.environment}"
    Environment = var.environment
  }
}

# Lambda Execution Policy
resource "aws_iam_policy" "lambda_execution_policy" {
  name        = "${var.project_name}-lambda-execution-policy-${var.environment}"
  description = "Policy for Lambda functions to access required AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_staging_bucket}",
          "arn:aws:s3:::${var.s3_staging_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "dms:DescribeReplicationTasks",
          "dms:DescribeReplicationInstances",
          "dms:DescribeEndpoints",
          "dms:StartReplicationTask",
          "dms:StopReplicationTask",
          "dms:ReloadTables"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-execution-policy-${var.environment}"
    Environment = var.environment
  }
}

# Attach policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Snowflake Access Role
resource "aws_iam_role" "snowflake_role" {
  name = "${var.project_name}-snowflake-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.snowflake_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.snowflake_external_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-snowflake-role-${var.environment}"
    Environment = var.environment
  }
}

# Snowflake S3 Access Policy
resource "aws_iam_policy" "snowflake_s3_policy" {
  name        = "${var.project_name}-snowflake-s3-policy-${var.environment}"
  description = "Policy for Snowflake to access S3 staging bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = "arn:aws:s3:::${var.s3_staging_bucket}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::${var.s3_staging_bucket}/*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-snowflake-s3-policy-${var.environment}"
    Environment = var.environment
  }
}

# Attach policy to Snowflake role
resource "aws_iam_role_policy_attachment" "snowflake_s3_policy_attachment" {
  role       = aws_iam_role.snowflake_role.name
  policy_arn = aws_iam_policy.snowflake_s3_policy.arn
}

# EventBridge Role for Lambda invocation
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-eventbridge-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eventbridge-role-${var.environment}"
    Environment = var.environment
  }
}

# EventBridge Lambda Invoke Policy
resource "aws_iam_policy" "eventbridge_lambda_policy" {
  name        = "${var.project_name}-eventbridge-lambda-policy-${var.environment}"
  description = "Policy for EventBridge to invoke Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eventbridge-lambda-policy-${var.environment}"
    Environment = var.environment
  }
}

# Attach policy to EventBridge role
resource "aws_iam_role_policy_attachment" "eventbridge_lambda_policy_attachment" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_lambda_policy.arn
}

# CloudWatch Role for cross-service access
resource "aws_iam_role" "cloudwatch_role" {
  name = "${var.project_name}-cloudwatch-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cloudwatch-role-${var.environment}"
    Environment = var.environment
  }
}

