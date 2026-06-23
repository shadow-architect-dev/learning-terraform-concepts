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
        ├── eks/              # EKSクラスター、Node Group、OIDC、ALB Controller、Fluent Bit (ログ転送)
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

## 🌟 [オプション] 最新モダン EKS Auto Mode 構成 (`eks-modern-auto/`)

本リポジトリの [`eks-modern-auto/`](file:///c:/Git/learning-terraform-concepts/eks-modern-auto/) ディレクトリには、AWS EKS（v1.32想定）の最新機能である **EKS Auto Mode** を土台とし、**Cilium (eBPF)**、**Istio Ambient Mesh (サイドカーレス)**、および **Datadog Agent (可観測性)** を統合した、次世代の Kubernetes インフラ基盤を構成する Terraform テンプレートを同梱しています。

金融・エンタープライズの堅牢性に加え、運用コストの極小化と圧倒的なネットワークパフォーマンスを両立させた「ベストプラクティス・スタック」を表現しています。

### 🚀 採用しているモダン技術スタックと選定理由

#### 1. 土台: EKS Auto Mode（Karpenter 自動管理）
* **選定理由**: 従来のノードグループ（MNG）管理を撤廃し、AWSが管理する **Karpenter** が直接EC2ノードのプロビジョニング、スケーリング、OS自動パッチを担います。
* **メリット**: ノード管理の手間がゼロになり、さらにロードバランサー（ELB）やブロックストレージ（EBS）のライフサイクルもEKSコントロールプレーンが自動管理するため、追加のインフラコントローラー（ALB ControllerやEBS CSI Driver等）の管理から解放されます。

#### 2. ネットワーク: Cilium（CNI Chaining モード）
* **選定理由**: カーネル内の **eBPF (Extended Berkeley Packet Filter)** を利用し、従来の `iptables` による重いパケット処理を回避した高速なコンテナ間通信とネットワークポリシー（L3/L4/L7）制御を提供します。
* **VPC CNI との調和 (Chaining Mode)**: EKS Auto Mode では標準で AWS VPC CNI が有効化されます。Ciliumを排他（Exclusive）モードで動かすとAuto Modeと競合するため、本構成では **`aws-vpc-cni` Chaining** を指定し、IPAMはVPC CNI、ポリシー制御とパケットフィルタリングはCiliumが担うハイブリッド設計としています。

#### 3. サービスメッシュ: Istio Ambient Mesh（サイドカーレス）
* **選定理由**: 従来のサイドカーモデル（Pod内にEnvoyコンテナを常駐させる）から進化し、ノード単位で動作する **`ztunnel` (DaemonSet)** と **`istio-cni`** を利用した**サイドカーレス・サービスメッシュ**を採用しています。
* **メリット**:
  * アプリケーションPodの起動順序問題を解消。
  * メモリ・CPU消費量を大幅に削減（サイドカーと比較して約50〜70%減）。
  * アプリケーションコードを変更せず、透過的な相互TLS（mTLS）暗号化およびL4テレメトリを即座に有効化。

#### 4. 監視: Datadog Agent（eBPF ネットワーク可観測性）
* **選定理由**: 各ノードに DaemonSet としてデプロイされ、ホストおよびコンテナのパフォーマンスを統合監視します。
* **最適化**: CiliumとIstio Ambientが稼働する複雑なネットワーク下で確実にパケットを監視するため、**`HostNetwork = true`** でエージェントを起動し、カーネルの **eBPF (System Probe / NPM)** を用いたリアルタイムなコンテナ間通信の接続関係とレイテンシを可視化します。

---

### 🛠️ アーキテクチャのトポロジー

![System Architecture](docs/images/architecture_auto.svg)

### ⚙️ 主な設定パラメータ解説（`helm_releases.tf`）

#### Cilium (`cni.chainingMode = "aws-vpc-cni"`)
VPC CNIとのチェイニングを有効化するためのパラメータです。また、コントロールプレーンとしての Cilium Operator も明示的にデプロイしています。
```hcl
cni.chainingMode     = "aws-vpc-cni"
cni.exclusive        = "false"
enableIPv4Masquerade = "false"    # VPC CNIがマスカレードを担当
tunnel               = "disabled" # トンネリング（VxLAN/Geneve）を無効化しVPCルーティングを利用
ipam.mode            = "aws-vpc-cni"
ipam.operator.enabled = "false"   # IPAMはVPC CNIに委ねる
operator.enabled     = "true"     # 司令塔(Operator)を明示的に有効化
operator.replicas    = "1"        # デモ用（本番はHAを考慮し2推奨）
```

#### Istio Ambient Mesh (`profile = "ambient"`)
Ambient Meshを有効にするため、CRD、CNIプラグイン、コントロールプレーン（`istiod`）、データプレーン（ztunnel）をそれぞれデプロイします。
* `istio-cni` が各ノードのネットワーク名前空間を監視し、アプリケーションのパケットを自動的かつ安全に `ztunnel` へリダイレクト（リダイレクション）します。
* L7制御を行うには、Kubernetes Gateway API を有効化し、Waypoint Proxy（L7司令塔プロキシ）をデプロイする必要があります。

#### Datadog (`agents.useHostNetwork = true`)
CNIチェイニングおよびサービスメッシュが初期化されるよりも先に、ノードのホストネットワークにバインドして確実に起動し、メトリクスのドロップを防ぐ実務的（本番考慮）なパラメータです。また、クラスタ管理を担う Cluster Agent も明示的にデプロイしています。
```hcl
datadog.clusterAgent.enabled = "true"  # 司令塔(Cluster Agent)を明示的に有効化
clusterAgent.replicas        = "1"     # 本番は2推奨
```

---

### 🛡️ EKS 司令塔 Pod（Control Plane & Operators）の重要性と役割

各ノードで動作する DaemonSet（Cilium、ztunnel、Datadog Agent）を統治し、クラスタ全体の同期や管理を担う **「司令塔（Control Plane / Operator / Waypoint）」** Pod が配置されています（詳細はトポロジー構成図を参照）。

1. **`istiod` (Istio Control Plane)**
   * **役割**: サービスメッシュ全体の司令塔。証明書 (CA) の発行や mTLS のセキュリティポリシー、`ztunnel` に対するルーティング設定 (xDS) の配信を集中管理します。
2. **`cilium-operator` (Cilium Operator)**
   * **役割**: Cilium 特有のカスタムリソース (CRD) のガベージコレクションや、Kubernetes サービスとの同期を司ります。IPAM（IPアドレス管理）は VPC CNI に委ねているため、`ipam.operator.enabled = false` に抑えつつ、その他のコントロールプレーン機能を安全に提供します。
3. **`datadog-cluster-agent` (Datadog Cluster Agent)**
   * **役割**: 各ノードの Datadog Agent と Kubernetes API サーバーの間のクッションとして機能します。API サーバーへの負荷集中を防ぎ、クラスタ全体のカスタムメトリクスを安全に収集します。
4. **`Waypoint Proxy` (Envoy / L7 Gateway)**
   * **役割**: Istio Ambient Mesh において L7 (HTTP / TLS レベル) の高度なルーティングやセキュリティ制御を行うためのプロキシです。必要に応じて Namespace 単位等でデプロイされ、L4 制御のみを行う ztunnel と協調します。

---

### 🚀 実行コマンド

本構成は静的検証が完了しています。

```bash
cd eks-modern-auto/
terraform init
terraform validate
```

---

## 📝 ログアーカイブ（Landing Zone）への Fluent Bit ログ転送のセットアップ

EKS（Workloadアカウント）側から Log Archive（Landing Zone）アカウントに対して、セキュアにコンテナログをクロスアカウント転送する構成が追加されました。

### 🛠️ 構成アーキテクチャ
* **Fluent Bit (DaemonSet)**: `logging` Namespace 上で各ワーカーノードからコンテナログを収集します。
* **IRSA (IAM Roles for Service Accounts)**: Fluent Bit Pod が `eks-cluster-<env>-fluent-bit-irsa` ロールを借用します。
* **クロスアカウント連携**: IRSA ロールが Log Archive 側の受信専用ロール `eks-fluent-bit-cross-account-role` を引き受け (AssumeRole)、同アカウント上の Kinesis Data Firehose へログを直接プッシュします。

### 🚀 適用手順
1. **変数の設定**:
   ルートの `terraform.tfvars` に、ログアーカイブ先のアカウントIDを定義します。
   ```hcl
   log_archive_account_id = "123456789012" # ログアーカイブ側の 12桁のAWSアカウントID
   ```
2. **適用**:
   リポジトリのルートディレクトリで以下を実行して、ログ転送設定をデプロイします。
   ```bash
   terraform init
   terraform apply
   ```

### 🔍 動作検証手順 (疎通確認)
1. **Podの起動確認**:
   ```bash
   kubectl get pods -n logging
   # 出力結果: aws-for-fluent-bit-xxxxx が各ノード上で Running であること
   ```
2. **ログ確認 (送信エラーがないか)**:
   ```bash
   kubectl logs -n logging -l app.kubernetes.io/name=aws-for-fluent-bit
   # AccessDeniedException や AssumeRole の失敗エラーがないことを確認します
   ```
3. **S3バケットでの着信確認**:
   Log Archive アカウントの S3 バケットの `workloads/` プレフィックス配下に、GZIP圧縮されたコンテナログオブジェクトが作成されていることを確認します。
