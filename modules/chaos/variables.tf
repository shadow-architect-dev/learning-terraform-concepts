variable "env_name" {
  type        = string
  description = "Environment name"
}
variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS nodes reside"
}
variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs of private subnets for EKS nodes"
}
