# Runbook: ALB Latency High (応答遅延アラート対応手順書)

* **アラート名**: `[<env>] ALB Latency High`
* **重要度**: Warning (レイテンシ 300ms 超) / Critical (レイテンシ 500ms 超)
* **対象インフラ**: AWS ALB (Application Load Balancer) ➡ EKS Target Group

---

## 1. 概要 (Overview)

本手順書は、Application Load Balancer（ALB）の応答時間（Latency）が許容しきい値（500ms）を超え、サービスレベル目標（SLO）に影響が出る恐れがある場合に、オンコールエンジニアが迅速にトリアージと一次対応を行うためのマニュアルです。

---

## 2. 一次対応ステップ (Triage & Mitigate)

### ステップ 1: 影響範囲の特定 (Triage)
1. **Datadog ダッシュボードの確認**:
   アラート通知のリンクから Datadog の「APM Services / Trace」および「ALB Dashboard」を開きます。
2. **ボトルネックのエンドポイント特定**:
   特定のAPI（例: `/api/v1/image-processing`）だけが遅いのか、静的ファイルを含むシステム全体が遅いのかを確認します。
   * **特定APIのみの場合**: アプリケーション（またはDB）起因の可能性が高いため、ステップ 2 へ。
   * **全体的に遅い場合**: ネットワークまたはノードリソース枯渇の可能性があるため、ステップ 3 へ。

---

### ステップ 2: アプリケーション / データベースの調査 (App & DB Check)
1. **直近のデプロイ履歴を確認**:
   GitHub Actions の実行履歴または `git log` を確認し、直近（30分以内）に本番リリースが行われたか確認します。
2. **DBの負荷状況確認**:
   AWS コンソールまたは Datadog 上で **Amazon Aurora** の `CPUUtilization` および `DatabaseConnections` メトリクスを確認します。
   * スロークエリが多発して DB CPU が 90% を超えている場合、開発担当者へエスカレーションし、一時的なクエリキャッシュ適用、または一時的な読み取りレプリカのスケールアップを検討します。

---

### ステップ 3: EKS ノード / Pod リソースの調査 (EKS Resource Check)
1. **ワーカーノードおよび Pod の CPU/メモリ使用率確認**:
   Bastion（操作端末）からクラスターに接続し、コマンドを実行します。
   ```bash
   # ノード全体の負荷確認
   kubectl top nodes
   
   # ポッドごとの負荷確認
   kubectl top pods -A --sort-by=cpu
   ```
2. **Karpenter のスケール状態確認**:
   リソース逼迫時にノードの自動プロビジョニングが正常に開始されているか（`Pending` 状態のノードがないか）を確認します。
   ```bash
   kubectl get nodes -w
   kubectl get events -n kube-system --sort-by='.metadata.creationTimestamp'
   ```

---

## 3. 応急処置アクション (Mitigation Actions)

### アクション A: アプリケーションのロールバック (Rollback)
直近のデプロイによるバグ（メモリリークや無限ループ等）が確定した場合、直ちに 1 世代前の正常なバージョンに切り戻します。
```bash
# Helm を用いてデプロイしている場合 (例: Webアプリ)
helm list -n prod
helm rollback <release-name> <previous-revision-number> -n prod
```

### アクション B: 手動でのレプリカ数スケールアウト (Manual Scale Out)
Karpenter によるノード追加は自動で行われますが、Pod の自動スケーリング（HPA）の反応が遅く、急激なスパイクアクセスに対応しきれていない場合、手動でレプリカ数を一時的に引き上げます。
```bash
kubectl scale deployment/web-app --replicas=10 -n prod
```

### アクション C: WAF によるメンテナンスモードの緊急発動 (Emergency Maintenance)
DBのデッドロックやシステム全体の完全崩壊が発生し、エラー予算が秒単位で急激に消費され続けている場合は、インフラ保護のため一時的にシステム全体をメンテナンスモード（503画面）に移行させます。
1. ルートの [terraform.tfvars](file:///c:/Git/learning-terraform-concepts/terraform.tfvars) を編集します。
   ```hcl
   maintenance_mode = true
   ```
2. Terraform を適用して WAF を有効化します。
   ```bash
   terraform apply -target=module.waf
   ```
   *※これにより、AWS WAFv2 が即座にすべてのトラフィックを遮断し、インフラ全体の負荷をゼロに抑えて調査時間を確保できます。*
