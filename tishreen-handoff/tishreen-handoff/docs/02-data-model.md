# 02 — Data Model (34 tables · 9 domains · PostgreSQL 15) — ERD v2.1

This is the **authoritative column-level specification**. `03-schema.sql` is its literal DDL.
JPA entities mirror these names exactly (`@Table(name = "order_items")`, snake_case columns via Spring's default naming).

## 0. Conventions (apply to every table)

- **Keys**: `id BIGINT GENERATED ALWAYS AS IDENTITY` (SMALLINT for `roles`, `permissions`). FK columns named `<singular_table>_id`.
- **Money**: `NUMERIC(14,2)`. **Weights/quantities**: `NUMERIC(12,3)` (gram precision). **Coordinates**: `NUMERIC(9,6)`. Never FLOAT/DOUBLE.
- **Time**: `TIMESTAMPTZ`. `created_at` everywhere (default `now()`); `updated_at` only where rows are edited, maintained by the shared trigger `set_updated_at()`.
- **Status columns**: `VARCHAR` + `CHECK` constraint, never a Postgres `ENUM` type. In Java: `@Enumerated(EnumType.STRING)`.
- **Bilingual**: `*_ar NOT NULL`, `*_en NULL`. Fallback to Arabic happens in the **service layer** (`LocalizedText.resolve(lang)`), never in components.
- **Soft delete**: `is_active = false` for anything with history. FKs are `ON DELETE RESTRICT` unless stated otherwise.
- **Three recurring patterns**: **Snapshot** (copy what a historical document showed), **Ledger** (movements, balance = `SUM`), **Extension** (1:1 role tables sharing `users.id`).

## 1. Domain map

| Domain (Java package) | Tables |
|---|---|
| `identity` | `roles`, `permissions`, `role_permissions`, `users`, `customer_profiles`, `employee_profiles`, `driver_profiles`, `otp_codes` |
| `delivery` | `delivery_zones`, `addresses`, `deliveries` |
| `platform` (notification/audit/settings) | `notification_log`, `audit_log`, `settings` |
| `catalog` | `categories`, `products`, `product_images`, `product_options` |
| `ordering` | `orders`, `order_items`, `order_status_history`, `payments` |
| `cms` | `theme_settings`, `content_blocks` |
| `loyalty` | `points_transactions`, `offers`, `offer_redemptions` |
| `support` | `faq_entries`, `support_tickets`, `ticket_messages` |
| `inventory` | `suppliers`, `purchase_invoices`, `purchase_items`, `stock_movements` |

Hubs: `users` and `orders` — almost every table references one of them.

---

## 2. Identity & permissions (8 tables)

### `roles`
| column | type | constraints | note |
|---|---|---|---|
| id | SMALLINT | PK identity | |
| code | VARCHAR(30) | UNIQUE NOT NULL | `ADMIN` `EMPLOYEE` `IT` `DRIVER` `CUSTOMER` — code depends on these, never translated |
| name_ar | VARCHAR(50) | NOT NULL | display |
| name_en | VARCHAR(50) | NULL | display |

### `permissions`
| column | type | constraints | note |
|---|---|---|---|
| id | SMALLINT | PK identity | |
| code | VARCHAR(50) | UNIQUE NOT NULL | used in `hasAuthority('ORDER_MANAGE')` |
| description | VARCHAR(150) | NULL | shown in admin |

### `role_permissions`
| column | type | constraints |
|---|---|---|
| role_id | SMALLINT | FK roles ON DELETE CASCADE |
| permission_id | SMALLINT | FK permissions ON DELETE CASCADE |
| PK | (role_id, permission_id) | prevents duplicate grants |

**Decision**: role = "who you are", permission = "what you may do". Granting a new permission to employees is a data row, not a release. One role per user (`users.role_id`); if dual roles are ever needed, migrate to a `user_roles` table without touching anything else.

### `users` ★
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| full_name | VARCHAR(120) | NOT NULL | |
| phone | VARCHAR(20) | UNIQUE NOT NULL | E.164 (`+963…`); login name **and** notification channel |
| password_hash | VARCHAR(100) | NOT NULL | BCrypt |
| role_id | SMALLINT | FK roles NOT NULL | |
| status | VARCHAR(20) | NOT NULL DEFAULT 'PENDING' CHECK IN ('PENDING','OTP_SENT','ACTIVE','BLOCKED') | route guards read this |
| preferred_language | CHAR(2) | NOT NULL DEFAULT 'ar' CHECK IN ('ar','en') | drives OTP/order message language |
| last_login_at | TIMESTAMPTZ | NULL | |
| created_at / updated_at | TIMESTAMPTZ | NOT NULL | trigger |

Indexes: `phone` (unique), `(role_id, status)`.

### `customer_profiles` (1:1)
| column | type | constraints | note |
|---|---|---|---|
| user_id | BIGINT | PK, FK users | PK=FK enforces 1:1 in the DB |
| staff_note | TEXT | NULL | internal ("يفضّل التوصيل مساءً"), never returned to customers |
| created_at | TIMESTAMPTZ | | |

### `employee_profiles` (1:1)
| column | type | note |
|---|---|---|
| user_id | BIGINT PK FK | |
| job_title | VARCHAR(80) | |
| hired_at | DATE | |
| note | TEXT | |
| created_at | TIMESTAMPTZ | |

### `driver_profiles` (1:1)
| column | type | note |
|---|---|---|
| user_id | BIGINT PK FK | |
| vehicle_type | VARCHAR(40) | |
| vehicle_plate | VARCHAR(20) | |
| is_available | BOOLEAN NOT NULL DEFAULT true | feeds the "available drivers" dropdown; toggled by driver or staff |
| created_at / updated_at | TIMESTAMPTZ | |

**Decision**: deliveries reference `users.id` (not `driver_profiles`) so every "who did what" column in the system points to the same table.

### `otp_codes`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| user_id | BIGINT | FK users NOT NULL | owner |
| code_hash | VARCHAR(100) | NOT NULL | hash of the 6-digit code (BCrypt or SHA-256+pepper) |
| purpose | VARCHAR(20) | NOT NULL CHECK IN ('ACTIVATION','PASSWORD_RESET') | |
| expires_at | TIMESTAMPTZ | NOT NULL | now + `otp.ttl_minutes` |
| attempts | SMALLINT | NOT NULL DEFAULT 0 | locked at `otp.max_attempts` |
| used_at | TIMESTAMPTZ | NULL | prevents reuse |
| created_by | BIGINT | FK users NULL | employee who generated (NULL = self-service reset request) |
| created_at | TIMESTAMPTZ | | |

Index: `(user_id, purpose, created_at DESC)`. Rows are never deleted — they are the audit trail of who activated whom.

---

## 3. Addresses & zones (2 tables)

### `delivery_zones`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| name_ar / name_en | VARCHAR(80) | ar NOT NULL | |
| fee | NUMERIC(14,2) | NOT NULL DEFAULT 0 | snapshotted into `orders.delivery_fee` |
| min_order | NUMERIC(14,2) | NOT NULL DEFAULT 0 | blocks checkout below it |
| is_active | BOOLEAN | NOT NULL DEFAULT true | pause a zone without breaking old orders |
| sort_order | INT | NOT NULL DEFAULT 0 | |
| created_at / updated_at | | | |

### `addresses`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| user_id | BIGINT | FK users NOT NULL ON DELETE CASCADE | |
| label | VARCHAR(40) | NULL | "البيت" / "العمل" |
| zone_id | BIGINT | FK delivery_zones NOT NULL | determines fee |
| details | TEXT | NOT NULL | free text: street, building, floor — **always mandatory** |
| latitude | NUMERIC(9,6) | NULL | optional map pin (Leaflet + OSM) |
| longitude | NUMERIC(9,6) | NULL | both null or both set (CHECK) |
| is_default | BOOLEAN | NOT NULL DEFAULT false | |
| created_at / updated_at | | | |

Indexes: `(user_id)`; **partial unique** `UNIQUE (user_id) WHERE is_default` → two defaults are impossible at DB level.
**Decision (v2.1)**: pin supplements the description because street names/house numbers are unreliable; the pin never selects the zone (no geofencing, no PostGIS).

---

## 4. Notifications (1 table here; `otp_codes` above)

### `notification_log`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| user_id | BIGINT | FK users NOT NULL | recipient (for `ORDER_SUBMIT` the customer who sends to the store) |
| channel | VARCHAR(20) | NOT NULL CHECK IN ('MANUAL_WHATSAPP','TELEGRAM','SMS') | channel used at the time |
| type | VARCHAR(30) | NOT NULL CHECK IN ('OTP','ORDER_SUBMIT','ORDER_UPDATE','TICKET_REPLY') | |
| payload | JSONB | NOT NULL | `{ "text": "...", "url": "https://wa.me/...", "lang": "ar", "orderNumber": "T-000123" }` |
| status | VARCHAR(15) | NOT NULL DEFAULT 'GENERATED' CHECK IN ('GENERATED','SENT','FAILED') | manual channel: SENT only after staff confirms |
| sent_by | BIGINT | FK users NULL | who pressed send |
| sent_at | TIMESTAMPTZ | NULL | |
| created_at | TIMESTAMPTZ | | |

Indexes: `(status, created_at)` (pending list), `(user_id, created_at DESC)`.
No FK to orders on purpose — payload keeps the channel generic.

---

## 5. Catalogue (4 tables)

### `categories`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| parent_id | BIGINT | FK categories NULL | self-referencing tree, NULL = root |
| name_ar / name_en | VARCHAR(80) | ar NOT NULL | |
| slug | VARCHAR(80) | UNIQUE NOT NULL | latin, one URL for both languages |
| image_key | VARCHAR(255) | NULL | `ImageStorage` key, not a path |
| sort_order | INT | NOT NULL DEFAULT 0 | |
| is_active | BOOLEAN | NOT NULL DEFAULT true | |
| created_at / updated_at | | | |

Index: `(parent_id, sort_order)`.

### `products` ★
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| category_id | BIGINT | FK categories NOT NULL | |
| name_ar / name_en | VARCHAR(120) | ar NOT NULL | |
| slug | VARCHAR(120) | UNIQUE NOT NULL | |
| description_ar / description_en | TEXT | NULL | |
| unit | VARCHAR(5) | NOT NULL CHECK IN ('KG','PIECE') | **the pivotal field**: KG is weighed, PIECE is counted |
| price | NUMERIC(14,2) | NOT NULL CHECK >= 0 | price per unit |
| cost_price | NUMERIC(14,2) | NULL | last purchase cost (updated by ERP) |
| stock_cached | NUMERIC(12,3) | NOT NULL DEFAULT 0 | derived cache; truth = `stock_movements` |
| low_stock_threshold | NUMERIC(12,3) | NOT NULL DEFAULT 0 | alert when `stock_cached <= threshold` |
| is_available | BOOLEAN | NOT NULL DEFAULT true | "out today" — shown greyed |
| is_active | BOOLEAN | NOT NULL DEFAULT true | withdrawn from catalogue |
| created_at / updated_at | | | |

Indexes: `(category_id, is_active, is_available)`, `slug` unique, `lower(name_ar)` btree for search (trigram later).
FK from `order_items`, `purchase_items`, `stock_movements` are RESTRICT: a product with history is never deleted.

### `product_images`
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| product_id | BIGINT FK products ON DELETE CASCADE | |
| storage_key | VARCHAR(255) NOT NULL | |
| sort_order | INT NOT NULL DEFAULT 0 | |
| is_primary | BOOLEAN NOT NULL DEFAULT false | cover image |
| created_at | | |

Index: `(product_id, sort_order)`; partial unique `(product_id) WHERE is_primary`.

### `product_options`
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| product_id | BIGINT FK products | |
| name_ar / name_en | VARCHAR(60) | "تقطيع", "تغليف", "حجم العبوة" |
| price_delta | NUMERIC(14,2) NOT NULL DEFAULT 0 | added to unit price |
| sort_order | INT NOT NULL DEFAULT 0 | |
| is_active | BOOLEAN NOT NULL DEFAULT true | |

**Decision**: generic options keep the door open for meat prep options ("ستيك", "مفروم") as rows later.

---

## 6. Orders — the heart (4 tables)

### `orders` ★
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| order_number | VARCHAR(20) | UNIQUE NOT NULL | `T-000123` from `order_number_seq`; the only id customers see |
| customer_id | BIGINT | FK users NOT NULL | |
| status | VARCHAR(25) | NOT NULL DEFAULT 'NEW' CHECK IN ('NEW','CONFIRMED','PREPARING','READY_FOR_PICKUP','OUT_FOR_DELIVERY','DELIVERY_FAILED','PICKED_UP','DELIVERED','CANCELLED') | 9 states |
| fulfillment_type | VARCHAR(10) | NOT NULL CHECK IN ('PICKUP','DELIVERY') | |
| lang | CHAR(2) | NOT NULL DEFAULT 'ar' CHECK IN ('ar','en') | customer language at order time (message regeneration) |
| pickup_time | TIMESTAMPTZ | NULL | PICKUP only |
| address_id | BIGINT | FK addresses NULL ON DELETE SET NULL | reference only |
| address_snapshot | TEXT | NULL | zone name + details copied at creation |
| delivery_lat / delivery_lng | NUMERIC(9,6) | NULL | pin snapshot → driver `geo:` link |
| zone_id | BIGINT | FK delivery_zones NULL | |
| delivery_fee | NUMERIC(14,2) | NOT NULL DEFAULT 0 | fee snapshot |
| subtotal | NUMERIC(14,2) | NOT NULL DEFAULT 0 | **estimate** at order time (requested qty) |
| discount_total | NUMERIC(14,2) | NOT NULL DEFAULT 0 | offers + points value |
| points_redeemed | INT | NOT NULL DEFAULT 0 | |
| final_total | NUMERIC(14,2) | NULL | set by finalize after actual weights; NULL = not weighed yet |
| payment_status | VARCHAR(15) | NOT NULL DEFAULT 'UNPAID' CHECK IN ('UNPAID','PARTIAL','PAID') | independent of `status` |
| customer_note | TEXT | NULL | |
| cancel_reason | VARCHAR(150) | NULL | |
| created_at / updated_at | | | |

CHECKs: `fulfillment_type='DELIVERY' → zone_id IS NOT NULL AND address_snapshot IS NOT NULL`; `fulfillment_type='PICKUP' → pickup_time IS NOT NULL`; `(delivery_lat IS NULL) = (delivery_lng IS NULL)`.
Indexes: `(customer_id, created_at DESC)` "my orders"; `(status, created_at)` staff queue (most frequent query); `order_number` unique; `(created_at)` reports.

**Decision**: `subtotal` and `final_total` are separate so that what the customer saw and what they paid are both visible in any dispute.

### `order_items` ★
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| order_id | BIGINT | FK orders NOT NULL ON DELETE CASCADE | |
| product_id | BIGINT | FK products NOT NULL (RESTRICT) | |
| product_name_snapshot | VARCHAR(120) | NOT NULL | name in `orders.lang` at the time |
| unit | VARCHAR(5) | NOT NULL CHECK IN ('KG','PIECE') | |
| unit_price_snapshot | NUMERIC(14,2) | NOT NULL | `product.price + option.price_delta` at the time |
| requested_qty | NUMERIC(12,3) | NOT NULL CHECK > 0 | customer asked (1.000) |
| actual_qty | NUMERIC(12,3) | NULL CHECK > 0 | scale result (1.070); NULL = not prepared yet |
| option_id | BIGINT | FK product_options NULL | |
| option_snapshot | VARCHAR(60) | NULL | option name at the time |
| line_total | NUMERIC(14,2) | NULL | `unit_price_snapshot × actual_qty`, set at finalize |
| note | TEXT | NULL | per-item customer note |
| created_at | | | |

Index: `(order_id)`, `(product_id, created_at)` (top products report).

### `order_status_history` (append-only)
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| order_id | BIGINT FK orders ON DELETE CASCADE | |
| from_status | VARCHAR(25) NULL | NULL on creation |
| to_status | VARCHAR(25) NOT NULL | |
| changed_by | BIGINT FK users NULL | NULL = system job |
| note | VARCHAR(150) NULL | cancel reason / remark |
| created_at | TIMESTAMPTZ | |

Index: `(order_id, created_at)`. Every row here is a potential customer notification.

### `payments`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| order_id | BIGINT | FK orders NOT NULL | |
| provider | VARCHAR(20) | NOT NULL | `COD` today; gateway code later |
| amount | NUMERIC(14,2) | NOT NULL CHECK > 0 | several rows allow partial payment |
| status | VARCHAR(15) | NOT NULL CHECK IN ('PENDING','COMPLETED','FAILED','REFUNDED') | |
| collected_by | BIGINT | FK users NULL | driver/employee who took the cash — basis of daily cash reconciliation |
| external_ref | VARCHAR(100) | NULL | gateway reference |
| payload | JSONB | NULL | gateway callback |
| completed_at | TIMESTAMPTZ | NULL | |
| created_at | | | |

Indexes: `(order_id)`, `(collected_by, created_at)`.
`orders.payment_status` = derived from `SUM(amount) WHERE status='COMPLETED'` vs `final_total` (updated in the same transaction).

---

## 7. Delivery (1 table)

### `deliveries` (1:1 with orders via UNIQUE)
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| order_id | BIGINT | FK orders NOT NULL **UNIQUE** | one delivery record per order |
| driver_id | BIGINT | FK users NULL | NULL until assigned |
| assigned_by | BIGINT | FK users NULL | |
| assigned_at | TIMESTAMPTZ | NULL | |
| delivered_at | TIMESTAMPTZ | NULL | |
| fail_reason | VARCHAR(150) | NULL | last failure reason |
| attempts | SMALLINT | NOT NULL DEFAULT 0 | incremented on each failure |
| created_at / updated_at | | | |

Index: `(driver_id, assigned_at DESC)` "my deliveries".
PICKUP orders have no row here. Cash is in `payments`, coordinates come from `orders.delivery_lat/lng`.

---

## 8. CMS (2 tables)

### `theme_settings`
| column | type | note |
|---|---|---|
| key | VARCHAR(60) PK | `theme_preset` (rose/orange/sky), `primary_hue` (empty or 0–360), `logo_key`, `store_name_ar`, `store_name_en`, `slogan_ar`, `slogan_en`, `font_display`, `font_body`, `font_label` |
| value | TEXT NOT NULL | |
| type | VARCHAR(10) NOT NULL CHECK IN ('COLOR','IMAGE','TEXT','FONT') | tells the admin UI which editor to show |
| updated_by | BIGINT FK users NULL | |
| updated_at | TIMESTAMPTZ | |

### `content_blocks`
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| block_type | VARCHAR(30) NOT NULL | `HERO_BANNER` `ANNOUNCEMENT_BAR` `FEATURED_CATEGORIES` `FEATURED_PRODUCTS` `OFFERS_STRIP` `RICH_TEXT` |
| title | VARCHAR(120) NULL | admin-facing label |
| payload | JSONB NOT NULL | bilingual content; ids of products/categories live here (no FK on purpose) |
| sort_order | INT NOT NULL DEFAULT 0 | |
| is_active | BOOLEAN NOT NULL DEFAULT true | |
| starts_at / ends_at | TIMESTAMPTZ NULL | scheduling (Ramadan banner appears/disappears alone) |
| updated_by | BIGINT FK users NULL | |
| created_at / updated_at | | |

Index: `(is_active, sort_order)`.

---

## 9. Loyalty & offers (3 tables)

### `points_transactions` (ledger)
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| customer_id | BIGINT | FK users NOT NULL | |
| type | VARCHAR(10) | NOT NULL CHECK IN ('EARN','REDEEM','ADJUST','EXPIRE','REVERSAL') | |
| points | INT | NOT NULL CHECK <> 0 | + earn / − redeem |
| order_id | BIGINT | FK orders NULL | cause |
| reason | VARCHAR(150) | NULL, CHECK (type <> 'ADJUST' OR reason IS NOT NULL) | mandatory on manual adjust |
| created_by | BIGINT | FK users NULL | NULL = system |
| created_at | | | |

Index: `(customer_id, created_at)`. Balance = `SELECT COALESCE(SUM(points),0) WHERE customer_id = ?`.

### `offers`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| name_ar / name_en | VARCHAR(120) | ar NOT NULL | |
| scope | VARCHAR(10) | NOT NULL CHECK IN ('PUBLIC','PRIVATE') | private = only eligible customers see it |
| conditions | JSONB | NOT NULL DEFAULT '{"all":[]}' | Specification tree — see `05-business-rules.md §5` |
| benefit_type | VARCHAR(20) | NOT NULL CHECK IN ('PERCENT','FIXED','FREE_DELIVERY','BONUS_POINTS') | |
| benefit_value | NUMERIC(14,2) | NOT NULL DEFAULT 0 | % / amount / points |
| applies_to | VARCHAR(10) | NOT NULL CHECK IN ('CART','PRODUCT','CATEGORY') | |
| target_id | BIGINT | NULL | product or category id when not CART |
| starts_at / ends_at | TIMESTAMPTZ | NULL | |
| usage_limit_total | INT | NULL | |
| usage_limit_per_customer | INT | NULL | |
| is_active | BOOLEAN | NOT NULL DEFAULT true | |
| created_at / updated_at | | | |

Index: `(is_active, starts_at, ends_at)`.

### `offer_redemptions`
| column | type | constraints |
|---|---|---|
| id | BIGINT | PK |
| offer_id | BIGINT | FK offers NOT NULL |
| order_id | BIGINT | FK orders NOT NULL |
| customer_id | BIGINT | FK users NOT NULL |
| discount_amount | NUMERIC(14,2) | NOT NULL DEFAULT 0 (0 for BONUS_POINTS) |
| created_at | | |
| UNIQUE | (offer_id, order_id) | an offer applies once per order |

Index: `(offer_id, customer_id)` for per-customer limits. Usage counts exclude orders with `status='CANCELLED'`.

---

## 10. Support & bot (3 tables)

### `faq_entries`
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| question_ar / question_en | TEXT | ar NOT NULL |
| answer_ar / answer_en | TEXT | ar NOT NULL |
| keywords | TEXT[] NOT NULL DEFAULT '{}' | both languages; matching uses these |
| sort_order | INT NOT NULL DEFAULT 0 | tie-breaker |
| is_active | BOOLEAN NOT NULL DEFAULT true | |
| created_at / updated_at | | |

Index: `GIN (keywords)`.

### `support_tickets`
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| ticket_number | VARCHAR(20) | UNIQUE NOT NULL | `S-000045` |
| customer_id | BIGINT | FK users NOT NULL | |
| category | VARCHAR(15) | NOT NULL CHECK IN ('ORDER','TECHNICAL','GENERAL') | routes: ORDER/GENERAL → staff, TECHNICAL → IT |
| order_id | BIGINT | FK orders NULL | context |
| subject | VARCHAR(150) | NOT NULL | |
| status | VARCHAR(15) | NOT NULL DEFAULT 'OPEN' CHECK IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED') | |
| assigned_to | BIGINT | FK users NULL | |
| source | VARCHAR(10) | NOT NULL CHECK IN ('CHATBOT','PORTAL','INTERNAL') | measures bot usefulness |
| closed_at | TIMESTAMPTZ | NULL | |
| created_at / updated_at | | | |

Indexes: `(status, category, created_at)`, `(customer_id, created_at DESC)`.

### `ticket_messages`
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| ticket_id | BIGINT FK support_tickets ON DELETE CASCADE | |
| sender_id | BIGINT FK users NOT NULL | customer or staff |
| body | TEXT NOT NULL | |
| is_internal | BOOLEAN NOT NULL DEFAULT false | **filtered in the service layer** — leaking one is worse than a render bug |
| created_at | | |

Index: `(ticket_id, created_at)`.

---

## 11. Inventory & purchasing (4 tables)

### `suppliers`
`id`, `name VARCHAR(120) NOT NULL`, `phone VARCHAR(20)`, `note TEXT`, `is_active BOOLEAN DEFAULT true`, `created_at/updated_at`.

### `purchase_invoices`
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| supplier_id | BIGINT FK suppliers NOT NULL | |
| invoice_number | VARCHAR(60) NOT NULL | supplier's number (not globally unique) — UNIQUE `(supplier_id, invoice_number)` |
| invoice_date | DATE NOT NULL | |
| total | NUMERIC(14,2) NOT NULL DEFAULT 0 | sum of lines |
| created_by | BIGINT FK users NULL | |
| created_at | | |

### `purchase_items`
`id`, `invoice_id FK purchase_invoices ON DELETE CASCADE`, `product_id FK products`, `qty NUMERIC(12,3) CHECK > 0`, `unit_cost NUMERIC(14,2) NOT NULL`, `line_total NUMERIC(14,2) NOT NULL`. Each line produces one `PURCHASE` stock movement and sets `products.cost_price = unit_cost`.

### `stock_movements` (ledger)
| column | type | constraints | note |
|---|---|---|---|
| id | BIGINT | PK | |
| product_id | BIGINT | FK products NOT NULL | |
| type | VARCHAR(15) | NOT NULL CHECK IN ('PURCHASE','SALE','WASTE','ADJUSTMENT','RETURN') | |
| qty | NUMERIC(12,3) | NOT NULL CHECK <> 0 | + in / − out |
| order_id | BIGINT | FK orders NULL | SALE / RETURN |
| purchase_invoice_id | BIGINT | FK purchase_invoices NULL | PURCHASE |
| reason | VARCHAR(150) | NULL, CHECK (type NOT IN ('WASTE','ADJUSTMENT') OR reason IS NOT NULL) | |
| created_by | BIGINT | FK users NULL | |
| created_at | | | |

Index: `(product_id, created_at)`. **Decision**: `products.stock_cached` is updated in the same transaction that inserts the movement.

---

## 12. System (2 tables)

### `audit_log` (append-only)
| column | type | note |
|---|---|---|
| id | BIGINT PK | |
| actor_id | BIGINT FK users NULL | NULL = system |
| actor_role | VARCHAR(20) | role snapshot |
| action | VARCHAR(40) NOT NULL | `UPDATE_PRICE`, `SEND_OTP` … |
| entity_type | VARCHAR(40) NOT NULL | `Order`, `Product`, `Offer`, `Setting` … |
| entity_id | BIGINT NULL | |
| old_value / new_value | JSONB | literal diff |
| ip | VARCHAR(45) | |
| correlation_id | VARCHAR(40) | joins with technical logs (`/it/logs`) |
| created_at | | |

Indexes: `(entity_type, entity_id)`, `(actor_id, created_at)`, `(created_at)`. First candidate for monthly partitioning.

### `settings`
| column | type | note |
|---|---|---|
| key | VARCHAR(60) PK | `notification.provider`, `store.whatsapp_number` … |
| value | TEXT NOT NULL | |
| group_name | VARCHAR(30) NOT NULL CHECK IN ('BUSINESS','TECHNICAL','PROVIDERS') | who may edit |
| updated_by | BIGINT FK users NULL | |
| updated_at | TIMESTAMPTZ | |

---

## 13. Relationship summary

| Kind | Pair | Enforced by |
|---|---|---|
| 1:1 | users ↔ customer/employee/driver_profiles | `user_id` is PK and FK |
| 1:1 | orders ↔ deliveries | `UNIQUE(order_id)` |
| N:M | roles ↔ permissions | `role_permissions` composite PK |
| N:M | offers ↔ orders | `offer_redemptions` + `UNIQUE(offer_id, order_id)` |
| self | categories ↔ categories | `parent_id` |
| double FK to users | otp_codes, deliveries, payments, support_tickets, notification_log, ticket_messages | owner column + actor column |
| partial unique | addresses | `UNIQUE(user_id) WHERE is_default` |
| partial unique | product_images | `UNIQUE(product_id) WHERE is_primary` |

## 14. Indexes that define screen speed

| Index | Screen |
|---|---|
| `orders(customer_id, created_at DESC)` | `/orders` |
| `orders(status, created_at)` | `/staff/queue` |
| `products(category_id, is_active, is_available)` | `/c/:slug` |
| `deliveries(driver_id, assigned_at DESC)` | `/driver/deliveries` |
| `payments(collected_by, created_at)` | cash reconciliation |
| `points_transactions(customer_id, created_at)` | `/account/points` |
| `stock_movements(product_id, created_at)` | `/admin/erp/stock` |
| `faq_entries USING GIN(keywords)` | bot |
| `audit_log(entity_type, entity_id)` | `/admin/audit` |
| `notification_log(status, created_at)` | `/staff/otp` pending sends |

## 15. Growth & partitioning
Fast-growing tables: `orders`, `order_items`, `stock_movements`, `audit_log`. The first three are indexed precisely; `audit_log` gets monthly range partitions when it exceeds ~5M rows (Phase 6+, `pg_partman` optional).
