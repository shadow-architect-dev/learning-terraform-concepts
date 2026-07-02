# 1. パスワード・認証トークンの自動生成と Secrets Manager 保存
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "db-credentials-${var.env_name}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.db_password.result
  })
}
resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}
resource "aws_secretsmanager_secret" "redis_secret" {
  name                    = "redis-credentials-${var.env_name}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "redis_secret_version" {
  secret_id = aws_secretsmanager_secret.redis_secret.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth_token.result
  })
}
# 2. セキュリティグループ (FISC準拠: egress空によりアウトバウンド通信を完全遮断)
resource "aws_security_group" "db" {
  name        = "sg-aurora-${var.env_name}"
  description = "Security Group for Aurora DB (No Outbound allowed)"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "Allow PostgreSQL access from EKS nodes"
  }
  tags = {
    Name        = "sg-aurora-${var.env_name}"
    Environment = var.env_name
  }
}
resource "aws_security_group" "redis" {
  name        = "sg-redis-${var.env_name}"
  description = "Security Group for ElastiCache Redis (No Outbound allowed)"
  vpc_id      = var.vpc_id
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "Allow Redis access from EKS nodes"
  }
  tags = {
    Name        = "sg-redis-${var.env_name}"
    Environment = var.env_name
  }
}
# 3. DBサブネットグループ & パラメータグループ
resource "aws_db_subnet_group" "this" {
  name       = "db-subnet-group-${var.env_name}"
  subnet_ids = var.isolated_subnet_ids
  tags = {
    Name        = "db-subnet-group-${var.env_name}"
    Environment = var.env_name
  }
}
resource "aws_rds_cluster_parameter_group" "this" {
  name   = "db-pg-${var.env_name}"
  family = "aurora-postgresql16"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}
# 4. Aurora Serverless v2 クラスター
resource "aws_rds_cluster" "this" {
  cluster_identifier              = "aurora-cluster-${var.env_name}"
  engine                          = "aurora-postgresql"
  engine_version                  = "16.1"
  database_name                   = "appdb"
  master_username                 = "postgres"
  master_password                 = random_password.db_password.result
  db_subnet_group_name            = aws_db_subnet_group.this.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  storage_encrypted               = true
  kms_key_id                      = var.kms_key_arn
  skip_final_snapshot             = true
  serverlessv2_scaling_configuration {
    min_capacity = var.db_min_capacity
    max_capacity = var.db_max_capacity
  }
  tags = {
    Name        = "aurora-cluster-${var.env_name}"
    Environment = var.env_name
    Schedule    = var.env_name == "dev" ? "office-hours" : null
  }
}
locals {
  db_instance_count = var.env_name == "prod" ? 2 : 1
}
resource "aws_rds_cluster_instance" "this" {
  count               = local.db_instance_count
  identifier          = "aurora-instance-${var.env_name}-${count.index}"
  cluster_identifier  = aws_rds_cluster.this.id
  instance_class      = var.db_instance_class
  engine              = aws_rds_cluster.this.engine
  engine_version      = aws_rds_cluster.this.engine_version
  publicly_accessible = false
  tags = {
    Name        = "aurora-instance-${var.env_name}-${count.index}"
    Environment = var.env_name
    Schedule    = var.env_name == "dev" ? "office-hours" : null
  }
}
# 5. ElastiCache Redis レプリケーショングループ
resource "aws_elasticache_subnet_group" "this" {
  name       = "redis-subnet-group-${var.env_name}"
  subnet_ids = var.isolated_subnet_ids
}
resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "redis-group-${var.env_name}"
  description                = "ElastiCache Redis Replication Group for ${var.env_name}"
  node_type                  = "cache.t4g.medium"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.redis.id]
  automatic_failover_enabled = var.env_name == "prod" ? true : false
  multi_az_enabled           = var.env_name == "prod" ? true : false
  num_cache_clusters         = var.env_name == "prod" ? 2 : 1
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  kms_key_id                 = var.kms_key_arn
  tags = {
    Name        = "redis-group-${var.env_name}"
    Environment = var.env_name
  }
}
