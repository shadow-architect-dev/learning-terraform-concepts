data "aws_availability_zones" "available" {
  state = "available"
}
# 1. VPC の定義
resource "aws_vpc" "this" {
  cidr_block           = var.ipam_pool_id == null ? var.vpc_cidr : null
  ipv4_ipam_pool_id    = var.ipam_pool_id
  ipv4_netmask_length  = var.ipam_pool_id != null ? 16 : null
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "vpc-${var.env_name}"
    Environment = var.env_name
  }
}
# 2. サブネットの定義 (3つのAZに分割)
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                                                = "subnet-public-${var.env_name}-${data.aws_availability_zones.available.names[count.index]}"
    Environment                                         = var.env_name
    "kubernetes.io/role/elb"                            = "1"
    "kubernetes.io/cluster/eks-cluster-${var.env_name}" = "shared"
  }
}
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name                                                = "subnet-private-${var.env_name}-${data.aws_availability_zones.available.names[count.index]}"
    Environment                                         = var.env_name
    "kubernetes.io/role/internal-elb"                   = "1"
    "kubernetes.io/cluster/eks-cluster-${var.env_name}" = "shared"
  }
}
resource "aws_subnet" "isolated" {
  count             = 3
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index + 8)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name        = "subnet-isolated-${var.env_name}-${data.aws_availability_zones.available.names[count.index]}"
    Environment = var.env_name
  }
}
# 3. インターネットゲートウェイ (IGW)
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "igw-${var.env_name}"
  }
}
# 4. NAT ゲートウェイ (集約アウトバウンド移行に伴い廃止)
# NAT GWは共通基盤（Shared Services）で一元管理するため、このVPCからは撤廃します。
# 5. ルートテーブルとルート
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "rt-public-${var.env_name}"
  }
}
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
# Private Route Table
resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "rt-private-${var.env_name}-${data.aws_availability_zones.available.names[count.index]}"
  }
}
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
# Isolated Route Table (ルート設定なし)
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "rt-isolated-${var.env_name}"
  }
}
resource "aws_route_table_association" "isolated" {
  count          = 3
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}
# 6. VPC エンドポイント (FISC準拠: 閉域接続)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], aws_route_table.private[*].id)
  tags = {
    Name = "vpce-s3-${var.env_name}"
  }
}
resource "aws_security_group" "vpce" {
  name        = "sg-vpc-endpoints-${var.env_name}"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.this.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
  tags = {
    Name = "sg-vpce-${var.env_name}"
  }
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
  tags = {
    Name = "vpce-ecr-dkr-${var.env_name}"
  }
}
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
  tags = {
    Name = "vpce-ecr-api-${var.env_name}"
  }
}
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
  tags = {
    Name = "vpce-sts-${var.env_name}"
  }
}
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpce.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
  tags = {
    Name = "vpce-logs-${var.env_name}"
  }
}

# ------------------------------------------------------------------------------
# 7. AWS Transit Gateway (TGW) 接続定義
# ------------------------------------------------------------------------------

# TGW VPC アタッチメントの作成
resource "aws_ec2_transit_gateway_vpc_attachment" "eks_tgw" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.private[*].id

  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name = "tgw-attachment-${var.env_name}"
  }
}

# プライベートルートテーブルから TGW 宛てのデフォルトルート定義（集約アウトバウンド）
resource "aws_route" "to_tgw" {
  count                  = 3
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0" # すべてのインターネット・閉域宛てをTGWへ
  transit_gateway_id     = var.transit_gateway_id
}
