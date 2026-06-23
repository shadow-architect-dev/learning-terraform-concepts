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
  # 初期状態はローカルバックエンド。本番運用時は S3 + DynamoDB のバックエンドに切り替え可能
  backend "local" {
    path = "terraform.tfstate"
  }

  # リモートバックエンド（S3 + DynamoDB）へ移行する際の記述例:
  # bootstrap 実行後に生成されたバケット名を指定して terraform init -migrate-state を実行します
  # backend "s3" {
  #   bucket         = "learning-terraform-state-dev-<ACCOUNT_ID>"
  #   key            = "dev/terraform.tfstate"
  #   region         = "ap-northeast-1"
  #   dynamodb_table = "learning-terraform-locks-dev"
  #   encrypt        = true
  # }
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
