# スクラップ材管理システム API構造

## 1. 概要

このシステムはHasura DDNを利用したGraphQL APIを提供し、スクラップ材の計量から在庫管理、取引、木灰処理までの一連のプロセスをカバーします。

## 2. APIエンドポイント

### 2.1 基本エンドポイント
- GraphQL API: `http://localhost:3280/v1/graphql`
- Admin Console: `http://localhost:3280/console`

### 2.2 認証
- Bearer token認証
- ロールベースのアクセス制御
- カスタムクレーム対応

## 3. コアドメイン

### 3.1 計量・チケット発行 (Ticketing)
```graphql
type WeightTicket {
  ticket_id: UUID!
  ticket_type: TicketTypeEnum!
  status: TicketStatusEnum!
  total_weight: Decimal!
  tare_weight: Decimal!
  net_weight: Decimal!  # 自動計算
  supplier: Supplier!
  vehicle: Vehicle
  yard: Yard!
  material_lines: [MaterialLine!]!
  compliance_info: ComplianceInfo
  created_at: Timestamp!
}
```

### 3.2 在庫管理 (Inventory)
```graphql
type InventoryLot {
  lot_id: UUID!
  material: Material!
  quantity: Decimal!
  unit: UnitEnum!
  avg_cost: Decimal!
  yard: Yard!
  state: LotStateEnum!
  tags: [LotTag!]!
  transfer_history: [TransferHistory!]!
}
```

### 3.3 受発注管理 (Orders)
```graphql
type Order {
  order_id: UUID!
  order_type: OrderTypeEnum!
  counterparty: Counterparty!
  status: OrderStatusEnum!
  order_lines: [OrderLine!]!
  linked_tickets: [LinkedTicket!]!
  invoices: [Invoice!]!
}
```

### 3.4 木灰処理 (WoodAsh)
```graphql
type ProcessBatch {
  batch_id: UUID!
  status: WoodAshStatusEnum!
  input_lot: InventoryLot!
  output_lot: InventoryLot
  quantity: Decimal!
  analysis_results: [AnalysisResult!]!
  process_start: Timestamp
  process_end: Timestamp
}
```

## 4. 主要なミューテーション

### 4.1 計量チケット
```graphql
mutation FinalizeWeightTicket($ticket_id: UUID!) {
  update_ticketing_weight_ticket_by_pk(
    pk_columns: { ticket_id: $ticket_id }
    _set: { status: FINALIZED, finalized_at: "now()" }
  ) {
    ticket_id
    status
    finalized_at
  }
}
```

### 4.2 在庫移動
```graphql
mutation TransferInventory(
  $lot_id: UUID!
  $from_yard_id: UUID!
  $to_yard_id: UUID!
  $quantity: Decimal!
) {
  insert_inventory_transfer_history_one(
    object: {
      lot_id: $lot_id
      from_yard_id: $from_yard_id
      to_yard_id: $to_yard_id
      quantity: $quantity
    }
  ) {
    transfer_history_id
  }
}
```

### 4.3 木灰処理
```graphql
mutation StartWoodAshProcess(
  $input_lot_id: UUID!
  $quantity: Decimal!
) {
  insert_wood_ash_process_batch_one(
    object: {
      input_lot_id: $input_lot_id
      quantity: $quantity
      status: RECEIVED
    }
  ) {
    batch_id
  }
}
```

## 5. サブスクリプション

### 5.1 リアルタイム計量データ
```graphql
subscription ScaleReadings($device_id: UUID!) {
  scale_gateway_scale_reading(
    where: { device_id: { _eq: $device_id } }
    order_by: { recorded_at: desc }
    limit: 1
  ) {
    weight
    recorded_at
  }
}
```

### 5.2 在庫アラート
```graphql
subscription LowStockAlert($threshold: Decimal!) {
  inventory_lot(
    where: {
      quantity: { _lt: $threshold }
      state: { _eq: FG }
    }
  ) {
    lot_id
    material { name }
    quantity
    yard { name }
  }
}
```

## 6. カスタムロジック実装

### 6.1 Computed Fields
- `WeightTicket.net_weight`: 総重量から風袋重量を差し引いて計算
- `OrderLine.amount`: 数量と単価から金額を計算

### 6.2 Action
- `finalizeWeightTicket`: 計量チケットの確定処理
- `completeWoodAshProcess`: 木灰処理の完了処理

### 6.3 Event Triggers
- 在庫移動時の在庫数更新
- 木灰処理完了時の新規ロット生成

## 7. エラーハンドリング

### 7.1 入力バリデーション
```graphql
input WeightTicketInput {
  total_weight: Decimal! # 0より大きい
  tare_weight: Decimal! # 0以上、total_weight以下
  supplier_id: UUID!
  yard_id: UUID!
  material_lines: [MaterialLineInput!]!
}
```

### 7.2 ビジネスロジックエラー
- 在庫不足エラー
- 重複チケットエラー
- 無効な状態遷移エラー

## 8. パフォーマンス最適化

### 8.1 クエリ設計
- 必要なフィールドのみ取得
- ページネーション実装
- 適切なインデックス設定

### 8.2 キャッシュ戦略
- 参照データのキャッシュ
- 集計結果のマテリアライズドビュー

## 9. セキュリティ

### 9.1 認可ルール
```yaml
ticket_finalize_permission:
  role: OPERATOR
  check:
    ticket:
      status: DRAFT
      yard:
        id: X-Hasura-Yard-Id
```

### 9.2 行レベルセキュリティ
```yaml
weight_ticket_select:
  role: USER
  check:
    yard_id: X-Hasura-Yard-Id
```

## 10. 監視とロギング

### 10.1 監査ログ
```graphql
type AuditLog {
  log_id: UUID!
  user_id: UUID!
  action: String!
  resource: AuditResourceEnum!
  resource_id: UUID
  timestamp: Timestamp!
  details: JsonB
}
```

### 10.2 メトリクス
- APIリクエスト数
- レスポンスタイム
- エラーレート
- アクティブサブスクリプション数