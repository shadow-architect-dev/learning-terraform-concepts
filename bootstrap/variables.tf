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

variable "project_name" {
  type        = string
  default     = "learning-terraform-concepts"
  description = "Project prefix name"
}
