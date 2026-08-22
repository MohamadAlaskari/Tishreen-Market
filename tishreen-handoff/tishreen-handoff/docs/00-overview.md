# 00 — Project Overview · مجمع تشرين (Tishreen Mall)

> Canonical product name: **مجمع تشرين** (the name on every Figma screen and in the knowledge files; English label "Tishreen Mall").
> Confirmed by Mohamad on 2026-08-22: the 2026-08-20 branding experiments («تشرين مول», slogan, brand mark, emerald primary) were reverted on purpose. Final: **مجمع تشرين**, rose preset, Tajawal text, Tufuli Arabic headings (Baloo Bhaijaan 2 stand-in). See `08`.
> Internal code name: `tishreen`. Repository root: `tishreen/`.

## 1. What we are building

A bilingual (Arabic-first, RTL) grocery e-commerce platform for a single physical store in Aleppo, Syria.
Five user roles share one REST API and one web app:

| Role | Code | What they do |
|---|---|---|
| Customer | `CUSTOMER` | Browse, order (pickup or delivery), earn/redeem loyalty points, use offers, open support tickets, chat with FAQ bot |
| Employee | `EMPLOYEE` | Order queue, confirm, **weigh items and set final price**, generate/send OTP, toggle product availability, record stock movements, answer tickets |
| Driver | `DRIVER` | Sees only deliveries assigned to them, delivers, records cash collected, reports failed attempts — **must work with intermittent internet** |
| IT | `IT` | Health, technical logs, provider switching, backups, technical tickets |
| Admin | `ADMIN` | Full CRUD over everything + CMS (theme, home blocks), offers, points, reports, audit log, settings |

## 2. Governing product facts (never contradict these)

1. **Order first, WhatsApp second.** `POST /api/v1/orders` must succeed and persist before the client opens the `wa.me` link. The WhatsApp message is a notification channel, not the record.
2. **Cash on delivery / pickup only** today. No payment gateway. `payments.provider = 'COD'`.
3. **Manual OTP activation.** An employee generates the code; the system prepares a WhatsApp message; the employee sends it from their own phone; the customer enters the code.
4. **Weighed goods.** Customer requests 1.000 kg, the scale says 1.070 kg, the employee enters `actual_qty`, the line and the order are re-priced on the actual weight. Points are earned on the final amount.
5. **No meat today.** The schema is generic (`product_options`) so meat and prep options can be added later as rows, not migrations.
6. **Arabic is primary (RTL); English optional.** `*_ar` columns mandatory, `*_en` optional with Arabic fallback in the service layer.
7. **Syria constraints are real engineering constraints** (see `11-syria-constraints.md`): US-hosted services block Syrian visitors, Google CDNs/fonts may not load, connectivity is intermittent, no international payment/messaging APIs.

## 3. Source-of-truth documents (read in this order)

| # | File | What it fixes |
|---|---|---|
| 00 | `00-overview.md` | This file — scope, roles, facts |
| 01 | `01-features.md` | Every feature and function, per role, with acceptance criteria |
| 02 | `02-data-model.md` | 34 tables, every column, constraint, index, and the decision behind it |
| 03 | `03-schema.sql` | Reference DDL (becomes Flyway `V1__init_schema.sql`) |
| 04 | `04-seed.sql` | Reference seed (becomes `V2__seed_core_data.sql`) + dev seed |
| 05 | `05-business-rules.md` | State machine, pricing by weight, points, offers engine, OTP, stock, audit |
| 06 | `06-api.md` | REST contract: endpoints, DTOs, errors, pagination, auth |
| 07 | `07-routes-screens.md` | 49 routes + map picker, guards, per-screen behaviour mapped to Figma |
| 08 | `08-design-system.md` | Tokens (`globals.css`), fonts, RTL rules, component mapping |
| 09 | `09-architecture.md` | Modular monolith packages, provider abstractions, AOP audit, security |
| 10 | `10-i18n.md` | i18n key conventions, `ar.json`/`en.json`, number/date/currency formatting |
| 11 | `11-syria-constraints.md` | Hosting, CDN, fonts, maps, offline driver, backups |
| 12 | `12-build-plan.md` | Six phases with task lists and acceptance criteria |
| 13 | `13-quality.md` | Definition of done, test strategy, review checklists |

Design source: Figma file key `0RLOI0q7lWCK1Rme8JjkKu` (single file, all roles, light+dark, 49 routed screens + map picker).

## 4. Tech stack (locked)

**Frontend** — TanStack Start (React 19, file-based routes) · TypeScript strict · Tailwind v4 · shadcn/ui (CLI-managed, `--rtl`) · react-i18next · TanStack Query · react-hook-form + zod · Leaflet (bundled, no CDN) · vite-plugin-pwa (driver offline shell) · Turborepo monorepo (`apps/web`, `packages/ui`) · pnpm.

**Backend** — Spring Boot 3.3+ (Java 21) · Spring Security (JWT) · Spring Data JPA · PostgreSQL 15 · Flyway · Spring AOP (audit) · Bean Validation · MapStruct (DTO mapping, optional) · springdoc-openapi · Maven (`./mvnw`). Modular Monolith: one package per domain, boundaries enforced by ArchUnit.

**Tests** — JUnit 5 + Mockito + Testcontainers (backend) · Vitest + Testing Library (frontend) · Playwright for the end-to-end order journey.

**Infra** — Docker Compose for local dev (postgres, optional minio) · VPS outside US-sanction-blocking providers · nginx reverse proxy · nightly `pg_dump`.

## 5. Glossary (Arabic ↔ code) — use these names verbatim

| Arabic | Code | Note |
|---|---|---|
| طلب / أصناف الطلب | `order` / `order_item` | `order_number` is the human-visible id (`T-000123`) |
| الوزن المطلوب / الفعلي | `requested_qty` / `actual_qty` | actual determines price |
| استلام / توصيل | `PICKUP` / `DELIVERY` | `orders.fulfillment_type` |
| منطقة توصيل | `delivery_zone` | has `fee` and `min_order` |
| عنوان | `address` | free-text `details` + optional map pin `latitude/longitude` |
| نقاط الولاء | `points_transaction` | ledger; balance = `SUM(points)` |
| عرض / استخدام عرض | `offer` / `offer_redemption` | conditions in JSONB |
| تذكرة دعم | `support_ticket` | category routes it (ORDER→staff, TECHNICAL→IT) |
| حركة مخزون | `stock_movement` | ledger; `products.stock_cached` is a derived cache |
| سجل التدقيق | `audit_log` | append-only, written by AOP |
| كود التفعيل | `otp_code` | hashed, 10-minute TTL, 5 attempts |
| سجل الإشعارات | `notification_log` | GENERATED → SENT (manual confirm) |
| بلوك الصفحة الرئيسية | `content_block` | JSONB payload, scheduled |
| إعدادات | `settings` | key/value; provider switches live here |

## 6. Working agreements for Claude Code

- Code, identifiers, file names, branches, commit messages: **English**.
- UI copy: **never hard-coded** — i18n keys only (`ar.json` default, `en.json` secondary).
- When a request contradicts these docs: **say so in two lines before doing anything**, then follow the user's decision.
- When adding a table/column/screen: state **where it fits** in the existing model and what it affects.
- Never invent table or route names — use the ones here verbatim.
- Big tasks: numbered plan → implement step 1 → stop for review.
- Full, runnable code. No `// TODO: implement`. No `any`, no `@ts-ignore`, no stray `console.log`.
