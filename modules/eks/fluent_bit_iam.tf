# 1. Log Archive アカウントの受信用ロールを引き受けるためのポリシー
resource "aws_iam_policy" "fluent_bit_assume_role" {
  name        = "eks-cluster-${var.env_name}-fluent-bit-assume-policy"
  description = "Allows EKS Fluent Bit to assume Log Archive logging role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        # Log Archive 側で作成された受信専用ロールのARNを指定
        Resource = "arn:aws:iam://${var.log_archive_account_id}:role/eks-fluent-bit-cross-account-role"
      }
    ]
  })
}

# 2. Fluent Bit 用の IRSA ロール
# Log Archive 側の信頼関係ポリシーで定義されているロール名（eks-cluster-XXX-fluent-bit-irsa）と完全一致させます
module "fluent_bit_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "eks-cluster-${var.env_name}-fluent-bit-irsa"

  oidc_providers = {
    main = {
      provider_arn               = aws_iam_openid_connect_provider.this.arn
      namespace_service_accounts = ["logging:aws-for-fluent-bit"]
    }
  }
}

# 作成したIRSAロールに AssumeRole ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "fluent_bit_assume_attach" {
  role       = module.fluent_bit_irsa.iam_role_name
  policy_arn = aws_iam_policy.fluent_bit_assume_role.arn
}
