# Scrappers API Reference

## Overview

このドキュメントは、HasuraによってGraphQL APIとして提供される各エンドポイントの詳細な仕様を説明します。

## 共通仕様

### クエリパラメータ

各エンドポイントで共通して使用可能なパラメータ：

- `where`: フィルタリング条件
- `order_by`: ソート条件
- `limit`: 取得件数制限
- `offset`: スキップする件数
- `distinct_on`: 重複を除外するフィールド

### レスポンス形式

すべてのレスポンスは以下の形式で返されます：

```graphql
{
  "data": {
    [エンドポイント名]: {
      // レスポンスデータ
    }
  }
}
```

### 認証

すべてのリクエストには適切な認証ヘッダーが必要です：

```
Authorization: Bearer <token>
```

## エンドポイント仕様

### 計量・チケット管理 API

#### TicketingWeightTicket

計量チケットの作成・管理を行うAPI

**フィールド**
- `ticketId`: UUID (主キー)
- `ticketType`: TicketTypeEnum! (INBOUND/OUTBOUND)
- `status`: TicketStatusEnum! (DRAFT/FINALIZED/CANCELLED)
- `totalWeight`: Numeric! (総重量)
- `tareWeight`: Numeric! (風袋重量)
- `netWeight`: Numeric (正味重量、自動計算)
- `supplierId`: UUID! (サプライヤーID)
- `vehicleId`: UUID (車両ID、オプショナル)
- `yardId`: UUID! (ヤードID)
- `priceApplied`: Numeric (適用価格)
- `finalizedAt`: Timestamptz (確定日時)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `financeInvoices`: [FinanceInvoice]
- `ordersLinkedTickets`: [OrdersLinkedTickets]
- `ticketingAttachments`: [TicketingAttachments]
- `ticketingComplianceInfos`: [TicketingComplianceInfo]
- `ticketingMaterialLines`: [TicketingMaterialLine]
- `partnerSupplier`: PartnerSupplier
- `fleetVehicle`: FleetVehicle
- `yardYard`: YardYard

**操作**
1. 一覧取得
```graphql
query {
  ticketingWeightTicket(
    where: TicketingWeightTicketBoolExp
    order_by: [TicketingWeightTicketOrderByExp]
    limit: Int
    offset: Int
  ) {
    ticketId
    ticketType
    status
    totalWeight
    # 他のフィールド...
  }
}
```

2. 単一レコード取得
```graphql
query {
  ticketingWeightTicketByTicketId(ticketId: UUID!) {
    ticketId
    ticketType
    status
    # 他のフィールド...
  }
}
```

3. 集計
```graphql
query {
  ticketingWeightTicketAggregate {
    aggregate {
      count
      sum {
        totalWeight
        netWeight
      }
    }
  }
}
### 在庫管理 API

#### InventoryInventoryLot

在庫ロットの管理を行うAPI

**フィールド**
- `lotId`: UUID! (主キー)
- `materialId`: UUID! (材料ID)
- `grade`: Text (グレード)
- `quantity`: Numeric! (数量)
- `unit`: UnitEnum! (単位)
- `avgCost`: Numeric! (平均原価)
- `yardId`: UUID! (ヤードID)
- `state`: LotStateEnum! (WIP/FG/SHIPPED)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `dispatchDispatchJobs`: [DispatchDispatchJob] (配送ジョブ)
- `masterMaterial`: MasterMaterial (材料マスタ)
- `yardYard`: YardYard (ヤード)
- `inventoryLotTags`: [InventoryLotTags] (ロットタグ)
- `inventoryTransferHistories`: [InventoryTransferHistory] (移動履歴)
- `ordersOrderLines`: [OrdersOrderLine] (注文明細)

**操作**
1. 一覧取得
```graphql
query {
  inventoryInventoryLot(
    where: InventoryInventoryLotBoolExp
    order_by: [InventoryInventoryLotOrderByExp]
    limit: Int
    offset: Int
  ) {
    lotId
    materialId
    quantity
    state
    # 他のフィールド...
  }
}
```

2. 単一レコード取得
```graphql
query {
  inventoryInventoryLotByLotId(lotId: UUID!) {
    lotId
    materialId
    quantity
    state
    # 他のフィールド...
  }
}
```

3. 集計
```graphql
query {
  inventoryInventoryLotAggregate {
    aggregate {
      count
      sum {
        quantity
        avgCost
      }
    }
  }
}
```

4. リレーションデータの取得例
```graphql
query {
  inventoryInventoryLot {
    lotId
    quantity
    masterMaterial {
      name
      code
    }
    inventoryLotTags {
      qrCode
    }
    inventoryTransferHistories {
      fromYardId
      toYardId
      transferredAt
    }
  }
}
### 注文管理 API

#### OrdersAbstractOrder

注文の基本情報を管理するAPI

**フィールド**
- `orderId`: UUID! (主キー)
- `orderType`: Text! (PURCHASE/SALES)
- `counterpartyId`: UUID! (取引先ID)
- `status`: OrderStatusEnum! (OPEN/PARTIALLY_FULFILLED/CLOSED/CANCELLED)
- `orderDate`: Date! (注文日)
- `expectedDate`: Date (予定日)
- `paymentTerms`: PaymentTermsEnum (支払条件)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `financeInvoices`: [FinanceInvoice] (請求書)
- `counterpartyCounterparty`: CounterpartyCounterparty (取引先)
- `ordersLinkedTickets`: [OrdersLinkedTickets] (紐付けチケット)
- `ordersOrderLines`: [OrdersOrderLine] (注文明細)

**操作**
1. 一覧取得
```graphql
query {
  ordersAbstractOrder(
    where: OrdersAbstractOrderBoolExp
    order_by: [OrdersAbstractOrderOrderByExp]
    limit: Int
    offset: Int
  ) {
    orderId
    orderType
    status
    orderDate
    # 他のフィールド...
  }
}
```

2. 単一レコード取得
```graphql
query {
  ordersAbstractOrderByOrderId(orderId: UUID!) {
    orderId
    orderType
    status
    # 他のフィールド...
  }
}
```

3. 集計
```graphql
query {
  ordersAbstractOrderAggregate {
    aggregate {
      count
    }
  }
}
```

4. リレーションデータの取得例
```graphql
query {
  ordersAbstractOrder {
    orderId
    status
    counterpartyCounterparty {
      name
    }
    ordersOrderLines {
      quantity
      price
      amount
    }
    financeInvoices {
      amount
      status
    }
  }
}
```

5. 複雑な検索例
```graphql
query {
  ordersAbstractOrder(
    where: {
      orderType: { _eq: "PURCHASE" }
      status: { _in: ["OPEN", "PARTIALLY_FULFILLED"] }
      orderDate: { _gte: "2024-01-01" }
      counterpartyCounterparty: {
        name: { _ilike: "%某社%" }
      }
    },
    order_by: [{ orderDate: desc }]
  ) {
    orderId
    orderType
    status
    orderDate
    counterpartyCounterparty {
      name
    }
    ordersOrderLines {
      materialId
      quantity
      price
      amount
    }
  }
}
### 価格管理 API

#### PricingPriceList

価格表を管理するAPI

**フィールド**
- `priceListId`: UUID! (主キー)
- `scope`: Text! (GLOBAL/YARD/CUSTOMER)
- `effectiveFrom`: Date! (適用開始日)
- `effectiveTo`: Date (適用終了日)
- `status`: PriceListStatusEnum! (DRAFT/PENDING_APPROVAL/ACTIVE/EXPIRED)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `pricingApprovalRoutes`: [PricingApprovalRoute] (承認ルート)
- `pricingPriceItems`: [PricingPriceItem] (価格アイテム)

**操作**
1. 一覧取得
```graphql
query {
  pricingPriceList(
    where: PricingPriceListBoolExp
    order_by: [PricingPriceListOrderByExp]
    limit: Int
    offset: Int
  ) {
    priceListId
    scope
    effectiveFrom
    effectiveTo
    status
    # 他のフィールド...
  }
}
```

2. 単一レコード取得
```graphql
query {
  pricingPriceListByPriceListId(priceListId: UUID!) {
    priceListId
    scope
    status
    # 他のフィールド...
  }
}
```

3. 有効な価格表の取得例
```graphql
query {
  pricingPriceList(
    where: {
      status: { _eq: "ACTIVE" }
      effectiveFrom: { _lte: "2024-04-21" }
      _or: [
        { effectiveTo: { _is_null: true } }
        { effectiveTo: { _gte: "2024-04-21" } }
      ]
    }
  ) {
    priceListId
    scope
    pricingPriceItems {
      materialId
      unitPrice
      currency
      minQty
      maxQty
    }
  }
}
```

4. 承認ワークフロー情報の取得
```graphql
query {
  pricingPriceList(
    where: { status: { _eq: "PENDING_APPROVAL" } }
  ) {
    priceListId
    scope
    pricingApprovalRoutes {
      requiredRole
      approvedBy
      approvedAt
    }
  }
}
### 配送管理 API

#### DispatchDispatchJob

配送ジョブを管理するAPI

**フィールド**
- `dispatchJobId`: UUID! (主キー)
- `lotId`: UUID! (在庫ロットID)
- `truckId`: UUID! (トラックID)
- `driverId`: UUID! (ドライバーID)
- `scheduledTime`: Timestamptz! (予定時刻)
- `status`: DispatchStatusEnum! (SCHEDULED/IN_TRANSIT/COMPLETED/CANCELLED)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `fleetDriver`: FleetDriver (ドライバー情報)
- `fleetTruck`: FleetTruck (トラック情報)
- `inventoryInventoryLot`: InventoryInventoryLot (在庫ロット)

**操作**
1. 一覧取得
```graphql
query {
  dispatchDispatchJob(
    where: DispatchDispatchJobBoolExp
    order_by: [DispatchDispatchJobOrderByExp]
    limit: Int
    offset: Int
  ) {
    dispatchJobId
    scheduledTime
    status
    # 他のフィールド...
  }
}
```

2. 単一レコード取得
```graphql
query {
  dispatchDispatchJobByDispatchJobId(dispatchJobId: UUID!) {
    dispatchJobId
    scheduledTime
    status
    # 他のフィールド...
  }
}
```

3. ドライバーと車両情報を含む配送スケジュール取得
```graphql
query {
  dispatchDispatchJob(
    where: {
      scheduledTime: { _gte: "2024-04-21T00:00:00Z" }
      status: { _in: ["SCHEDULED", "IN_TRANSIT"] }
    },
    order_by: [{ scheduledTime: asc }]
  ) {
    dispatchJobId
    scheduledTime
    status
    fleetDriver {
      name
      licenseNo
    }
    fleetTruck {
      plateNumber
      capacityKg
    }
    inventoryInventoryLot {
      quantity
      unit
      masterMaterial {
        name
      }
    }
  }
}
```

4. ドライバー別の配送実績集計
```graphql
query {
  dispatchDispatchJob(
    where: { status: { _eq: "COMPLETED" } }
  ) {
    fleetDriver {
      name
    }
    dispatchDispatchJobAggregate {
      aggregate {
        count
      }
    }
  }
}
```

5. リアルタイム配送状況監視（サブスクリプション）
```graphql
subscription {
  dispatchDispatchJob(
    where: { status: { _in: ["SCHEDULED", "IN_TRANSIT"] } }
  ) {
    dispatchJobId
    status
    scheduledTime
    fleetDriver {
      name
    }
    fleetTruck {
      plateNumber
    }
  }
}
### 請求管理 API

#### FinanceInvoice

請求書を管理するAPI

**フィールド**
- `invoiceId`: UUID! (主キー)
- `orderId`: UUID (注文ID)
- `ticketId`: UUID (計量チケットID)
- `amount`: Numeric! (請求金額)
- `currency`: CurrencyEnum! (通貨)
- `status`: InvoiceStatusEnum! (DRAFT/ISSUED/PAID/VOID)
- `issuedAt`: Timestamptz! (発行日時)
- `dueDate`: Date! (支払期限)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `ordersAbstractOrder`: OrdersAbstractOrder (注文)
- `ticketingWeightTicket`: TicketingWeightTicket (計量チケット)
- `financePayments`: [FinancePayment] (入金)

**操作**
1. 一覧取得
```graphql
query {
  financeInvoice(
    where: FinanceInvoiceBoolExp
    order_by: [FinanceInvoiceOrderByExp]
    limit: Int
    offset: Int
  ) {
    invoiceId
    amount
    currency
    status
    # 他のフィールド...
  }
}
```

2. 単一レコード取得
```graphql
query {
  financeInvoiceByInvoiceId(invoiceId: UUID!) {
    invoiceId
    amount
    status
    # 他のフィールド...
  }
}
```

3. 未払い請求書の検索
```graphql
query {
  financeInvoice(
    where: {
      status: { _eq: "ISSUED" }
      dueDate: { _lte: "2024-04-21" }
    },
    order_by: [{ dueDate: asc }]
  ) {
    invoiceId
    amount
    currency
    dueDate
    ordersAbstractOrder {
      orderType
      counterpartyCounterparty {
        name
      }
    }
  }
}
```

4. 入金状況の確認
```graphql
query {
  financeInvoice(
    where: { status: { _in: ["ISSUED", "PAID"] } }
  ) {
    invoiceId
    amount
    status
    financePayments {
      amount
      paidAt
      method
    }
    financePaymentsAggregate {
      aggregate {
        sum {
          amount
        }
      }
    }
  }
}
```

5. 請求集計
```graphql
query {
  financeInvoiceAggregate {
    aggregate {
      count
      sum {
        amount
      }
    }
  }
}
```

6. 月次請求レポート
```graphql
query {
  financeInvoice(
    where: {
      issuedAt: {
        _gte: "2024-04-01T00:00:00Z"
        _lt: "2024-05-01T00:00:00Z"
      }
    }
  ) {
    status
    financeInvoiceAggregate {
      aggregate {
        count
        sum {
          amount
        }
      }
    }
  }
}
## 共通機能

### フィルタリング

すべてのクエリで使用可能な比較演算子:

- `_eq`: 等しい
- `_neq`: 等しくない
- `_gt`: より大きい
- `_gte`: 以上
- `_lt`: より小さい
- `_lte`: 以下
- `_in`: リストに含まれる
- `_nin`: リストに含まれない
- `_is_null`: NULLである

論理演算子:
- `_and`: すべての条件を満たす
- `_or`: いずれかの条件を満たす
- `_not`: 条件を満たさない

### ソート

`order_by`パラメータで使用可能な並び順:
- `asc`: 昇順
- `desc`: 降順

### ページネーション

- `limit`: 取得件数の制限
- `offset`: スキップする件数

### リレーションデータの取得

ネストされたオブジェクトとして関連データを取得可能:
```graphql
query {
  entityName {
    id
    relationshipName {
      id
      field1
      field2
    }
  }
}
```

### 集計

集計関数:
- `count`: 件数
- `sum`: 合計
- `avg`: 平均
- `max`: 最大値
- `min`: 最小値

## 使用例

### 1. 入荷から在庫登録までの流れ

```graphql
# 1. 計量チケットの作成
mutation {
  insertTicketingWeightTicket(
    object: {
      ticketType: "INBOUND"
      status: "DRAFT"
      totalWeight: 1000
      tareWeight: 200
      supplierId: "..."
      yardId: "..."
      materialLines: {
        data: [{
          materialId: "..."
          quantity: 800
          unit: "KG"
        }]
      }
    }
  ) {
    ticketId
  }
}

# 2. 在庫ロットの登録
mutation {
  insertInventoryInventoryLot(
    object: {
      materialId: "..."
      quantity: 800
      unit: "KG"
      avgCost: 100
      yardId: "..."
      state: "WIP"
    }
  ) {
    lotId
  }
}
```

### 2. 注文から出荷までの流れ

```graphql
# 1. 注文の作成
mutation {
  insertOrdersAbstractOrder(
    object: {
      orderType: "SALES"
      counterpartyId: "..."
      status: "OPEN"
      orderDate: "2024-04-21"
      orderLines: {
        data: [{
          materialId: "..."
          quantity: 500
          unit: "KG"
          price: 150
        }]
      }
    }
  ) {
    orderId
  }
}

# 2. 配送ジョブの登録
mutation {
  insertDispatchDispatchJob(
    object: {
      lotId: "..."
      truckId: "..."
      driverId: "..."
      scheduledTime: "2024-04-22T10:00:00Z"
      status: "SCHEDULED"
    }
  ) {
    dispatchJobId
  }
}
```

### 3. 請求と入金管理

```graphql
# 1. 請求書の発行
mutation {
  insertFinanceInvoice(
    object: {
      orderId: "..."
      amount: 75000
      currency: "JPY"
      status: "DRAFT"
      issuedAt: "2024-04-21T00:00:00Z"
      dueDate: "2024-05-21"
    }
  ) {
    invoiceId
  }
}

# 2. 入金の記録
mutation {
  insertFinancePayment(
    object: {
      invoiceId: "..."
      amount: 75000
      paidAt: "2024-04-25T00:00:00Z"
      method: "BANK_TRANSFER"
    }
  ) {
    paymentId
  }
}
### 計量機器管理 API

#### ScaleGatewayScaleDevice

計量機器を管理するAPI

**フィールド**
- `deviceId`: UUID! (主キー)
- `model`: Text! (機器モデル)
- `serialNumber`: Text! (シリアル番号)
- `location`: Text (設置場所)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `scaleGatewayScaleReadings`: [ScaleGatewayScaleReading] (計量記録)

**操作**
1. 一覧取得
```graphql
query {
  scaleGatewayScaleDevice(
    where: ScaleGatewayScaleDeviceBoolExp
    order_by: [ScaleGatewayScaleDeviceOrderByExp]
  ) {
    deviceId
    model
    serialNumber
    location
  }
}
```

2. 単一レコード取得（2つの方法）
```graphql
# デバイスIDによる取得
query {
  scaleGatewayScaleDeviceByDeviceId(deviceId: UUID!) {
    deviceId
    model
    serialNumber
  }
}

# シリアル番号による取得
query {
  scaleGatewayScaleDeviceBySerialNumber(serialNumber: String!) {
    deviceId
    model
    serialNumber
  }
}
```

3. 計量記録の取得
```graphql
query {
  scaleGatewayScaleDevice {
    deviceId
    model
    location
    scaleGatewayScaleReadings(
      order_by: [{ recordedAt: desc }]
      limit: 10
    ) {
      weight
      recordedAt
    }
    scaleGatewayScaleReadingsAggregate {
      aggregate {
        count
      }
    }
  }
}
```

4. デバイス監視（サブスクリプション）
```graphql
subscription {
  scaleGatewayScaleDevice {
    deviceId
    model
    location
    scaleGatewayScaleReadings(
      limit: 1
      order_by: [{ recordedAt: desc }]
    ) {
      weight
      recordedAt
    }
  }
}
### マスターデータ管理 API

#### MasterMaterial

材料マスタを管理するAPI

**フィールド**
- `materialId`: UUID! (主キー)
- `code`: Text! (材料コード)
- `name`: Text! (材料名)
- `defaultUnit`: UnitEnum! (デフォルト単位)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `inventoryInventoryLots`: [InventoryInventoryLot] (在庫ロット)
- `ordersOrderLines`: [OrdersOrderLine] (注文明細)
- `pricingPriceItems`: [PricingPriceItem] (価格設定)
- `ticketingMaterialLines`: [TicketingMaterialLine] (計量明細)

**操作**
1. 一覧取得
```graphql
query {
  masterMaterial(
    where: MasterMaterialBoolExp
    order_by: [MasterMaterialOrderByExp]
  ) {
    materialId
    code
    name
    defaultUnit
  }
}
```

2. 単一レコード取得（2つの方法）
```graphql
# IDによる取得
query {
  masterMaterialByMaterialId(materialId: UUID!) {
    materialId
    code
    name
    defaultUnit
  }
}

# コードによる取得
query {
  masterMaterialByCode(code: String!) {
    materialId
    code
    name
    defaultUnit
  }
}
```

3. 在庫状況の確認
```graphql
query {
  masterMaterial {
    materialId
    code
    name
    inventoryInventoryLots(
      where: { state: { _eq: "FG" } }
    ) {
      quantity
      unit
      yardYard {
        name
      }
    }
    inventoryInventoryLotsAggregate {
      aggregate {
        sum {
          quantity
        }
      }
    }
  }
}
```

4. 価格履歴の確認
```graphql
query {
  masterMaterial {
    materialId
    code
    name
    pricingPriceItems(
      where: {
        pricingPriceList: {
          status: { _eq: "ACTIVE" }
        }
      }
    ) {
      unitPrice
      currency
      minQty
      maxQty
      pricingPriceList {
        effectiveFrom
        effectiveTo
      }
    }
  }
}
```

5. 取引履歴の分析
```graphql
query {
  masterMaterial {
    materialId
    name
    ticketingMaterialLines(
      where: {
        ticketingWeightTicket: {
          status: { _eq: "FINALIZED" }
          ticketType: { _eq: "INBOUND" }
        }
      }
    ) {
      quantity
      ticketingWeightTicket {
        finalizedAt
      }
    }
    ordersOrderLines(
      where: {
        ordersAbstractOrder: {
          orderType: { _eq: "SALES" }
        }
      }
    ) {
      quantity
      price
      amount
    }
  }
}
### 認証・認可管理 API

#### IdentityUsers

ユーザー管理を行うAPI

**フィールド**
- `userId`: UUID! (主キー)
- `username`: Text! (ユーザー名)
- `email`: Text! (メールアドレス)
- `passwordHash`: Text! (パスワードハッシュ)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**リレーション**
- `identityAuditLogs`: [IdentityAuditLog] (監査ログ)
- `identityUserRoles`: [IdentityUserRoles] (ロール割り当て)
- `pricingApprovalRoutes`: [PricingApprovalRoute] (価格承認ルート)
- `supportSupportTickets`: [SupportSupportTicket] (サポートチケット)

**操作**
1. 一覧取得
```graphql
query {
  identityUsers(
    where: IdentityUsersBoolExp
    order_by: [IdentityUsersOrderByExp]
  ) {
    userId
    username
    email
    # 他のフィールド...
  }
}
```

2. 単一ユーザー取得（3つの方法）
```graphql
# IDによる取得
query {
  identityUsersByUserId(userId: UUID!) {
    userId
    username
    email
  }
}

# ユーザー名による取得
query {
  identityUsersByUsername(username: String!) {
    userId
    username
    email
  }
}

# メールアドレスによる取得
query {
  identityUsersByEmail(email: String!) {
    userId
    username
    email
  }
}
```

3. ユーザーロールの取得
```graphql
query {
  identityUsers {
    userId
    username
    identityUserRoles {
      identityRoles {
        name
        identityRolePermissions {
          identityPermissions {
            name
          }
        }
      }
    }
  }
}
```

4. 監査ログの確認
```graphql
query {
  identityUsers {
    userId
    username
    identityAuditLogs(
      order_by: [{ timestamp: desc }]
      limit: 10
    ) {
      action
      resource
      resourceId
      timestamp
      details
    }
  }
}
```

5. 承認タスクの確認
```graphql
query {
  identityUsers {
    userId
    username
    pricingApprovalRoutes(
      where: { approvedAt: { _is_null: true } }
    ) {
      requiredRole
      pricingPriceList {
        effectiveFrom
        effectiveTo
        status
      }
    }
  }
}
```

#### セキュリティに関する注意事項

1. パスワードハッシュ
- passwordHashフィールドは慎重に扱う必要があります
- クライアントサイドでの表示は避けてください

2. ロールベースアクセス制御
- すべてのAPIエンドポイントはロールベースのアクセス制御が適用されています
- 適切な認証ヘッダーと必要な権限が必要です

3. 監査ログ
- すべての重要な操作は自動的に監査ログに記録されます
- 監査ログはセキュリティ分析に活用してください
### 取引先管理 API

#### CounterpartyCounterparty

取引先情報を管理するAPI

**フィールド**
- `counterpartyId`: UUID! (主キー)
- `name`: Text! (取引先名)
- `kind`: Text! (CUSTOMER/VENDOR)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**操作**
1. 取引先の検索
```graphql
query {
  counterpartyCounterparty(
    where: {
      kind: { _eq: "CUSTOMER" }
      name: { _ilike: "%株式会社%" }
    }
  ) {
    counterpartyId
    name
    kind
  }
}
```

### 車両・ドライバー管理 API

#### FleetVehicle/FleetTruck

車両情報を管理するAPI

**フィールド**
- `vehicleId/truckId`: UUID! (主キー)
- `plateNumber`: Text! (ナンバープレート)
- `capacityKg`: Numeric (積載容量、トラックの場合)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

#### FleetDriver

ドライバー情報を管理するAPI

**フィールド**
- `driverId`: UUID! (主キー)
- `name`: Text! (ドライバー名)
- `licenseNo`: Text! (免許証番号)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**操作例**
```graphql
# 車両とドライバーの割り当て状況確認
query {
  dispatchDispatchJob(
    where: { status: { _eq: "SCHEDULED" } }
  ) {
    scheduledTime
    fleetTruck {
      plateNumber
      capacityKg
    }
    fleetDriver {
      name
      licenseNo
    }
  }
}
```

### システム設定 API

#### ConfigurationSettings

システム設定を管理するAPI

**フィールド**
- `settingKey`: Text! (主キー)
- `settingValue`: JSONB! (設定値)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

#### ConfigurationTemplates

テンプレートを管理するAPI

**フィールド**
- `templateId`: UUID! (主キー)
- `name`: Text! (テンプレート名)
- `content`: Text! (テンプレート内容)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

### レポート管理 API

#### ReportingReportDefinition

レポート定義を管理するAPI

**フィールド**
- `reportDefinitionId`: UUID! (主キー)
- `name`: Text! (レポート名)
- `description`: Text (説明)
- `query`: JSONB! (クエリ定義)
- `schedule`: ScheduleEnum! (実行スケジュール)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**操作例**
```graphql
# スケジュール済みレポートの取得
query {
  reportingReportDefinition(
    where: { schedule: { _neq: "ON_DEMAND" } }
  ) {
    name
    description
    schedule
    reportingReportRuns(
      order_by: [{ executedAt: desc }]
      limit: 1
    ) {
      executedAt
      resultLocation
    }
  }
}
### コンプライアンス管理 API

#### ComplianceIdentityRecord

本人確認記録を管理するAPI

**フィールド**
- `identityId`: UUID! (主キー)
- `individualName`: Text (個人名)
- `documentType`: DocumentTypeEnum (PASSPORT/DRIVERS_LICENSE/NATIONAL_ID)
- `documentNumber`: Text (書類番号)
- `issuedDate`: Date (発行日)
- `expiryDate`: Date (有効期限)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**操作例**
```graphql
# 期限切れ間近の本人確認書類の検索
query {
  complianceIdentityRecord(
    where: {
      expiryDate: {
        _gte: "2024-04-21"
        _lte: "2024-05-21"
      }
    }
  ) {
    individualName
    documentType
    documentNumber
    expiryDate
  }
}
```

### カスタムフィールド管理 API

#### ConfigurationCustomFieldDef

カスタムフィールドを定義するAPI

**フィールド**
- `customFieldDefId`: UUID! (主キー)
- `context`: CustomFieldContextEnum! (TICKET/INVENTORY/ORDER)
- `fieldName`: Text! (フィールド名)
- `fieldType`: CustomFieldTypeEnum! (TEXT/NUMBER/DATE/BOOLEAN)
- `metadata`: JSONB (追加設定)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**操作例**
```graphql
# コンテキスト別のカスタムフィールド取得
query {
  configurationCustomFieldDef(
    where: { context: { _eq: "TICKET" } }
  ) {
    fieldName
    fieldType
    metadata
  }
}
```

### 監査ログ API

#### IdentityAuditLog

システム操作の監査ログを管理するAPI

**フィールド**
- `auditLogId`: UUID! (主キー)
- `userId`: UUID (操作ユーザーID)
- `action`: Text! (実行アクション)
- `resource`: AuditResourceEnum! (操作対象リソース)
- `resourceId`: UUID (対象リソースID)
- `timestamp`: Timestamptz! (実行時刻)
- `details`: JSONB (詳細情報)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**操作例**
```graphql
# リソース種別ごとの操作ログ取得
query {
  identityAuditLog(
    where: {
      resource: { _eq: "WEIGHT_TICKET" }
      timestamp: { _gte: "2024-04-14T00:00:00Z" }
    },
    order_by: [{ timestamp: desc }]
  ) {
    action
    timestamp
    details
    identityUsers {
      username
    }
  }
}
```

### ヤード管理 API

#### YardYard

ヤード情報を管理するAPI

**フィールド**
- `yardId`: UUID! (主キー)
- `name`: Text! (ヤード名)
- `location`: Text (所在地)
- `createdAt`: Timestamptz!
- `updatedAt`: Timestamptz!

**操作例**
```graphql
# ヤードごとの在庫状況確認
query {
  yardYard {
    name
    location
    inventoryInventoryLots(
      where: { state: { _eq: "FG" } }
    ) {
      masterMaterial {
        name
      }
      quantity
      unit
    }
    inventoryInventoryLotsAggregate {
      aggregate {
        count
      }
    }
  }
}