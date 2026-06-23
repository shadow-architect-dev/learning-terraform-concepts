variable "env_name" {
  type        = string
  description = "Environment name"
}
variable "vpc_id" {
  type        = string
  description = "VPC ID"
}
variable "isolated_subnet_ids" {
  type        = list(string)
  description = "List of isolated subnet IDs for DB/Redis"
}
variable "eks_node_security_group_id" {
  type        = string
  description = "Security Group ID of the EKS worker nodes"
}
variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN for encryption"
}
variable "db_instance_class" {
  type        = string
  description = "Aurora Serverless v2 instance class"
}
variable "db_min_capacity" {
  type        = number
  description = "Aurora Serverless v2 minimum capacity (ACU)"
}
variable "db_max_capacity" {
  type        = number
  description = "Aurora Serverless v2 maximum capacity (ACU)"
}
