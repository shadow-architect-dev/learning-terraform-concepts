output "web_acl_arn" {
  value       = aws_wafv2_web_acl.this.arn
  description = "WAFv2 Web ACL ARN"
}
output "web_acl_name" {
  value       = aws_wafv2_web_acl.this.name
  description = "WAFv2 Web ACL Name"
}
