module "vpc" {
  source             = "./modules/vpc"
  env_name           = var.env_name
  vpc_cidr           = var.vpc_cidr
  ipam_pool_id       = var.ipam_pool_id
  transit_gateway_id = var.transit_gateway_id
}
module "security" {
  source   = "./modules/security"
  env_name = var.env_name
}
module "eks" {
  source                 = "./modules/eks"
  env_name               = var.env_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  kms_key_arn            = module.security.kms_key_arn
  node_instance_type     = var.eks_node_instance_type
  node_desired_size      = var.eks_node_desired_size
  node_max_size          = var.eks_node_max_size
  node_min_size          = var.eks_node_min_size
  log_archive_account_id = var.log_archive_account_id
  aws_region             = var.aws_region
  datadog_api_key        = var.datadog_api_key
  datadog_app_key        = var.datadog_app_key
}
module "database" {
  source                     = "./modules/database"
  env_name                   = var.env_name
  vpc_id                     = module.vpc.vpc_id
  isolated_subnet_ids        = module.vpc.isolated_subnet_ids
  eks_node_security_group_id = module.eks.cluster_security_group_id
  kms_key_arn                = module.security.kms_key_arn
  db_instance_class          = var.db_instance_class
  db_min_capacity            = var.db_min_capacity
  db_max_capacity            = var.db_max_capacity
}
module "waf" {
  source           = "./modules/waf"
  env_name         = var.env_name
  maintenance_mode = var.maintenance_mode
  bypass_ip_cidrs  = var.waf_bypass_ip_cidrs
}

module "monitoring" {
  source       = "./modules/monitoring"
  env_name     = var.env_name
  cluster_name = module.eks.cluster_name
}

module "chaos" {
  source             = "./modules/chaos"
  env_name           = var.env_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "cloudfront" {
  source       = "./modules/cloudfront"
  env_name     = var.env_name
  alb_arn      = var.eks_alb_arn
  alb_dns_name = var.eks_alb_dns_name
}
