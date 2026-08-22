---
name: order-lifecycle
description: The complete order lifecycle of Tishreen — createOrder algorithm, state machine with side-effects per transition, estimated vs final pricing with actual weights, points earn/redeem/reversal, stock SALE/RETURN, COD payment and idempotency. Load for any work on orders, checkout, staff preparation, delivery or points.
user-invocable: false
---
# Order lifecycle (normative text: tishreen-handoff/tishreen-handoff/docs/05-business-rules.md §1–§6)

## createOrder (one transaction, then WhatsApp)
1. Validate user `ACTIVE` + role `CUSTOMER`; store open (`store.is_open`, hours) else `423 STORE_CLOSED`.
2. Load products (`is_active`, `is_available`) → `422 PRODUCT_UNAVAILABLE`; validate qty: KG multiple of `orders.weight_step_kg` ≥ `orders.min_weight_kg` (`WEIGHT_STEP_INVALID`), PIECE integer ≥ 1.
3. Unit price = product.price + option.price_delta (folded); line estimate = unit × requested_qty (scale 2).
4. Fulfillment: DELIVERY → address must belong to user, zone active (`ZONE_INACTIVE`), snapshot address + zone (fee, name) + lat/lng; goods subtotal ≥ zone.min_order (`BELOW_MIN_ORDER`, compared before discounts). PICKUP → `pickup_time` ≥ now + `orders.pickup_lead_minutes` and inside hours (`PICKUP_TIME_INVALID`).
5. Offers: evaluate all active offers (scope PUBLIC, or TARGETED to this user) against the cart; pick the **single best monetary** offer (highest discount; tie → lowest id) + all BONUS_POINTS offers; FREE_DELIVERY only for DELIVERY; usage limits exclude cancelled orders.
6. Points: optional `redeemPoints` ≥ `loyalty.min_redeem_points`, ≤ balance (`POINTS_INSUFFICIENT`), value = points × `loyalty.redeem_point_value`, capped at `loyalty.max_redeem_share` × goods subtotal (after offer discount).
7. Persist `orders` (status `NEW`, `order_number` from sequence, `customer_language`, snapshots, estimates), `order_items`, `offer_redemptions`, `points_transactions REDEEM` (negative), `order_status_history(null→NEW)`.
8. Build WhatsApp text (skill `whatsapp-notification`) in the customer's language, `wa.me/<store number digits>?text=<urlencoded>`; insert `notification_log(type ORDER_SUBMIT, status GENERATED)`.
9. Return `201 {order, whatsappUrl}`. The client opens the URL; the order exists regardless.

## Transitions (permission · side-effects)
| from → to | who | side-effects |
|---|---|---|
| NEW → CONFIRMED | ORDER_MANAGE | history; notification `ORDER_CONFIRMED` (GENERATED) |
| CONFIRMED → PREPARING | ORDER_MANAGE | history |
| PREPARING (weigh) | ORDER_WEIGH | `actual_qty` per item (PIECE auto = requested); `@Audited(UPDATE_WEIGHT)`; deviation > `orders.weight_tolerance_pct` → warning flag only |
| PREPARING (finalize) | ORDER_MANAGE | all KG items weighed else `422`; line_total = unit × actual; re-evaluate the applied offer on actual goods (FIXED capped at goods); points discount capped again; `final_total = goods − discount − points_discount + delivery_fee` ≥ 0; idempotent |
| PREPARING → READY_FOR_PICKUP | ORDER_MANAGE (PICKUP, finalized) | **stock SALE** per item (−actual), `stock_cached` updated, idempotent per order; notification `ORDER_READY` |
| PREPARING → OUT_FOR_DELIVERY | ORDER_ASSIGN_DRIVER (DELIVERY, finalized, driver available) | `deliveries` row/driver set; stock SALE (same as above); `@Audited(ASSIGN_DRIVER)` |
| READY_FOR_PICKUP → PICKED_UP | ORDER_MANAGE | payment COD recorded (`RECORD_PAYMENT`), points EARN = floor(goods_final / `loyalty.earn_amount_unit`) × `loyalty.earn_points_per_amount` + BONUS_POINTS offers, `expires_at` = now + `loyalty.expiry_days` |
| OUT_FOR_DELIVERY → DELIVERED | DELIVERY_OWN (own delivery) + `Idempotency-Key` | `collected_amount`, payment, `delivered_at`, points EARN (same rule) |
| OUT_FOR_DELIVERY → DELIVERY_FAILED | DELIVERY_OWN | `failure_reason` required, `attempts + 1` |
| DELIVERY_FAILED → OUT_FOR_DELIVERY | ORDER_ASSIGN_DRIVER | retry while `attempts < delivery.max_attempts` |
| any non-terminal → CANCELLED | customer while `orders.customer_cancel_while` (NEW) / ORDER_CANCEL | `cancel_reason` required; stock RETURN if SALE was written; points REVERSAL of REDEEM; redemptions no longer count; `@Audited(CANCEL_ORDER)` |
Terminal: `PICKED_UP DELIVERED CANCELLED`. Every transition: `SELECT … FOR UPDATE` on the order, `order_status_history` row, `@Audited(CHANGE_ORDER_STATUS)`, `ORDER_INVALID_TRANSITION` (409) otherwise.

## Payments
`payments(method COD, amount, recorded_by, idempotency_key UNIQUE)`; `payment_status` derived: sum ≥ final_total → PAID, 0 → UNPAID, else PARTIAL. Replaying the same key returns the first result (200, not 201).

## Points ledger
Types `EARN`(+) `REDEEM`(−) `ADJUST`(±, reason, `POINTS_ADJUST`, audited) `EXPIRE`(−, nightly job for EARN rows past `expires_at` not yet consumed FIFO) `REVERSAL`(+ on cancel). Balance = `SUM(points)` via `v_points_balance`; `/account/points` is a statement, not a balance widget.
