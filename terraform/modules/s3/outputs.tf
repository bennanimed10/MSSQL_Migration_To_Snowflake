# S3 bucket outputs
output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.staging.id
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.staging.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.staging.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.staging.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.staging.bucket_regional_domain_name
}

output "bucket_hosted_zone_id" {
  description = "Hosted zone ID of the S3 bucket"
  value       = aws_s3_bucket.staging.hosted_zone_id
}

output "bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.staging.region
}

output "bucket_website_endpoint" {
  description = "Website endpoint of the S3 bucket"
  value       = aws_s3_bucket.staging.website_endpoint
}

output "bucket_website_domain" {
  description = "Website domain of the S3 bucket"
  value       = aws_s3_bucket.staging.website_domain
}

