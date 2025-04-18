-- 必要拡張
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 共通スキーマ
CREATE SCHEMA IF NOT EXISTS common;

-- 共通ユーティリティ DDL
-- ENUM 定義
CREATE TYPE ticket_status_enum        AS ENUM ('Draft','Finalized','Cancelled');
CREATE TYPE order_status_enum         AS ENUM ('OPEN','PARTIALLY_FULFILLED','CLOSED','CANCELLED');
CREATE TYPE lot_state_enum            AS ENUM ('WIP','FG','SHIPPED');
CREATE TYPE invoice_status_enum       AS ENUM ('DRAFT','ISSUED','PAID','VOID');
CREATE TYPE attachment_type_enum      AS ENUM ('PDF','BOL','PHOTO','OTHER');
CREATE TYPE price_list_status_enum    AS ENUM ('DRAFT','PENDING_APPROVAL','ACTIVE','EXPIRED');
CREATE TYPE dispatch_status_enum      AS ENUM ('SCHEDULED','IN_TRANSIT','COMPLETED','CANCELLED');
CREATE TYPE support_ticket_status_enum AS ENUM ('OPEN','IN_PROGRESS','CLOSED');
-- TODO: Add ENUM for audit_log.resource

-- updated_at 自動更新トリガ関数
CREATE OR REPLACE FUNCTION common.fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- 1. Scale Gateway
CREATE SCHEMA IF NOT EXISTS scale_gateway;

CREATE TABLE scale_gateway.scale_device (
  device_id        UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  model            TEXT    NOT NULL,
  serial_number    TEXT    NOT NULL UNIQUE,
  location         TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- updated_at trigger already exists

CREATE TABLE scale_gateway.scale_reading (
  reading_id       UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id        UUID    NOT NULL REFERENCES scale_gateway.scale_device(device_id),
  weight           NUMERIC(12,3) NOT NULL CHECK(weight >= 0),
  recorded_at      TIMESTAMPTZ NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_scale_reading
BEFORE UPDATE ON scale_gateway.scale_reading
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 2. Ticketing
CREATE SCHEMA IF NOT EXISTS ticketing;

CREATE TABLE ticketing.weight_ticket (
  ticket_id        UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_type      TEXT    NOT NULL, -- TODO: Consider ENUM if types are fixed
  status           ticket_status_enum NOT NULL, -- Changed to ENUM
  total_weight     NUMERIC(12,3) NOT NULL CHECK(total_weight >= 0),
  tare_weight      NUMERIC(12,3) NOT NULL CHECK(tare_weight >= 0),
  net_weight       NUMERIC(12,3) GENERATED ALWAYS AS (total_weight - tare_weight) STORED,
  supplier_id      UUID    NOT NULL, -- TODO: Add FK to suppliers table
  vehicle_id       UUID, -- TODO: Add FK to vehicles table
  yard_id          UUID    NOT NULL, -- TODO: Add FK to yards table
  price_applied    NUMERIC(14,4),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added updated_at
  finalized_at     TIMESTAMPTZ
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_weight_ticket
BEFORE UPDATE ON ticketing.weight_ticket
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.material_line (
  material_line_id UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id        UUID    NOT NULL REFERENCES ticketing.weight_ticket(ticket_id) ON DELETE CASCADE,
  material_id      UUID    NOT NULL, -- TODO: Add FK to materials table
  grade            TEXT, -- TODO: Consider ENUM if grades are fixed
  quantity         NUMERIC(12,3) NOT NULL CHECK(quantity >= 0),
  unit             TEXT    NOT NULL, -- TODO: Consider ENUM for units
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_material_line
BEFORE UPDATE ON ticketing.material_line
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.compliance_info (
  compliance_info_id UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id          UUID  UNIQUE NOT NULL REFERENCES ticketing.weight_ticket(ticket_id) ON DELETE CASCADE,
  identity_id        UUID  NOT NULL REFERENCES compliance.identity_record(identity_id), -- Added FK
  fingerprint_hash   TEXT,
  id_scan_url        TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_compliance_info
BEFORE UPDATE ON ticketing.compliance_info
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.photos (
  photo_id         UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  compliance_info_id UUID  NOT NULL REFERENCES ticketing.compliance_info(compliance_info_id) ON DELETE CASCADE,
  url              TEXT    NOT NULL,
  uploaded_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_photos
BEFORE UPDATE ON ticketing.photos
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE ticketing.attachments (
  attachment_id    UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id        UUID    NOT NULL REFERENCES ticketing.weight_ticket(ticket_id) ON DELETE CASCADE,
  url              TEXT    NOT NULL,
  type             attachment_type_enum NOT NULL, -- Changed to ENUM
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_attachments
BEFORE UPDATE ON ticketing.attachments
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 3. Inventory
CREATE SCHEMA IF NOT EXISTS inventory;

CREATE TABLE inventory.inventory_lot (
  lot_id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  material_id      UUID    NOT NULL, -- TODO: Add FK to materials table
  grade            TEXT, -- TODO: Consider ENUM if grades are fixed
  quantity         NUMERIC(12,3) NOT NULL CHECK(quantity >= 0),
  unit             TEXT    NOT NULL, -- TODO: Consider ENUM for units
  avg_cost         NUMERIC(14,4) NOT NULL,
  yard_id          UUID    NOT NULL, -- TODO: Add FK to yards table
  state            lot_state_enum NOT NULL, -- Changed to ENUM
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- updated_at trigger already exists

CREATE TABLE inventory.lot_tags (
  lot_tag_id       UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id           UUID    NOT NULL REFERENCES inventory.inventory_lot(lot_id) ON DELETE CASCADE,
  qr_code          TEXT    NOT NULL UNIQUE,
  printed_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_lot_tags
BEFORE UPDATE ON inventory.lot_tags
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE inventory.transfer_history (
  transfer_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id             UUID    NOT NULL REFERENCES inventory.inventory_lot(lot_id) ON DELETE CASCADE,
  from_yard_id       UUID    NOT NULL, -- TODO: Add FK to yards table
  to_yard_id         UUID    NOT NULL, -- TODO: Add FK to yards table
  quantity           NUMERIC(12,3) NOT NULL CHECK(quantity >= 0),
  transferred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_transfer_history
BEFORE UPDATE ON inventory.transfer_history
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();
-- TODO: Add trigger to prevent quantity > inventory_lot.quantity

-- 4. Orders
CREATE SCHEMA IF NOT EXISTS orders;

CREATE TABLE orders.abstract_order (
  order_id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  order_type        TEXT    NOT NULL CHECK(order_type IN ('PURCHASE','SALES')), -- TODO: Consider ENUM
  counterparty_id   UUID    NOT NULL, -- TODO: Add FK to counterparties table
  status            order_status_enum NOT NULL, -- Changed to ENUM
  order_date        DATE    NOT NULL,
  expected_date     DATE,
  payment_terms     TEXT, -- TODO: Consider ENUM
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- updated_at trigger already exists

CREATE TABLE orders.order_line (
  order_line_id     UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id          UUID    NOT NULL REFERENCES orders.abstract_order(order_id) ON DELETE CASCADE,
  material_id       UUID    NOT NULL, -- TODO: Add FK to materials table
  quantity          NUMERIC(12,3) NOT NULL CHECK(quantity >= 0),
  unit              TEXT    NOT NULL, -- TODO: Consider ENUM for units
  price             NUMERIC(14,4) NOT NULL,
  lot_ref           UUID    REFERENCES inventory.inventory_lot(lot_id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_order_line
BEFORE UPDATE ON orders.order_line
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();
-- TODO: Add CHECK constraint or trigger to ensure lot_ref is only used for SALES orders

CREATE TABLE orders.linked_tickets (
  linked_ticket_id  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id          UUID    NOT NULL REFERENCES orders.abstract_order(order_id) ON DELETE CASCADE,
  ticket_id         UUID    NOT NULL, -- TODO: Add FK to ticketing.weight_ticket
  net_weight        NUMERIC(12,3) NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_linked_tickets
BEFORE UPDATE ON orders.linked_tickets
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 5. Pricing
CREATE SCHEMA IF NOT EXISTS pricing;

CREATE TABLE pricing.price_list (
  price_list_id     UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  scope             TEXT    NOT NULL CHECK(scope IN ('GLOBAL','YARD','CUSTOMER')), -- TODO: Consider ENUM
  effective_from    DATE    NOT NULL,
  effective_to      DATE,
  status            price_list_status_enum NOT NULL, -- Changed to ENUM
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added updated_at
  CHECK (effective_to IS NULL OR effective_from <= effective_to) -- Added CHECK
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_price_list
BEFORE UPDATE ON pricing.price_list
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE pricing.price_item (
  price_item_id     UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  price_list_id     UUID    NOT NULL REFERENCES pricing.price_list(price_list_id) ON DELETE CASCADE,
  material_id       UUID    NOT NULL, -- TODO: Add FK to materials table
  unit_price        NUMERIC(14,4) NOT NULL,
  currency          TEXT    NOT NULL, -- TODO: Consider ENUM
  min_qty           NUMERIC(12,3) NOT NULL DEFAULT 0,
  max_qty           NUMERIC(12,3),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added updated_at
  UNIQUE(price_list_id, material_id, min_qty) -- Added UNIQUE constraint
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_price_item
BEFORE UPDATE ON pricing.price_item
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();
-- TODO: Consider EXCLUDE constraint for price item date/quantity ranges

CREATE TABLE pricing.approval_route (
  approval_route_id UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  price_list_id     UUID    NOT NULL REFERENCES pricing.price_list(price_list_id) ON DELETE CASCADE,
  required_role     TEXT    NOT NULL, -- TODO: Consider FK to roles table or ENUM
  approved_by       UUID, -- TODO: Add FK to users table
  approved_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_approval_route
BEFORE UPDATE ON pricing.approval_route
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 6. Dispatch
CREATE SCHEMA IF NOT EXISTS dispatch;

CREATE TABLE dispatch.dispatch_job (
  dispatch_job_id   UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id            UUID    NOT NULL REFERENCES inventory.inventory_lot(lot_id),
  truck_id          UUID    NOT NULL, -- TODO: Add FK to trucks table
  driver_id         UUID    NOT NULL, -- TODO: Add FK to drivers table
  scheduled_time    TIMESTAMPTZ NOT NULL,
  status            dispatch_status_enum NOT NULL, -- Changed to ENUM
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_dispatch_job
BEFORE UPDATE ON dispatch.dispatch_job
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 7. Finance
CREATE SCHEMA IF NOT EXISTS finance;

CREATE TABLE finance.invoice (
  invoice_id        UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id          UUID    REFERENCES orders.abstract_order(order_id),
  ticket_id         UUID    REFERENCES ticketing.weight_ticket(ticket_id),
  amount            NUMERIC(14,4) NOT NULL,
  currency          TEXT    NOT NULL, -- TODO: Consider ENUM
  status            invoice_status_enum NOT NULL, -- Changed to ENUM
  issued_at         TIMESTAMPTZ NOT NULL,
  due_date          DATE    NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added updated_at
  -- Added CHECK for polymorphic reference
  CHECK ((order_id IS NOT NULL)::int + (ticket_id IS NOT NULL)::int = 1)
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_invoice
BEFORE UPDATE ON finance.invoice
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE finance.payment (
  payment_id        UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id        UUID    REFERENCES finance.invoice(invoice_id),
  amount            NUMERIC(14,4) NOT NULL,
  paid_at           TIMESTAMPTZ NOT NULL,
  method            TEXT    NOT NULL, -- TODO: Consider ENUM
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_payment
BEFORE UPDATE ON finance.payment
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();
-- TODO: Add trigger/check to ensure payment.amount <= remaining invoice amount

CREATE TABLE finance.journal_entry (
  journal_entry_id  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_date        DATE    NOT NULL,
  description       TEXT,
  data              JSONB   NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_journal_entry
BEFORE UPDATE ON finance.journal_entry
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 8. Compliance
CREATE SCHEMA IF NOT EXISTS compliance;

CREATE TABLE compliance.identity_record (
  identity_id       UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  individual_name   TEXT,
  document_type     TEXT, -- TODO: Consider ENUM
  document_number   TEXT,
  issued_date       DATE,
  expiry_date       DATE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_identity_record
BEFORE UPDATE ON compliance.identity_record
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE compliance.regulatory_report (
  report_id         UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  report_type       TEXT    NOT NULL, -- TODO: Consider ENUM
  generated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  data              JSONB   NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_regulatory_report
BEFORE UPDATE ON compliance.regulatory_report
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 9. Reporting
CREATE SCHEMA IF NOT EXISTS reporting;

CREATE TABLE reporting.report_definition (
  report_definition_id UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT    NOT NULL UNIQUE, -- Added UNIQUE
  description       TEXT,
  query             JSONB   NOT NULL,
  schedule          TEXT, -- TODO: Consider specific type or ENUM for schedule format
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_report_definition
BEFORE UPDATE ON reporting.report_definition
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE reporting.report_run (
  report_run_id     UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  report_definition_id UUID NOT NULL REFERENCES reporting.report_definition(report_definition_id),
  executed_at       TIMESTAMPTZ NOT NULL,
  result_location   TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_report_run
BEFORE UPDATE ON reporting.report_run
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 10. Identity & Security
CREATE SCHEMA IF NOT EXISTS identity;

CREATE TABLE identity.users (
  user_id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  username          TEXT    NOT NULL UNIQUE,
  email             TEXT    NOT NULL UNIQUE,
  password_hash     TEXT    NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- updated_at trigger already exists

CREATE TABLE identity.roles (
  role_id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT    NOT NULL UNIQUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_roles
BEFORE UPDATE ON identity.roles
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.user_roles (
  user_id           UUID    NOT NULL REFERENCES identity.users(user_id),
  role_id           UUID    NOT NULL REFERENCES identity.roles(role_id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added updated_at
  PRIMARY KEY(user_id, role_id)
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_user_roles
BEFORE UPDATE ON identity.user_roles
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.permissions (
  permission_id     UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT    NOT NULL UNIQUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_permissions
BEFORE UPDATE ON identity.permissions
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.role_permissions (
  role_id           UUID    NOT NULL REFERENCES identity.roles(role_id),
  permission_id     UUID    NOT NULL REFERENCES identity.permissions(permission_id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added updated_at
  PRIMARY KEY(role_id, permission_id)
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_role_permissions
BEFORE UPDATE ON identity.role_permissions
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE identity.audit_log (
  audit_log_id      UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID    REFERENCES identity.users(user_id),
  action            TEXT    NOT NULL,
  resource          TEXT    NOT NULL, -- TODO: Consider ENUM or FK
  resource_id       UUID,
  timestamp         TIMESTAMPTZ NOT NULL DEFAULT now(),
  details           JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_audit_log
BEFORE UPDATE ON identity.audit_log
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();
-- TODO: Consider triggers on other tables to automatically insert into audit_log

-- 11. Configuration
CREATE SCHEMA IF NOT EXISTS configuration;

CREATE TABLE configuration.settings (
  setting_key       TEXT    PRIMARY KEY,
  setting_value     JSONB   NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_settings
BEFORE UPDATE ON configuration.settings
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE configuration.custom_field_def (
  custom_field_def_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  context           TEXT    NOT NULL, -- TODO: Consider ENUM
  field_name        TEXT    NOT NULL,
  field_type        TEXT    NOT NULL, -- TODO: Consider ENUM
  metadata          JSONB,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added updated_at
  UNIQUE(context, field_name) -- Added UNIQUE constraint
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_custom_field_def
BEFORE UPDATE ON configuration.custom_field_def
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

CREATE TABLE configuration.templates (
  template_id       UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT    NOT NULL UNIQUE, -- Added UNIQUE
  content           TEXT    NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(), -- Added created_at
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now() -- Added updated_at
);
-- Add updated_at trigger
CREATE TRIGGER trg_upd_templates
BEFORE UPDATE ON configuration.templates
FOR EACH ROW EXECUTE FUNCTION common.fn_set_updated_at();

-- 12. Support
CREATE SCHEMA IF NOT EXISTS support;

CREATE TABLE support.support_ticket (
  support_ticket_id UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID    REFERENCES identity.users(user_id),
  subject           TEXT    NOT NULL,
  description       TEXT    NOT NULL,
  status            support_ticket_status_enum NOT NULL, -- Changed to ENUM
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- updated_at trigger already exists

CREATE TABLE support.kb_article (
  kb_article_id     UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  title             TEXT    NOT NULL UNIQUE, -- Added UNIQUE
  content           TEXT    NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- updated_at trigger already exists

-- Recommended Indexes
-- Scale Gateway
CREATE INDEX idx_scale_reading_device_time ON scale_gateway.scale_reading (device_id, recorded_at DESC);

-- Ticketing
CREATE INDEX idx_weight_ticket_status_finalized ON ticketing.weight_ticket (status, finalized_at DESC);
-- CREATE INDEX idx_weight_ticket_supplier ON ticketing.weight_ticket (supplier_id); -- FK index
-- CREATE INDEX idx_weight_ticket_yard ON ticketing.weight_ticket (yard_id); -- FK index
-- CREATE INDEX idx_material_line_ticket ON ticketing.material_line (ticket_id); -- FK index
-- CREATE INDEX idx_material_line_material ON ticketing.material_line (material_id); -- FK index
-- CREATE INDEX idx_compliance_info_ticket ON ticketing.compliance_info (ticket_id); -- FK index (already unique)
-- CREATE INDEX idx_compliance_info_identity ON ticketing.compliance_info (identity_id); -- FK index
-- CREATE INDEX idx_photos_compliance_info ON ticketing.photos (compliance_info_id); -- FK index
-- CREATE INDEX idx_attachments_ticket ON ticketing.attachments (ticket_id); -- FK index

-- Inventory
CREATE INDEX idx_inventory_lot_yard_state ON inventory.inventory_lot (yard_id, state);
-- CREATE INDEX idx_inventory_lot_material ON inventory.inventory_lot (material_id); -- FK index
-- CREATE INDEX idx_lot_tags_lot ON inventory.lot_tags (lot_id); -- FK index
-- CREATE INDEX idx_transfer_history_lot ON inventory.transfer_history (lot_id); -- FK index
-- CREATE INDEX idx_transfer_history_from_yard ON inventory.transfer_history (from_yard_id); -- FK index
-- CREATE INDEX idx_transfer_history_to_yard ON inventory.transfer_history (to_yard_id); -- FK index

-- Orders
-- CREATE INDEX idx_abstract_order_counterparty ON orders.abstract_order (counterparty_id); -- FK index
CREATE INDEX idx_order_line_order ON orders.order_line (order_id); -- FK index
-- CREATE INDEX idx_order_line_material ON orders.order_line (material_id); -- FK index
-- CREATE INDEX idx_order_line_lot_ref ON orders.order_line (lot_ref); -- FK index
-- CREATE INDEX idx_linked_tickets_order ON orders.linked_tickets (order_id); -- FK index
-- CREATE INDEX idx_linked_tickets_ticket ON orders.linked_tickets (ticket_id); -- FK index

-- Pricing
-- CREATE INDEX idx_price_list_status ON pricing.price_list (status); -- ENUM index
-- CREATE INDEX idx_price_item_price_list ON pricing.price_item (price_list_id); -- FK index
-- CREATE INDEX idx_price_item_material ON pricing.price_item (material_id); -- FK index
-- CREATE INDEX idx_approval_route_price_list ON pricing.approval_route (price_list_id); -- FK index
-- CREATE INDEX idx_approval_route_approved_by ON pricing.approval_route (approved_by); -- FK index

-- Dispatch
-- CREATE INDEX idx_dispatch_job_lot ON dispatch.dispatch_job (lot_id); -- FK index
-- CREATE INDEX idx_dispatch_job_truck ON dispatch.dispatch_job (truck_id); -- FK index
-- CREATE INDEX idx_dispatch_job_driver ON dispatch.dispatch_job (driver_id); -- FK index
-- CREATE INDEX idx_dispatch_job_status ON dispatch.dispatch_job (status); -- ENUM index

-- Finance
-- CREATE INDEX idx_invoice_order ON finance.invoice (order_id); -- FK index
-- CREATE INDEX idx_invoice_ticket ON finance.invoice (ticket_id); -- FK index
CREATE INDEX idx_invoice_status_due_date ON finance.invoice (status, due_date);
-- CREATE INDEX idx_payment_invoice ON finance.payment (invoice_id); -- FK index
-- CREATE INDEX idx_journal_entry_date ON finance.journal_entry (entry_date); -- Date index

-- Compliance
-- CREATE INDEX idx_identity_record_document_type ON compliance.identity_record (document_type); -- ENUM index
-- CREATE INDEX idx_regulatory_report_type ON compliance.regulatory_report (report_type); -- ENUM index

-- Reporting
-- CREATE INDEX idx_report_run_definition ON reporting.report_run (report_definition_id); -- FK index
-- CREATE INDEX idx_report_run_executed_at ON reporting.report_run (executed_at); -- Date index

-- Identity & Security
-- CREATE INDEX idx_users_username ON identity.users (username); -- UNIQUE index
-- CREATE INDEX idx_users_email ON identity.users (email); -- UNIQUE index
-- CREATE INDEX idx_roles_name ON identity.roles (name); -- UNIQUE index
-- CREATE INDEX idx_user_roles_user ON identity.user_roles (user_id); -- PK/FK index
-- CREATE INDEX idx_user_roles_role ON identity.user_roles (role_id); -- PK/FK index
-- CREATE INDEX idx_permissions_name ON identity.permissions (name); -- UNIQUE index
-- CREATE INDEX idx_role_permissions_role ON identity.role_permissions (role_id); -- PK/FK index
-- CREATE INDEX idx_role_permissions_permission ON identity.role_permissions (permission_id); -- PK/FK index
-- CREATE INDEX idx_audit_log_user ON identity.audit_log (user_id); -- FK index
-- CREATE INDEX idx_audit_log_resource ON identity.audit_log (resource); -- ENUM/Text index
-- CREATE INDEX idx_audit_log_timestamp ON identity.audit_log (timestamp); -- Date index

-- Configuration
-- CREATE INDEX idx_settings_key ON configuration.settings (setting_key); -- PK index
-- CREATE INDEX idx_custom_field_def_context ON configuration.custom_field_def (context); -- ENUM/Text index
-- CREATE INDEX idx_custom_field_def_field_name ON configuration.custom_field_def (field_name); -- Text index
-- CREATE INDEX idx_templates_name ON configuration.templates (name); -- UNIQUE index

-- Support
-- CREATE INDEX idx_support_ticket_user ON support.support_ticket (user_id); -- FK index
CREATE INDEX idx_support_ticket_status_updated ON support.support_ticket (status, updated_at DESC);
-- CREATE INDEX idx_kb_article_title ON support.kb_article (title); -- UNIQUE index
-- CREATE INDEX idx_kb_article_updated_at ON support.kb_article (updated_at DESC); -- Date index

-- Note: FK indexes are often automatically created by PostgreSQL, but explicitly adding them can sometimes be beneficial.
-- Review and add/remove indexes based on query patterns and performance monitoring.