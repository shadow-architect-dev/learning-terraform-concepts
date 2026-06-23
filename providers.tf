terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
  # 初期セットアップ時は local バックエンドで実行し、S3 作成後に移行します。
  # 移行の際は backend "local" ブロックをコメントアウトし、backend "s3" ブロックに値を入力して terraform init を実行してください。

  # backend "local" {
  #   path = "terraform.tfstate"
  # }

  backend "s3" {
    bucket         = "YOUR_STATE_BUCKET_NAME"   # bootstrapの実行結果(state_bucket_name)を入力
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "YOUR_DYNAMODB_TABLE_NAME" # bootstrapの実行結果(dynamodb_table_name)を入力
    encrypt        = true
  }
}
provider "aws" {
  region = var.aws_region
}
# EKSクラスター作成後に Helm / Kubernetes プロバイダーを動的接続するための設定
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
