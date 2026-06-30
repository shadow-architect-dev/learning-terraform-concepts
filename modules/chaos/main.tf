# 1. AWS FIS 用の IAM ロール
resource "aws_iam_role" "fis" {
  name = "fis-execution-role-${var.env_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# FISに必要な最小ポリシーの付与 (SSM, EC2操作権限)
resource "aws_iam_role_policy" "fis" {
  name = "fis-execution-policy-${var.env_name}"
  role = aws_iam_role.fis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RebootInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "arn:aws:ec2:*:*:instance/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetDocument"
        ]
        Resource = [
          "arn:aws:ssm:*:*:document/*",
          "arn:aws:ec2:*:*:instance/*"
        ]
      }
    ]
  })
}

# 2. AWS FIS 実験テンプレート (Chaos Experiment Template)
resource "aws_fis_experiment_template" "eks_node_cpu_stress" {
  description = "Inject CPU stress into EKS worker nodes to test auto-scaling and alert thresholds."
  role_arn    = aws_iam_role.fis.arn

  stop_condition {
    source = "none"
  }

  # 実験対象ターゲットの定義 (EKS Private Subnet 内の EC2 インスタンス群)
  target {
    name           = "eks-worker-nodes"
    resource_type  = "aws:ec2:instance"
    selection_mode = "COUNT(1)" # ランダムに1つのノードを対象

    resource_tag {
      key   = "Environment"
      value = var.env_name
    }
  }

  # 実験アクションの定義 (SSMでCPUストレスコマンドを送信)
  action {
    action_id = "aws:ssm:send-command"
    name      = "cpu-stress-injection"

    parameter {
      key   = "documentArn"
      value = "arn:aws:ssm:ap-northeast-1::document/AWS-RunCPUStress"
    }

    parameter {
      key   = "documentParameters"
      value = "{\"DurationSeconds\":\"300\",\"CPU\":\"100\"}"
    }

    parameter {
      key   = "duration"
      value = "PT5M" # 5分間実行
    }

    target {
      key   = "Instances"
      value = "eks-worker-nodes"
    }
  }

  tags = {
    Name        = "fis-eks-cpu-stress-${var.env_name}"
    Environment = var.env_name
  }
}
