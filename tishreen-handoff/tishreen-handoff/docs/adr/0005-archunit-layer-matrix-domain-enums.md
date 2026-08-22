# ADR-0005 — ArchUnit layer dependency matrix and the domain-enum exception

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session 014f36db)

## Context
`docs/09-architecture.md` §2 fixes the internal module layout (`api / application / domain / dto /
infrastructure / events`) and the cross-module boundary rule, and `docs/13-quality.md` §2 lists the
ArchUnit checks — but neither pins down the intra-module dependency matrix, nor how DTOs and events
may expose a status without leaking entities: docs/09 places `OrderStatus (enum)` in `domain`, while
`OrderDto` lives in `dto` and other modules may never import `domain`. P1-T7 (#5) had to fix both to
write the rules.

## Decision
The ArchUnit tests (`api/src/test/java/com/tishreen/api/arch/`) enforce this matrix inside every
domain module (`identity catalog ordering delivery loyalty support inventory cms`):
`api → application, dto, events` · `application →` everything except `api` · `infrastructure →
domain, dto` · `dto`/`events` → shared types only · `domain` → nothing else in the module.
Sole exception: a module's own `api`, `dto` and `events` may reference its **domain enums**
(e.g. `OrderStatus`) — entities and everything else in `domain` never. The cross-module rule of
docs/09 §2 stays absolute (only `api`/`dto`/`events` and service interfaces are importable), so an
enum needed by another module must move to that module's `dto` or to `shared`. Provider rules bind
by fully qualified name (`platform.notification.NotificationChannel`, `platform.storage.ImageStorage`,
`platform.payment.PaymentProvider`, `platform.chatbot.ChatbotProvider`); all rules use
`allowEmptyShould(true)` so they are dormant on empty packages and bind with the first class.

## Consequences
- Docs updated: `docs/09-architecture.md` §2 (layering note under the boundary rule).
- Tests: `ModuleBoundaryRulesTest`, `ModuleLayeringRulesTest` run in `./mvnw verify`; an intentional
  violation fails the build (proven in #5).
- Later phases inherit the matrix; a DTO exposing a domain enum cross-module is a test failure by
  design and forces the enum into `dto`/`shared`.
- Rollback: the matrix lives in two test classes plus this note — a contained change.
