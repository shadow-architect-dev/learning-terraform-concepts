data "aws_caller_identity" "current" {}

# KMS Key for S3 Bucket Encryption
resource "aws_kms_key" "state_kms_key" {
  description             = "KMS Key for Terraform State S3 Bucket Encryption"
  deletion_window_in_days = var.env_name == "prod" ? 30 : 7
  enable_key_rotation     = var.env_name == "prod"

  tags = {
    Name        = "${var.project_name}-state-key-${var.env_name}"
    Environment = var.env_name
  }
}

resource "aws_kms_alias" "state_kms_key_alias" {
  name          = "alias/${var.project_name}-state-key-${var.env_name}"
  target_key_id = aws_kms_key.state_kms_key.key_id
}

# S3 Bucket to store State files
resource "aws_s3_bucket" "state_bucket" {
  # learning-terraform-state-dev-<account_id>
  bucket        = "${var.project_name}-state-${var.env_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.env_name == "prod" ? false : true # dev/stgは検証用に削除可能

  # prevent_destroy を設定したい場合は以下のようにライフサイクルブロックを使用します。
  # 検証時にコメントアウトできるよう、本番（prod）環境で有効にするなどの運用を行います。
  lifecycle {
    # prevent_destroy = true # 本番運用時は有効化して意図しない削除を防止
  }

  tags = {
    Name        = "${var.project_name}-state-bucket-${var.env_name}"
    Environment = var.env_name
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "state_bucket_versioning" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-side Encryption (SSE) using KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "state_bucket_encryption" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.state_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Block Public Access to S3 State Bucket (FISC/Security Best Practice)
resource "aws_s3_bucket_public_access_block" "state_bucket_public_access" {
  bucket = aws_s3_bucket.state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "state_locks" {
  name         = "${var.project_name}-locks-${var.env_name}"
  billing_mode = "PAY_PER_REQUEST" # オンデマンド（コスト最適）
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.env_name == "prod"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state_kms_key.arn
  }

  tags = {
    Name        = "${var.project_name}-locks-${var.env_name}"
    Environment = var.env_name
  }
}
