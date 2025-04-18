# ドメインモデル設計ドキュメント

> **バージョン**: 1.0 (Draft)
> **作成日**: 2025-04-19
> **作成者**: プロジェクトアーキテクト ChatGPT

---

## 1. 目的・概要

本ドキュメントは、リサイクル／資源管理システムのコアフロー（計量チケット → 在庫 → 受発注 → 決済）を中心に設計されたドメインモデルを、詳細にまとめたものです。ドメイン言語、集約（Aggregates）ごとの責務、不変条件、イベント連携パターン、技術スタックへのマッピングを網羅しています。

### 1.1 コアドメインとサブドメイン

- **コアドメイン**: Ticketing, Inventory, Orders, Pricing
- **サポート / 汎用サブドメイン**: Scale Gateway, Dispatch, Finance, Compliance, Reporting, Identity & Security, Configuration, Support

---

## 2. コンテキストマップ

| バウンデッドコンテキスト        | 主なユースケース / サブドメイン                         | 代表エンティティ / 集約                                                                                          | 主なインターフェース                       |
|-------------------------------|---------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|--------------------------------------------|
| **Scale Gateway**             | - 計量器からのリアルタイム重量取得<br>- 誤入力防止 & デバイス監視 | - **ScaleDevice**（値オブジェクト）<br>- **ScaleReading**（イベント）                                                  | 直結ドライバ、gRPC / REST / WebSocket     |
| **Ticketing**                 | - 計量チケットの発行・確定<br>- 写真 / ID スキャン添付       | - **WeightTicket**（集約ルート）<br>  - MaterialLine VO<br>  - ComplianceInfo VO                                          | REST API、ドメインイベント `TicketFinalized` |
| **Inventory**                 | - 在庫ロット生成・移動・評価<br>- QR タグ付与 & スキャン     | - **InventoryLot**（集約）<br>  - LotTag VO                                                                         | 内部イベント `InventoryAdjusted`         |
| **Pricing**                   | - 品目別価格表管理<br>- 個別契約価格<br>- ロック/承認フロー | - **PriceList**（集約）<br>  - PriceItem VO<br>  - **ContractPrice**（独立集約）                                           | REST API、LME 価格インポート             |
| **Orders**                    | - 購買/販売オーダーライフサイクル<br>- 計量/出荷実績リンク  | - **PurchaseOrder / SalesOrder**（集約）<br>  - OrderLine VO                                                             | REST API、ドメインイベント               |
| **Dispatch**                  | - コンテナ & トラック配車計画<br>- ドライバー実績登録       | - **DispatchJob**（集約）<br>  - AssetRef VO                                                                           | モバイル API、GPS コールバック           |
| **Finance**                   | - 支払/請求生成・入出金登録<br>- 仕訳エクスポート         | - **Payment / Invoice**（集約）<br>- **JournalEntry**（イベントストア風）                                                 | QuickBooks API、ATM ドライバ              |
| **Compliance**                | - 本人確認/規制報告ファイル生成<br>- LeadsOnline アップロード | - **IdentityRecord** VO<br>- **RegulatoryReport**（集約）                                                              | File / SFTP、政府系 API                |
| **Reporting**                 | - カスタムレポート定義 & 実行<br>- ダッシュボード配信      | - **ReportDefinition**（メタ）<br>- **ReportRun**（結果）                                                              | REST API、CSV / PDF エクスポート、Webhook |
| **Identity & Security**       | - ユーザー/ロール/権限<br>- 2FA, 監査ログ               | - **User**（集約）<br>- Role / Permission VO<br>- **AuditLog**（イベント購読者）                                           | OIDC / SAML、SCIM                     |
| **Configuration**             | - カスタムフィールド & テンプレート<br>- 承認ワークフロー設定 | - **Setting**（KV）<br>- CustomFieldDef / Template                                                                   | 管理者 API                             |
| **Support**                   | - サポートチケット & ナレッジ<br>- オンボーディング進捗管理 | - **SupportTicket**（集約）<br>- **KBArticle**                                                                        | ヘルプデスク API、チャットウィジェット      |

---

## 3. 集約ごとの内部モデル

### 3.1 WeightTicket 集約 (Ticketing)
```text
WeightTicket (
  ticketId,
  ticketType,
  status,
  totalWeight,
  tareWeight,
  netWeight,
  supplierId,
  vehicleId,
  yardId,
  priceApplied,
  createdAt,
  finalizedAt
)
 ├─ MaterialLine[ ] (materialId, grade, quantity, unit)
 ├─ ComplianceInfo (identityId, fingerprintHash, idScanUrl, photos[ ])
 ├─ Attachments[ ] (url, type, createdAt)
 └─ Domain Events
      • TicketFinalized
      • TicketCancelled
```
**不変条件**:
- `netWeight = totalWeight − tareWeight`
- `status` 遷移: `Draft → Finalized → (optional) Cancelled`（単射）
- `ComplianceInfo` の必須チェックは `Configuration` に定義された州/取引区分ルールに従う

---

### 3.2 InventoryLot 集約 (Inventory)
```text
InventoryLot (
  lotId,
  materialId,
  grade,
  quantity,
  unit,
  avgCost,
  yardId,
  state [WIP|FG|SHIPPED],
  createdAt,
  updatedAt
)
 ├─ LotTag (qrCode, printedAt)
 ├─ TransferHistory[ ] (fromYardId, toYardId, quantity, timestamp)
 └─ Domain Events
      • InventoryAdjusted
      • LotTransferred
```
**不変条件**:
- `quantity ≥ 0`（負在庫禁止）
- `state` 遷移: `WIP → FG → SHIPPED`

---

### 3.3 PurchaseOrder / SalesOrder 集約 (Orders)
```text
AbstractOrder (
  orderId,
  orderType {PURCHASE|SALES},
  counterpartyId,
  status [OPEN|PARTIALLY_FULFILLED|CLOSED|CANCELLED],
  orderDate,
  expectedDate,
  paymentTerms
)
 ├─ OrderLine[ ] (materialId, quantity, unit, price, lotRef?)
 ├─ LinkedTickets[ ] (ticketId, netWeight)
 └─ Domain Events
      • OrderFulfilled
      • OrderAdjusted
```
---

### 3.4 PriceList 集約 (Pricing)
```text
PriceList (
  priceListId,
  scope [GLOBAL|YARD|CUSTOMER],
  effectiveFrom,
  effectiveTo,
  status
)
 ├─ PriceItem[ ] (materialId, unitPrice, currency, minQty, maxQty)
 ├─ ApprovalRoute (requiredRole, approvedBy, approvedAt)
 └─ Domain Events
      • PriceChanged
```

---

## 4. ドメインイベント & サービス連携パターン

| イベント                   | 発行コンテキスト | サブスクライバ           | 主なリアクション                                               |
|----------------------------|------------------|--------------------------|---------------------------------------------------------------|
| `TicketFinalized`          | Ticketing        | Inventory, Finance       | - WIP 在庫ロット生成<br>- 平均コスト計算<br>- Invoice の Pending 作成 |
| `LotTransferred`           | Inventory        | Dispatch                 | - 拠点間移動の配車ジョブ自動生成                                   |
| `OrderFulfilled`           | Orders           | Finance                  | - 売上/仕入計上                                                |
| `PriceChanged`             | Pricing          | Ticketing, Orders        | - 価格キャッシュ更新                                           |
| `PaymentCompleted`         | Finance          | Orders                   | - オーダーステータス更新                                        |
| `ComplianceReportReady`    | Compliance       | Government Adapter       | - 自治体システムへレポート送信                                   |

*非同期イベントは Kafka / NATS などのイベントバスでやりとり、外部連携は専用アダプタで処理。*

---

## 5. 技術アーキテクチャへのマッピング

| レイヤ           | 推奨技術例                       | 補足                                                          |
|------------------|----------------------------------|--------------------------------------------------------------|
| **API (Edge)**   | GraphQL (Hasura DDN), REST Gateway | BFF でロールベースのフィールドフィルタリング                  |
| **Application**  | NestJS, Go, .NET                 | Command / Event Handler モデル                                |
| **Domain**       | TypeScript, Kotlin               | クリーンアーキテクチャ、値オブジェクトの不変性担保          |
| **Persistence**  | PostgreSQL                       | スキーマ単位分離、EventStoreDB でイベントストアを管理         |
| **Messaging**    | Kafka, NATS JetStream            | Exactly-once producer, Outbox パターン                       |
| **Identity**     | Auth0, Azure AD (OIDC)           | Hasura JWT + RLS で権限制御                                   |
| **Compliance Docs** | AWS S3 + Object Lock           | イミュータブルストレージ                                      |
| **Reporting DW** | BigQuery, Redshift               | CDC で OLTP → OLAP 同期                                       |
| **DevOps**       | Kubernetes, ArgoCD, Terraform    | コンテキスト単位の Helm Chart                                 |

---

## 6. バウンデッドコンテキスト間依存関係ダイアグラム

```mermaid
flowchart LR
    ScaleGateway -->|Ticket| Ticketing
    Ticketing -- TicketFinalized --> Inventory
    Inventory -- LotTransferred --> Dispatch
    Orders -- PriceChanged --> Ticketing
    Pricing -->|PriceChanged| Orders
    Finance <--|OrderFulfilled| Orders
    Finance <--|TicketFinalized| Ticketing
```  
*太線: 非同期イベント / 細線: 同期 API 呼び出し*

---

## 7. 典型的ユーザーストーリー

### 7.1 仕入計量フロー
1. `ScaleGateway` が重量をポーリング → `ScaleReading` 発行
2. オペレータが UI でサプライヤー・材料選択し `WeightTicket` を Draft 保存
3. 車両退出後、ネット重量自動算出 → `TicketFinalized` 発火
4. `Inventory` が WIP ロット生成 & コスト記録
5. `Finance` が支払いレコード (Pending) を作成

### 7.2 販売出荷フロー
1. セールスが `SalesOrder` を OPEN で登録
2. 倉庫担当が在庫ロットを引当 → `state = SHIPPED`
3. `Dispatch` が配車ジョブを作成 (BOL 自動生成)
4. 取引確定後 `Finance` が `Invoice` を発行 → 入金待ち

---

## 8. 設計ディスカッション用チェックリスト

- **集約境界の粒度**: 一チケット内で複数材料を保持しても要件を満たすか？
- **ID 体系**: ULID 統一 vs コンテキストローカル連番
- **通貨・単位換算**: 多通貨サポート & kg↔t 丸め戦略
- **履歴保管**: Event Sourcing vs Temporal Tables
- **承認ワークフロー**: プラグイン型 vs BPMN 外部化
- **ハードウェア連携**: ドライバ実装言語 & gRPC 設計
- **レポート性能**: OLAP スキーマ vs マテリアライズドビュー
- **セキュリティ**: RLS, 属性ベースアクセス制御
- **マルチテナンシー**: DB 分離 vs スキーマ分離 vs Row 分離

---

## 9. 今後の展望

1. TDD による Hasura DDN 実装ドキュメント化
2. Next.js プロトタイプとの統合テスト
3. パフォーマンス・セキュリティ評価
4. 本番移行に向けた運用設計

---

*以上が詳細なドメインモデル設計ドキュメントです。ご意見・ご質問があればフィードバックをお願いします。*

