variable "env_name" {
  type        = string
  description = "Environment name"
}
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}
variable "aws_region" {
  type        = string
  default     = "ap-northeast-1"
  description = "AWS Region"
}
