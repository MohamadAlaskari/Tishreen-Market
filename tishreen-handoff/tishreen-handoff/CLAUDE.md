# مجمع تشرين (Tishreen Mall) · Claude Code project memory

Arabic-first (RTL) grocery e-commerce for a single store in Aleppo, Syria. Five roles (CUSTOMER, EMPLOYEE, DRIVER, IT, ADMIN),
one REST API (`/api/v1`), one web app. Design is finished and documented; **implement, don't redesign.**

## Read before coding
`docs/00-overview.md` → then the doc for your task: `01-features` · `02-data-model` · `03-schema.sql` · `04-seed.sql` ·
`05-business-rules` · `06-api` · `07-routes-screens` · `08-design-system` · `09-architecture` · `10-i18n` · `11-syria-constraints` · `12-build-plan` · `13-quality`.
Skills in `.claude/skills/` condense these; agents in `.claude/agents/` review against them.

## Stack (locked)
- Web: TanStack Start + React 19 + TypeScript strict + Tailwind v4 + shadcn/ui (CLI only, `--rtl`) + react-i18next + TanStack Query + react-hook-form/zod + Leaflet (bundled). Monorepo `apps/web` + `packages/ui`, **pnpm** + Turborepo.
- API: Spring Boot 3.3 / Java 21 / Maven (`./mvnw`), Spring Security JWT, Spring Data JPA, PostgreSQL 15, Flyway, Spring AOP audit, springdoc. **Modular monolith**: `identity catalog ordering delivery loyalty support inventory cms platform shared` (ArchUnit-enforced boundaries).
- Tests: JUnit 5 + Mockito + Testcontainers + ArchUnit · Vitest + Testing Library · Playwright.

## Non-negotiable rules
1. **RTL first**: only logical utilities (`ms- me- ps- pe- start- end- text-start text-end rounded-s- rounded-e- border-s border-e`). Never `ml/mr/pl/pr/left/right/text-left/text-right`.
2. **Colours only via tokens** (`bg-primary`, `text-muted-foreground`, `text-link`, `bg-primary-subtle`…). No `#hex`, `oklch()`, `rgb()`, Tailwind palette colours, or `bg-[…]` in components. Links in dark mode use `text-link`.
3. **No literal UI text** — i18n keys only (`ar.json` default, `en.json` secondary). DB content `*_ar` mandatory, `*_en` optional with Arabic fallback **in the service layer**.
4. **Database is the source of truth**: `POST /orders` persists **before** the `wa.me` link is returned/opened. WhatsApp is a notification, not a record.
5. **Snapshots**: product name/price/option, address, zone fee, customer language are copied into the order at creation. Historical screens read snapshots, never joins.
6. **Ledgers**: points and stock are movements; balance = `SUM`. No editable balance column (`products.stock_cached` is a derived cache updated in the same transaction).
7. **Audit via AOP** (`@Audited`) is mandatory for: UPDATE_PRICE, UPDATE_WEIGHT, SEND_OTP, CHANGE_ORDER_STATUS, CANCEL_ORDER, RECORD_PAYMENT, ADJUST_POINTS, SWITCH_PROVIDER, UPDATE_SETTING, BLOCK_USER, CHANGE_ROLE, STOCK_ADJUSTMENT, ASSIGN_DRIVER.
8. **Providers behind interfaces** (`NotificationChannel`, `ImageStorage`, `PaymentProvider`, `ChatbotProvider`) selected at runtime from the `settings` table — no provider SDK outside `platform`.
9. **Server computes money/points/state**; frontend checks are UX only. Money `BigDecimal` scale 2 HALF_UP, quantities scale 3; DB `NUMERIC(14,2)` / `NUMERIC(12,3)`, never floats.
10. **No hard deletes** of anything with history (`is_active=false`, FKs `ON DELETE RESTRICT`).
11. **No secrets in code or git** — env vars only; `.env.example` documents them.
12. **No external runtime URLs** (CDNs, Google Fonts, Google Maps) — Syria blocks them. Fonts/Leaflet/icons are bundled or self-hosted.
13. Use table, column, route, status and permission names **verbatim** from the docs. Never invent names.
14. shadcn components are added with `pnpm dlx shadcn@latest add <name>` from `apps/web`, then edited — never hand-copied.

## Working style
- Reply in the user's language (Arabic or German); code, identifiers, files, branches, commits in English.
- If a request contradicts the docs, say so in two lines **before** acting.
- New table/column/screen → state where it fits in the existing model and the side-effects.
- Big task → numbered plan, implement step 1, stop for review. Prefer a recommended option + one alternative + a two-line reason over long comparisons.
- Deliver complete runnable code; no `TODO: implement`, no `any`, no `@ts-ignore`, no stray `console.log`/`System.out`.
- Every list query paginated and indexed. Comments explain *why*.
- Flag Syria constraints whenever they matter (hosting, CDN, offline driver, payments, messaging).
- GitHub tickets only via the `ticket` skill (`.claude/skills/ticket/`): dependencies `Blocked by:` / `Blocks:` mirrored on **both** issues, `blocked` label while a blocker is open. After implementing a ticket, deliver the handover from that skill — commit message + `git add`/`git commit` command with the file list, PR title and PR description.

## Commands
```bash
# web
pnpm install · pnpm dev · pnpm -F web typecheck · pnpm -F web test · pnpm -F web build · pnpm lint
pnpm dlx shadcn@latest add <component>   # run inside apps/web
# api
./mvnw -q verify                 # unit + integration (Testcontainers) + ArchUnit
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
./mvnw -q test -Dtest=OrderStateMachineTest
# infra
docker compose -f infra/docker-compose.yml up -d postgres
```

## Key identifiers (memorise)
Order statuses: `NEW CONFIRMED PREPARING READY_FOR_PICKUP OUT_FOR_DELIVERY DELIVERY_FAILED PICKED_UP DELIVERED CANCELLED`.
User statuses: `PENDING OTP_SENT ACTIVE BLOCKED`. Fulfillment: `PICKUP DELIVERY`. Units: `KG PIECE`.
Points types: `EARN REDEEM ADJUST EXPIRE REVERSAL`. Stock types: `PURCHASE SALE WASTE ADJUSTMENT RETURN`.
Settings keys: `notification.provider storage.provider payment.provider chatbot.provider` (+ `store.* orders.* loyalty.* otp.* auth.* backup.* map.tile_url`).
Theme presets: `rose` (default) `orange` `sky` — `data-theme` on `<html>`, `.dark` for dark mode; derived tokens `link primary-subtle destructive-subtle`.
Fonts: Tajawal (text) · Tufuli Arabic for main headings (licensed, pending files → Baloo Bhaijaan 2 stand-in/fallback) · Cairo (labels, prices) · IBM Plex Mono (codes) — all self-hosted.
Branding final: «مجمع تشرين», rose preset; the 20.08 emerald/تشرين مول experiments were reverted — never reintroduce them.
Order number `T-000123`, ticket number `S-000045`. Figma file `0RLOI0q7lWCK1Rme8JjkKu` (node index in `docs/07 §10`).
