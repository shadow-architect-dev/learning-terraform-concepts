output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution"
  value       = length(aws_cloudfront_distribution.this) > 0 ? aws_cloudfront_distribution.this[0].domain_name : ""
}
