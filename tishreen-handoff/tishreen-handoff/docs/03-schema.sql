-- ============================================================================
-- Tishreen Mall — reference DDL (PostgreSQL 15) — ERD v2.1 — 34 tables
-- Becomes: api/src/main/resources/db/migration/V1__init_schema.sql
-- Conventions: money NUMERIC(14,2) · qty NUMERIC(12,3) · coords NUMERIC(9,6)
--              TIMESTAMPTZ everywhere · statuses VARCHAR + CHECK · RESTRICT by default
-- ============================================================================

-- ---------- shared trigger ----------
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------- human-readable numbers ----------
CREATE SEQUENCE order_number_seq  START 1 INCREMENT 1;
CREATE SEQUENCE ticket_number_seq START 1 INCREMENT 1;

-- ============================================================================
-- 1) IDENTITY & PERMISSIONS
-- ============================================================================
CREATE TABLE roles (
    id       SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code     VARCHAR(30) NOT NULL UNIQUE,              -- ADMIN EMPLOYEE IT DRIVER CUSTOMER
    name_ar  VARCHAR(50) NOT NULL,
    name_en  VARCHAR(50)
);

CREATE TABLE permissions (
    id          SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR(50)  NOT NULL UNIQUE,          -- ORDER_MANAGE, OTP_SEND ...
    description VARCHAR(150)
);

CREATE TABLE role_permissions (
    role_id       SMALLINT NOT NULL REFERENCES roles(id)       ON DELETE CASCADE,
    permission_id SMALLINT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE users (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name          VARCHAR(120) NOT NULL,
    phone              VARCHAR(20)  NOT NULL UNIQUE,   -- E.164, login name + notification channel
    password_hash      VARCHAR(100) NOT NULL,          -- BCrypt
    role_id            SMALLINT     NOT NULL REFERENCES roles(id),
    status             VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING','OTP_SENT','ACTIVE','BLOCKED')),
    preferred_language CHAR(2)      NOT NULL DEFAULT 'ar'
                       CHECK (preferred_language IN ('ar','en')),
    last_login_at      TIMESTAMPTZ,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_users_role_status ON users(role_id, status);
CREATE TRIGGER trg_users_updated BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE customer_profiles (
    user_id    BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    staff_note TEXT,                                   -- internal, never exposed to the customer
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE employee_profiles (
    user_id    BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    job_title  VARCHAR(80),
    hired_at   DATE,
    note       TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE driver_profiles (
    user_id       BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    vehicle_type  VARCHAR(40),
    vehicle_plate VARCHAR(20),
    is_available  BOOLEAN NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_driver_profiles_updated BEFORE UPDATE ON driver_profiles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE otp_codes (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code_hash  VARCHAR(100) NOT NULL,                  -- never the plain code
    purpose    VARCHAR(20)  NOT NULL
               CHECK (purpose IN ('ACTIVATION','PASSWORD_RESET')),
    expires_at TIMESTAMPTZ  NOT NULL,
    attempts   SMALLINT     NOT NULL DEFAULT 0,
    used_at    TIMESTAMPTZ,
    created_by BIGINT REFERENCES users(id),            -- NULL = self-service request
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_otp_user ON otp_codes(user_id, purpose, created_at DESC);

-- ============================================================================
-- 2) ZONES & ADDRESSES
-- ============================================================================
CREATE TABLE delivery_zones (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name_ar    VARCHAR(80)   NOT NULL,
    name_en    VARCHAR(80),
    fee        NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (fee >= 0),
    min_order  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (min_order >= 0),
    is_active  BOOLEAN       NOT NULL DEFAULT true,
    sort_order INT           NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_delivery_zones_updated BEFORE UPDATE ON delivery_zones
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE addresses (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label      VARCHAR(40),
    zone_id    BIGINT      NOT NULL REFERENCES delivery_zones(id),
    details    TEXT        NOT NULL,                   -- street, building, floor — always mandatory
    latitude   NUMERIC(9,6),                           -- optional map pin (Leaflet + OSM)
    longitude  NUMERIC(9,6),
    is_default BOOLEAN     NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_addresses_pin CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CONSTRAINT chk_addresses_lat CHECK (latitude  IS NULL OR latitude  BETWEEN -90  AND 90),
    CONSTRAINT chk_addresses_lng CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);
CREATE INDEX idx_addresses_user ON addresses(user_id);
CREATE UNIQUE INDEX uq_addresses_default ON addresses(user_id) WHERE is_default;
CREATE TRIGGER trg_addresses_updated BEFORE UPDATE ON addresses
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 3) NOTIFICATIONS (NotificationChannel persistence)
-- ============================================================================
CREATE TABLE notification_log (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    BIGINT      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel    VARCHAR(20) NOT NULL
               CHECK (channel IN ('MANUAL_WHATSAPP','TELEGRAM','SMS')),
    type       VARCHAR(30) NOT NULL
               CHECK (type IN ('OTP','ORDER_SUBMIT','ORDER_UPDATE','TICKET_REPLY')),
    payload    JSONB       NOT NULL,                   -- { text, url, lang, orderNumber? }
    status     VARCHAR(15) NOT NULL DEFAULT 'GENERATED'
               CHECK (status IN ('GENERATED','SENT','FAILED')),
    sent_by    BIGINT REFERENCES users(id),
    sent_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_notification_status ON notification_log(status, created_at);
CREATE INDEX idx_notification_user   ON notification_log(user_id, created_at DESC);

-- ============================================================================
-- 4) CATALOGUE
-- ============================================================================
CREATE TABLE categories (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id  BIGINT REFERENCES categories(id),       -- self-referencing tree
    name_ar    VARCHAR(80)  NOT NULL,
    name_en    VARCHAR(80),
    slug       VARCHAR(80)  NOT NULL UNIQUE,
    image_key  VARCHAR(255),
    sort_order INT          NOT NULL DEFAULT 0,
    is_active  BOOLEAN      NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_categories_parent ON categories(parent_id, sort_order);
CREATE TRIGGER trg_categories_updated BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE products (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id         BIGINT        NOT NULL REFERENCES categories(id),
    name_ar             VARCHAR(120)  NOT NULL,
    name_en             VARCHAR(120),
    slug                VARCHAR(120)  NOT NULL UNIQUE,
    description_ar      TEXT,
    description_en      TEXT,
    unit                VARCHAR(5)    NOT NULL CHECK (unit IN ('KG','PIECE')),
    price               NUMERIC(14,2) NOT NULL CHECK (price >= 0),
    cost_price          NUMERIC(14,2),
    stock_cached        NUMERIC(12,3) NOT NULL DEFAULT 0,  -- cache; truth = stock_movements
    low_stock_threshold NUMERIC(12,3) NOT NULL DEFAULT 0,
    is_available        BOOLEAN       NOT NULL DEFAULT true, -- out today
    is_active           BOOLEAN       NOT NULL DEFAULT true, -- withdrawn
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_browse ON products(category_id, is_active, is_available);
CREATE INDEX idx_products_name   ON products(lower(name_ar));
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE product_images (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  BIGINT       NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    storage_key VARCHAR(255) NOT NULL,                 -- key for ImageStorage, not a path
    sort_order  INT          NOT NULL DEFAULT 0,
    is_primary  BOOLEAN      NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_product_images ON product_images(product_id, sort_order);
CREATE UNIQUE INDEX uq_product_images_primary ON product_images(product_id) WHERE is_primary;

CREATE TABLE product_options (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name_ar     VARCHAR(60)   NOT NULL,
    name_en     VARCHAR(60),
    price_delta NUMERIC(14,2) NOT NULL DEFAULT 0,
    sort_order  INT           NOT NULL DEFAULT 0,
    is_active   BOOLEAN       NOT NULL DEFAULT true
);
CREATE INDEX idx_product_options ON product_options(product_id, sort_order);

-- ============================================================================
-- 5) ORDERS — snapshots
-- ============================================================================
CREATE TABLE orders (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number     VARCHAR(20)   NOT NULL UNIQUE,    -- T-000123
    customer_id      BIGINT        NOT NULL REFERENCES users(id),
    status           VARCHAR(25)   NOT NULL DEFAULT 'NEW'
        CHECK (status IN ('NEW','CONFIRMED','PREPARING','READY_FOR_PICKUP',
                          'OUT_FOR_DELIVERY','DELIVERY_FAILED','PICKED_UP',
                          'DELIVERED','CANCELLED')),
    fulfillment_type VARCHAR(10)   NOT NULL CHECK (fulfillment_type IN ('PICKUP','DELIVERY')),
    lang             CHAR(2)       NOT NULL DEFAULT 'ar' CHECK (lang IN ('ar','en')),
    pickup_time      TIMESTAMPTZ,
    address_id       BIGINT REFERENCES addresses(id) ON DELETE SET NULL,
    address_snapshot TEXT,
    delivery_lat     NUMERIC(9,6),
    delivery_lng     NUMERIC(9,6),
    zone_id          BIGINT REFERENCES delivery_zones(id),
    delivery_fee     NUMERIC(14,2) NOT NULL DEFAULT 0,
    subtotal         NUMERIC(14,2) NOT NULL DEFAULT 0,  -- estimate on requested qty
    discount_total   NUMERIC(14,2) NOT NULL DEFAULT 0,  -- offers + points value
    points_redeemed  INT           NOT NULL DEFAULT 0,
    final_total      NUMERIC(14,2),                     -- after actual weights; NULL = not finalized
    payment_status   VARCHAR(15)   NOT NULL DEFAULT 'UNPAID'
        CHECK (payment_status IN ('UNPAID','PARTIAL','PAID')),
    customer_note    TEXT,
    cancel_reason    VARCHAR(150),
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_orders_delivery CHECK (
        fulfillment_type <> 'DELIVERY' OR (zone_id IS NOT NULL AND address_snapshot IS NOT NULL)),
    CONSTRAINT chk_orders_pickup CHECK (
        fulfillment_type <> 'PICKUP' OR pickup_time IS NOT NULL),
    CONSTRAINT chk_orders_pin CHECK ((delivery_lat IS NULL) = (delivery_lng IS NULL))
);
CREATE INDEX idx_orders_customer ON orders(customer_id, created_at DESC);
CREATE INDEX idx_orders_queue    ON orders(status, created_at);
CREATE INDEX idx_orders_created  ON orders(created_at);
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE order_items (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id              BIGINT        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id            BIGINT        NOT NULL REFERENCES products(id),   -- RESTRICT
    product_name_snapshot VARCHAR(120)  NOT NULL,
    unit                  VARCHAR(5)    NOT NULL CHECK (unit IN ('KG','PIECE')),
    unit_price_snapshot   NUMERIC(14,2) NOT NULL,      -- product.price + option.price_delta
    requested_qty         NUMERIC(12,3) NOT NULL CHECK (requested_qty > 0),
    actual_qty            NUMERIC(12,3) CHECK (actual_qty IS NULL OR actual_qty > 0),
    option_id             BIGINT REFERENCES product_options(id),
    option_snapshot       VARCHAR(60),
    line_total            NUMERIC(14,2),               -- set at finalize
    note                  TEXT,
    created_at            TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_order_items_order   ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id, created_at);

CREATE TABLE order_status_history (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    BIGINT      NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    from_status VARCHAR(25),
    to_status   VARCHAR(25) NOT NULL,
    changed_by  BIGINT REFERENCES users(id),           -- NULL = system
    note        VARCHAR(150),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_order_status_history ON order_status_history(order_id, created_at);

CREATE TABLE payments (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     BIGINT        NOT NULL REFERENCES orders(id),
    provider     VARCHAR(20)   NOT NULL,               -- COD today
    amount       NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    status       VARCHAR(15)   NOT NULL
                 CHECK (status IN ('PENDING','COMPLETED','FAILED','REFUNDED')),
    collected_by BIGINT REFERENCES users(id),          -- driver / employee
    external_ref VARCHAR(100),
    payload      JSONB,
    completed_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);
CREATE INDEX idx_payments_order     ON payments(order_id);
CREATE INDEX idx_payments_collector ON payments(collected_by, created_at);

-- ============================================================================
-- 6) DELIVERY
-- ============================================================================
CREATE TABLE deliveries (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id     BIGINT      NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    driver_id    BIGINT REFERENCES users(id),          -- NULL until assigned
    assigned_by  BIGINT REFERENCES users(id),
    assigned_at  TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    fail_reason  VARCHAR(150),
    attempts     SMALLINT    NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_deliveries_driver ON deliveries(driver_id, assigned_at DESC);
CREATE TRIGGER trg_deliveries_updated BEFORE UPDATE ON deliveries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 7) CMS
-- ============================================================================
CREATE TABLE theme_settings (
    key        VARCHAR(60) PRIMARY KEY,
    value      TEXT        NOT NULL,
    type       VARCHAR(10) NOT NULL CHECK (type IN ('COLOR','IMAGE','TEXT','FONT')),
    updated_by BIGINT REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_theme_settings_updated BEFORE UPDATE ON theme_settings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE content_blocks (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    block_type VARCHAR(30) NOT NULL,                   -- HERO_BANNER ANNOUNCEMENT_BAR FEATURED_CATEGORIES FEATURED_PRODUCTS OFFERS_STRIP RICH_TEXT
    title      VARCHAR(120),
    payload    JSONB       NOT NULL DEFAULT '{}'::jsonb,
    sort_order INT         NOT NULL DEFAULT 0,
    is_active  BOOLEAN     NOT NULL DEFAULT true,
    starts_at  TIMESTAMPTZ,
    ends_at    TIMESTAMPTZ,
    updated_by BIGINT REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_content_blocks_window CHECK (starts_at IS NULL OR ends_at IS NULL OR starts_at < ends_at)
);
CREATE INDEX idx_content_blocks ON content_blocks(is_active, sort_order);
CREATE TRIGGER trg_content_blocks_updated BEFORE UPDATE ON content_blocks
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 8) LOYALTY & OFFERS
-- ============================================================================
CREATE TABLE points_transactions (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id BIGINT      NOT NULL REFERENCES users(id),
    type        VARCHAR(10) NOT NULL
                CHECK (type IN ('EARN','REDEEM','ADJUST','EXPIRE','REVERSAL')),
    points      INT         NOT NULL CHECK (points <> 0),
    order_id    BIGINT REFERENCES orders(id),
    reason      VARCHAR(150),
    created_by  BIGINT REFERENCES users(id),           -- NULL = system
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_points_adjust_reason CHECK (type <> 'ADJUST' OR reason IS NOT NULL)
);
CREATE INDEX idx_points_customer ON points_transactions(customer_id, created_at);
CREATE INDEX idx_points_order    ON points_transactions(order_id);

CREATE TABLE offers (
    id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name_ar                  VARCHAR(120)  NOT NULL,
    name_en                  VARCHAR(120),
    scope                    VARCHAR(10)   NOT NULL CHECK (scope IN ('PUBLIC','PRIVATE')),
    conditions               JSONB         NOT NULL DEFAULT '{"all":[]}'::jsonb,
    benefit_type             VARCHAR(20)   NOT NULL
        CHECK (benefit_type IN ('PERCENT','FIXED','FREE_DELIVERY','BONUS_POINTS')),
    benefit_value            NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (benefit_value >= 0),
    applies_to               VARCHAR(10)   NOT NULL CHECK (applies_to IN ('CART','PRODUCT','CATEGORY')),
    target_id                BIGINT,
    starts_at                TIMESTAMPTZ,
    ends_at                  TIMESTAMPTZ,
    usage_limit_total        INT CHECK (usage_limit_total IS NULL OR usage_limit_total > 0),
    usage_limit_per_customer INT CHECK (usage_limit_per_customer IS NULL OR usage_limit_per_customer > 0),
    is_active                BOOLEAN       NOT NULL DEFAULT true,
    created_at               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at               TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_offers_target CHECK (applies_to = 'CART' OR target_id IS NOT NULL),
    CONSTRAINT chk_offers_window CHECK (starts_at IS NULL OR ends_at IS NULL OR starts_at < ends_at)
);
CREATE INDEX idx_offers_active ON offers(is_active, starts_at, ends_at);
CREATE TRIGGER trg_offers_updated BEFORE UPDATE ON offers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE offer_redemptions (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    offer_id        BIGINT        NOT NULL REFERENCES offers(id),
    order_id        BIGINT        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    customer_id     BIGINT        NOT NULL REFERENCES users(id),
    discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_offer_redemptions UNIQUE (offer_id, order_id)
);
CREATE INDEX idx_offer_redemptions_customer ON offer_redemptions(offer_id, customer_id);

-- ============================================================================
-- 9) SUPPORT & BOT
-- ============================================================================
CREATE TABLE faq_entries (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    question_ar TEXT        NOT NULL,
    question_en TEXT,
    answer_ar   TEXT        NOT NULL,
    answer_en   TEXT,
    keywords    TEXT[]      NOT NULL DEFAULT '{}',
    sort_order  INT         NOT NULL DEFAULT 0,
    is_active   BOOLEAN     NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_faq_keywords ON faq_entries USING GIN (keywords);
CREATE TRIGGER trg_faq_entries_updated BEFORE UPDATE ON faq_entries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE support_tickets (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_number VARCHAR(20)  NOT NULL UNIQUE,         -- S-000045
    customer_id   BIGINT       NOT NULL REFERENCES users(id),
    category      VARCHAR(15)  NOT NULL CHECK (category IN ('ORDER','TECHNICAL','GENERAL')),
    order_id      BIGINT REFERENCES orders(id),
    subject       VARCHAR(150) NOT NULL,
    status        VARCHAR(15)  NOT NULL DEFAULT 'OPEN'
                  CHECK (status IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED')),
    assigned_to   BIGINT REFERENCES users(id),
    source        VARCHAR(10)  NOT NULL CHECK (source IN ('CHATBOT','PORTAL','INTERNAL')),
    closed_at     TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX idx_tickets_queue    ON support_tickets(status, category, created_at);
CREATE INDEX idx_tickets_customer ON support_tickets(customer_id, created_at DESC);
CREATE TRIGGER trg_support_tickets_updated BEFORE UPDATE ON support_tickets
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE ticket_messages (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id   BIGINT      NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
    sender_id   BIGINT      NOT NULL REFERENCES users(id),
    body        TEXT        NOT NULL,
    is_internal BOOLEAN     NOT NULL DEFAULT false,    -- filtered in the service layer
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ticket_messages ON ticket_messages(ticket_id, created_at);

-- ============================================================================
-- 10) INVENTORY & PURCHASING
-- ============================================================================
CREATE TABLE suppliers (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(120) NOT NULL,
    phone      VARCHAR(20),
    note       TEXT,
    is_active  BOOLEAN      NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_suppliers_updated BEFORE UPDATE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE purchase_invoices (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id    BIGINT        NOT NULL REFERENCES suppliers(id),
    invoice_number VARCHAR(60)   NOT NULL,             -- supplier's number
    invoice_date   DATE          NOT NULL,
    total          NUMERIC(14,2) NOT NULL DEFAULT 0,
    created_by     BIGINT REFERENCES users(id),
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_purchase_invoice UNIQUE (supplier_id, invoice_number)
);
CREATE INDEX idx_purchase_invoices_date ON purchase_invoices(invoice_date);

CREATE TABLE purchase_items (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id BIGINT        NOT NULL REFERENCES purchase_invoices(id) ON DELETE CASCADE,
    product_id BIGINT        NOT NULL REFERENCES products(id),
    qty        NUMERIC(12,3) NOT NULL CHECK (qty > 0),
    unit_cost  NUMERIC(14,2) NOT NULL CHECK (unit_cost >= 0),
    line_total NUMERIC(14,2) NOT NULL
);
CREATE INDEX idx_purchase_items_invoice ON purchase_items(invoice_id);

CREATE TABLE stock_movements (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id          BIGINT        NOT NULL REFERENCES products(id),
    type                VARCHAR(15)   NOT NULL
        CHECK (type IN ('PURCHASE','SALE','WASTE','ADJUSTMENT','RETURN')),
    qty                 NUMERIC(12,3) NOT NULL CHECK (qty <> 0),  -- + in / - out
    order_id            BIGINT REFERENCES orders(id),
    purchase_invoice_id BIGINT REFERENCES purchase_invoices(id),
    reason              VARCHAR(150),
    created_by          BIGINT REFERENCES users(id),
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT chk_stock_reason CHECK (type NOT IN ('WASTE','ADJUSTMENT') OR reason IS NOT NULL)
);
CREATE INDEX idx_stock_product ON stock_movements(product_id, created_at);
CREATE INDEX idx_stock_order   ON stock_movements(order_id);

-- ============================================================================
-- 11) SYSTEM
-- ============================================================================
CREATE TABLE audit_log (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    actor_id       BIGINT REFERENCES users(id),        -- NULL = system
    actor_role     VARCHAR(20),
    action         VARCHAR(40) NOT NULL,
    entity_type    VARCHAR(40) NOT NULL,
    entity_id      BIGINT,
    old_value      JSONB,
    new_value      JSONB,
    ip             VARCHAR(45),
    correlation_id VARCHAR(40),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_actor  ON audit_log(actor_id, created_at);
CREATE INDEX idx_audit_time   ON audit_log(created_at);

CREATE TABLE settings (
    key        VARCHAR(60) PRIMARY KEY,
    value      TEXT        NOT NULL,
    group_name VARCHAR(30) NOT NULL DEFAULT 'BUSINESS'
               CHECK (group_name IN ('BUSINESS','TECHNICAL','PROVIDERS')),
    updated_by BIGINT REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER trg_settings_updated BEFORE UPDATE ON settings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 12) HELPER VIEWS (read-only conveniences; never written to)
-- ============================================================================
CREATE VIEW v_points_balance AS
SELECT customer_id, COALESCE(SUM(points), 0)::INT AS balance
FROM points_transactions GROUP BY customer_id;

CREATE VIEW v_stock_balance AS
SELECT product_id, COALESCE(SUM(qty), 0)::NUMERIC(12,3) AS balance
FROM stock_movements GROUP BY product_id;

-- ============================================================================
-- 13) APPEND-ONLY PROTECTION (application role must not UPDATE/DELETE these)
--     Run as the DB owner after creating the app role `tishreen_app`:
--       REVOKE UPDATE, DELETE ON audit_log, order_status_history, points_transactions,
--              stock_movements, otp_codes FROM tishreen_app;
--     Kept as a comment so Flyway runs under any role in dev.
-- ============================================================================
-- END — 34 tables
