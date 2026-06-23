output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "EKS Cluster Name"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "EKS Cluster Endpoint"
}

output "cluster_security_group_id" {
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description = "EKS Cluster Security Group ID"
}
