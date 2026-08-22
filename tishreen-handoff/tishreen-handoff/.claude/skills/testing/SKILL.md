---
name: testing
description: Testing toolkit and conventions for Tishreen — JUnit 5/Mockito unit tests, Testcontainers integration base class, ArchUnit rules, provider contract tests, Vitest/Testing Library setup with the RTL matcher, Playwright journeys, dev seed accounts. Load before writing or running tests.
user-invocable: false
---
# Testing conventions (test names and cases: docs/13-quality.md)

**Backend**
- Unit (`src/test/java/.../domain|application`): plain JUnit 5 + AssertJ + Mockito; no Spring context; `Clock` injected (fixed `2026-08-22T10:00+03:00`); settings via an in-memory `SettingsReader` stub.
- Integration: `AbstractIntegrationTest` (`@SpringBootTest`, `@Testcontainers`, `PostgreSQLContainer("postgres:15")`, Flyway applies `db/migration` + `db/dev`, `@DynamicPropertySource` wires the URL); `MockMvc` + helper `asUser(phone)` issuing a real JWT for dev accounts (`+963911000001` admin … `+963911000006` pending customer, password `Tishreen!Dev1`).
- ArchUnit (`ArchitectureTest`): module boundary rules, `platform`-only SDK imports, controllers return DTOs, domain free of Spring/JPA annotations except `jakarta.persistence` in `domain.model`, no `java.util.Date`/`double` in `domain`/`dto`.
- Provider contracts: `abstract class NotificationChannelContractTest { abstract NotificationChannel subject(); }` + one concrete subclass per implementation.
- Run: `./mvnw -q test -Dtest=<Class>`; full `./mvnw -q verify` (unit + IT + ArchUnit). Paste real output.

**Frontend**
- Vitest + `@testing-library/react` + `jest-dom`; `setupTests.ts` registers `i18n` with `ar` test resources and the custom matcher `toHaveNoPhysicalDirectionClasses(el)` (greps `className` for `ml- mr- pl- pr- left- right- text-left text-right rounded-l rounded-r border-l border-r`).
- Render helper `renderRtl(ui, {dir:'rtl'|'ltr', theme:'rose'})` wrapping QueryClient, router memory history, i18n.
- API mocked with `msw` handlers per feature (`src/test/handlers/*.ts`) returning DTO shapes from docs/06.
- Run: `pnpm -F web test` / `pnpm -F web test -- <file>`; E2E `pnpm -F web e2e` (Playwright, needs `docker compose up`).

**Journeys (Playwright)**: `customer-order.spec.ts` (register → activate via staff OTP → cart → checkout quote → order → staff confirm/weigh/finalize/ready → pickup → points), `driver-offline.spec.ts`, `staff-otp-desk.spec.ts`, `admin-offer-builder.spec.ts`.

**Definition of done**: tests exist for every rule touched, run green locally, named exactly as in docs/13, no `@Disabled` without a phase tag.
