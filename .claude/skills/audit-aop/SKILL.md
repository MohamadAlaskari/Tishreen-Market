---
name: audit-aop
description: How auditing works in Tishreen — the @Audited annotation, AuditAspect behaviour, the mandatory action list, old/new snapshot capture, correlation ids, and the read side (/admin/audit). Load when adding any sensitive operation or touching platform.audit.
user-invocable: false
---
# Append-only audit via AOP (normative: tishreen-handoff/tishreen-handoff/docs/05 §10, tishreen-handoff/tishreen-handoff/docs/09 §5)

```java
@Audited(action = AuditAction.UPDATE_PRICE, entity = "products", idParam = "productId")
public ProductDto updatePrice(long productId, Money newPrice) { … }
```
- `AuditAspect` (`@Around` on `@Audited`): resolves actor from `CurrentUser` (id, role), `ip` + `correlationId` from `RequestContext`, calls `AuditSnapshotProvider` for the entity **before** and **after** (JSON of the audited fields only — never password hashes, OTP hashes, tokens), writes one `audit_log` row after the method returns; on exception it writes nothing and rethrows. Runs in the same transaction (commit/rollback together).
- Mandatory actions (missing one = review blocker): `UPDATE_PRICE UPDATE_WEIGHT SEND_OTP CHANGE_ORDER_STATUS CANCEL_ORDER RECORD_PAYMENT ADJUST_POINTS SWITCH_PROVIDER UPDATE_SETTING BLOCK_USER CHANGE_ROLE STOCK_ADJUSTMENT ASSIGN_DRIVER`. Also recommended: `UPDATE_OFFER`, `UPDATE_ZONE`, `UPDATE_THEME`.
- `audit_log` is append-only: no JPA `save` on existing rows, DB role has no UPDATE/DELETE; retention is a business decision (never purge in v1).
- `correlation_id`: `X-Correlation-Id` header accepted from the web app (generated per page load) or created server-side; echoed in every response and log line; clickable in `/it/logs`, `/it/health`, `/admin/audit`.
- Read side: `GET /admin/audit?entityType&entityId&actorId&action&from&to&page` (AUDIT_VIEW, also IT); response rows show actor name, role, action, diff (old/new), time, correlation id. Indexes: `(entity_type, entity_id)`, `(created_at)`.
- Tests: `AuditAspectIT` asserts exactly one row per audited call with correct old/new; ArchUnit rule: every method named `updatePrice|updateWeight|changeStatus|cancel|recordPayment|adjustPoints|switchProvider|updateSetting|block|changeRole|adjustStock|assignDriver` in `application` packages is annotated `@Audited`.
