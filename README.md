# learning-terraform-concepts

FISC安全対策基準に準拠した、セキュアで高可用性な AWS EKS 3層Webアプリケーションインフラをプレーンな Terraform (HCL) で定義したコードベースです。ポートフォリオ用として、金融機関等の厳しいセキュリティ要件を満たす設計パターンを実装しています。

---

## 📌 アーキテクチャ概要

本インフラは、パブリック、プライベート、およびインターネットから完全に分離されたアイソレート（孤立）の3つのレイヤーで構成されています。

![System Architecture](docs/images/architecture.svg)

---

## 🛡️ FISC安全対策基準に準拠したセキュリティ設計

金融・政府機関等のインフラで求められる **FISC（金融機関等コンピュータシステム安全対策基準）** に準拠するため、以下のインフラ制御を徹底しています。

### 1. 送信（Egress）の完全遮断
* **設計**: データベース（Aurora）およびキャッシュ（Redis）が配置されるアイソレートサブネット用のセキュリティグループにおいて、**送信（Egress）ルールを完全に排除**しています。
* **効果**: 万が一インフラ内でマルウェア感染や不正侵入が発生した場合でも、重要データが格納されたDB/キャッシュ層から外部へのデータ流出（C2サーバーへの通信など）を物理的・ネットワーク的に防ぎます。

### 2. 通信の暗号化の強制（Transit Encryption）
* **Aurora**: パラメータグループにて `rds.force_ssl = 1` を強制し、アプリケーションとのすべてのSQL通信をSSL/TLSで暗号化します。
* **ElastiCache Redis**: `transit_encryption_enabled = true` を設定し、インメモリキャッシュとの間のデータ転送も暗号化します。

### 3. カスタマー管理キー (CMK) によるデータ暗号化（At-Rest Encryption）
* **設計**: AWS管理のデフォルトキーではなく、KMS（Key Management Service）で作成した**カスタマー管理キー（CMK）**を使用しています。
* **対象**:
  * EKS Secrets（Kubernetes内のシークレットデータのエンベロープ暗号化）
  * RDS Auroraストレージ
  * ElastiCache Redis（保管時暗号化）
  * Secrets Manager（認証情報の暗号化）

### 4. 閉域接続の徹底（VPC Endpoints）
* **設計**: プライベートサブネットからAWSの各種マネージドサービス（ECR、S3、STS、CloudWatch Logs）へのアクセスは、NAT Gateway（インターネット）を経由させず、**プライベートVPCエンドポイント（Interface/Gateway型）**を経由させます。
* **効果**: インターネットを介さないため、中間者攻撃のリスクを低減し、耐障害性とセキュリティを高めます。

---

## 📁 フォルダ・モジュール構成

可読性と再利用性を高めるため、モノリスな記述を避け、役割ごとにモジュール化しています。

```text
learning-terraform-concepts/
  ├── .agents/                # AIエージェント（Antigravity）用設定フォルダ
  │     └── AGENTS.md         # プロジェクト専用のコーディング規約・FISC制約
  ├── providers.tf            # 各種プロバイダー（AWS, Kubernetes, Helm）の定義
  ├── variables.tf            # ルートレベルの変数宣言
  ├── outputs.tf              # インフラのアウトプット定義
  ├── main.tf                 # 各子モジュールの呼び出しと結合定義
  ├── terraform.tfvars        # 開発環境用の実パラメータ値
  └── modules/
        ├── vpc/              # VPC、3AZサブネット、NAT GW、VPCエンドポイント
        ├── security/         # KMS CMKの作成とポリシー管理
        ├── eks/              # EKSクラスター、Node Group、OIDC、ALB Controller
        ├── database/         # Aurora DB、Redis、認証情報、Egress空のSG
        └── waf/              # WAFv2 WebACL、IP制限、503メンテナンス画面定義
```

---

## ⚙️ WAFv2 による運用性設計

* **メンテナンスモード**:
  * 変数 `maintenance_mode = true` に設定することで、AWS WAFv2を通じて全てのトラフィックに対して即座にカスタムの503メンテナンス画面（HTML）を返却します。
  * 開発者や特定の関係者は、`waf_bypass_ip_cidrs` に送信元IPを指定することで、メンテナンス中もサービスへバイパスアクセスして検証を行える実用的な仕組みを実装しています。

---

## 🛠️ 検証コマンド

本リポジトリは構文・モジュール依存関係の検証が完了しています。

```powershell
# 1. 依存プロバイダーのダウンロードと初期化
terraform init

# 2. HCLコードのフォーマット整形
terraform fmt -recursive

# 3. 構文や参照関係の静的検証
terraform validate
```

## 🚀 初期セットアップ: リモートバックエンド（S3/DynamoDB）の構築

本プロジェクトは、複数人開発やデプロイ競合防止（ステートロック）を考慮し、S3とDynamoDBによるリモートバックエンド構成を採用しています。新規に構築を開始する際は、以下の「鶏と卵」問題をクリアするブートストラップ手順を実行してください。

### ステップ 1: バックエンド用リソースの作成（ローカル実行）

まず、ステート保存用のS3バケットと、ロック管理用のDynamoDBテーブルをローカル管理で作成します。

1. `bootstrap/` ディレクトリに移動します。
   ```bash
   cd bootstrap
   ```

2. 初期化とプロビジョニングを実行します（この時点のステートはローカルで一時管理されます）。
   ```bash
   terraform init
   terraform apply
   ```

3. 出力された `s3_bucket_name` と `dynamodb_table_name` をメモします。

### ステップ 2: メインインフラへのリモートバックエンド適用（移行）

作成したリソースをメインのインフラコードのバックエンドとして適用し、ステートファイルをS3へ移行します。

1. ルートディレクトリに戻ります。
   ```bash
   cd ..
   ```

2. `providers.tf` の `backend "s3"` ブロックに、先ほどメモしたS3バケット名とDynamoDBテーブル名を入力します。

3. 初期化コマンドを実行します。
   ```bash
   terraform init
   ```

4. ターミナルに 「ローカルのステートをリモートS3へ移行しますか？ (Do you want to copy existing state...)」 とメッセージが表示されるので、`yes` と入力します。

これで、初期セットアップは完了です。以降は安全なリモートバックエンド管理下で `terraform plan` / `apply` を実行できます。

---

## 🌟 [オプション] 最新モダン EKS Auto Mode 構成 (eks-modern-auto/)

本リポジトリには、通常の3層Webインフラ（Aurora/Redis）構成に加えて、AWS EKS (v1.32想定) の最新機能を活用した別館構成を同梱しています。

* **フォルダ位置**: [`eks-modern-auto/`](file:///c:/Git/learning-terraform-concepts/eks-modern-auto/)
* **構成要素**:
  * **EKS Auto Mode**: マネージドKarpenterによるノード自動スケール、ELB（ロードバランサー）、EBS（ブロックストレージ）のライフサイクル自動管理。
  * **Cilium (CNI Chaining)**: AWS VPC CNI と競合させずに、eBPF による高性能ネットワークポリシー制御を有効化。
  * **Istio Ambient Mesh**: サイドカー不要で、ノードレベルの ztunnel による安全な L4 mTLS と L7 制御。
  * **Datadog Agent**: HostNetwork接続によるコンテナおよび eBPF ネットワークの可観測性。

詳細なアーキテクチャ設計および検証手順については/またはセットアップについて、**[eks-modern-auto/README.md](file:///c:/Git/learning-terraform-concepts/eks-modern-auto/README.md)** を参照してください。
