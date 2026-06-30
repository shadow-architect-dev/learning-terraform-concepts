# 1. EKS クラスター用 IAM ロール
resource "aws_iam_role" "cluster" {
  name = "eks-cluster-role-${var.env_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name        = "eks-cluster-role-${var.env_name}"
    Environment = var.env_name
  }
}
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}
# 2. EKS クラスター本体
resource "aws_eks_cluster" "this" {
  name     = "eks-cluster-${var.env_name}"
  role_arn = aws_iam_role.cluster.arn
  version  = "1.30"
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }
  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]
  tags = {
    Name        = "eks-cluster-${var.env_name}"
    Environment = var.env_name
  }
}
# 3. EKS ワーカーノード用 IAM ロール
resource "aws_iam_role" "node" {
  name = "eks-node-role-${var.env_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name        = "eks-node-role-${var.env_name}"
    Environment = var.env_name
  }
}
resource "aws_iam_role_policy_attachment" "node_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}
resource "aws_iam_role_policy_attachment" "node_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}
# 4. Managed Node Group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "ng-${var.env_name}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }
  update_config {
    max_unavailable = 1
  }
  instance_types = [var.node_instance_type]
  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_registry
  ]
  tags = {
    Name        = "eks-node-group-${var.env_name}"
    Environment = var.env_name
  }
}
# 5. OIDC プロバイダー (IRSA用)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
# 6. AWS Load Balancer Controller 用 IRSA 設定
locals {
  oidc_provider_arn_arn_parts = split("/", aws_iam_openid_connect_provider.this.arn)
  oidc_provider_name          = join("/", slice(local.oidc_provider_arn_arn_parts, 1, length(local.oidc_provider_arn_arn_parts)))
}
data "aws_iam_policy_document" "aws_load_balancer_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_name}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_name}:aud"
      values   = ["sts.amazonaws.com"]
    }
    principals {
      identifiers = [aws_iam_openid_connect_provider.this.arn]
      type        = "Federated"
    }
  }
}
resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "eks-alb-controller-role-${var.env_name}"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume.json
}
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${var.env_name}"
  path        = "/"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolDetails",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTrustStores"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
          Null         = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags", "ec2:DeleteTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules",
          "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
          "ec2:UpdateSecurityGroupRuleDescriptionsEgress"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false" }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = "*"
        Condition = {
          Null = { "aws:RequestTag/elbv2.k8s.aws/cluster" = "false" }
        }
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}
# 7. AWS Load Balancer Controller Helm リリース
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"
  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }
  depends_on = [
    aws_eks_node_group.this
  ]
}
