data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}
resource "aws_kms_key" "this" {
  description             = "KMS CMK for EKS and resource encryption (${var.env_name})"
  deletion_window_in_days = var.env_name == "prod" ? 30 : 7
  enable_key_rotation     = var.env_name == "prod"
  policy                  = data.aws_iam_policy_document.kms_policy.json
  tags = {
    Name        = "kms-key-${var.env_name}"
    Environment = var.env_name
  }
}
resource "aws_kms_alias" "this" {
  name          = "alias/kms-key-${var.env_name}"
  target_key_id = aws_kms_key.this.key_id
}
