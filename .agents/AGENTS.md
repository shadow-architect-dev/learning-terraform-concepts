# project-rules

## 1. Terraform 開発における約束事
- すべてのTerraformコードはプレーンな HCL (HashiCorp Configuration Language) で記述する。
- リソースには適切な `Name` タグと `Environment` タグを必ず付与する。
- 変数はすべて `variables.tf` に、出力は `outputs.tf` にまとめ、`main.tf` に直書きしない。

## 2. FISC安全対策基準に準拠したインフラ制御ルール
- **送信（Egress）の完全遮断**:
  データベース（Aurora）およびキャッシュ（Redis）のセキュリティグループからは、送信（Egress）ルールを完全に排除し、アウトバウンドを完全遮断する。
- **通信の暗号化の強制**:
  - Aurora は `rds.force_ssl = 1` をパラメータグループで強制する。
  - Redis は `transit_encryption_enabled = true` を設定する。
- **データ暗号化の徹底 (保管時暗号化)**:
  KMS のカスタマー管理キー (CMK) を用いて、EKS Secrets、RDSストレージ、Redis、Secrets Managerのすべてのデータ保存領域をエンベロープ暗号化する。
- **閉域接続 (VPC Endpoints)**:
  ECR、S3、STS、CloudWatch Logs へのアクセスは、インターネット（NAT Gateway）を経由せず、プライベートVPCエンドポイント（Interface/Gateway型）を経由させる。
- **環境パリティとコスト削減の両立**:
  dev環境のNAT Gatewayは1台（非可用）、prod環境は3台（マルチAZ対応）にするなど、環境レベルに応じたコスト最適化を考慮すること。

## 3. 構成図・ドキュメント規約
- **ベクター画像（SVG）の採用**:
  プロジェクトのアーキテクチャ図は、テキストMermaidではなく、拡大しても文字がぼやけない高品質なベクター画像「SVGフォーマット」として `docs/images/architecture.svg` に配置し、`README.md` から読み込めるようにすること。
- **ビジュアル・論理的正しさの厳守**:
  - AWS公式アイコンをベースにしたプレミアムなデザインにすること。
  - ネットワークおよび通信の方向性を正しく描くこと（EKS Nodesから各DB/Redisへ個別に並列接続し、余分な横の矢印を排除。NAT Gatewayは一方向のアウトバウンド矢印のみにするなど）。
  - 可用性ゾーン（AZ-A, AZ-B, AZ-C）等のテキストラベルは美しく左寄せ（左詰め）でアライメントを統一すること。
