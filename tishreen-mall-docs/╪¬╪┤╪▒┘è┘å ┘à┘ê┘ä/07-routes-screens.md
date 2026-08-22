# 07 — Routes & Screens (49 routed screens + map picker)

Figma file `0RLOI0q7lWCK1Rme8JjkKu`, pages: `01 · Foundations`, `02 · Components`, `03 · Customer`, `04 · Staff`, `05 · Driver`, `06 · Admin`, `07 · IT`, `08 · Flows`. Every screen frame is named by its route (`/staff/orders/:id`).
Prototype transitions: forward = push from the **right** (RTL), back = pop.

## 1. Route tree (TanStack Start, file-based)

```
apps/web/src/routes/
├─ __root.tsx                    # html dir/lang, theme vars from GET /theme, i18n, QueryClient, toaster
├─ _customer.tsx                 # layout: header (brand mark, search, cart), bottom tabs (mobile), footer
│  ├─ _customer/index.tsx        # /
│  ├─ _customer/categories.tsx   # /categories
│  ├─ _customer/c.$slug.tsx      # /c/:slug
│  ├─ _customer/p.$slug.tsx      # /p/:slug
│  ├─ _customer/offers.tsx       # /offers
│  ├─ _customer/cart.tsx         # /cart
│  ├─ _customer/support.index.tsx  # /support
│  └─ _customer/support.$nr.tsx    # /support/:nr            (guard: CUSTOMER)
├─ _guest.tsx                    # layout: centered card; redirects authenticated users home
│  ├─ _guest/login.tsx           # /login
│  └─ _guest/register.tsx        # /register
├─ _activation.tsx               # guard: logged in AND status PENDING|OTP_SENT
│  └─ _activation/activate.tsx   # /activate
├─ _account.tsx                  # guard: CUSTOMER + ACTIVE (PENDING → /activate)
│  ├─ _account/checkout.tsx      # /checkout
│  ├─ _account/orders.index.tsx  # /orders
│  ├─ _account/orders.$nr.tsx    # /orders/:nr
│  ├─ _account/account.index.tsx # /account
│  └─ _account/account.points.tsx# /account/points
├─ _staff.tsx                    # guard: EMPLOYEE|ADMIN; layout: RTL sidebar (desktop) / top tabs (tablet)
│  ├─ _staff/staff.queue.tsx
│  ├─ _staff/staff.orders.$id.tsx
│  ├─ _staff/staff.otp.tsx
│  ├─ _staff/staff.products.tsx
│  ├─ _staff/staff.stock.tsx
│  └─ _staff/staff.tickets.tsx
├─ _driver.tsx                   # guard: DRIVER; layout: mobile, large touch targets, offline banner
│  ├─ _driver/driver.deliveries.index.tsx
│  └─ _driver/driver.deliveries.$id.tsx
├─ _admin.tsx                    # guard: ADMIN; layout: sidebar + topbar search
│  ├─ _admin/admin.index.tsx     # /admin
│  ├─ _admin/admin.users.tsx
│  ├─ _admin/admin.products.tsx
│  ├─ _admin/admin.categories.tsx
│  ├─ _admin/admin.orders.tsx
│  ├─ _admin/admin.staff.tsx
│  ├─ _admin/admin.zones.tsx
│  ├─ _admin/admin.cms.theme.tsx
│  ├─ _admin/admin.cms.blocks.tsx
│  ├─ _admin/admin.offers.index.tsx
│  ├─ _admin/admin.offers.$id.tsx    # /admin/offers/new | /admin/offers/:id  (offer builder)
│  ├─ _admin/admin.points.tsx
│  ├─ _admin/admin.support.tsx
│  ├─ _admin/admin.faq.tsx
│  ├─ _admin/admin.erp.stock.tsx
│  ├─ _admin/admin.erp.suppliers.tsx
│  ├─ _admin/admin.erp.purchases.tsx
│  ├─ _admin/admin.reports.tsx
│  ├─ _admin/admin.audit.tsx
│  └─ _admin/admin.settings.tsx
└─ _it.tsx                       # guard: IT|ADMIN
   ├─ _it/it.health.tsx
   ├─ _it/it.logs.tsx
   ├─ _it/it.providers.tsx
   ├─ _it/it.backups.tsx
   └─ _it/it.tickets.tsx
```
Count: customer 16 · staff 6 · driver 2 · admin 20 · IT 5 = **49**. The **map picker** (Figma `311:439`) is a full-screen sheet component `AddressMapPicker`, opened from `/checkout` and `/account` — not a route.

## 2. Guards (UX only — the API enforces for real)

Implemented once in `src/lib/auth/guards.ts` and used in each layout's `beforeLoad`:

| Guard | Rule | Redirect |
|---|---|---|
| `requireGuest` | no session | `/` |
| `requireAuth` | session present (any status) | `/login?next=` |
| `requireActive` | status `ACTIVE` | `PENDING/OTP_SENT → /activate`, `BLOCKED → /login` with toast |
| `requireRole(...roles)` | `user.role ∈ roles` | `/` (customer) — never render a forbidden admin shell |
| `/checkout` | `requireActive` + role `CUSTOMER` + cart non-empty | `/cart` |

Session = access token in memory + refresh cookie; on app start call `POST /auth/refresh` once (silently) then `GET /me`.

## 3. Shared screen behaviours

- **Loading**: skeletons matching card shapes (no spinners on lists). **Empty states** with one action. **Errors**: toast with localized message + `correlationId` in a small "رمز الخطأ" line for support.
- **Lists**: server pagination; mobile infinite scroll (customer), desktop pager (admin/staff).
- **Money**: `formatMoney(amount, lang)` → `180,000 ل.س` / `SYP 180,000`. **Weights**: `1.250 كغ`.
- **Polling**: `refetchInterval` 15s (staff queue), 30s (customer order detail while non-terminal), 20s (driver list when online).
- **Dark mode**: follows system + manual toggle in header (persisted). Every screen verified in both.

## 4. Customer screens

| Route | Figma | Spec |
|---|---|---|
| `/` | `4:5` | Header (wordmark «مجمع تشرين» in `heading/md` — or the uploaded logo from `GET /theme.logoUrl` —, search, cart badge). Renders `GET /home` blocks. Bottom tabs: الرئيسية · الأقسام · السلة · طلباتي · حسابي. Announcement bar binds `primary-subtle`. |
| `/categories` | | Grid of root categories with images, each expands to children. |
| `/c/:slug` | | Breadcrumb, child-category chips, product grid (`app/ProductCard 43:20`: image, name, price per unit, "أضف" button; unavailable = greyed badge). Sort & availability filter. |
| `/p/:slug` | | Gallery (swipe), name, price with unit badge, **estimate notice for KG**, option chips (`price_delta` shown as `+2,000`), **qty stepper** (KG: ±0.250, min 0.250, input accepts decimals; PIECE: ±1), note textarea, sticky "أضف إلى السلة" with line estimate. |
| `/offers` | | Cards: name, benefit badge (`PERCENT 10%`, `توصيل مجاني`), validity, conditions summary (generated from the JSON tree via `describeConditions()`). |
| `/cart` | | Lines with thumbnail, option, qty stepper, note, remove; quote summary (subtotal/estimate); warnings from `/checkout/quote`; CTA "إتمام الطلب" (disabled with reason when blocked). Guest → CTA leads to `/login?next=/checkout`. |
| `/login` | | Phone (E.164 mask `+963 9xx xxx xxx`), password, "نسيت كلمة المرور" (dialog → `POST /auth/password-reset/request`), link to register. |
| `/register` | | Name, phone, password (strength hint), language; success → `/activate`. |
| `/activate` | | 6-digit OTP input (auto-advance, paste), "لم يصلك الكود؟ تواصل معنا" (wa.me store link), shows remaining attempts after a failure, locked state with instructions. |
| `/checkout` | `7:5` | Fulfillment segmented control; PICKUP: time slots; DELIVERY: address card (`7:17`) with radio list, "+ عنوان جديد", **optional row "تحديد الموقع على الخريطة" (اختياري)** → `AddressMapPicker`; zone fee & min-order hint; note; points slider (0…`maxRedeemablePoints`, step 50) with live value; offer line (auto); summary; button "تأكيد الطلب وإرسال واتساب". After `201` → open `whatsappUrl` → `/orders/:nr?sent=1`. |
| `AddressMapPicker` | `311:439` | Leaflet map, OSM tiles from `settings.map.tile_url`, starts at geolocation or city centre, draggable pin, "تحديد موقعي" (`locate-fixed`), bottom bar "تأكيد الموقع والعودة" / "تخطي — إكمال بدون تحديد الموقع"; note that the description stays mandatory. Lazy-loaded chunk. |
| `/orders` | | Tabs: الجارية · المكتملة · الملغاة; rows with status badge (`Badge/status` variant per state), estimate/final, date. |
| `/orders/:nr` | | Status timeline (vertical, RTL), items (requested → actual once weighed, strike estimate), totals (estimate vs final), fulfillment info (+ `geo:` link if pin), actions: cancel (NEW only), reorder, WhatsApp again, open ticket. Banner when `?sent=1`. |
| `/account` | | Profile form, language, password change, addresses list (default badge, edit/delete, set default), add address form (zone select, details, map step). |
| `/account/points` | | Balance hero, **statement** list (type icon, ±points, order link, date), private offers section. |
| `/support` | | Bot chat (message list, quick questions from top FAQ, escalation CTA), my tickets list. |
| `/support/:nr` | | Thread (public messages), reply box (hidden when CLOSED), status badge, linked order. |

## 5. Staff screens

| Route | Figma | Spec |
|---|---|---|
| `/staff/queue` | | Status tabs with counts (`GET /staff/orders/counts`), search, rows (`StaffOrderRow`), one-tap "تأكيد" on NEW, row → detail. Sound/visual cue on new NEW orders (polling diff). |
| `/staff/orders/:id` | `8:5` | Three-column (RTL): sidebar · main (items table: name/option, requested, **`actual_qty` input**, line total; PIECE rows read-only; deviation warning row state) · summary panel (estimate, final, fee, discount, total; customer card with phone/WhatsApp; staff note). Actions by state (see `05 §1`). Audit hint next to actions. Driver dropdown for dispatch. Cancel dialog with reason chips. |
| `/staff/otp` | | Pending users list (name, phone, status, last notification), "توليد الكود" → panel: **code once, large** · prepared message · "فتح واتساب" (`wa.me`) · "تأكيد الإرسال" (separate button) · countdown to expiry. Also pending reset requests. |
| `/staff/products` | | Search, list with availability switch and price inline edit (confirm dialog), stock cached. |
| `/staff/stock` | | Movement form (product search, type, qty, reason), low-stock list, movement history per product. |
| `/staff/tickets` | | ORDER/GENERAL tickets; thread with internal toggle; assign to me; status. |

## 6. Driver screens

| Route | Figma | Spec |
|---|---|---|
| `/driver/deliveries` | `30:5` | Availability toggle; offline banner ("لا يوجد اتصال — تُعرض آخر قائمة محفوظة"); groups by zone; `DeliveryCard` (customer name right, order code left, status badge, amount to collect, attempts); totals bar (count, cash to collect). Pull-to-refresh. |
| `/driver/deliveries/:id` | `17:5` | Address card (`17:21`): text, call button, WhatsApp button, **"فتح الموقع في الخرائط"** outline button (`geo:lat,lng?q=lat,lng` — hidden when no pin); items list; amount; primary "تم التسليم" (dialog: amount collected prefilled, note) ; secondary "فشل التسليم" → **bottom sheet overlay** with reason chips + free text → confirm. Both actions enqueue when offline with `Idempotency-Key`. |

## 7. Admin screens (shell: sidebar · topbar search · filter bar · table · detail drawer)

| Route | Spec highlights |
|---|---|
| `/admin` | KPI tiles (link to the fixing screen), today's orders by status chart (monochrome chart tokens), revenue sparkline, attention list. |
| `/admin/users` | table (name, phone, role, status, created), filters, row actions: OTP, block/unblock, change role, note. |
| `/admin/staff` | tabs EMPLOYEE/DRIVER/IT; create dialog with profile fields; driver availability; reset password (generates OTP reset). |
| `/admin/products` | table with image, category, unit, price, cost, stock, flags; drawer form: bilingual fields, slug (auto from `name_en` or transliteration, editable), unit, price, thresholds, options editor (rows), images uploader (drag order, primary star). |
| `/admin/categories` | tree with drag reorder (`@dnd-kit`), inline edit, image, active toggle; slug uniqueness error inline. |
| `/admin/orders` | filters (status, date range, fulfillment, zone, driver, search); table; drawer = staff detail + reassign/force cancel. |
| `/admin/zones` | table inline-editable fee/min order, active, reorder. |
| `/admin/cms/theme` | editors by `type` (color picker → writes hex; image uploader; text ar/en; font select), live preview column; "نشر" applies (invalidates `/theme` cache). |
| `/admin/cms/blocks` | sortable list; per-type editor forms (bilingual title/subtitle, image, CTA href, product/category pickers with search); schedule; preview. |
| `/admin/offers` | table with usage stats; `/admin/offers/new`, `/:id` = **builder**: basics → conditions (row builder from `GET /admin/offers/condition-types`, nested all/any groups) → benefit → scope/target → validity/limits → preview of generated description + JSON (read-only). |
| `/admin/points` | rules card (settings subset), adjust form (customer search, ±points, reason), liability & monthly movement chart, customer statement lookup. |
| `/admin/support` | all tickets, assign, SLA age color, category filter. |
| `/admin/faq` | CRUD list, keyword chips, "جرّب البوت" tester showing matched entry and score. |
| `/admin/erp/stock` | table (cached vs ledger, mismatch badge), low-stock filter, valuation total, "إعادة احتساب" button, movement ledger drawer. |
| `/admin/erp/suppliers` | CRUD. |
| `/admin/erp/purchases` | invoice list; create form with line rows (product search, qty, unit cost, line total), totals; view/print. |
| `/admin/reports` | tabs per report, date range, charts (chart tokens) + table, CSV export button. |
| `/admin/audit` | filters, table, diff dialog (old vs new JSON side by side), link to `/it/logs?correlationId=`. |
| `/admin/settings` | BUSINESS keys grouped (store, orders, loyalty, OTP) with typed inputs and validation. |

## 8. IT screens

| Route | Spec |
|---|---|
| `/it/health` | status tiles (DB, disk, storage, uptime, JVM, last backup, pending notifications, errors/hour), each with link to logs filtered. |
| `/it/logs` | filter bar (correlationId, level, time range, text), virtualized table, row expand with exception; `correlation_id` is clickable everywhere else. |
| `/it/providers` | four cards, current value, radio of available implementations, health check button, confirm dialog ("سيؤثر فورًا"), audit note. |
| `/it/backups` | list (name, size, date, checksum, ok), "تشغيل نسخة الآن" (progress via polling job), download, retention setting link. |
| `/it/tickets` | TECHNICAL tickets thread/assign/status. |

## 9. Component mapping (packages/ui ↔ Figma `02 · Components`)

| Figma component set | shadcn/ui base | Notes |
|---|---|---|
| `Button` (`39:52`) | `button` | variants default/secondary/outline/ghost/destructive/link; sizes sm/md/lg/icon; RTL icon on the **start** side |
| `Badge/status` | `badge` | one variant per order status; colours via `primary-subtle`/`destructive-subtle`/`muted` |
| `app/ProductCard` (`43:20`) | card + button | image ratio 1:1, name 2 lines clamp, unit badge |
| `app/BottomTab` (`36:19`) | custom | 5 tabs, active uses `primary` |
| `Icon` (`60:476`) | `lucide-react` | 65 Lucide v1.31.0 icons, same names (`shopping-cart`, `map-pin`, `locate-fixed`, `wifi-off`, …) — never add another icon set |
| `app/NavItem` (`36:8`) | custom | sidebar item, leading icon on the start (right) side |
| *(logo)* | `<img>` from `GET /theme.logoUrl` | no brand component exists in Figma yet; wordmark text fallback; ratio width = height × 87.5/75.6 if the brand mark is supplied |
| `Input`, `Select`, `Textarea`, `Switch`, `Checkbox`, `RadioGroup`, `Dialog`, `Sheet`, `Tabs`, `Table`, `Skeleton`, `Toast`, `DropdownMenu`, `Command` (search), `Slider` (points) | same names | add via `pnpm dlx shadcn@latest add <name>` from `apps/web` |
| `Stepper/Qty` | custom (`packages/ui/src/qty-stepper.tsx`) | KG/PIECE modes |
| `OtpInput` | custom | 6 boxes, RTL-safe (digits LTR inside) |
| `StatusTimeline` | custom | vertical, RTL |
| `MapPicker` | custom (Leaflet) | lazy |

## 10. Figma node index (verified 2026-08-22 against the live file)

Pages: `0:1` Foundations · `1:63` Components · `1:64` Customer · `1:65` Staff · `1:66` Driver · `1:67` Admin · `1:68` IT · `1:69` Flows · `91:2` Theme QA · `198:2` Typografie QA.

| Route | Node | Frame | Route | Node | Frame |
|---|---|---|---|---|---|
| `/` | `4:5` | 390×844 | `/admin` | `126:2062` | 1440×900 |
| `/categories` | `102:321` | 390×844 | `/admin/orders` | `120:430` | 1440×900 |
| `/c/:slug` | `25:5` | 390×844 | `/admin/products` | `120:715` | 1440×900 |
| `/p/:slug` | `5:5` | 390×844 | `/admin/categories` | `120:1006` | 1440×900 |
| `/offers` | `102:400` | 390×844 | `/admin/zones` | `120:1282` | 1440×900 |
| `/cart` | `13:5` | 390×844 | `/admin/users` | `21:5` | 1440×900 |
| `/checkout` | `7:5` | 390×844 | `/admin/staff` | `122:1007` | 1440×900 |
| `/checkout` map picker (component) | `311:439` | 390×844 | `/admin/offers` | `122:1304` | 1440×900 |
| `/login` | `25:86` | 390×844 | `/admin/offers/new` | `19:5` | 1440×900 |
| `/register` | `26:5` | 390×844 | `/admin/points` | `122:1605` | 1440×900 |
| `/activate` | `13:71` | 390×844 | `/admin/cms/theme` | `130:2389` | 1440×900 |
| `/orders` | `104:373` | 390×844 | `/admin/cms/blocks` | `20:5` | 1440×900 |
| `/orders/:nr` | `15:5` | 390×844 | `/admin/support` | `122:1881` | 1440×900 |
| `/account` | `26:52` | 390×844 | `/admin/faq` | `123:1602` | 1440×900 |
| `/account/points` | `27:5` | 390×844 | `/admin/erp/stock` | `132:2558` | 1440×900 |
| `/support` | `104:487` | 390×844 | `/admin/erp/suppliers` | `123:1894` | 1440×900 |
| `/support/:nr` | `27:82` | 390×844 | `/admin/erp/purchases` | `123:2170` | 1440×900 |
| `/staff/queue` | `16:5` | 1280×860 | `/admin/reports` | `132:2901` | 1440×900 |
| `/staff/orders/:id` | `8:5` | 1280×860 | `/admin/audit` | `126:2420` | 1440×900 |
| `/staff/orders/:id` — pre-weighing state | `154:370` | 1280×860 | `/admin/settings` | `133:2866` | 1440×900 |
| `/staff/otp` | `28:5` | 1280×860 | `/it/health` | `115:90` | 1280×860 |
| `/staff/products` | `106:190` | 1280×860 | `/it/logs` | `115:217` | 1280×860 |
| `/staff/stock` | `106:340` | 1280×860 | `/it/providers` | `22:5` | 1280×860 |
| `/staff/tickets` | `109:316` | 1280×860 | `/it/backups` | `117:188` | 1280×860 |
| `/driver/deliveries` | `30:5` | 390×844 | `/it/tickets` | `117:347` | 1280×860 |
| `/driver/deliveries/:id` | `17:5` | 390×844 | | | |
| `/driver/deliveries/:id` — failure sheet (overlay) | `17:46` | 390×844 | | | |

Sub-frames used in the specs: checkout address card `7:17`, driver address card `17:21`. Components: `Button 39:52`, `Badge 41:10`, `Input 41:24`, `Card 42:2`, `Icon 60:476` (`map-pin 59:82`, `locate-fixed 310:44`), `app/ProductCard 43:20`, `app/BottomTab 36:19`, `app/NavItem 36:8`.
**Not present in the file** (do not reference): `Brand/Symbol 253:116`, `Brand/Logo 249:141`, brand vector `248:4`, brand QA board `254:100`.

