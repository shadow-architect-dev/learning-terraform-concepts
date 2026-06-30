variable "env_name" {
  type        = string
  description = "Environment name"
}
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = null
}
variable "ipam_pool_id" {
  type        = string
  description = "AWS VPC IPAM Pool ID"
  default     = null
}
variable "transit_gateway_id" {
  type        = string
  description = "AWS Transit Gateway ID"
}
variable "aws_region" {
  type        = string
  default     = "ap-northeast-1"
  description = "AWS Region"
}
