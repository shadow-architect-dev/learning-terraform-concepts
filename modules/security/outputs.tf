output "kms_key_arn" {
  value       = aws_kms_key.this.arn
  description = "ARN of KMS CMK"
}
output "kms_key_id" {
  value       = aws_kms_key.this.key_id
  description = "Key ID of KMS CMK"
}
