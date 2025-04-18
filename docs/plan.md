フェーズ0. 全体設計・環境準備
リポジトリ構成の確立

mono‑repo（例: packages/backend, packages/frontend） or multi‑repo を選定

共通ルール（ESLint／Prettier／EditorConfig）をルートに配置

ツールチェイン選定

Hasura CLI + metadata YAML（Git 管理）

Next.js 14（App Router or Pages）

Jest + Testing Library for unit/integration tests

Cypress or Playwright for E2E

GraphQL Code Generator for型安全なクエリ／ミューテーション

CI: GitHub Actions（プルリクエストで自動テスト／Hasura metadata のバリデーション）

Shared Types／ドメイン定義

packages/shared/types/ に TypeScript のインターフェース（WeightTicket, InventoryLot…）を定義

Hasura のテーブル設計と厳密に一致させる

フェーズ1. ドメインモデル → Hasura DDN 定義
1.1 テーブル／View 定義（metadata/schema.graphql または metadata/tables.yaml）
まずは最小スコープ：weight_tickets, inventory_lots, purchase_orders, price_lists から開始

TDD サイクル

失敗するテストを書く

ts
コピーする
編集する
// tests/graphql/weightTicket.test.ts
import { graphqlClient } from "../../src/hasuraClient";
test("Draft の WeightTicket を生成できる", async () => {
  const CREATE_TICKET = `
    mutation CreateTicket($input: weight_tickets_insert_input!) {
      insert_weight_tickets_one(object: $input) {
        ticketId
        status
      }
    }
  `;
  // Draft → まだ status フィールドが認識されないはず
  await expect(
    graphqlClient.request(CREATE_TICKET, { input: {/*…*/} })
  ).rejects.toThrow();
});
テーブル／カラムを追加 → Hasura metadata に反映

テストをパスさせる → Hasura CLI で hasura metadata apply して再実行

1.2 ビジネスルールの表現
netWeight = totalWeight − tareWeight は generated column で実装

yaml
コピーする
編集する
tables:
  - table:
      schema: public
      name: weight_tickets
    columns:
      - name: netWeight
        is_generated: STORED
        generation_expression: "(totalWeight - tareWeight)"
テスト: netWeight が自動計算されるかを GraphQL 経由で検証

フェーズ2. Action／Event Trigger 設計
2.1 Domain Event のトリガー
TicketFinalized → 在庫ロット生成用の Event Trigger を Hasura に設定

TDD サイクル

失敗テスト: ticket.status を Finalized に更新しても InventoryLot が生成されない

Trigger 定義（metadata/actions.yaml）を追加

テストパス:

ts
コピーする
編集する
test("Finalized 時に InventoryLot が生成される", async () => {
  // Draft → Finalize mutation 実行
  // InventoryLot テーブルをクエリして 1 件存在することを確認
});
2.2 Remote Schema / Action
複雑な承認フロー（ApprovalRoute）や外部連携は Hasura Actions で実装

テスト:

モックサーバーを立てて、Action エンドポイントへのリクエスト／レスポンスを検証

フェーズ3. Next.js フロントエンドのプロトタイプ
3.1 GraphQL Codegen & 型安全
codegen.yml を用意して、Hasura のスキーマから TypeScript 型を生成

テスト:

yarn codegen → 型エラーが発生しないことを CI テストに含める

3.2 コンポーネント単体テスト
例: TicketForm.tsx

テストファースト:

tsx
コピーする
編集する
// __tests__/TicketForm.test.tsx
import { render, screen, fireEvent } from "@testing-library/react";
import { TicketForm } from "../components/TicketForm";
test("必須フィールドに入力せず送信するとバリデーションエラー", async () => {
  render(<TicketForm />);
  fireEvent.click(screen.getByText("作成"));
  expect(await screen.findByText("サプライヤーを選択してください")).toBeInTheDocument();
});
実装: バリデーション付きフォームを完成させ、テストをパスさせる

3.3 ページ／ルーティングテスト
Next.js の App Router で /tickets/new ページを作成

React Testing Library + Next.js テスティングユーティリティ で以下を検証：

正しい初期状態

GraphQL mutation 実行後、画面遷移 or 通知表示

フェーズ4. 統合テスト & E2E
ハンドラブルなテスト環境

Docker Compose で Hasura + Postgres + Next.js を立ち上げ

Cypress / Playwright で典型フローを自動化

「チケット作成 → Finalize → 在庫ロット生成 → フロント画面に反映」までをシナリオ化

CI パイプライン

cypress run or npx playwright test を GitHub Actions に組み込み

フェーズ5. CI／CD と品質担保
Pull Request 毎に

yarn lint / yarn type-check

yarn test:unit / yarn test:integration

yarn test:e2e

hasura metadata validate

デプロイ

Hasura Cloud or Self‑hosted へメタデータ自動同期

Vercel に Next.js を自動デプロイ

フェーズ6. プロトタイプ評価＋フィードバック
MVP 機能リスト と照らし合わせ、抜け漏れチェック

パフォーマンス計測（GraphQL クエリレイテンシ、ページロード時間）

セキュリティレビュー（RLS / JWT 設定、XSS／CSRF）

次フェーズ:

ドメインイベントの監視ダッシュボード構築

支払／請求フロー（Finance）の TDD 実装

まとめ
TDD サイクル を各層（Hasura スキーマ／Action、Next.js コンポーネント、E2E）で徹底

Hasura DDN の metadata-as‑code によるバージョン管理

CI／CD で常に品質担保されたプロトタイプを高速に反復

最小限のスコープから始め、領域ごとにテストを先行させることで着実にビジネス価値を形にする

このプランに沿って開発を進めれば、「計量チケット ⇔ 在庫 ⇔ 受発注 ⇔ 決済」のコアフローを Hasura＋Next.js で高品質かつ可視性の高いプロトタイプとしてローンチできます。ぜひ最初のテストファイル作成からスタートしましょう！