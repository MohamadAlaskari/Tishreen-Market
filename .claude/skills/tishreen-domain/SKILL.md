---
name: tishreen-domain
description: Core domain knowledge for مجمع تشرين (Tishreen) — roles, vocabulary, the seven governing facts, status vocabularies, permission codes, settings keys and the locked architecture decisions. Load first for any task that touches business logic, data or API design.
user-invocable: false
---
# Tishreen domain in one page (details: tishreen-handoff/tishreen-handoff/docs/00, 01, 05)

**What**: single-store grocery e-commerce in Aleppo, Arabic-first RTL, English secondary. Roles: `CUSTOMER` (shop, track, points, tickets), `EMPLOYEE` (confirm, weigh, finalize, OTP desk, stock), `DRIVER` (own deliveries, COD, offline), `ADMIN` (everything incl. CMS, offers, reports, audit, business settings), `IT` (health, logs, providers, backups, technical settings, tech tickets).

**Seven governing facts**
1. Weighed goods: KG products are ordered in 0.250 kg steps, priced *estimated*, re-priced on `actual_qty` at the store (deviation > 30 % → warning only).
2. Order-first-then-WhatsApp: `POST /orders` persists everything, then returns a `wa.me` URL the customer opens; WhatsApp is notification, not record.
3. Manual OTP: staff generate a 6-digit code (hash stored, TTL 10 min, 5 attempts), send it through their own WhatsApp, mark sent; customer enters it on `/activate`.
4. COD only; payment recorded by staff (pickup) or driver (delivery); `payment_status` derived.
5. Points & stock are ledgers; balances are sums.
6. Everything sensitive is audited via AOP; nothing is hard-deleted.
7. Providers (notification, storage, payment, chatbot) are interfaces switched in `settings` at runtime.

**Vocabularies (verbatim)**
- Order status: `NEW → CONFIRMED → PREPARING → (READY_FOR_PICKUP → PICKED_UP) | (OUT_FOR_DELIVERY → DELIVERED | DELIVERY_FAILED → retry/cancel)`, `CANCELLED` from non-terminal states. Points earned at `DELIVERED`/`PICKED_UP`.
- User status `PENDING OTP_SENT ACTIVE BLOCKED`; fulfillment `PICKUP DELIVERY`; unit `KG PIECE`; points `EARN REDEEM ADJUST EXPIRE REVERSAL`; stock `PURCHASE SALE WASTE ADJUSTMENT RETURN`; payment status `UNPAID PARTIAL PAID`; ticket `OPEN IN_PROGRESS RESOLVED CLOSED`; notification status `GENERATED SENT FAILED`; OTP purpose `ACTIVATION PASSWORD_RESET`.
- Permissions (35): `ORDER_VIEW_ALL ORDER_MANAGE ORDER_WEIGH ORDER_ASSIGN_DRIVER ORDER_CANCEL DELIVERY_OWN DELIVERY_COLLECT_PAYMENT OTP_SEND USER_VIEW USER_MANAGE STAFF_MANAGE PRODUCT_VIEW_INTERNAL PRODUCT_MANAGE PRODUCT_AVAILABILITY PRODUCT_PRICE_EDIT CATEGORY_MANAGE STOCK_MOVE PURCHASE_MANAGE SUPPLIER_MANAGE ZONE_MANAGE OFFER_MANAGE POINTS_ADJUST CMS_MANAGE FAQ_MANAGE TICKET_VIEW TICKET_REPLY TICKET_ASSIGN REPORT_VIEW AUDIT_VIEW SETTINGS_BUSINESS SETTINGS_TECHNICAL PROVIDER_SWITCH LOGS_VIEW BACKUP_MANAGE HEALTH_VIEW`. Customers have none — role + ownership.
- Audit actions: `UPDATE_PRICE UPDATE_WEIGHT SEND_OTP CHANGE_ORDER_STATUS CANCEL_ORDER RECORD_PAYMENT ADJUST_POINTS SWITCH_PROVIDER UPDATE_SETTING BLOCK_USER CHANGE_ROLE STOCK_ADJUSTMENT ASSIGN_DRIVER`.
- Settings groups `BUSINESS` (admin) / `TECHNICAL` (IT) / `PROVIDERS` (IT). Keys: `store.* orders.* delivery.max_attempts loyalty.* otp.* bot.match_threshold auth.* storage.* backup.* logs.* map.tile_url notification.provider storage.provider payment.provider chatbot.provider` (values in tishreen-handoff/tishreen-handoff/docs/04).
- Readable numbers: orders `T-000123`, tickets `S-000045`. Money `SYP`, `NUMERIC(14,2)`; quantities `NUMERIC(12,3)`.

**Glossary ar ↔ code**: طلب order · سلة cart · وزن فعلي actual_qty · تحضير PREPARING · جاهز للاستلام READY_FOR_PICKUP · قيد التوصيل OUT_FOR_DELIVERY · تم التوصيل DELIVERED · فشل التوصيل DELIVERY_FAILED · ملغى CANCELLED · نقاط points · عرض offer · منطقة zone · تفعيل activation · كود code (OTP) · تذكرة ticket · مخزون stock · مورد supplier · فاتورة شراء purchase_invoice · مزوّد provider.

**Locked decisions** (ADR required to change): single `users` + 3 profile tables; snapshots in `order_items`/`orders`; ledgers; AOP audit; provider interfaces; `product_options` instead of variants; no meat products (schema stays generic); TanStack Start + Spring modular monolith; PostgreSQL only (no PostGIS, no Redis for v1).
