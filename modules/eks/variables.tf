variable "env_name" {
  type        = string
  description = "Environment name"
}
variable "vpc_id" {
  type        = string
  description = "VPC ID"
}
variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS nodes"
}
variable "kms_key_arn" {
  type        = string
  description = "KMS CMK ARN for Secrets encryption"
}
variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for worker nodes"
}
variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
}
variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
}
variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
}

variable "log_archive_account_id" {
  type        = string
  description = "AWS Account ID of the Log Archive account"
}

variable "aws_region" {
  type        = string
  description = "Target AWS Region"
}

variable "datadog_api_key" {
  type        = string
  description = "Datadog API Key"
  sensitive   = true
}

variable "datadog_app_key" {
  type        = string
  description = "Datadog APP Key"
  sensitive   = true
}
