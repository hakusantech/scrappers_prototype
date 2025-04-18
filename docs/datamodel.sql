/* ========================================================================
   0. 拡張機能
   ======================================================================== */
CREATE EXTENSION IF NOT EXISTS pgcrypto;

/* ========================================================================
   1. スキーマ定義
   ======================================================================== */
CREATE SCHEMA IF NOT EXISTS common;
CREATE SCHEMA IF NOT EXISTS master;        -- 材料などのマスタ
CREATE SCHEMA IF NOT EXISTS partner;       -- 取引先
CREATE SCHEMA IF NOT EXISTS yard;          -- ヤード
CREATE SCHEMA IF NOT EXISTS fleet;         -- 車両・ドライバー
CREATE SCHEMA IF NOT EXISTS counterparty;  -- 受発注の相手先
/* ――― 既存ドメインスキーマ ――― */
CREATE SCHEMA IF NOT EXISTS scale_gateway;
CREATE SCHEMA IF NOT EXISTS ticketing;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS orders;
CREATE SCHEMA IF NOT EXISTS pricing;
CREATE SCHEMA IF NOT EXISTS dispatch;
CREATE SCHEMA IF NOT EXISTS finance;
CREATE SCHEMA IF NOT EXISTS compliance;
CREATE SCHEMA IF NOT EXISTS reporting;
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS configuration;
CREATE SCHEMA IF NOT EXISTS support;

/* ========================================================================
   2. ENUM（すべて確定値化）
   ======================================================================== */
-- コア
CREATE TYPE ticket_status_enum        AS ENUM ('DRAFT','FINALIZED','CANCELLED');
CREATE TYPE ticket_type_enum          AS ENUM ('INBOUND','OUTBOUND');
CREATE TYPE order_status_enum         AS ENUM ('OPEN','PARTIALLY_FULFILLED','CLOSED','CANCELLED');
CREATE TYPE lot_state_enum            AS ENUM ('WIP','FG','SHIPPED');
CREATE TYPE invoice_status_enum       AS ENUM ('DRAFT','ISSUED','PAID','VOID');
CREATE TYPE attachment_type_enum      AS ENUM ('PDF','BOL','PHOTO','OTHER');
CREATE TYPE price_list_status_enum    AS ENUM ('DRAFT','PENDING_APPROVAL','ACTIVE','EXPIRED');
CREATE TYPE dispatch_status_enum      AS ENUM ('SCHEDULED','IN_TRANSIT','COMPLETED','CANCELLED');
CREATE TYPE support_ticket_status_enum AS ENUM ('OPEN','IN_PROGRESS','CLOSED');

-- マスタ系
CREATE TYPE currency_enum             AS ENUM ('JPY','USD','EUR');
CREATE TYPE unit_enum                 AS ENUM ('KG','TON','LB');
CREATE TYPE payment_terms_enum        AS ENUM ('COD','NET_30','PREPAID');
CREATE TYPE payment_method_enum       AS ENUM ('BANK_TRANSFER','CASH','CARD');
CREATE TYPE document_type_enum        AS ENUM ('PASSPORT','DRIVERS_LICENSE','NATIONAL_ID');
CREATE TYPE schedule_enum             AS ENUM ('ON_DEMAND','DAILY','WEEKLY','MONTHLY','CRON_EXPR');
CREATE TYPE custom_field_context_enum AS ENUM ('TICKET','INVENTORY','ORDER');
CREATE TYPE custom_field_type_enum    AS ENUM ('TEXT','NUMBER','DATE','BOOLEAN');

-- 監査ログリソース
CREATE TYPE audit_resource_enum       AS ENUM (
  'SCALE_DEVICE','WEIGHT_TICKET','INVENTORY_LOT','ABSTRACT_ORDER',
  'PRICE_LIST','DISPATCH_JOB','INVOICE','SUPPORT_TICKET','USER'
);

/* ========================================================================
   3. 共通トリガ関数
   ======================================================================== */
CREATE OR REPLACE FUNCTION common.fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

/* ========================================================================
   4. 参照テーブル（最小構成）
   ======================================================================== */
-- 材料
CREATE TABLE master.material (
  material_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,
  default_unit  unit_enum NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_material
BEFORE UPDATE ON master.material
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- サプライヤ
CREATE TABLE partner.supplier (
  supplier_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_supplier
BEFORE UPDATE ON partner.supplier
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- ヤード
CREATE TABLE yard.yard (
  yard_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL UNIQUE,
  location      TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_yard
BEFORE UPDATE ON yard.yard
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 車両・ドライバー
CREATE TABLE fleet.vehicle (
  vehicle_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plate_number  TEXT NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_vehicle
BEFORE UPDATE ON fleet.vehicle
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE fleet.truck (
  truck_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plate_number  TEXT NOT NULL UNIQUE,
  capacity_kg   NUMERIC(12,3),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_truck
BEFORE UPDATE ON fleet.truck
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE fleet.driver (
  driver_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  license_no    TEXT NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_driver
BEFORE UPDATE ON fleet.driver
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 受発注相手先
CREATE TABLE counterparty.counterparty (
  counterparty_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL UNIQUE,
  kind            TEXT NOT NULL CHECK (kind IN ('CUSTOMER','VENDOR')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_counterparty
BEFORE UPDATE ON counterparty.counterparty
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* ========================================================================
   5. ドメインテーブル
   ======================================================================== */
/* 5‑1  Scale Gateway ----------------------------------------------------- */
CREATE TABLE scale_gateway.scale_device (
  device_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model         TEXT NOT NULL,
  serial_number TEXT NOT NULL UNIQUE,
  location      TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_scale_device
BEFORE UPDATE ON scale_gateway.scale_device
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE scale_gateway.scale_reading (
  reading_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id     UUID NOT NULL REFERENCES scale_gateway.scale_device(device_id),
  weight        NUMERIC(12,3) NOT NULL CHECK (weight >= 0),
  recorded_at   TIMESTAMPTZ NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_scale_reading
BEFORE UPDATE ON scale_gateway.scale_reading
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑2  Ticketing --------------------------------------------------------- */
CREATE TABLE ticketing.weight_ticket (
  ticket_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_type   ticket_type_enum NOT NULL,
  status        ticket_status_enum NOT NULL,
  total_weight  NUMERIC(12,3) NOT NULL CHECK (total_weight >= 0),
  tare_weight   NUMERIC(12,3) NOT NULL CHECK (tare_weight  >= 0),
  net_weight    NUMERIC(12,3) GENERATED ALWAYS AS (total_weight - tare_weight) STORED,
  supplier_id   UUID NOT NULL REFERENCES partner.supplier(supplier_id),
  vehicle_id    UUID REFERENCES fleet.vehicle(vehicle_id),
  yard_id       UUID NOT NULL REFERENCES yard.yard(yard_id),
  price_applied NUMERIC(14,4),
  finalized_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_weight_ticket
BEFORE UPDATE ON ticketing.weight_ticket
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.material_line (
  material_line_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id        UUID NOT NULL REFERENCES ticketing.weight_ticket(ticket_id) ON DELETE CASCADE,
  material_id      UUID NOT NULL REFERENCES master.material(material_id),
  grade            TEXT,
  quantity         NUMERIC(12,3) NOT NULL CHECK (quantity >= 0),
  unit             unit_enum NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_material_line
BEFORE UPDATE ON ticketing.material_line
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE compliance.identity_record (
  identity_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  individual_name TEXT,
  document_type   document_type_enum,
  document_number TEXT,
  issued_date     DATE,
  expiry_date     DATE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_identity_record
BEFORE UPDATE ON compliance.identity_record
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.compliance_info (
  compliance_info_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id          UUID UNIQUE NOT NULL REFERENCES ticketing.weight_ticket(ticket_id) ON DELETE CASCADE,
  identity_id        UUID NOT NULL REFERENCES compliance.identity_record(identity_id),
  fingerprint_hash   TEXT,
  id_scan_url        TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_compliance_info
BEFORE UPDATE ON ticketing.compliance_info
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.photos (
  photo_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  compliance_info_id UUID NOT NULL REFERENCES ticketing.compliance_info(compliance_info_id) ON DELETE CASCADE,
  url               TEXT NOT NULL,
  uploaded_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_photos
BEFORE UPDATE ON ticketing.photos
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.attachments (
  attachment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id     UUID NOT NULL REFERENCES ticketing.weight_ticket(ticket_id) ON DELETE CASCADE,
  url           TEXT NOT NULL,
  type          attachment_type_enum NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_attachments
BEFORE UPDATE ON ticketing.attachments
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑3  Inventory --------------------------------------------------------- */
CREATE TABLE inventory.inventory_lot (
  lot_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id  UUID NOT NULL REFERENCES master.material(material_id),
  grade        TEXT,
  quantity     NUMERIC(12,3) NOT NULL CHECK (quantity >= 0),
  unit         unit_enum NOT NULL,
  avg_cost     NUMERIC(14,4) NOT NULL,
  yard_id      UUID NOT NULL REFERENCES yard.yard(yard_id),
  state        lot_state_enum NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_inventory_lot
BEFORE UPDATE ON inventory.inventory_lot
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE inventory.lot_tags (
  lot_tag_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id       UUID NOT NULL REFERENCES inventory.inventory_lot(lot_id) ON DELETE CASCADE,
  qr_code      TEXT NOT NULL UNIQUE,
  printed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_lot_tags
BEFORE UPDATE ON inventory.lot_tags
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE inventory.transfer_history (
  transfer_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id        UUID NOT NULL REFERENCES inventory.inventory_lot(lot_id) ON DELETE CASCADE,
  from_yard_id  UUID NOT NULL REFERENCES yard.yard(yard_id),
  to_yard_id    UUID NOT NULL REFERENCES yard.yard(yard_id),
  quantity      NUMERIC(12,3) NOT NULL CHECK (quantity >= 0),
  transferred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (from_yard_id <> to_yard_id)
);
CREATE TRIGGER trg_upd_transfer_history
BEFORE UPDATE ON inventory.transfer_history
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑4  Orders ------------------------------------------------------------ */
CREATE TABLE orders.abstract_order (
  order_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_type      TEXT NOT NULL CHECK (order_type IN ('PURCHASE','SALES')),
  counterparty_id UUID NOT NULL REFERENCES counterparty.counterparty(counterparty_id),
  status          order_status_enum NOT NULL,
  order_date      DATE NOT NULL,
  expected_date   DATE,
  payment_terms   payment_terms_enum,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_abstract_order
BEFORE UPDATE ON orders.abstract_order
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE orders.order_line (
  order_line_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id      UUID NOT NULL REFERENCES orders.abstract_order(order_id) ON DELETE CASCADE,
  material_id   UUID NOT NULL REFERENCES master.material(material_id),
  quantity      NUMERIC(12,3) NOT NULL CHECK (quantity >= 0),
  unit          unit_enum NOT NULL,
  price         NUMERIC(14,4) NOT NULL,
  amount        NUMERIC(14,4) GENERATED ALWAYS AS (quantity * price) STORED,
  lot_ref       UUID REFERENCES inventory.inventory_lot(lot_id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (
    (lot_ref IS NULL) OR
    (lot_ref IS NOT NULL AND EXISTS (
      SELECT 1 FROM inventory.inventory_lot l
      WHERE l.lot_id = lot_ref AND (SELECT order_type FROM orders.abstract_order o WHERE o.order_id = order_id ) = 'SALES'
    ))
  )
);
CREATE TRIGGER trg_upd_order_line
BEFORE UPDATE ON orders.order_line
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE orders.linked_tickets (
  linked_ticket_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id   UUID NOT NULL REFERENCES orders.abstract_order(order_id) ON DELETE CASCADE,
  ticket_id  UUID NOT NULL REFERENCES ticketing.weight_ticket(ticket_id),
  net_weight NUMERIC(12,3) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_linked_tickets
BEFORE UPDATE ON orders.linked_tickets
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑5  Pricing ----------------------------------------------------------- */
CREATE TABLE pricing.price_list (
  price_list_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scope          TEXT NOT NULL CHECK (scope IN ('GLOBAL','YARD','CUSTOMER')),
  effective_from DATE NOT NULL,
  effective_to   DATE,
  status         price_list_status_enum NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (effective_to IS NULL OR effective_from <= effective_to)
);
CREATE TRIGGER trg_upd_price_list
BEFORE UPDATE ON pricing.price_list
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE pricing.price_item (
  price_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  price_list_id UUID NOT NULL REFERENCES pricing.price_list(price_list_id) ON DELETE CASCADE,
  material_id   UUID NOT NULL REFERENCES master.material(material_id),
  unit_price    NUMERIC(14,4) NOT NULL,
  currency      currency_enum NOT NULL DEFAULT 'JPY',
  min_qty       NUMERIC(12,3) NOT NULL DEFAULT 0,
  max_qty       NUMERIC(12,3),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (price_list_id, material_id, min_qty),
  CHECK (max_qty IS NULL OR max_qty > min_qty)
);
CREATE TRIGGER trg_upd_price_item
BEFORE UPDATE ON pricing.price_item
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE pricing.approval_route (
  approval_route_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  price_list_id UUID NOT NULL REFERENCES pricing.price_list(price_list_id) ON DELETE CASCADE,
  required_role TEXT NOT NULL,
  approved_by   UUID REFERENCES identity.users(user_id),
  approved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_approval_route
BEFORE UPDATE ON pricing.approval_route
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑6  Dispatch ---------------------------------------------------------- */
CREATE TABLE dispatch.dispatch_job (
  dispatch_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id      UUID NOT NULL REFERENCES inventory.inventory_lot(lot_id),
  truck_id    UUID NOT NULL REFERENCES fleet.truck(truck_id),
  driver_id   UUID NOT NULL REFERENCES fleet.driver(driver_id),
  scheduled_time TIMESTAMPTZ NOT NULL,
  status      dispatch_status_enum NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_dispatch_job
BEFORE UPDATE ON dispatch.dispatch_job
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑7  Finance ----------------------------------------------------------- */
CREATE TABLE finance.invoice (
  invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id   UUID REFERENCES orders.abstract_order(order_id),
  ticket_id  UUID REFERENCES ticketing.weight_ticket(ticket_id),
  amount     NUMERIC(14,4) NOT NULL,
  currency   currency_enum NOT NULL DEFAULT 'JPY',
  status     invoice_status_enum NOT NULL,
  issued_at  TIMESTAMPTZ NOT NULL,
  due_date   DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK ((order_id IS NOT NULL)::int + (ticket_id IS NOT NULL)::int = 1)
);
CREATE TRIGGER trg_upd_invoice
BEFORE UPDATE ON finance.invoice
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE finance.payment (
  payment_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id        UUID NOT NULL REFERENCES finance.invoice(invoice_id),
  amount            NUMERIC(14,4) NOT NULL,
  paid_at           TIMESTAMPTZ NOT NULL,
  method            payment_method_enum NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (amount >= 0)
);
CREATE TRIGGER trg_upd_payment
BEFORE UPDATE ON finance.payment
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 過払防止トリガ
CREATE OR REPLACE FUNCTION finance.fn_check_overpayment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_total NUMERIC(14,4);
BEGIN
  SELECT COALESCE(SUM(amount),0) INTO v_total
  FROM finance.payment
  WHERE invoice_id = NEW.invoice_id
    AND (TG_OP = 'UPDATE' AND payment_id <> NEW.payment_id OR TG_OP = 'INSERT');

  IF v_total + NEW.amount > (SELECT amount FROM finance.invoice WHERE invoice_id = NEW.invoice_id) THEN
    RAISE EXCEPTION 'Payment exceeds invoice balance';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_chk_overpayment
BEFORE INSERT OR UPDATE ON finance.payment
FOR EACH ROW EXECUTE FUNCTION finance.fn_check_overpayment();

CREATE TABLE finance.journal_entry (
  journal_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_date       DATE NOT NULL,
  description      TEXT,
  data             JSONB NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_journal_entry
BEFORE UPDATE ON finance.journal_entry
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑8  Reporting --------------------------------------------------------- */
CREATE TABLE reporting.report_definition (
  report_definition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL UNIQUE,
  description   TEXT,
  query         JSONB NOT NULL,
  schedule      schedule_enum NOT NULL DEFAULT 'ON_DEMAND',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_report_definition
BEFORE UPDATE ON reporting.report_definition
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE reporting.report_run (
  report_run_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_definition_id UUID NOT NULL REFERENCES reporting.report_definition(report_definition_id),
  executed_at       TIMESTAMPTZ NOT NULL,
  result_location   TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_report_run
BEFORE UPDATE ON reporting.report_run
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑9  Identity & Security ---------------------------------------------- */
CREATE TABLE identity.users (
  user_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username      TEXT NOT NULL UNIQUE,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_users
BEFORE UPDATE ON identity.users
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.roles (
  role_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name      TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_roles
BEFORE UPDATE ON identity.roles
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.user_roles (
  user_id    UUID NOT NULL REFERENCES identity.users(user_id),
  role_id    UUID NOT NULL REFERENCES identity.roles(role_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, role_id)
);
CREATE TRIGGER trg_upd_user_roles
BEFORE UPDATE ON identity.user_roles
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.permissions (
  permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL UNIQUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_permissions
BEFORE UPDATE ON identity.permissions
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.role_permissions (
  role_id        UUID NOT NULL REFERENCES identity.roles(role_id),
  permission_id  UUID NOT NULL REFERENCES identity.permissions(permission_id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (role_id, permission_id)
);
CREATE TRIGGER trg_upd_role_permissions
BEFORE UPDATE ON identity.role_permissions
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.audit_log (
  audit_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES identity.users(user_id),
  action       TEXT NOT NULL,
  resource     audit_resource_enum NOT NULL,
  resource_id  UUID,
  timestamp    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  details      JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_audit_log
BEFORE UPDATE ON identity.audit_log
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑10 Configuration ----------------------------------------------------- */
CREATE TABLE configuration.settings (
  setting_key   TEXT PRIMARY KEY,
  setting_value JSONB NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_settings
BEFORE UPDATE ON configuration.settings
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE configuration.custom_field_def (
  custom_field_def_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  context     custom_field_context_enum NOT NULL,
  field_name  TEXT NOT NULL,
  field_type  custom_field_type_enum NOT NULL,
  metadata    JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (context, field_name)
);
CREATE TRIGGER trg_upd_custom_field_def
BEFORE UPDATE ON configuration.custom_field_def
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE configuration.templates (
  template_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL UNIQUE,
  content      TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_templates
BEFORE UPDATE ON configuration.templates
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* 5‑11 Support ----------------------------------------------------------- */
CREATE TABLE support.support_ticket (
  support_ticket_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES identity.users(user_id),
  subject     TEXT NOT NULL,
  description TEXT NOT NULL,
  status      support_ticket_status_enum NOT NULL DEFAULT 'OPEN',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_support_ticket
BEFORE UPDATE ON support.support_ticket
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE support.kb_article (
  kb_article_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title         TEXT NOT NULL UNIQUE,
  content       TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TRIGGER trg_upd_kb_article
BEFORE UPDATE ON support.kb_article
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

/* ========================================================================
   6. インデックス（代表例のみ。実運用で EXPLAIN を見ながら追加/削除）
   ======================================================================== */
-- Scale Reading
CREATE INDEX idx_scale_reading_device_time ON scale_gateway.scale_reading(device_id, recorded_at DESC);

-- Ticketing
CREATE INDEX idx_weight_ticket_status_finalized ON ticketing.weight_ticket(status, finalized_at DESC);
CREATE INDEX idx_material_line_ticket ON ticketing.material_line(ticket_id);
CREATE INDEX idx_compliance_identity ON ticketing.compliance_info(identity_id);

-- Inventory
CREATE INDEX idx_inventory_lot_yard_state ON inventory.inventory_lot(yard_id, state);

-- Orders
CREATE INDEX idx_order_line_order ON orders.order_line(order_id);

-- Pricing
CREATE INDEX idx_price_list_status ON pricing.price_list(status);
CREATE INDEX idx_price_item_material ON pricing.price_item(material_id);

-- Dispatch
CREATE INDEX idx_dispatch_job_status_time ON dispatch.dispatch_job(status, scheduled_time DESC);

-- Finance
CREATE INDEX idx_invoice_status_due ON finance.invoice(status, due_date);
CREATE INDEX idx_payment_invoice ON finance.payment(invoice_id);

-- Support
CREATE INDEX idx_support_ticket_status_updated ON support.support_ticket(status, updated_at DESC);

/* ========================================================================
   7. ビュー例（合計残高など）
   ======================================================================== */
CREATE MATERIALIZED VIEW orders.v_order_totals AS
SELECT
  o.order_id,
  SUM(l.amount)         AS line_total,
  COALESCE(SUM(p.amount),0) AS paid_total,
  SUM(l.amount) - COALESCE(SUM(p.amount),0) AS balance_due
FROM orders.abstract_order o
LEFT JOIN orders.order_line   l USING (order_id)
LEFT JOIN finance.invoice     i ON i.order_id = o.order_id
LEFT JOIN finance.payment     p ON p.invoice_id = i.invoice_id
GROUP BY o.order_id
WITH DATA;

/* ========================================================================
   完了！
   ======================================================================== */
