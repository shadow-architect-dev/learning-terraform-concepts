resource "aws_cloudfront_vpc_origin" "this" {
  count = var.env_name != "dev" && var.alb_arn != "" ? 1 : 0

  vpc_origin_endpoint_config {
    name                   = "cf-vpc-origin-${var.env_name}"
    arn                    = var.alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  count = var.env_name != "dev" && var.alb_arn != "" ? 1 : 0

  enabled         = true
  is_ipv6_enabled = true
  comment         = "CloudFront Distribution using VPC Origins for ${var.env_name}"
  price_class     = "PriceClass_100"

  origin {
    domain_name = var.alb_dns_name != "" ? var.alb_dns_name : "dummy.local"
    origin_id   = "EKS-ALB-${var.env_name}"

    vpc_origin_config {
      vpc_origin_id = aws_cloudfront_vpc_origin.this[0].id
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "EKS-ALB-${var.env_name}"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Authorization"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "cf-distribution-${var.env_name}"
    Environment = var.env_name
  }
}
