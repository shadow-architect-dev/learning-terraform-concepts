variable "env_name" {
  type        = string
  description = "Environment name"
}
variable "maintenance_mode" {
  type        = bool
  description = "Enable maintenance mode (block traffic with 503)"
}
variable "bypass_ip_cidrs" {
  type        = list(string)
  description = "IP CIDR list allowed to bypass maintenance mode"
}
