# scrappers_api セットアップ & データモデル概要

このリポジトリでは **Hasura DDN (Distributed Data Network)** を用いて、PostgreSQL 上に構築した大規模ドメインモデルを **スーパーグラフ API** として公開するまでのローカル開発フローをまとめています。Quick Start レベルの手順では物足りない方、複数スキーマ・FK・トリガが入り組んだ本格的スキーマを DDN で試してみたい方に向けた README です。

---
## 目次
1. 前提条件
2. クイックセットアップ手順
3. ローカル開発ワークフロー詳細
4. データモデル概要
5. よくあるトラブルシューティング
6. 参考リンク

---
## 1. 前提条件
| ツール | バージョン | 備考 |
|--------|------------|------|
| **DDN CLI** | `>= v2.28.0` | `curl -L https://graphql-engine-cdn.hasura.io/ddn/cli/v4/get.sh \| bash` で入手 |
| **Docker Desktop / Engine** | Compose `>= v2.20` | ローカル Engine & Connector のビルド／実行に利用 |
| **macOS / Linux / Windows** | WSL2 推奨 | ARM-Linux は現状 CLI がネイティブ対応していません |

> ⚠️ **環境変数**  
> - `HASURA_DDN_PAT` … Cloud 連携が必要な場合のみ設定（ローカル完結なら不要）
> - `.env` … DDN CLI が生成・参照する Connector 向け環境変数を保持

---
## 2. クイックセットアップ手順 ✨
```bash
# 0) リポジトリを clone
$ git clone <this repo> && cd scrappers_api

# 1) CLI ログイン（ブラウザが開きます）
$ ddn auth login

# 2) Supergraph プロジェクトを初期化
$ ddn supergraph init app && cd app

# 3) Postgres Connector を作成（ローカル DB を同時生成）
$ ddn connector init scrappers_api -i  # hub-connector は hasura/postgres を選択

# 4) サンプル DB（巨大 DDL）を流し込む
$ docker compose -f connector/scrappers_api/compose.postgres-adminer.yaml up -d
$ psql -h localhost -p 5711 -U user dev < ../../ddl/all_schema.sql

# 5) スキーマを再インポート
$ ddn connector introspect scrappers_api

# 6) モデル・コマンド・リレーションを一括生成
$ ddn model add scrappers_api "*"
$ ddn command add scrappers_api "*"
$ ddn relationship add scrappers_api "*"

# 7) Supergraph ビルド & ローカル Engine 起動
$ ddn supergraph build local
$ ddn run docker-start   # ← ログ用タブで実行したままにする

# 8) 別タブで GraphQL コンソール起動
$ ddn console --local  # ブラウザが http://localhost:3280 へ接続
```
これで **GraphiQL** から全モデルに対し Query／Mutation が叩ける状態になります 🎉

---
## 3. ローカル開発ワークフロー詳細
| フェーズ | コマンド | 説明 |
|-----------|----------|------|
| **DDL 変更** | psql / Adminer / 他 | DB スキーマを編集（例: テーブル追加） |
| **再インポート** | `ddn connector introspect` | 変更を DDN メタデータへ反映 |
| **メタデータ更新** | `ddn model/command/relationship add` | 新リソースを追跡する |
| **ビルド** | `ddn supergraph build local` | JSON アーティファクト生成 (`engine/build`) |
| **実行** | `ddn run docker-start` | Engine + Connector コンテナを再起動 |
| **テスト** | `ddn console --local` | GraphiQL で確認 |

> 📝 **TIPS**  
> `docker compose down` で孤立した旧コンテナを掃除してから再起動するとポート競合を防げます。

---
## 4. データモデル概要
### サブドメイン毎の主要テーブル
| サブドメイン | 代表テーブル | 役割 |
|--------------|--------------|------|
| **master** | `material` | 材料マスタ |
| **partner** | `supplier` | 仕入先マスタ |
| **yard** | `yard` | ヤード（拠点） |
| **fleet** | `vehicle`, `truck`, `driver` | 車両・ドライバー管理 |
| **counterparty** | `counterparty` | 取引先（得意先・仕入先） |
| **identity** | `users`, `roles`, `permissions` | 認証・権限 |
| **scale_gateway** | `scale_device`, `scale_reading` | 計量器連携 |
| **ticketing** | `weight_ticket`, `material_line` | 入出荷計量チケット |
| **inventory** | `inventory_lot`, `transfer_history` | 在庫ロット・移動履歴 |
| **orders** | `abstract_order`, `order_line` | 受発注ヘッダ／明細 |
| **pricing** | `price_list`, `price_item` | 価格表管理 |
| **dispatch** | `dispatch_job` | 配車ジョブ |
| **finance** | `invoice`, `payment` | 請求・入金 |
| **reporting** | `report_definition`, `report_run` | 帳票定義・実行履歴 |
| **configuration** | `settings`, `custom_field_def` | 設定・カスタム項目 |
| **support** | `support_ticket`, `kb_article` | サポート問い合わせ |

*FK/リレーション* は DDN が自動生成したスキーマを通じ、ネストクエリで横断的に取得可能です（例：`weightTicket { supplier { name } }`）。

---
## 5. よくあるトラブルシューティング

### データベース関連

1. 拡張機能 (pgcrypto) の権限
   ```sql
   -- 開発環境では dev ロールに SUPERUSER 権限を付与
   ALTER ROLE dev WITH SUPERUSER;
   -- または
   GRANT CREATE ON DATABASE dev TO dev;
   ```

2. テーブル参照の外部キー制約
   - Identity & Security セクションを先に作成
   - または後付けで ALTER TABLE で FK を追加

3. サブクエリを使用した CHECK 制約
   - PostgreSQL の制限により、CHECK 制約内でのサブクエリは使用不可
   - 代わりにトリガ関数で実装

4. トリガ名の重複
   - スキーマ内でユニークな命名が必要
   - 例: `trg_upd_<schema>_<table>` の形式を使用

5. TG_OP の参照方法
   - SQL 文中での直接参照は不可
   - PL/pgSQL のIF文で分岐処理を実装

### DDN関連

| 症状 | 原因 / 対処 |
|------|-------------|
| `unable to initialize connection pool` | Postgres コンテナが起動していない / `docker compose up -d` で再起動 |
| `validation failed: no such field on type Query` | **ビルドし忘れ**。DDL 変更後は必ず `introspect → build` まで実行 |
| `404 /healthz` | Engine のポート公開が 3280 以外になっている。`docker ps` で確認 |
| `Cannot print PromptQL secret key` | Cloud 連携機能を無効のまま `ddn run docker-start` しているだけなので無視可 |

---
## 6. 参考リンク
- [Hasura DDN ドキュメント](https://hasura.io/docs/latest/ddn/)  
- [Connector Hub – hasura/postgres](https://hasura.io/hub/connectors/hasura/postgres)