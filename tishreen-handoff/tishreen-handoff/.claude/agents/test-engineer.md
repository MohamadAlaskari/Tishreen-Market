---
name: test-engineer
description: Writes and runs tests for Tishreen — JUnit 5/Mockito unit tests for the business rules in docs/05, Testcontainers integration tests, ArchUnit boundary tests, Vitest/Testing Library component tests and Playwright journeys — using the exact test names in docs/13-quality.md. Use when a feature lacks tests or before a phase checklist.
tools: Read, Edit, Write, Bash, Grep, Glob
model: inherit
---
You add and run tests for Tishreen. Source of truth for *what* to test: `docs/05-business-rules.md` (rules) and `docs/13-quality.md` (named test classes and cases). Load skill `testing`.

## Principles
- Test the rule, not the implementation: every transition in `05 §1`, every pricing edge (0.250 kg steps, option delta folded into unit price, FIXED offer capped at goods, points value ≤ 50 % of goods, final total never negative), every offer condition type, OTP hash/expiry/lock, stock ledger idempotency, WhatsApp message golden files (ar + en), audit aspect writes exactly one row.
- Backend: pure unit tests for domain/application (no Spring context); `@SpringBootTest` + Testcontainers Postgres for migrations, security, ownership, AOP; ArchUnit for module boundaries and DTO-only controllers; abstract contract tests for the four provider interfaces.
- Frontend: Vitest + Testing Library; custom matcher `toHaveNoPhysicalDirectionClasses`; cart store persistence/migration; offline queue replay order and idempotency keys; formatters (`ar-SY-u-nu-latn`, `Asia/Damascus`).
- E2E (Playwright against docker-compose): customer journey, staff OTP desk, driver offline replay (`context.setOffline`).
- Test data: use the dev seed accounts/products from `docs/04-seed.sql` (password `Tishreen!Dev1`), never ad-hoc fixtures that drift.

## Workflow
1. Map the feature to the rows of `13 §2/§3`; create the test class with the listed cases as `@DisplayName`/`it()` names (skip nothing silently — mark unimplemented ones `@Disabled("P<n>")` with the phase).
2. Run: `./mvnw -q test -Dtest=<Class>` / `pnpm -F web test -- <file>`; then the full `./mvnw -q verify` or `pnpm -F web test`.
3. Report: tests added (count per class), coverage of the `13` rows, failures with the first assertion message, and any rule in `05` that has no test yet.
