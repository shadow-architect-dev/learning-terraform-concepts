# ログ転送用 Namespace
resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

# Helmデプロイ (AWS for Fluent Bit)
resource "helm_release" "fluent_bit" {
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = "0.1.34"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-for-fluent-bit"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.fluent_bit_irsa.iam_role_arn
  }

  # 設定ファイル (CloudWatch Logs を無効化し、Kinesis Firehose の設定を投入)
  values = [
    <<-EOT
    cloudWatchLogs:
      enabled: false # 自アカウントへの送信を無効化してコストカット
    
    kinesisFirehose:
      enabled: true
      region: ${var.aws_region}
      # 既存の Firehose ストリーム名を指定
      deliveryStream: "LogArchiveDeliveryStream"
      # 送信時に Log Archive 側の受信専用ロールを引き受ける設定
      role_arn: "arn:aws:iam://${var.log_archive_account_id}:role/eks-fluent-bit-cross-account-role"
      active_key: "log"
    EOT
  ]

  depends_on = [
    kubernetes_namespace.logging
  ]
}
