git commit# リサイクル／資源管理システム

## 概要

このシステムは、リサイクル業界向けの統合管理プラットフォームです。計量チケットの発行から在庫管理、受発注、決済まで、リサイクルビジネスの主要な業務フローをカバーします。

## 主要機能

### 1. 計量・チケット発行 (Ticketing)
- 計量器からのリアルタイム重量取得
- 計量チケットの発行・確定
- 写真・ID スキャンの添付
- コンプライアンス情報の管理

### 2. 在庫管理 (Inventory)
- 在庫ロットの生成・移動・評価
- QRタグ付与とスキャン機能
- ロケーション管理
- 在庫移動履歴の追跡

### 3. 受発注管理 (Orders)
- 購買/販売オーダーのライフサイクル管理
- 計量/出荷実績との連携
- 価格表との連動
- 配車計画との連携

### 4. 価格管理 (Pricing)
- 品目別価格表の管理
- 個別契約価格の設定
- 承認フローの制御
- 価格履歴の追跡

## アーキテクチャ

### バックエンド
- Hasura DDN (Distributed Data Network)
- PostgreSQL データベース
- イベント駆動アーキテクチャ
- マイクロサービス構成

### フロントエンド
- Next.js 14 (App Router)
- GraphQL (型安全なAPI通信)
- TailwindCSS
- Jest + Testing Library

### インフラストラクチャ
- Kubernetes / Docker
- Kafka / NATS (イベントバス)
- AWS S3 (コンプライアンス文書保管)
- BigQuery / Redshift (レポーティング)

## 開発環境のセットアップ

```bash
# 必要なツール
Node.js ≥ 18 LTS
npm ≥ 10
Docker Desktop (最新版)
Hasura DDN CLI v4.x

# インストール
git clone [repository-url]
cd [repository-name]
npm install

# 開発サーバー起動
npm run dev
```

## プロジェクト構成

```
.
├── packages/
│   ├── backend/      # Hasura DDN / カスタムアクション
│   ├── frontend/     # Next.js アプリケーション
│   └── shared/       # 共有型定義・ユーティリティ
├── hasura/
│   └── metadata/     # Hasura DDN メタデータ
└── docs/            # プロジェクトドキュメント
```

## テスト

```bash
# ユニット/統合テスト
npm test

# E2Eテスト
npm run test:e2e
```

## 品質管理

- ESLint / Prettier によるコード品質の維持
- Jest によるユニットテスト
- Cypress による E2E テスト
- GitHub Actions による CI/CD
- Hasura メタデータの自動検証

## ライセンス

プロプライエタリ

## コントリビューション

1. main ブランチから feature ブランチを作成
2. コミットメッセージは[Conventional Commits](https://www.conventionalcommits.org/)に従う
3. プルリクエストを作成
4. レビュー後、main ブランチにマージ

## 技術サポート

- バグ報告は GitHub Issues へ
- 技術的な質問は Discussion フォーラムへ
