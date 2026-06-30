variable "env_name" {
  type        = string
  description = "Environment name (e.g. dev, prod)"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS Cluster"
}
