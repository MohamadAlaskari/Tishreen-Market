# 01 — Features & Functions (complete catalogue)

Every feature below has: **What** · **Who** · **Rules** · **Data touched** · **Acceptance criteria (AC)**.
IDs (`F-xx`) are referenced from the build plan and the test plan.

---

## A. Cross-cutting

### F-01 Bilingual UI with RTL-first layout
- **What**: Arabic default, English secondary. `<html dir="rtl" lang="ar">` by default; switching language flips `dir` and re-renders. Persisted per user (`users.preferred_language`) and for guests in `localStorage`.
- **Rules**: logical CSS only (`ms-/me-/ps-/pe-/start-/end-`), no `left/right`, `ml/mr`. Numbers shown with Western digits by default (`0-9`) — configurable later; currency `ل.س` after the number in Arabic, `SYP` in English.
- **AC**: every screen renders correctly in both directions; no horizontal overflow in RTL at 360px width; language switch persists across reload.

### F-02 Authentication & accounts
- **What**: Register (name, WhatsApp phone E.164, password, language) → `PENDING`. Login with phone + password → JWT. Refresh tokens. Logout. Forgot password via OTP (`PASSWORD_RESET`).
- **Rules**: phone normalized to E.164 (`+963…`) before uniqueness check; BCrypt (cost 12); login throttle 10/min per phone and per IP; `BLOCKED` users cannot log in; `PENDING/OTP_SENT` users log in but are redirected to `/activate` everywhere except `/activate` and `/account` (read-only).
- **Data**: `users`, `customer_profiles` (created at register), `otp_codes`, `notification_log`, `audit_log`.
- **AC**: duplicate phone → `409 USER_PHONE_EXISTS`; wrong password → `401 AUTH_BAD_CREDENTIALS` (same message for unknown phone); blocked → `403 USER_BLOCKED`.

### F-03 Manual OTP activation
- **What**: Staff/admin generates a 6-digit code for a `PENDING` user; the system stores the **hash**, builds a WhatsApp message in the user's language, opens `wa.me/<phone>?text=…` on the employee's device; employee confirms "sent"; customer enters code on `/activate`.
- **Rules**: TTL `otp.ttl_minutes` (10); `otp.max_attempts` (5) → locked, must regenerate; regenerating invalidates prior unused codes (set `used_at` = now, or mark superseded via `expires_at = now()`); `users.status` → `OTP_SENT` on generate, `ACTIVE` on success; `notification_log` row `GENERATED` → `SENT` only when the employee taps confirm (`sent_by`, `sent_at`).
- **Data**: `otp_codes`, `notification_log`, `users`, `audit_log(SEND_OTP)`.
- **AC**: code never stored in plaintext (DB inspection shows hash only); 6th wrong attempt returns `423 OTP_LOCKED`; expired → `410 OTP_EXPIRED`; the staff screen shows the code **once** (big) next to the prepared message.

### F-04 Audit trail
- **What**: Append-only `audit_log` written automatically by an AOP aspect for sensitive operations.
- **Mandatory actions**: `UPDATE_PRICE`, `UPDATE_WEIGHT`, `SEND_OTP`, `CHANGE_ORDER_STATUS`, `CANCEL_ORDER`, `RECORD_PAYMENT`, `ADJUST_POINTS`, `SWITCH_PROVIDER`, `UPDATE_SETTING`, `BLOCK_USER`, `CHANGE_ROLE`, `STOCK_ADJUSTMENT`, `ASSIGN_DRIVER`.
- **AC**: each row has actor, role snapshot, entity type/id, old/new JSON, IP, `correlation_id`; rows can't be updated/deleted by the app user (no UPDATE/DELETE grant on the table for the app role).

### F-05 Notifications (abstracted channel)
- **What**: `NotificationChannel` interface; today `manual-whatsapp` → creates `notification_log` rows with a ready `wa.me` link + text; staff sends manually and confirms. Future `telegram-bot`/`sms` flip `settings.notification.provider`.
- **Triggers**: OTP; order status `CONFIRMED`, `READY_FOR_PICKUP`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED`; ticket reply (non-internal message by staff).
- **AC**: every trigger creates exactly one `GENERATED` row; "pending sends" list for staff; confirming marks `SENT`; switching provider doesn't require restart.

### F-06 Image storage (abstracted)
- **What**: `ImageStorage` interface; `local-disk` today (`/var/tishreen/media`), `minio`/`s3` later. DB stores `storage_key`, never a path/URL. Public URL = `/media/{key}` served by the API (or nginx for local-disk).
- **Rules**: upload limit 5 MB; accepted `image/jpeg, image/png, image/webp`; server re-encodes to WebP + generates a 400px thumbnail (`{key}.thumb.webp`).
- **AC**: switching provider leaves DB untouched; URL builder is the only place that knows the provider.

### F-07 Settings & provider switching (no redeploy)
- **What**: `settings` key/value grouped `BUSINESS` (admin), `TECHNICAL` and `PROVIDERS` (IT). Values cached in memory, invalidated on write.
- **AC**: changing `notification.provider` from `/it/providers` takes effect on the next call; every change is audited (`UPDATE_SETTING` / `SWITCH_PROVIDER`).

---

## B. Customer

### F-10 Home page composed from CMS blocks
- **What**: `/` renders active `content_blocks` ordered by `sort_order`, filtered by `starts_at/ends_at`. Block types: `HERO_BANNER`, `ANNOUNCEMENT_BAR`, `FEATURED_CATEGORIES`, `FEATURED_PRODUCTS`, `OFFERS_STRIP`, `RICH_TEXT`.
- **Rules**: a block referencing a product/category that is inactive is rendered without that item (silently skipped). Payload is bilingual (`{ "title": {"ar":"…","en":"…"} , … }`).
- **AC**: `GET /api/v1/home` is cacheable (ETag / 60s); unknown `block_type` is ignored by the frontend with a dev-only warning.

### F-11 Catalogue browsing & search
- **What**: `/categories` (tree), `/c/:slug` (category + descendants, filters: availability, sort by price/name), `/p/:slug` (gallery, price per KG/PIECE, options as chips with `price_delta`, availability badge, note field). Search box: server-side `ILIKE` on `name_ar/name_en` + slug (Phase 6 may add trigram index).
- **Rules**: inactive products/categories are 404 for customers; unavailable (`is_available=false`) are shown greyed with "نفد مؤقتًا" and cannot be added to cart.
- **AC**: category listing paginated (`size=24`); product page shows "السعر تقديري — يُحدَّد بعد الوزن" for `KG` products.

### F-12 Cart (guest-capable, local)
- **What**: Cart lives in `localStorage` (`tishreen.cart.v1`), no server table. Lines: `productId, optionId?, qty, note`. KG stepper in `orders.weight_step_kg` (0.250) steps, min 0.250; PIECE stepper integers, min 1.
- **Rules**: on every cart open and before checkout, `POST /checkout/quote` re-validates prices/availability and returns warnings (price changed, item unavailable → line flagged, must remove).
- **AC**: cart survives reload; a guest who logs in keeps the cart; unavailable lines block checkout until removed.

### F-13 Checkout (pickup or delivery) with points & offers
- **What**: `/checkout`: fulfillment toggle; **PICKUP** → pickup time (slots from store hours, min +45 min); **DELIVERY** → address picker (default address preselected), optional map pin, zone fee & min order shown; note; points slider (redeemable up to rules); automatic best offer; order summary (estimate).
- **Rules**: requires `CUSTOMER` + `ACTIVE`; store must be open (`store.is_open`) else show closed message; zone `min_order` enforced on goods subtotal (before discounts); all money computed server-side by `POST /checkout/quote`; the UI only displays.
- **Flow**: `POST /orders` → `201 {order, whatsappUrl}` → client opens `whatsappUrl` (`window.open`/`location.href` on mobile) → navigate to `/orders/:nr` with banner "إن لم تُفتح رسالة واتساب اضغط هنا".
- **Data**: `orders`, `order_items` (snapshots), `offer_redemptions`, `points_transactions(REDEEM)`, `notification_log(ORDER_SUBMIT)`, `order_status_history(NULL→NEW)`.
- **AC**: order exists in DB before WhatsApp opens (verified by test: API returns 201 then URL); WhatsApp text is in `orders.lang`; message contains order number, items with qty/unit/option, estimate, fulfillment details.

### F-14 My orders & live status
- **What**: `/orders` list (paginated, newest first, status badges), `/orders/:nr` detail with timeline (from `order_status_history`), items (requested vs actual when weighed), totals (estimate vs final), delivery/pickup info, "إعادة الطلب" (reorder → fills cart), "إلغاء" (only while `NEW`), "فتح رسالة واتساب" again, "افتح تذكرة دعم" (prefills order).
- **AC**: customer can only see own orders (`404` for others, not `403`); polling every 30s on detail page while non-terminal (no websockets in Phase 1–5).

### F-15 Account & addresses (+ optional map pin)
- **What**: `/account`: profile (name, language, password change), addresses CRUD (label, zone, details, default), optional **"حدد موقعك على الخريطة"** step → Leaflet map (OSM tiles, bundled JS), starts at device geolocation or `store.city_center_lat/lng`; pin is draggable; "تأكيد الموقع" / "تخطي".
- **Rules**: `details` and `zone_id` remain mandatory; pin does **not** choose the zone; at most one default address (partial unique index).
- **AC**: map is lazy-loaded only when the step is opened; coordinates stored as `NUMERIC(9,6)`; deleting an address used by past orders is allowed (orders keep the snapshot) — address row is soft-hidden? **Decision**: hard delete allowed because `orders.address_id` is `ON DELETE SET NULL` (snapshot keeps the text).

### F-16 Loyalty points (statement, not balance)
- **What**: `/account/points`: balance (= `SUM`) + statement of transactions (EARN/REDEEM/ADJUST/EXPIRE/REVERSAL) + private offers the customer qualifies for.
- **Rules**: see `05-business-rules.md §4`. Earn on `DELIVERED`/`PICKED_UP` on goods total (`final_total − delivery_fee`), `loyalty.earn_points_per_amount` per `loyalty.earn_amount_unit`. Redeem at checkout: `loyalty.redeem_point_value` per point, min `loyalty.min_redeem_points`, max share `loyalty.max_redeem_share` of goods subtotal.
- **AC**: balance never stored; cancelling a redeemed order writes `REVERSAL`; statement paginated.

### F-17 Offers (public list + automatic application)
- **What**: `/offers` lists active `PUBLIC` offers with bilingual name, benefit, validity; checkout applies the best eligible monetary offer automatically and all eligible `BONUS_POINTS` offers.
- **AC**: offer with exhausted `usage_limit_total` or per-customer limit is not applied; cancelled orders don't count toward limits.

### F-18 Support tickets & FAQ bot
- **What**: `/support`: bot chat panel (rule-based FAQ matcher) + "my tickets" list; `/support/:nr` thread. Bot answers from `faq_entries` by keyword match; if no match above threshold → offers to open a ticket (`source=CHATBOT`) with the conversation as first message.
- **Rules**: internal messages (`is_internal=true`) are filtered **in the service layer**; customers can reply until `CLOSED`.
- **AC**: bot response < 300ms (pure DB/keyword); escalation creates ticket with category chosen by the customer (`ORDER` requires an order number).

---

## C. Employee (staff)

### F-20 Order queue
- **What**: `/staff/queue`: tabs `NEW | CONFIRMED | PREPARING | READY/OUT | FAILED`, newest `NEW` first, counters, search by order number/phone. Row shows fulfillment, items count, estimate, customer, age ("منذ 4 دقائق"), WhatsApp button (opens chat with customer).
- **Rules**: `EMPLOYEE` or `ADMIN`. Poll every 15s. Confirm with one tap from the list.
- **AC**: queue query uses index `orders(status, created_at)`; confirm triggers `CONFIRMED` notification (`GENERATED`).

### F-21 Order preparation & weighing (the core screen)
- **What**: `/staff/orders/:id`: item table; **`actual_qty` is the only input** per line (KG lines), PIECE lines auto-fill; live line total; deviation warning when `|actual−requested|/requested > orders.weight_tolerance_pct` (30%); summary panel (estimate vs final, fee, discount, final total); actions: "بدء التحضير", "تأكيد الأوزان" (finalize), then "جاهز للاستلام" (PICKUP) or "إسناد سائق وإرسال" (DELIVERY, driver dropdown from `driver_profiles.is_available`), "إلغاء" with reason.
- **Rules**: finalize requires all KG lines weighed; finalize recomputes `line_total`, `orders.final_total`; `UPDATE_WEIGHT` audited per line with old/new; stock `SALE` movements written when leaving `PREPARING`.
- **AC**: deviation > tolerance shows the warning state (Figma third row) but does not block; re-weighing after finalize is allowed while still `PREPARING` (audited); `final_total` is `NULL` until finalize.

### F-22 OTP desk
- **What**: `/staff/otp`: list of users `PENDING` (and pending `PASSWORD_RESET` requests); generate → code shown once + prepared message + "فتح واتساب" + "تأكيد الإرسال".
- **AC**: see F-03.

### F-23 Product availability & price
- **What**: `/staff/products`: search, toggle `is_available`, edit `price` (audited `UPDATE_PRICE`). No create/delete (admin only).
- **AC**: price edit requires confirmation dialog; change visible to customers immediately (catalog cache ≤ 60s or invalidated).

### F-24 Stock movements
- **What**: `/staff/stock`: record `WASTE` (−), `ADJUSTMENT` (±, reason mandatory), `RETURN` (+); view movement history per product; low-stock list.
- **AC**: `stock_cached` updated in the same transaction; `reason` required for WASTE/ADJUSTMENT (`422`).

### F-25 Staff tickets
- **What**: `/staff/tickets`: `ORDER` and `GENERAL` tickets; reply (public/internal), assign to self, set status.
- **AC**: public reply triggers `TICKET_REPLY` notification.

---

## D. Driver

### F-30 My deliveries (offline-tolerant)
- **What**: `/driver/deliveries`: list of deliveries assigned to me with status `OUT_FOR_DELIVERY` (and `DELIVERY_FAILED` for retry), grouped by zone, totals to collect; availability toggle.
- **Offline**: list cached (TanStack Query persister → IndexedDB); PWA app shell; actions queued when offline and replayed in order with an `Idempotency-Key`; UI shows "سيُرسل عند عودة الاتصال".
- **AC**: after airplane mode, the last loaded list is visible; queued actions replay and reconcile without duplicates (server idempotent on key).

### F-31 Delivery detail & completion
- **What**: `/driver/deliveries/:id`: customer name, phone (tap to call / WhatsApp), address text, **"فتح الموقع في الخرائط"** (`geo:lat,lng` → native maps incl. offline OsmAnd) when coordinates exist, items, amount to collect; actions: "تم التسليم" (amount collected prefilled = final_total, editable) → `DELIVERED`; "فشل التسليم" bottom sheet with reason chips (لم يجب · عنوان خاطئ · رفض الاستلام · أخرى) → `DELIVERY_FAILED`.
- **AC**: `DELIVERED` writes `payments(COD, COMPLETED, collected_by=driver)`, sets `payment_status`, `deliveries.delivered_at`, `points EARN`; failed increments `attempts`, stores `fail_reason`.

---

## E. Admin

### F-40 Dashboard
- Today's orders by status, revenue today/7d/30d, pending activations count → `/admin/users`, low-stock count → `/admin/erp/stock`, failed deliveries today, open tickets, last backup status (from IT health) → `/it/backups`.

### F-41 Users & staff
- `/admin/users`: search, filter by role/status, generate OTP, block/unblock (`BLOCK_USER`), change role (`CHANGE_ROLE`), staff note. `/admin/staff`: create EMPLOYEE/DRIVER/IT accounts (with profile), edit profiles, driver availability, employment info.

### F-42 Catalogue management
- `/admin/products`: CRUD, multi-image upload with ordering and primary flag, options with `price_delta`, unit, price, cost (read-only, from purchases), thresholds, `is_active`/`is_available`. `/admin/categories`: tree CRUD with drag ordering, image, slug (auto from `name_en` or transliteration, editable, unique).

### F-43 Orders (all)
- `/admin/orders`: all statuses, filters (status, date range, fulfillment, zone, driver), detail drawer with same actions as staff plus reassign driver and force-cancel.

### F-44 Zones
- `/admin/zones`: CRUD fee/min order/active/sort. Deactivation hides zone from new addresses and checkout; existing orders keep their snapshot.

### F-45 CMS
- `/admin/cms/theme` (Figma `130:2389`): pick one of the **three audited presets** (وردي `rose` · برتقالي `orange` · سماوي `sky`), optional **hue-only** tweak (L and C locked), logo upload (SVG/PNG ≤ 512 KB), store name ar/en, font display. Live preview uses the real component library. **Server-side contrast gate** (button text on primary, link on background, active nav item, link on subtle surface — all ≥ 4.5:1) — one failure ⇒ `422 THEME_CONTRAST_FAILED`, nothing saved. Persisted in `theme_settings`; served by `GET /theme` (applied at runtime on `:root`).
- `/admin/cms/blocks`: block list with drag order, enable/disable, schedule, per-type editor with bilingual fields and product/category pickers.

### F-46 Offers & points
- `/admin/offers`: list; `/admin/offers/new|:id`: **offer builder** — name ar/en, scope, conditions builder (rows of `type` + params, see `05-business-rules.md §5`), benefit, applies-to + target picker, validity, limits, active; usage statistics (redemptions, total discount).
- `/admin/points`: earning rules (settings), manual adjustment form (customer search, ± points, mandatory reason) → `ADJUST` + audit; liability report.

### F-47 Support & FAQ
- `/admin/support`: all tickets, assign to employee/IT, SLA ages. `/admin/faq`: CRUD bilingual Q/A with keywords chips and order; "test the bot" box.

### F-48 ERP
- `/admin/erp/suppliers`: CRUD. `/admin/erp/purchases`: create invoice (supplier, number, date, lines product/qty/unit cost) → writes `purchase_items` + `PURCHASE` movements + updates `products.cost_price`; list/print. `/admin/erp/stock`: stock overview (cached vs computed check button), movement ledger, low stock, valuation.

### F-49 Reports
- `/admin/reports`: sales by day/week/month (successful orders), orders by status, top products (qty & revenue), offers cost, points liability & movement, driver cash reconciliation per day (`payments.collected_by`), failed deliveries by reason, stock valuation. CSV export for each.

### F-50 Audit & settings
- `/admin/audit`: filter by entity type/id, actor, action, date; diff view old/new; link to `/it/logs?correlationId=`. `/admin/settings`: BUSINESS group editor (store phone, hours, open/closed, weight step, tolerance, loyalty rules, OTP TTL).

---

## F. IT

### F-60 Health — `/it/health`: DB ping, disk free, storage provider check, uptime, JVM memory, last backup time/size, pending notifications count, error rate last hour (from logs).
### F-61 Logs — `/it/logs`: search JSON logs by `correlationId`, level, time range, free text; paginated; link from audit rows.
### F-62 Providers — `/it/providers`: four switches (`notification`, `storage`, `payment`, `chatbot`) with available implementations and health of each; switching audited (`SWITCH_PROVIDER`).
### F-63 Backups — `/it/backups`: list nightly `pg_dump` files (name, size, date, checksum), run now, download, retention setting.
### F-64 Technical tickets — `/it/tickets`: `TECHNICAL` tickets; reply/assign/status.

---

## G. Non-functional requirements

| Area | Requirement |
|---|---|
| Performance | Catalogue and home pages < 1s TTFB on VPS; list endpoints paginated (max `size=100`); N+1 forbidden (use fetch joins / DTO projections) |
| Availability | Driver flows usable offline; API restart < 10s; nightly backups with restore test documented |
| Security | JWT (access 30 min, refresh 7 days rotating), BCrypt 12, rate limits on auth/OTP, ownership checks on every customer endpoint, CORS restricted to the web app origin(s) (`app.cors.origins`, credentials for the refresh cookie; no dev proxy — `09 §4`), security headers, no secrets in git |
| Privacy | Phone numbers masked in logs (`+9639****123`), OTP never logged |
| Accessibility | WCAG AA contrast (tokens verified), focus visible, 44px touch targets on staff/driver screens |
| Observability | JSON logs with `correlationId`, `userId`, `role`; Spring Actuator health/metrics; request timing |
| Data integrity | Money `NUMERIC(14,2)`, weight `NUMERIC(12,3)`, no floats; snapshots; ledgers; `ON DELETE RESTRICT` default |
