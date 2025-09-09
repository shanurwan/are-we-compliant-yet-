output "region" {
  description = "Deployment region (enforced by policy for data residency)"
  value       = var.region
}

output "bucket_name" {
  description = "Primary S3 bucket for demo data (versioned + SSE)"
  value       = aws_s3_bucket.data.bucket
}

output "bucket_arn" {
  description = "ARN of the data bucket"
  value       = aws_s3_bucket.data.arn
}

output "log_group_name" {
  description = "CloudWatch log group for baseline audit logs"
  value       = aws_cloudwatch_log_group.app.name
}

output "db_identifier" {
  description = "RDS instance identifier (encrypted, non-public)"
  value       = aws_db_instance.db.id
}

output "db_endpoint" {
  description = "RDS writer endpoint (no creds included)"
  value       = aws_db_instance.db.address
}
