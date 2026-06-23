variable "aws_region" {
  type        = string
  default     = "ap-northeast-1"
  description = "Target AWS Region"
}

variable "env_name" {
  type        = string
  default     = "dev"
  description = "Environment name (dev, stg, prod)"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.10.0.0/16"
  description = "VPC CIDR Block"
}
