output "db_endpoint" {
  value       = aws_rds_cluster.this.endpoint
  description = "Aurora Cluster Writer Endpoint"
}
output "db_reader_endpoint" {
  value       = aws_rds_cluster.this.reader_endpoint
  description = "Aurora Cluster Reader Endpoint"
}
output "redis_primary_endpoint" {
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
  description = "Redis Primary Endpoint Address"
}
output "db_security_group_id" {
  value       = aws_security_group.db.id
  description = "Security Group ID of Aurora"
}
output "redis_security_group_id" {
  value       = aws_security_group.redis.id
  description = "Security Group ID of Redis"
}
