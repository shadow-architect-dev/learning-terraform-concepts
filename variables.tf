variable "aws_region" {
  type        = string
  description = "Target AWS Region"
  default     = "ap-northeast-1"
}
variable "env_name" {
  type        = string
  description = "Environment name (dev, stg, prod)"
}
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR Block"
  default     = null
}
variable "ipam_pool_id" {
  type        = string
  description = "AWS VPC IPAM pool ID shared by platform"
}
variable "transit_gateway_id" {
  type        = string
  description = "AWS Transit Gateway ID shared by platform"
}
# Database variables
variable "db_instance_class" {
  type        = string
  description = "Aurora Serverless v2 instance size"
  default     = "db.serverless"
}
variable "db_min_capacity" {
  type        = number
  description = "Aurora Serverless v2 min ACU"
  default     = 0.5
}
variable "db_max_capacity" {
  type        = number
  description = "Aurora Serverless v2 max ACU"
  default     = 2.0
}
# EKS variables
variable "eks_node_instance_type" {
  type        = string
  description = "EC2 instance type for EKS worker nodes"
  default     = "t3.medium"
}
variable "eks_node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}
variable "eks_node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 5
}
variable "eks_node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}
# WAF variables
variable "maintenance_mode" {
  type        = bool
  default     = false
  description = "Enable maintenance mode (block traffic with 503)"
}
variable "waf_bypass_ip_cidrs" {
  type        = list(string)
  default     = []
  description = "IP CIDR list allowed to bypass maintenance mode"
}

variable "log_archive_account_id" {
  type        = string
  description = "AWS Account ID of the Log Archive account"
}

variable "datadog_api_key" {
  type        = string
  description = "Datadog API Key"
  sensitive   = true
  default     = "dummy_api_key"
}

variable "datadog_app_key" {
  type        = string
  description = "Datadog APP Key"
  sensitive   = true
  default     = "dummy_app_key"
}
