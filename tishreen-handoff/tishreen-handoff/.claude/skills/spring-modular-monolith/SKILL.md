---
name: spring-modular-monolith
description: How the Tishreen Spring Boot API is structured and coded — package layout per module, allowed dependencies and ports, DTO/records, exception → error code mapping, security annotations, transactions/locking, pagination, provider selection, logging. Load for any backend coding task.
user-invocable: false
---
# Spring modular monolith conventions (full text: docs/09-architecture.md §2–§7)

**Layout** `api/src/main/java/com/tishreen/api/<module>/{api,application,domain,infrastructure,dto,events,ports}` for modules `identity catalog ordering delivery loyalty support inventory cms platform shared`. `shared` = cross-cutting value objects (`Money`, `Quantity`, `LocalizedText`, `BusinessException`, `PageResponse`). `platform` = settings, audit aspect, providers (interfaces + implementations), security, correlation id, health/logs/backups.

**Dependency rule (ArchUnit-enforced)**: `api → application → domain`; `infrastructure → domain`; another module only via its `application` service interface + `dto`, or a port interface declared in *your* module's `ports/` and implemented in the other module's `infrastructure` (`CatalogGateway`, `ZoneGateway`, `LoyaltyGateway`, `StockGateway`). No cycles; `platform` imported by all, imports none. Provider SDKs (MinIO/S3/Telegram…) only in `platform.infrastructure`.

**Entities**: JPA, `@Table(name="…")`, `@Enumerated(STRING)`, `OffsetDateTime`, `BigDecimal(precision, scale)`, `@Version` on `orders`/`products`, lazy associations, no cascade REMOVE. Repositories in `infrastructure`; domain services pure.

**Application services**: `@Service @Transactional`; one public method = one use case; load aggregate with `@Lock(PESSIMISTIC_WRITE)` for status transitions and stock/points writes; emit `events` (`OrderStatusChanged`, `OrderDelivered`) for side-effects in other modules via Spring events (same transaction, `@TransactionalEventListener(AFTER_COMMIT)` for notifications).

**Controllers** (`api/`): `@RestController @RequestMapping("/api/v1/…")`, `@PreAuthorize("hasAuthority('PERMISSION')")`, `@Valid` DTO records in/out, `PageResponse<T>` for lists (`page`, `size≤100`, `sort`), `ResponseEntity` with proper codes (`201` create, `204` void). Public endpoints are annotated with a `// public endpoint` comment and listed in `SecurityConfig`.

**Errors**: throw `new BusinessException(ErrorCode.X, Map.of(...))`; `GlobalExceptionHandler` maps to `{code, message(localized), details, correlationId}` with HTTP codes from docs/06 §2; validation → `400` with `details.fields`; never leak stack traces.

**Security**: stateless JWT (30 min) + refresh cookie (7 d, rotating); `CurrentUser` resolver gives `userId, role, permissions, status`; ownership helper `requireOwner(entity.userId)` → 404 on mismatch; rate limiter on `/auth/login`, `/auth/activate`, `/staff/otp/*`.

**Providers**: `NotificationChannel`, `ImageStorage`, `PaymentProvider`, `ChatbotProvider` interfaces in `platform.providers`; implementations registered with a `@Provider("manual-whatsapp")` qualifier; `ProviderSelector.get(NotificationChannel.class)` reads `settings.<kind>.provider` (cached 30 s) at call time — switching needs no restart.

**Audit**: `@Audited(action = AuditAction.X, entity = "orders", idParam = "orderId")` on the service method; `AuditAspect` writes one `audit_log` row per call (actor, role, ip, correlation id, old/new snapshots from `AuditSnapshotProvider`).

**Money/qty**: `Money.of("12000.00")`, scale 2 HALF_UP; `Quantity` scale 3, KG step validation 0.250 from settings; never `double`.

**Config**: `application.yml` uses `${ENV}` placeholders only; profiles `dev` (adds `db/dev` Flyway location, CORS localhost), `prod`. Logging JSON lines (logback) with `correlationId`; daily rotation to `logs.directory`.

**Testing hooks**: `@DataJpaTest` rarely; prefer pure unit tests + `AbstractIntegrationTest` (Testcontainers Postgres, Flyway migrate, seeded dev data).
