# 1. Availability SLO
# 30日間で5xxエラーの割合を0.1%未満に抑える（可用性 99.9% ターゲット）
resource "datadog_service_level_objective" "availability_slo" {
  name        = "[${var.env_name}] EKS Web Application Availability SLO"
  type        = "metric"
  description = "Target 99.9% availability over 7, 30 and 90 days. Measures percentage of non-5xx requests."

  query {
    # 分子 (正常リクエスト数): 全リクエスト数 - 5xxエラー数
    numerator = "sum:aws.elb.request_count{kube_cluster_name:${var.cluster_name}} - sum:aws.elb.httpcode_elb_5xx{kube_cluster_name:${var.cluster_name}}"
    # 分母 (総リクエスト数): 全リクエスト数
    denominator = "sum:aws.elb.request_count{kube_cluster_name:${var.cluster_name}}"
  }

  thresholds {
    timeframe = "30d"
    target    = 99.9
    warning   = 99.95
  }

  thresholds {
    timeframe = "7d"
    target    = 99.9
    warning   = 99.95
  }

  tags = [
    "Env:${var.env_name}",
    "Cluster:${var.cluster_name}",
    "ManagedBy:Terraform"
  ]
}

# 2. Latency SLO
# 30日間で全リクエストの 90% 以上が 500ms (0.5秒) 以内に応答する目標
resource "datadog_service_level_objective" "latency_slo" {
  name        = "[${var.env_name}] EKS Web Application Latency SLO"
  type        = "metric"
  description = "Target 90% of requests responded within 500ms over 30 days."

  query {
    # 分子 (500ms未満で応答したリクエスト数): レイテンシタグが 0.5s 未満の総数
    numerator = "sum:aws.elb.request_count{kube_cluster_name:${var.cluster_name},latency:<0.5}"
    # 分母 (総リクエスト数)
    denominator = "sum:aws.elb.request_count{kube_cluster_name:${var.cluster_name}}"
  }

  thresholds {
    timeframe = "30d"
    target    = 90.0
    warning   = 95.0
  }

  tags = [
    "Env:${var.env_name}",
    "Cluster:${var.cluster_name}",
    "ManagedBy:Terraform"
  ]
}
