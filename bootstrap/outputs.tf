output "state_bucket_name" {
  value       = aws_s3_bucket.state_bucket.id
  description = "Name of the S3 bucket to use in backend config"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.state_locks.id
  description = "Name of the DynamoDB table to use in backend config"
}

output "kms_key_arn" {
  value       = aws_kms_key.state_kms_key.arn
  description = "ARN of the KMS key used for S3 and DynamoDB encryption"
}
