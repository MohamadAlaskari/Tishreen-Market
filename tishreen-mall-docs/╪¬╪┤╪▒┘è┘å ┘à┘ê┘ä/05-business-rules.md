# 05 — Business Rules (server-side truth)

All money/points/state rules are computed and enforced in the backend. Frontend checks are UX only.
Every rule here has a unit test name in `13-quality.md`.

---

## 1. Order lifecycle — state machine (9 states)

```
                ┌────────────┐
 (create) ────▶ │    NEW     │ ───────────────┐
                └─────┬──────┘                │
          confirm     │                       │ cancel (staff / customer while NEW)
                ┌─────▼──────┐                │
                │ CONFIRMED  │ ───────────────┤
                └─────┬──────┘                │
      startPreparing  │                       │ cancel (staff)
                ┌─────▼──────┐                │
                │ PREPARING  │ ───────────────┤
                └──┬──────┬──┘                │
   PICKUP: ready   │      │ DELIVERY: dispatch(driverId)
          ┌────────▼──┐ ┌─▼────────────────┐  │
          │READY_FOR_ │ │ OUT_FOR_DELIVERY │◀─┼──────────┐
          │PICKUP     │ └──┬───────────┬───┘  │          │ retry(driverId?)
          └────┬──────┘    │delivered  │failed│     ┌────┴────────────┐
   pickedUp    │           ▼           ▼      │     │ DELIVERY_FAILED │───▶ cancel (staff)
          ┌────▼──────┐ ┌──────────┐ ┌────────┴─────┴─────────────────┘
          │ PICKED_UP │ │DELIVERED │ │ CANCELLED │
          └───────────┘ └──────────┘ └───────────┘
```

| From | To | Action | Who (permission) | Preconditions | Side effects |
|---|---|---|---|---|---|
| — | NEW | `createOrder` | CUSTOMER (ACTIVE) | store open; cart valid; min order met | items snapshots; `order_status_history(NULL→NEW)`; `offer_redemptions`; `points REDEEM`; `notification_log(ORDER_SUBMIT)` |
| NEW | CONFIRMED | `confirm` | `ORDER_MANAGE` | — | history; notification `ORDER_UPDATE` ("استلمنا طلبك") |
| NEW | CANCELLED | `cancel` | `ORDER_CANCEL` or the **owner** (customer) | reason required for staff | history; points `REVERSAL`; redemptions excluded from limits (via status) |
| CONFIRMED | PREPARING | `startPreparing` | `ORDER_MANAGE` | — | history |
| CONFIRMED | CANCELLED | `cancel` | `ORDER_CANCEL` | reason | as above |
| PREPARING | PREPARING | `setActualQty(item)` | `ORDER_WEIGH` | item.unit=KG (PIECE auto) | `audit UPDATE_WEIGHT` old/new |
| PREPARING | PREPARING | `finalize` | `ORDER_MANAGE` | all KG lines weighed | recompute `line_total`, `final_total`; audit |
| PREPARING | READY_FOR_PICKUP | `ready` | `ORDER_MANAGE` | PICKUP; `final_total` not null | **stock SALE movements**; history; notification ("طلبك جاهز") |
| PREPARING | OUT_FOR_DELIVERY | `dispatch(driverId)` | `ORDER_ASSIGN_DRIVER` | DELIVERY; finalized; driver role=DRIVER & `is_available` | `deliveries` upsert (driver, assigned_by/at); **stock SALE**; history; audit `ASSIGN_DRIVER`; notification ("السائق في الطريق") |
| PREPARING | CANCELLED | `cancel` | `ORDER_CANCEL` | reason | points reversal |
| READY_FOR_PICKUP | PICKED_UP | `pickedUp(amount)` | `ORDER_MANAGE` | — | `payments(COD, COMPLETED, collected_by=staff)`; `payment_status`; **points EARN**; history; audit `RECORD_PAYMENT` |
| READY_FOR_PICKUP | CANCELLED | `cancel` | `ORDER_CANCEL` | reason | stock `RETURN` (+) reversing SALE; points reversal |
| OUT_FOR_DELIVERY | DELIVERED | `delivered(amount)` | `DELIVERY_OWN` **and** `deliveries.driver_id = me` (or `ORDER_MANAGE`) | — | `payments(COD, COMPLETED, collected_by=driver)`; `payment_status`; `deliveries.delivered_at`; **points EARN**; history; notification ("شكرًا لك"); audit `RECORD_PAYMENT` |
| OUT_FOR_DELIVERY | DELIVERY_FAILED | `failed(reason)` | driver (own) or staff | reason from list or free text | `deliveries.attempts++`, `fail_reason`; history |
| DELIVERY_FAILED | OUT_FOR_DELIVERY | `retry(driverId?)` | `ORDER_ASSIGN_DRIVER` | attempts < `delivery.max_attempts` (else only cancel) | reassign optional; history |
| DELIVERY_FAILED | CANCELLED | `cancel` | `ORDER_CANCEL` | reason | stock `RETURN`; points reversal |

Rules:
- Any transition not in the table → `409 ORDER_INVALID_TRANSITION` with `{from, to}`.
- Transitions are executed inside one `@Transactional` method that locks the order row (`SELECT … FOR UPDATE` via `@Lock(PESSIMISTIC_WRITE)`) to prevent double actions from two staff tabs.
- `changed_by` is the current user; NULL only for scheduled jobs.
- Terminal states: `PICKED_UP`, `DELIVERED`, `CANCELLED`. `payment_status` may still change on terminal orders only through an admin payment correction (audited).
- `DELIVERY_FAILED` is not terminal; the driver's list keeps showing it under "فشل — بانتظار القرار".

Customer self-cancel: allowed only while `status = NEW` (setting `orders.customer_cancel_while`). After that the customer must contact the store (the detail page shows the WhatsApp button instead of cancel).

---

## 2. Order creation & pricing (estimate)

Input (`CreateOrderRequest`): `fulfillmentType`, `pickupTime?`, `addressId?`, `items[{productId, optionId?, qty, note?}]`, `pointsToRedeem`, `customerNote?`, `lang`.

Algorithm (all in `OrderingService.createOrder`, single transaction):

1. **Guards**: user `ACTIVE` & role `CUSTOMER`; `store.is_open = true` else `423 STORE_CLOSED`; items non-empty (`≤ 50 lines`).
2. **Load products** by ids `FOR SHARE`; reject inactive/unavailable (`422 PRODUCT_UNAVAILABLE {productId}`); validate option belongs to product and is active.
3. **Quantity validation**: `KG` → multiple of `orders.weight_step_kg` and `≥ orders.min_weight_kg`; `PIECE` → positive integer.
4. **Snapshots per line**: `product_name_snapshot = name in lang (fallback ar)`, `unit`, `unit_price_snapshot = price + COALESCE(option.price_delta,0)`, `option_snapshot = option name in lang`, `requested_qty`, `actual_qty = NULL`, `line_total = NULL`.
5. **Goods subtotal** `S = Σ unit_price_snapshot × requested_qty` (rounded half-up to 2 dp per line, then summed).
6. **Fulfillment**:
   - `PICKUP`: `pickup_time` required, `≥ now + orders.pickup_lead_minutes`, inside store hours → `422 PICKUP_TIME_INVALID`.
   - `DELIVERY`: address must belong to the customer (`404 ADDRESS_NOT_FOUND`); zone active (`422 ZONE_INACTIVE`); `S ≥ zone.min_order` (`422 BELOW_MIN_ORDER {minOrder}`); snapshots: `address_snapshot = "<zone name_ar> — <details>"`, `delivery_lat/lng`, `zone_id`, `delivery_fee = zone.fee`.
7. **Offers** (§5): evaluate eligible offers on the cart context; choose **one** monetary offer with the highest discount (tie → lowest id); collect all `BONUS_POINTS` offers. `offerDiscount` is capped at `S` (or at `delivery_fee` for FREE_DELIVERY).
8. **Points redemption** (§4): validate `pointsToRedeem`; `pointsValue = pointsToRedeem × loyalty.redeem_point_value`; cap so that `pointsValue ≤ loyalty.max_redeem_share × (S − offerDiscountOnGoods)`.
9. `discount_total = offerDiscount + pointsValue`; `subtotal = S`; `final_total = NULL`; `payment_status = UNPAID`; `status = NEW`; `order_number = 'T-' || lpad(nextval('order_number_seq'), 6, '0')`.
10. Persist order, items, `order_status_history (NULL → NEW)`, `offer_redemptions` (one per applied offer, `discount_amount`), `points_transactions (REDEEM, −pointsToRedeem, order_id)`.
11. **Notification**: build WhatsApp text (§7) in `lang`; `NotificationChannel.send(ORDER_SUBMIT)` → `notification_log` row; return `{ order, whatsappUrl }`.

`POST /checkout/quote` runs steps 1–9 **without persisting** and returns the computed figures plus `warnings[]` (price changed vs client-sent `expectedUnitPrice`, unavailable items, points capped). The frontend must call it before showing the confirm button and must treat its numbers as the only truth.

Display estimate to customer: `estimatedTotal = subtotal + delivery_fee − discount_total` with the label "تقديري — يُحدَّد السعر النهائي بعد الوزن" when any line is `KG`.

---

## 3. Weighing & finalize (actual pricing)

- `setActualQty(orderId, itemId, actualQty)`: order must be `PREPARING`; item `unit = KG`; `actualQty > 0`, 3 dp. Deviation `d = |actual − requested| / requested`. If `d > orders.weight_tolerance_pct/100` the response carries `warning: WEIGHT_DEVIATION` (UI shows the warning row) — **not blocked**. Audit `UPDATE_WEIGHT {old, new, requested}`.
- `finalize(orderId)`: all `KG` lines have `actual_qty`; for `PIECE` lines set `actual_qty = requested_qty` if null. `line_total = round(unit_price_snapshot × actual_qty, 2)`. `goodsActual = Σ line_total`.
  - Re-evaluate the monetary offer on the **actual** goods (same offer id; PERCENT recomputed, FIXED unchanged but capped at `goodsActual`, FREE_DELIVERY unchanged). Update that `offer_redemptions.discount_amount`.
  - Points value is **not** recomputed (the customer already paid points) but is capped at `goodsActual − offerDiscount` (never negative totals).
  - `discount_total = offerDiscount + pointsValue`; `final_total = max(0, goodsActual + delivery_fee − discount_total)`.
  - Audit `CHANGE_ORDER_STATUS`? No — audit `FINALIZE_ORDER` is not in the mandatory list; finalize is logged as `UPDATE_PRICE` on entity `Order` with `{subtotal, final_total, lines[]}`.
- Re-finalize is allowed while still `PREPARING` (idempotent recomputation).

---

## 4. Loyalty points (ledger)

Settings: `loyalty.earn_points_per_amount` (1), `loyalty.earn_amount_unit` (1000), `loyalty.redeem_point_value` (10), `loyalty.min_redeem_points` (100), `loyalty.max_redeem_share` (0.5), `loyalty.expiry_days` (365).

- **Balance** = `SUM(points)` for the customer (`v_points_balance`). Never cached in a column.
- **Earn** at `DELIVERED` / `PICKED_UP`: `goods = final_total − delivery_fee` (≥ 0); `points = floor(goods / earn_amount_unit) × earn_points_per_amount` plus `BONUS_POINTS` offers applied to the order. Row: `EARN, +points, order_id, created_by NULL`. No points on cancelled or estimated totals.
- **Redeem** at checkout: `pointsToRedeem ≥ min_redeem_points` (or 0); `≤ balance`; value cap per §2.8; row `REDEEM, −points, order_id`. Row `REVERSAL, +points, order_id` on cancel.
- **Adjust** (admin `POINTS_ADJUST`): `ADJUST, ±points, reason (mandatory), created_by`; audited `ADJUST_POINTS`.
- **Expire** (Phase 6 scheduled job, daily): for each customer, compute unexpired earn lots older than `expiry_days` not yet consumed (FIFO) → `EXPIRE, −points, reason "expiry"`. Disabled when `loyalty.expiry_days = 0`.
- Concurrency: redemption checks balance inside the order transaction with `SELECT … FOR UPDATE` on the customer's `users` row (simple, single-store scale).

---

## 5. Offers engine (Specification pattern over JSONB)

`offers.conditions` is a tree:
```json
{ "all": [ {cond}, {cond} ] }            // AND
{ "any": [ {cond}, {cond} ] }            // OR
{ "all": [ {cond}, { "any": [ … ] } ] }  // nesting allowed
```
Condition types (each maps to a `Specification<CartContext>` class in `loyalty.engine.rules`):

| `type` | params | true when |
|---|---|---|
| `MIN_CART_TOTAL` | `value` | goods subtotal ≥ value |
| `MIN_ITEMS` | `value` | number of lines ≥ value |
| `FIRST_ORDER` | — | customer has no non-cancelled orders |
| `MIN_PREVIOUS_ORDERS` | `value` | count of `DELIVERED/PICKED_UP` orders ≥ value |
| `PRODUCT_IN_CART` | `productId`, `minQty?` | a line of product with qty ≥ minQty (default any) |
| `CATEGORY_IN_CART` | `categoryId` | a line whose product is in category or its descendants |
| `FULFILLMENT` | `value` (`PICKUP`/`DELIVERY`) | matches |
| `ZONE_IN` | `zoneIds[]` | delivery zone in list |
| `WEEKDAY_IN` | `days[]` (1=Mon…7=Sun) | store-timezone weekday |
| `TIME_WINDOW` | `from`, `to` (`HH:mm`) | store-timezone time |
| `CUSTOMER_IN` | `customerIds[]` | customer in list (typical for `PRIVATE`) |
| `LANGUAGE` | `value` | customer language |

Unknown `type` → offer is treated as **not eligible** and a warning is logged (never a 500).

Eligibility also requires: `is_active`; `starts_at ≤ now ≤ ends_at` (null = open); `usage_limit_total` not reached (count of redemptions on non-cancelled orders); `usage_limit_per_customer` not reached; `PRIVATE` offers additionally must evaluate true on conditions (they are listed to the customer on `/account/points` only when eligible).

Benefit computation on goods `G` (actual or estimate):
- `PERCENT`: `applies_to=CART` → `G × value/100`; `PRODUCT/CATEGORY` → sum over matching lines × value/100.
- `FIXED`: `min(value, base)` where base is `G` or the matching lines' sum.
- `FREE_DELIVERY`: `delivery_fee` (0 for pickup → offer not eligible if fee is 0).
- `BONUS_POINTS`: no discount; `value` points added at earn time.

Selection: best single monetary offer + all BONUS_POINTS offers. Discount is rounded to 2 dp. Admin UI builds the JSON from rows (type select + params); the API validates the tree against the registry of known types (`422 OFFER_CONDITION_UNKNOWN`).

---

## 6. OTP (manual activation & password reset)

- Generate (`OTP_SEND`): `code = 6 random digits (SecureRandom)`; store `code_hash = BCrypt(code)` (cost 10 is enough here), `expires_at = now + otp.ttl_minutes`, `purpose`, `created_by`; invalidate previous unused codes of the same user+purpose (`used_at = now`). If purpose `ACTIVATION` and user `PENDING` → `OTP_SENT`. Build message in `users.preferred_language`:
  - ar: `مرحبًا {name}، كود تفعيل حسابك في مجمع تشرين هو: {code} — صالح لمدة {ttl} دقائق.`
  - en: `Hi {name}, your Tishreen Mall activation code is: {code} — valid for {ttl} minutes.`
  → `notification_log (OTP, GENERATED, payload {text, url: https://wa.me/{phone}?text=…})`. Audit `SEND_OTP {userId, purpose}` (never the code).
- Mark sent: `notification_log.status = SENT, sent_by, sent_at`.
- Verify (`POST /auth/activate {code}` for the logged-in user; `POST /auth/password-reset/confirm {phone, code, newPassword}`): take the latest unused code for purpose; `expires_at < now` → `410 OTP_EXPIRED`; `attempts ≥ otp.max_attempts` → `423 OTP_LOCKED`; mismatch → `attempts++`, `400 OTP_INVALID {remaining}`; match → `used_at = now`, then `users.status = ACTIVE` (activation) or set new password + invalidate refresh tokens (reset).
- Self-service reset request (`POST /auth/password-reset/request {phone}`): always returns `202` (no enumeration); if the phone exists and is not BLOCKED, creates the OTP row with `created_by NULL` and the GENERATED notification so it appears on `/staff/otp`.
- Rate limits: generate ≤ 3 per user per hour; verify ≤ 10 per phone per 10 min (in-memory bucket; IP-based as well).

---

## 7. WhatsApp order message (`ORDER_SUBMIT`)

Built server-side by `WhatsAppMessageBuilder` from the persisted order (never from client data). Arabic template (`lang = ar`):
```
طلب جديد #{orderNumber}
الاسم: {customerName}
الهاتف: {customerPhone}
{fulfillmentLine}
الأصناف:
• {name}{optionSuffix} — {qty} {unit}{noteSuffix}
…
المجموع التقديري: {subtotal} ل.س
رسوم التوصيل: {deliveryFee} ل.س
الخصم: {discountTotal} ل.س
الإجمالي التقديري: {estimatedTotal} ل.س
{customerNoteLine}
الأسعار تقديرية وتُحدَّد نهائيًا بعد الوزن.
```
- `fulfillmentLine`: `توصيل إلى: {address_snapshot}` or `استلام من المتجر: {pickup_time in Asia/Damascus, e.g. اليوم 18:30}`.
- `optionSuffix` = ` ({option_snapshot})`; `unit` = `كغ` / `قطعة`; `qty` formatted `1.250` for KG, `2` for PIECE.
- English template mirrors it. Amounts formatted with thousands separators, no decimals for SYP (`180,000`).
- URL: `https://wa.me/{store.whatsapp_number digits only}?text={URL-encoded text}`. The API returns `whatsappUrl` and the client opens it immediately after the `201`.
- Status change messages (`ORDER_UPDATE`) go **to the customer** number: short templates per status in `messages_{lang}.properties` (`order.update.CONFIRMED`, …).

---

## 8. Stock (ledger + cache)

- Every change is a `stock_movements` row; `products.stock_cached += qty` in the same transaction (`UPDATE products SET stock_cached = stock_cached + :qty`).
- `SALE` rows (−`actual_qty`) are written once when the order leaves `PREPARING` (`ready` / `dispatch`), one row per item, `order_id` set.
- Cancellation after SALE → `RETURN` rows (+qty, `order_id`).
- `PURCHASE` rows from purchase invoices (+qty, `purchase_invoice_id`); also `products.cost_price = unit_cost`.
- `WASTE` (−), `ADJUSTMENT` (±) require `reason`; audited `STOCK_ADJUSTMENT`.
- Negative stock is allowed (weighed goods reality) but flagged on `/admin/erp/stock`; a "recompute cache" admin action resets `stock_cached = SUM(qty)` (audited).
- Low stock: `stock_cached <= low_stock_threshold` → dashboard counter and `/staff/stock` list.

---

## 9. Payments (COD)

- `PaymentProvider` `cod`: `create()` returns a PENDING intent without persisting; the actual row is written at `pickedUp`/`delivered` with `amount` = collected (default `final_total`), `status = COMPLETED`, `completed_at`, `collected_by`.
- `payment_status`: `PAID` if `Σ COMPLETED ≥ final_total`; `PARTIAL` if `0 < Σ < final_total`; else `UNPAID`. Short-collections are allowed (driver notes), flagged for admin in cash reconciliation.
- Idempotency: driver endpoints accept `Idempotency-Key` header (UUID); the key is stored in an in-memory/DB-backed cache (`payments.external_ref = 'idem:' + key` for COD) so replayed offline actions don't double-record.

---

## 10. Notifications & audit (cross-cutting)

- `NotificationChannel.send(NotificationRequest{userId, type, lang, templateKey, params, orderNumber?})` → implementations persist one `notification_log` row and return its id. `manual-whatsapp` returns `status GENERATED` with the `wa.me` URL; automated channels return `SENT`/`FAILED`.
- Audit aspect: `@Audited(action = "UPDATE_PRICE", entity = "Product")` on service methods; `@AuditId` marks the id parameter; `AuditSnapshotter` captures `old` before and `new` after via a `Supplier<Map<String,Object>>` provided by the service; actor/role from `SecurityContext`; `ip` from request; `correlation_id` from MDC (`CorrelationIdFilter` sets it from `X-Correlation-Id` or a UUID and echoes it back in the response header).

---

## 11. Numbers, rounding, time

- Money arithmetic with `BigDecimal`, scale 2, `RoundingMode.HALF_UP`; quantities scale 3.
- SYP displays with no decimals (`180,000 ل.س`) but is stored with 2 dp.
- All timestamps UTC in DB; business-time logic (store hours, weekday, time windows, pickup slots) uses `settings.store.timezone` (`Asia/Damascus`).

## 12. Ticket routing

- `ORDER` and `GENERAL` → visible in `/staff/tickets` and `/admin/support`; `TECHNICAL` → `/it/tickets` and `/admin/support`.
- `source = CHATBOT` when escalated by the bot; `PORTAL` when opened from `/support`; `INTERNAL` when staff opens on behalf of a customer.
- A public staff reply (`is_internal=false`) → `notification_log(TICKET_REPLY)` to the customer.
- `RESOLVED` → auto `CLOSED` after 72h without customer reply (scheduled job, Phase 6).

## 13. FAQ bot (rule-based)

- Normalize input: lower-case, strip Arabic diacritics/tatweel, unify `أإآ→ا`, `ة→ه`, `ى→ي`; tokenize on whitespace/punctuation.
- Score each active `faq_entries` row by the count of its `keywords` that appear as tokens or substrings (≥ 3 chars); best score ≥ `bot.match_threshold` wins (tie → `sort_order`); answer in the request language with Arabic fallback.
- No match → reply with the "لم أفهم سؤالك — هل تريد فتح تذكرة؟" template and `canEscalate=true`; the client then calls `POST /me/tickets` with `source=CHATBOT`.
