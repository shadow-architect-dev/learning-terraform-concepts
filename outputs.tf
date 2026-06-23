output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}
output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS Cluster Name"
}
output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS Cluster Endpoint"
}
output "db_endpoint" {
  value       = module.database.db_endpoint
  description = "Aurora Cluster Writer Endpoint"
}
output "redis_primary_endpoint" {
  value       = module.database.redis_primary_endpoint
  description = "Redis Primary Endpoint Address"
}
output "waf_web_acl_arn" {
  value       = module.waf.web_acl_arn
  description = "WAFv2 Web ACL ARN"
}
