---
name: offers-engine
description: The rule engine behind Tishreen offers — JSONB condition schema (all/any nesting, 12 condition types), Specification-pattern evaluation, benefit types, applies_to scopes, usage limits, best-offer selection, re-evaluation at finalize, and the admin offer builder contract. Load for anything under /admin/offers, /offers, checkout quote or points bonuses.
user-invocable: false
---
# Offers engine (normative: docs/05-business-rules.md §5; builder screen Figma `19:5`)

## `offers.conditions` JSONB
```json
{ "all": [ {"type":"MIN_CART_TOTAL","value":150000},
           {"any":[ {"type":"CATEGORY_IN_CART","value":[3,4]}, {"type":"PRODUCT_IN_CART","value":[12]} ]},
           {"type":"FULFILLMENT","value":"DELIVERY"} ] }
```
Root is `all` or `any`; nodes are conditions `{type, value}` or nested groups. Unknown `type` → offer **not eligible** + WARN log (never crash, never grant).

| type | value | true when |
|---|---|---|
| `MIN_CART_TOTAL` | money | goods subtotal (estimate at checkout, actual at finalize) ≥ value |
| `MIN_ITEMS` | int | total line count ≥ value |
| `PRODUCT_IN_CART` | [productId] | any listed product in cart |
| `CATEGORY_IN_CART` | [categoryId] | any product whose category (or ancestor) is listed |
| `MIN_PRODUCT_QTY` | {productId, qty} | that product's qty ≥ qty |
| `FULFILLMENT` | `PICKUP`\|`DELIVERY` | equals |
| `ZONE_IN` | [zoneId] | DELIVERY and zone listed |
| `FIRST_ORDER` | — | customer has no non-cancelled order |
| `CUSTOMER_ORDERS_MIN` | int | count of DELIVERED/PICKED_UP orders ≥ value |
| `WEEKDAY_IN` | [0–6] | `Asia/Damascus` weekday in list |
| `TIME_BETWEEN` | {from:"HH:mm", to:"HH:mm"} | local time in window |
| `POINTS_BALANCE_MIN` | int | points balance ≥ value |

## Benefits
`PERCENT` (value %, uncapped — admins use FIXED when a cap is needed) · `FIXED` (money, capped at the eligible goods amount) · `FREE_DELIVERY` (fee → 0, DELIVERY only) · `BONUS_POINTS` (value points added to EARN at delivery/pickup). `applies_to`: `CART` whole goods subtotal; `PRODUCT` / `CATEGORY` (+`target_id`, descendants included) only the matching lines.

## Eligibility & selection
Active, `valid_from ≤ now ≤ valid_to`, `scope PUBLIC` or TARGETED row for the user, `usage_limit_total` and `usage_limit_per_customer` counted over `offer_redemptions` of **non-cancelled** orders. At checkout quote and createOrder: evaluate every eligible offer, compute its discount, apply the **single best monetary offer** (highest discount, tie → lowest `offers.id`) plus all BONUS_POINTS offers. Record `offer_redemptions(discount_amount)`. At finalize re-evaluate the *same* offer on actual quantities (never switch offers after creation); if it is no longer eligible the discount becomes 0 and the staff screen shows why.

## Implementation (Java)
`Specification` interface `boolean isSatisfiedBy(CartContext ctx)`; `ConditionParser` turns JSONB into a tree of specs (`AllSpec`, `AnySpec`, one class per type in `loyalty.domain.conditions`); `OfferEngine.evaluate(cart, customer, now)` returns `List<OfferResult{offer, discount, bonusPoints, reasons}>`; `describeConditions(conditions, lang)` renders human text for the builder preview and `/offers`. Admin `POST/PUT /admin/offers` validates the JSON against the schema (unknown type, wrong value shape → `400` field errors) and requires `OFFER_MANAGE`.

## Builder screen contract (`/admin/offers/new`)
Left: name ar/en, scope (+ customer picker for TARGETED), validity, limits. Middle: condition tree editor (add group all/any, add condition by type with typed inputs). Right: benefit type/value/applies_to, live preview text (`describeConditions`), "test against a customer cart" that calls `POST /admin/offers/preview` (dry run, no persistence).
