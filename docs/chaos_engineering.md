# Chaos Engineering Playbook (障害注入テスト手順書)

本インフラは、FISC安全対策基準に準拠したセキュアで高可用性な設計を採用しています。本ドキュメントは、インフラの自己修復能力（Self-Healing）と耐障害性が想定通りに機能するかを検証するための、カオスエンジニアリング検証シナリオです。

---

## 🧪 シナリオ 1: EKS ワーカーノードの強制終了 (Node Failure)

### 1. 概要
ワーカーノード（EC2インスタンス）が突然クラッシュまたはシャットダウンした場合に、コンテナの再配置とノードの自動プロビジョニング（Karpenter）が正常に行われるかを検証します。

### 2. 検証手順
1. 現在稼働中のワーカーノードと、そこに配置されているPodを確認します。
   ```bash
   kubectl get nodes
   kubectl get pods -o wide
   ```
2. AWS CLI を使用して、稼働中の EC2 インスタンス（ノード）を1台強制終了します。
   ```bash
   aws ec2 terminate-instances --instance-ids <target-node-instance-id>
   ```
3. クラスターの状態をリアルタイムで監視します。
   ```bash
   kubectl get nodes -w
   kubectl get pods -w
   ```

### 3. 期待される挙動 (SLO達成基準)
* **自己修復**: 終了したノード上のPodが即座に `Terminating` または `Unknown` になり、別の正常なノードに再スケジュール（`Pending` ➡ `Running`）されること。
* **オートスケーリング**: クラスター全体のCPU/メモリ容量が不足した場合、**Karpenter / EKS Auto Mode** が自動的に新しい EC2 インスタンスを検知・起動し、2分以内に Ready 状態にすること。

---

## 🧪 シナリオ 2: アベイラビリティゾーン (AZ) 障害のシミュレーション

### 1. 概要
AWSの特定のAZ（例: `ap-northeast-1a`）で大規模障害が発生したと仮定し、マルチAZ（3AZ）設計の冗長化が正しく機能するかを検証します。

### 2. 検証手順
1. AWS Network ACL (NACL) を用いて、対象のサブネット（`ap-northeast-1a` に配置されたパブリック/プライベートサブネット）宛てのすべてのインバウンド/アウトバウンドトラフィックを拒否（Deny）するルールを適用します。
2. アプリケーションのエンドポイントに対して、外部から継続的な疎通テストを実行します。
   ```bash
   while true; do curl -s -o /dev/null -w "%{http_code}\n" http://<your-alb-dns-name>/; sleep 1; done
   ```

### 3. 期待される挙動 (SLO達成基準)
* **トラフィックの自動切り替え**: ALB（Application Load Balancer）のヘルスチェック機能により、障害の発生した `ap-northeast-1a` 上のターゲットグループが `Unhealthy` として自動で切り離されること。
* **サービス無停止**: 疎通テストで一瞬の瞬断（数秒〜十数秒）を除き、リクエストが残り2つのAZ（`ap-northeast-1b`, `ap-northeast-1c`）にルーティングされ、`200 OK` が返却され続けること。

---

## 🧪 シナリオ 3: アプリケーション Pod のメモリリークと OOM クラッシュ

### 1. 概要
アプリケーション Pod がメモリリークを起こし、リミットを超えて OOM (Out Of Memory) クラッシュした場合に、Kubernetes のセルフヒーリングが正常に動作するかを検証します。

### 2. 検証手順
1. メモリを急速に消費する検証用マニフェスト（`stress` コンテナを同梱したもの）をデプロイ、または実行中のコンテナ内で以下のコマンドを実行して意図的にメモリリークを起こします。
   ```bash
   kubectl exec -it <pod-name> -- tail /dev/zero
   ```
2. Pod のステータスと再起動回数を監視します。
   ```bash
   kubectl get pods -w
   ```

### 3. 期待される挙動 (SLO達成基準)
* **プロセス自動検知**: Kubelet がコンテナのメモリ限界超過を検知し、即座にコンテナを終了（OOMKilled）させること。
* **セルフヒーリング**: Pod の `RestartPolicy` (Always) に従い、Pod自体は削除されず、コンテナがミリ秒単位で自動再起動（Restartカウントが +1 になる）し、即座にサービスが復旧すること。
* **トラフィック保護**: 再起動中の Pod が完全に立ち上がるまでの間、Readiness Probe によりロードバランサーからのトラフィック割り振りが一時的に遮断され、ユーザーへエラーが返らないこと。
