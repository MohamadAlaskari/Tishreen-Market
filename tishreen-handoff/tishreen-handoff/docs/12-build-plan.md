# 12 — Build Plan (6 phases · one vertical slice at a time)

Each phase ends with a runnable, demonstrable outcome and a checklist. Work inside a phase in the listed order;
each numbered task is one Claude Code session-sized unit (plan → implement → tests → review). Use `/phase <n>` to load the phase context.

Branching (ADR-0002): GitHub issue branches off `main` — one branch + PR per ticket (`<issue-nr>-<slug>`, base `main`); merging the PR closes the ticket. Commits: conventional (`feat(ordering): finalize order pricing`).

---

## Phase 1 — Foundations (monorepo, theme, i18n, RTL, API skeleton, DB)
**Outcome**: empty bilingual app shell in both directions + API with Flyway schema and seed, health endpoint, CI.

1. **P1-T1 Monorepo init** — `pnpm dlx shadcn@latest init --preset b4iTphWki --template start --monorepo --rtl --pointer`; Turborepo pipelines; TS strict; ESLint (`eslint-plugin-tailwindcss` off — our hook covers tokens), Prettier; commit `.nvmrc`, `pnpm-lock.yaml`.
2. **P1-T2 Tokens & fonts** — replace generated `globals.css` with `08 §2.1` (rose default + orange + sky blocks + derived tokens); self-host Tajawal, Cairo, IBM Plex Mono and Baloo Bhaijaan 2 (`@font-face`, files in `public/fonts/`; Tufuli Arabic slot prepared for the licensed files); `data-theme` + `.dark` switching on `<html>`; verify the contrast table of `08 §2` for all three presets.
3. **P1-T3 i18n & direction** — react-i18next, `ar.json` skeleton (`common`, `nav`, `errors`), `en.json`; `<html dir lang>` switching; formatters.
4. **P1-T4 Layout shells** — `__root`, `_customer` (header, bottom tabs), `_guest`, `_staff`, `_driver`, `_admin`, `_it` with placeholder pages for all 49 routes (titles only) and guards wired to a stub session.
5. **P1-T5 API project** — Spring Boot 3.3, Java 21, Maven, modules packages, `shared` (Money, LocalizedText, ApiError, Page), `CorrelationIdFilter`, JSON logging, Actuator, springdoc, profiles, `docker-compose` postgres.
6. **P1-T6 Schema** — `V1__init_schema.sql` from `03-schema.sql` (verbatim), `V2__seed_core_data.sql` from `04-seed.sql` Part A, `db/dev/V900` Part B; Testcontainers smoke test that counts 34 tables.
7. **P1-T7 ArchUnit** — module boundary tests; `platform` only package importing providers.
8. **P1-T8 CI** — GitHub Actions: pnpm lint/typecheck/test/build; `./mvnw verify` with Testcontainers; artifact upload.

**Checklist**: app runs in ar/en; `GET /actuator/health` ok; Flyway clean on fresh DB; CI green; hooks in `.claude/` pass on the repo.

## Phase 2 — Identity (register · login · OTP · roles)
**Outcome**: a customer registers, staff generates OTP, customer activates and logs in; role guards work end-to-end.

1. **P2-T1 Users & security** — entities (`User`, profiles, `Role`, `Permission`), `UserRepository`, `PasswordEncoder`, JWT issuer/validator, refresh cookie, `JwtAuthFilter`, `AppPrincipal`, `@EnableMethodSecurity`.
2. **P2-T2 Auth endpoints** — register/login/refresh/logout/me/patch me/password; rate limiting; errors localized; tests (unit + MockMvc).
3. **P2-T3 OTP** — `OtpService` (generate/verify/lock/expire), `NotificationChannel` + `manual-whatsapp` impl, `notification_log`, audit aspect (`SEND_OTP`), staff endpoints (`/staff/otp/*`, mark-sent), activation & reset endpoints; contract tests for the channel.
4. **P2-T4 Frontend auth** — session store, api client with refresh, `/login`, `/register`, `/activate` (OTP input), forgot-password dialog, guards real; `/account` profile basics.
5. **P2-T5 Staff OTP desk** — `/staff/otp` screen (code once, message, wa.me, confirm sent, countdown).
6. **P2-T6 Admin users (minimal)** — `/admin/users` list/search, generate OTP, block/unblock (audited), change role; `/admin/staff` create staff/driver/IT.

**Checklist**: F-02, F-03 ACs pass; audit rows present; blocked user rejected within 60s.

## Phase 3 — Catalogue & cart (guest-capable)
**Outcome**: browsing categories/products with images in both languages; cart persists; quote endpoint returns server-computed estimates.

1. **P3-T1 Catalog backend** — entities, repositories with projections, public endpoints (`/categories`, `/categories/{slug}`, `/products`, `/products/{slug}`), localized resolution, caching (ETag), search.
2. **P3-T2 ImageStorage** — interface, `local-disk` impl, WebP re-encode + thumbnail, `/media/{key}`, admin upload endpoints, contract test.
3. **P3-T3 Admin catalogue** — `/admin/products` (form, images, options), `/admin/categories` (tree, reorder), `/admin/zones`.
4. **P3-T4 Customer catalogue UI** — `/`, `/categories`, `/c/:slug`, `/p/:slug` (stepper, options, estimate notice), `ProductCard`, skeletons, empty states.
5. **P3-T5 Cart** — zustand store, `/cart` screen, `POST /checkout/quote` (server: steps 1–9 of 05 §2 without persistence; offers/points stubs return zero until Phase 6 but the code path exists), warnings UI.
6. **P3-T6 CMS read side** — `content_blocks` rendering on `/` from `GET /home` (seeded blocks); `GET /theme` → `data-theme` preset + optional hue override applied in `__root.tsx`.

**Checklist**: F-10, F-11, F-12 ACs; Lighthouse mobile ≥ 85 on `/` with throttling; all images served as WebP.

## Phase 4 — Ordering (checkout → WhatsApp → staff weighing)
**Outcome**: first real end-to-end order: customer checks out, WhatsApp opens, employee confirms, weighs, finalizes, marks ready/picked up.

1. **P4-T1 Order creation** — `OrderingService.createOrder` (05 §2 fully), ports to catalog/delivery, snapshots, order number sequence, `ORDER_SUBMIT` notification, `WhatsAppMessageBuilder` (ar/en), pessimistic locking; unit tests for pricing and message text.
2. **P4-T2 State machine** — `OrderStateMachine` table-driven transitions (05 §1), `order_status_history`, events, audit (`CHANGE_ORDER_STATUS`, `CANCEL_ORDER`), customer cancel while NEW.
3. **P4-T3 Weighing & finalize** — `setActualQty`, deviation warning, `finalize` recompute (05 §3), audit `UPDATE_WEIGHT`/`UPDATE_PRICE`.
4. **P4-T4 Staff endpoints** — `/staff/orders*`, counts, confirm/start/ready/picked-up/cancel, drivers list; notification `ORDER_UPDATE` generation + `/staff/notifications` pending list.
5. **P4-T5 Checkout UI** — `/checkout` (pickup slots, address list + new address form, points slider (disabled until Phase 6), summary), open `whatsappUrl` after 201, `/orders`, `/orders/:nr` timeline, reorder, cancel.
6. **P4-T6 Staff UI** — `/staff/queue` (tabs/counts/poll/confirm), `/staff/orders/:id` (weighing table, warning row, summary, actions), pending notifications panel (send + confirm).
7. **P4-T7 Stock SALE on leaving PREPARING** — `StockGateway` impl in inventory (movements + cache), `RETURN` on cancel after SALE; tests.
8. **P4-T8 Admin orders** — `/admin/orders` list/filters/drawer reusing staff components.

**Checklist**: Playwright journey `register → activate → browse → cart → checkout → (WhatsApp URL asserted) → staff confirm → weigh → finalize → ready → picked up`; points/stock ledgers consistent; F-13, F-14, F-20, F-21 ACs.

## Phase 5 — Delivery & driver (offline) · COD · deployment
**Outcome**: delivery orders dispatched to drivers, delivered with cash recorded, failures handled; app deployed and tested from Syria.

1. **P5-T1 Delivery backend** — `deliveries`, dispatch/retry/delivered/failed (05 §1), `payments` COD + `payment_status`, idempotency store, `DELIVERY_OWN` ownership, driver availability.
2. **P5-T2 Map pin** — address lat/lng in API + `/account` address form with `AddressMapPicker` (Leaflet bundled), checkout optional row, order snapshot `delivery_lat/lng`.
3. **P5-T3 Driver UI** — `/driver/deliveries` (groups, totals, availability, offline banner), `/driver/deliveries/:id` (call/WhatsApp/`geo:` button, delivered dialog, failed sheet), PWA shell, IndexedDB persister, mutation queue + replay.
4. **P5-T4 Staff/admin dispatch** — driver dropdown in `/staff/orders/:id`, retry/reassign, failed reasons list; admin reassign/force cancel.
5. **P5-T5 Cash reconciliation report (first report)** — `/admin/reports` skeleton with `cash-reconciliation` and `sales`.
6. **P5-T6 Infra** — nginx config, systemd unit, `.env.example`, `backup.sh`/`restore.sh`, deployment runbook; in-Syria checklist (11) executed; tile reachability decision.

**Checklist**: airplane-mode test passes (F-30 AC); `payments.collected_by` reconciliation matches; 11 §checklist all green.

## Phase 6 — CMS · Loyalty & offers · Support & bot · ERP · Reports · IT
**Outcome**: every remaining screen and job; feature-complete v1.

1. **P6-T1 Loyalty** — points ledger service (earn on terminal success, redeem at checkout with caps, reversal, manual adjust), `/me/points`, `/account/points`, `/admin/points`, checkout points slider live.
2. **P6-T2 Offers engine** — Specification registry + JSON validator, evaluation in quote/create/finalize, `offer_redemptions`, limits, `/offers`, `/me/offers`, admin builder `/admin/offers/*` with condition-types endpoint, `describeConditions()` in both languages.
3. **P6-T3 CMS admin** — `/admin/cms/theme` (preset cards, hue-only slider, live preview with real components, logo upload, **server contrast gate** `ThemeContrastValidator` + unit tests), `/admin/cms/blocks` (sortable, per-type editors, schedule).
4. **P6-T4 Support & bot** — tickets (customer/staff/IT/admin endpoints, internal-message filtering), `ChatbotProvider` `faq-rules` (normalizer + scorer), `/support`, `/support/:nr`, `/staff/tickets`, `/it/tickets`, `/admin/support`, `/admin/faq` + tester, `TICKET_REPLY` notifications, auto-close job.
5. **P6-T5 ERP** — suppliers, purchase invoices (movements + cost), `/staff/stock`, `/admin/erp/*`, recompute cache, low-stock, valuation.
6. **P6-T6 Reports** — all endpoints + CSV; `/admin/reports` tabs with charts; `/admin` dashboard.
7. **P6-T7 Audit & settings UI** — `/admin/audit` (diff dialog, correlation link), `/admin/settings` typed editors.
8. **P6-T8 IT module** — `/it/health`, `/it/logs` (JSON log reader), `/it/providers` (selector + health checks + stubs for telegram/sms/minio/s3/llm), `/it/backups` (list/run/download), TECHNICAL settings; jobs (backup, points expiry, log prune).
9. **P6-T9 Hardening** — security review checklist (06 §12), performance pass (N+1 scan, indexes verified with `EXPLAIN`), accessibility pass, Lighthouse, final in-Syria test.

**Checklist**: all F-xx ACs green; test coverage: backend business rules 100% of listed cases, frontend critical paths; `docs/` updated for any deviation.

---

## Deviations policy
If implementation must deviate from `02`–`08`, record it in `docs/decisions/ADR-<n>-<slug>.md` (context, decision, consequences) and update the affected doc in the same PR.
