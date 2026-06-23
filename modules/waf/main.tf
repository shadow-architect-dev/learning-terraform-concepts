resource "aws_wafv2_ip_set" "bypass" {
  name               = "waf-bypass-ips-${var.env_name}"
  description        = "IP Set for bypassing maintenance mode"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = length(var.bypass_ip_cidrs) > 0 ? var.bypass_ip_cidrs : ["192.0.2.0/32"]
  tags = {
    Name        = "waf-bypass-ips-${var.env_name}"
    Environment = var.env_name
  }
}
resource "aws_wafv2_web_acl" "this" {
  name        = "waf-web-acl-${var.env_name}"
  description = "WAFv2 Web ACL with maintenance control for ALB"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }
  custom_response_body {
    key          = "maintenance_html"
    content_type = "TEXT_HTML"
    content      = <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Maintenance | 只今メンテナンス中です</title>
    <style>
        body { text-align: center; padding: 150px; font-family: "Helvetica Neue", Arial, sans-serif; background-color: #f7f9fa; color: #333; }
        h1 { font-size: 50px; margin: 0; color: #e02f2f; }
        article { display: block; text-align: left; width: 650px; margin: 0 auto; background: #fff; padding: 40px; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
    </style>
</head>
<body>
<article>
    <h1>只今メンテナンス中です</h1>
    <div>
        <p>いつもご利用いただきありがとうございます。現在、システムメンテナンスを行っております。ご不便をおかけいたしますが、しばらく時間をおいてから再度アクセスしていただくようお願い申し上げます。</p>
        <p>&mdash; システム運用管理チーム</p>
    </div>
</article>
</body>
</html>
EOF
  }
  rule {
    name     = "MaintenanceModeRule"
    priority = 1
    action {
      dynamic "block" {
        for_each = var.maintenance_mode ? [1] : []
        content {
          custom_response {
            response_code            = 503
            custom_response_body_key = "maintenance_html"
          }
        }
      }
      dynamic "count" {
        for_each = var.maintenance_mode ? [] : [1]
        content {}
      }
    }
    statement {
      not_statement {
        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.bypass.arn
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "MaintenanceModeRuleMetric-${var.env_name}"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-web-acl-metric-${var.env_name}"
    sampled_requests_enabled   = true
  }
  tags = {
    Name        = "waf-web-acl-${var.env_name}"
    Environment = var.env_name
  }
}
