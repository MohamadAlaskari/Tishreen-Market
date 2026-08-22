# 09 — Architecture

## 1. Repository layout

```
tishreen/
├─ apps/web/                      # TanStack Start (React 19)
│  ├─ src/routes/                 # file routes (see 07)
│  ├─ src/features/<domain>/      # api.ts (queries/mutations) · components/ · hooks/ · schemas.ts (zod) · types.ts
│  │   auth · catalog · cart · checkout · orders · account · loyalty · support · staff · driver · admin · it
│  ├─ src/lib/api/                # client.ts (fetch wrapper: base URL, bearer, refresh, correlation id, Accept-Language), types.ts (generated from OpenAPI), errors.ts
│  ├─ src/lib/auth/               # session store, guards.ts
│  ├─ src/lib/i18n/               # i18next setup, formatters (money, qty, date)
│  ├─ src/lib/offline/            # idb persister, mutation queue (driver)
│  ├─ src/locales/ar.json · en.json
│  ├─ src/styles/globals.css
│  └─ public/fonts/ · public/icons/ · public/manifest.webmanifest
├─ packages/ui/                   # shadcn components + brand + custom (qty-stepper, otp-input, status-timeline, map-picker)
├─ api/                           # Spring Boot 3 · Java 21 · Maven
│  ├─ src/main/java/com/tishreen/api/
│  │  ├─ TishreenApiApplication.java
│  │  ├─ identity/      catalog/      ordering/     delivery/
│  │  ├─ loyalty/       support/      inventory/    cms/
│  │  ├─ platform/      # notification · storage · payment · chatbot · audit · settings · logging · backup
│  │  └─ shared/        # money, ids, localized text, exceptions, pagination, security principal, time
│  ├─ src/main/resources/db/migration/   V1__init_schema.sql · V2__seed_core_data.sql · V3__… (additive only)
│  ├─ src/main/resources/db/dev/         V900__dev_sample_data.sql (profile dev)
│  ├─ src/main/resources/messages_ar.properties · messages_en.properties
│  └─ src/test/java/...                  unit · integration (Testcontainers) · arch (ArchUnit)
├─ infra/                         # docker-compose.yml · nginx.conf · scripts/backup.sh · scripts/restore.sh
├─ docs/                          # this package
├─ .claude/                       # agents, skills, hooks, settings
├─ turbo.json · pnpm-workspace.yaml · package.json
└─ CLAUDE.md
```

## 2. Backend — Modular Monolith

Each domain package has the same internal shape:
```
ordering/
├─ api/            OrderController, StaffOrderController           (web layer: DTOs in/out, @PreAuthorize)
├─ application/    OrderingService (use cases), OrderStateMachine, PricingService, OrderNumberGenerator
├─ domain/         Order, OrderItem, OrderStatus (enum), OrderStatusHistory, Payment   (JPA entities, invariants)
├─ infrastructure/ OrderRepository (Spring Data), specifications, WhatsAppMessageBuilder
├─ dto/            records: CreateOrderRequest, OrderDto, StaffOrderDetail, QuoteRequest/Response …
└─ events/         OrderStatusChanged (application event)
```

**Boundary rule (ArchUnit-enforced):** a package may import another package's `api`/`dto`/`events` and its public *service interface*, never its `domain` or `infrastructure`. Cross-module needs go through small **ports** declared by the consumer and implemented by the owner, e.g.:

| Consumer needs | Port (in consumer) | Implemented in |
|---|---|---|
| ordering needs product prices/availability | `ordering.ports.CatalogGateway { ProductSnapshot load(id) }` | catalog |
| ordering needs zone fee/min | `ordering.ports.ZoneGateway` | delivery |
| ordering applies offers/points | `ordering.ports.LoyaltyGateway { OfferResult evaluate(CartContext); void redeem(); void earn(); void reverse(); }` | loyalty |
| ordering writes stock | `ordering.ports.StockGateway { void sale(orderId, lines); void returnStock(orderId) }` | inventory |
| everything notifies | `platform.notification.NotificationChannel` | platform |
| everything audits | `platform.audit.@Audited` | platform |

Application events (`ApplicationEventPublisher`, synchronous, same transaction unless `@TransactionalEventListener(AFTER_COMMIT)`): `OrderCreated`, `OrderStatusChanged`, `OrderFinalized`, `PaymentRecorded`, `TicketReplied`. Listeners: notification (AFTER_COMMIT), loyalty earn (BEFORE_COMMIT inside same tx), stock sale (same tx).

**Layering inside a module (ArchUnit-enforced, ADR-0005):** `api → application, dto, events` · `application →` everything except `api` · `infrastructure → domain, dto` · `dto`/`events` are plain data carriers · `domain` depends on nothing else in the module. Sole exception: the module's own `api`/`dto`/`events` may reference **domain enums** (e.g. `OrderStatus`) — entities never. Across modules the boundary rule above stays absolute, so an enum needed by another module moves to `dto` or `shared`.

### Provider abstraction (the "everything abstract" principle)
```java
public interface NotificationChannel { String key(); NotificationResult send(NotificationRequest r); }
public interface ImageStorage      { String key(); String put(String key, InputStream in, String contentType); Optional<StoredObject> get(String key); void delete(String key); }
public interface PaymentProvider   { String key(); PaymentIntent create(OrderPaymentContext ctx); PaymentResult handleCallback(Map<String,String> payload); boolean cashOnDelivery(); }
public interface ChatbotProvider   { String key(); BotReply reply(String message, String lang, BotContext ctx); }
```
- Implementations are Spring beans named by key: `manual-whatsapp`, `telegram-bot` (stub), `sms` (stub); `local-disk`, `minio` (`@ConditionalOnProperty(app.storage.minio.enabled)`), `s3` (stub); `cod`; `faq-rules`, `llm` (stub).
- `ProviderSelector<T>` picks the active bean **at call time** from `SettingsService.get("notification.provider")` — switching from `/it/providers` needs no restart. `@ConditionalOnProperty` only gates implementations that need external config.
- Contract tests: each interface has an abstract test class; every implementation must extend it (`ManualWhatsAppChannelTest extends NotificationChannelContractTest`).

### Audit via AOP
```java
@Audited(action = "UPDATE_PRICE", entity = "Product")
public ProductDto updatePrice(@AuditId Long id, BigDecimal price) { … }
```
`AuditAspect` (`@Around`): resolves actor (`SecurityContext`), role, IP (`RequestContextHolder`), `correlationId` (MDC), calls `AuditSnapshotter` registered per entity type to capture `old` (before proceed) and `new` (after), then `auditLogRepository.save(...)` in the same transaction. Failure to audit = failure of the operation (no silent loss).

### Security
- `SecurityFilterChain`: stateless, `JwtAuthFilter` → `UsernamePasswordAuthenticationToken(principal = AppPrincipal{id, role, status, lang}, authorities = perms + ROLE_x)`.
- `@EnableMethodSecurity`; controllers use `@PreAuthorize`. Customer ownership checked in services.
- Rate limiting: `RateLimitFilter` with in-memory token buckets keyed by phone/IP for `/auth/**` and `/staff/otp/generate`.
- Passwords: `BCryptPasswordEncoder(12)`. OTP: BCrypt(10) or `HmacSHA256` with `app.otp.pepper` env secret.
- `CorrelationIdFilter` first in chain; JSON logging (logback + `logstash-logback-encoder`) with MDC `correlationId`, `userId`, `role`.
- Secrets only from environment: `DB_URL`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`, `JWT_REFRESH_SECRET`, `OTP_PEPPER`, `MINIO_*`. `.env.example` committed, `.env` ignored.

### Configuration
`application.yml` (profiles `dev`, `prod`): datasource, flyway locations, `app.cors.origins`, `app.storage.local.base-path`, `app.media.public-path=/api/v1/media`, `app.backup.*`, `app.logs.dir`, `springdoc.enabled` (dev/IT). Business settings come from the `settings` table via `SettingsService` (cached, `@CacheEvict` on write).

### Scheduled jobs (`platform.jobs`, `@Scheduled`, single instance)
- Nightly backup (`backup.schedule_cron`): `pg_dump | gzip` → `backup.directory`, sha256, prune by `backup.retention_days`.
- Points expiry (daily 03:00, Phase 6).
- Tickets auto-close RESOLVED → CLOSED after 72h (Phase 6).
- Log retention prune (daily).

### Error handling
`@RestControllerAdvice GlobalExceptionHandler`: `BusinessException(code, status, args)` → localized `ApiError`; `MethodArgumentNotValidException` → `400` with field codes; everything else → `500` with correlation id, logged at ERROR with stack trace (never returned).

### Persistence rules
- Entities: `@Table(name = "…")`, `@Column(name = "…")` explicit on every field; `BigDecimal` for money/qty; `OffsetDateTime` for TIMESTAMPTZ; `@Enumerated(STRING)`; `@Version` not used (pessimistic locking on orders).
- Repositories return DTO projections for lists (`interface OrderSummaryView`) to avoid N+1; detail loads use `@EntityGraph`.
- Flyway: migrations are **additive**; never edit a released migration; dev seed in a separate location.

## 3. Frontend architecture

- **Data**: TanStack Query for all server state (`queryKey` conventions `['orders', 'mine', params]`); mutations invalidate precisely. No global store for server data. Cart = `zustand` store persisted to `localStorage` (`tishreen.cart.v1` with schema version).
- **API client** (`src/lib/api/client.ts`): base URL from `import.meta.env.VITE_API_URL`, attaches bearer, `Accept-Language`, `X-Correlation-Id`; on `401` tries one `POST /auth/refresh` then retries; maps `ApiError` to typed `AppError`.
- **Types**: generated from OpenAPI (`openapi-typescript`) into `src/lib/api/types.ts` — never hand-written duplicates of DTOs.
- **Forms**: react-hook-form + zod schemas in `features/*/schemas.ts`; server `422 details.fields` mapped back to form errors.
- **i18n**: react-i18next, `ar` default, lazy `en`; see `10-i18n.md`.
- **Offline (driver only)**: `@tanstack/query-persist-client` with IndexedDB persister; mutation queue (`src/lib/offline/queue.ts`) storing `{url, body, idempotencyKey, createdAt}`; replays on `online` event in order; PWA service worker precaches the app shell (`vite-plugin-pwa`, `navigateFallback` for `/driver/*`).
- **Maps**: `leaflet` + `react-leaflet` bundled; tile URL from `GET /theme`? No — from a public settings endpoint `GET /config` → `{ mapTileUrl, cityCenter, weightStepKg, currency }` (small, cached).
- **Routing**: layouts own guards + shells; routes own loaders (`loader` uses `queryClient.ensureQueryData`); pending components are skeletons.
- **Build**: Vite; `pnpm turbo build`; bundle analysis once per phase; no external CDN imports anywhere.

## 4. Local development

`infra/docker-compose.yml`: `postgres:15` (port 5432, volume), optional `minio`. API: `./mvnw spring-boot:run -Dspring-boot.run.profiles=dev` (Flyway applies V1, V2, V900). Web: `pnpm dev` (proxy `/api` → `localhost:8080`). Dev accounts: see `04-seed.sql` Part B (`Tishreen!Dev1`).

## 5. Deployment (Phase 5+)
- Single VPS (non-US-blocking provider), Ubuntu, nginx (TLS, static web, `/api` proxy, `/media` static for local-disk), systemd service for the API (fat jar), Postgres local, fonts/Leaflet/tiles reachability test from inside Syria before launch.
- Web is prerendered/SSR by TanStack Start Node adapter behind nginx; API and web share the domain (`/api/v1`).
