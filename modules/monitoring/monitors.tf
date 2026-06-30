# 1. EKS Node CPU Utilization Monitor
resource "datadog_monitor" "eks_node_cpu" {
  name    = "[${var.env_name}] EKS Node CPU Utilization High"
  type    = "metric alert"
  message = "EKS node CPU utilization has exceeded 80% on {{host.name}} (Cluster: ${var.cluster_name}). Notify: @slack-sre-alerts"

  # system.cpu.idleが20未満 = CPU使用率80%超
  query = "avg(last_5m):avg:system.cpu.idle{kube_cluster_name:${var.cluster_name}} by {host} < 20"

  monitor_thresholds {
    critical = 20
    warning  = 30 # CPU使用率70%超相当
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = [
    "Env:${var.env_name}",
    "Cluster:${var.cluster_name}",
    "ManagedBy:Terraform"
  ]
}

# 2. ALB 5xx Error Rate Monitor
resource "datadog_monitor" "alb_5xx_errors" {
  name    = "[${var.env_name}] ALB 5xx Error Rate High"
  type    = "metric alert"
  message = "ALB 5xx error rate is high on cluster ${var.cluster_name}. Over 1% of requests are failing. Notify: @slack-sre-alerts"

  # 全リクエストに占める5xxエラーの割合が1%を超えたらアラート
  query = "sum(last_5m):sum:aws.elb.httpcode_elb_5xx{kube_cluster_name:${var.cluster_name}} / sum:aws.elb.request_count{kube_cluster_name:${var.cluster_name}} * 100 > 1"

  monitor_thresholds {
    critical = 1.0
    warning  = 0.5
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = [
    "Env:${var.env_name}",
    "Cluster:${var.cluster_name}",
    "ManagedBy:Terraform"
  ]
}

# 3. ALB Latency Monitor
resource "datadog_monitor" "alb_latency" {
  name    = "[${var.env_name}] ALB Latency High"
  type    = "metric alert"
  message = "ALB average latency has exceeded 500ms on cluster ${var.cluster_name}.\n\nRunbook: https://github.com/shadow-architect-dev/learning-terraform-concepts/blob/main/docs/runbooks/alb_latency_high.md\n\nNotify: @slack-sre-alerts"

  # 平均レイテンシが0.5秒(500ms)を超えたらアラート
  query = "avg(last_5m):avg:aws.elb.latency{kube_cluster_name:${var.cluster_name}} > 0.5"

  monitor_thresholds {
    critical = 0.5
    warning  = 0.3
  }

  notify_no_data    = false
  renotify_interval = 60

  tags = [
    "Env:${var.env_name}",
    "Cluster:${var.cluster_name}",
    "ManagedBy:Terraform"
  ]
}
