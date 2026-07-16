variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "alb_arn" {
  description = "The ARN of the internal Application Load Balancer to connect via VPC Origins (only for stg/prod)"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  type        = string
  default     = ""
}
