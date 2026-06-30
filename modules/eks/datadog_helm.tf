# Datadog Agent デプロイ用の Helm リリース
resource "helm_release" "datadog_agent" {
  name             = "datadog-agent"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  namespace        = "monitoring"
  create_namespace = true
  version          = "3.84.0"

  set {
    name  = "datadog.apiKey"
    value = var.datadog_api_key
  }

  set {
    name  = "datadog.appKey"
    value = var.datadog_app_key
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  # Datadog Cluster Agent の有効化 (API負荷軽減とクラスタ内メトリクス統合)
  set {
    name  = "datadog.clusterAgent.enabled"
    value = "true"
  }

  # コンテナログ収集の有効化
  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  # APM (アプリケーションパフォーマンス監視) のポート開放
  set {
    name  = "datadog.apm.portEnabled"
    value = "true"
  }

  # システムプロセス収集の有効化
  set {
    name  = "datadog.processAgent.processCollection"
    value = "true"
  }

  depends_on = [
    aws_eks_node_group.this
  ]
}
