output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID"
}
output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of Public Subnets"
}
output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "IDs of Private Subnets"
}
output "isolated_subnet_ids" {
  value       = aws_subnet.isolated[*].id
  description = "IDs of Isolated Subnets"
}
