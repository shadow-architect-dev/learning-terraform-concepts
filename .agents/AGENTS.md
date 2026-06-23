# project-rules
## Terraform 開発における約束事
- すべてのTerraformコードはプレーンな HCL (HashiCorp Configuration Language) で記述する。
- リソースには適切な `Name` タグと `Environment` タグを必ず付与する。
- 変数はすべて `variables.tf` に、出力は `outputs.tf` にまとめ、`main.tf` に直書きしない。
## FISC安全対策基準に準拠したインフラ制御ルール
1. **送信（Egress）の完全遮断**:
   データベース（Aurora）およびキャッシュ（Redis）のセキュリティグループからは、送信（Egress）ルールを完全に排除する。
2. **通信の暗号化**:
   - Aurora は `rds.force_ssl = 1` をパラメータグループで強制する。
   - Redis は `transit_encryption_enabled = true` を設定する。
3. **データ暗号化の徹底**:
   KMS のカスタマー管理キー (CMK) を用いて、EKS Secrets、RDSストレージ、Redisをエンベロープ暗号化する。
4. **閉域接続**:
   ECR、S3、STS、CloudWatch Logs へのアクセスは、インターネット（NAT Gateway）を経由せず、プライベートVPCエンドポイント（Interface/Gateway型）を経由させる。
