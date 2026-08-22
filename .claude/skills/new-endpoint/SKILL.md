---
name: new-endpoint
description: Implement one REST endpoint of Tishreen end-to-end from its row in tishreen-handoff/tishreen-handoff/docs/06-api.md — DTOs, service, security, audit, messages, tests, docs.
argument-hint: <METHOD /api/v1/path> e.g. "POST /orders/{id}/cancel"
disable-model-invocation: true
---
Implement the endpoint **$ARGUMENTS** exactly as specified in `tishreen-handoff/tishreen-handoff/docs/06-api.md` (find its row; if it is not there, stop and propose the row first).

Open questions first: if the spec leaves a product, scope or architecture question open (ambiguous requirement, docs silent or contradictory, several sensible options), ask Mohamad — short options + a recommendation — and implement only after the answer.

Checklist (do all, in order):
1. Permission from the row → `@PreAuthorize("hasAuthority('…')")`; customer/driver endpoints add the ownership check in the service (404 on mismatch).
2. Request/response DTO records in `<module>/dto` matching the TS shapes in `tishreen-handoff/tishreen-handoff/docs/06 §11`; `@Valid` constraints; `Money` as string with 2 decimals, quantities 3 decimals.
3. Service method in `application` with `@Transactional`, locking for state changes, rule implementation from `tishreen-handoff/tishreen-handoff/docs/05` (load `order-lifecycle` / `offers-engine` skill as relevant), `@Audited` if the action is in the mandatory list, `Idempotency-Key` handling if the row says so.
4. Error codes from `tishreen-handoff/tishreen-handoff/docs/06 §2` via `BusinessException`; add `messages_ar.properties` + `messages_en.properties` entries.
5. Tests: unit test for the rule (`tishreen-handoff/tishreen-handoff/docs/13 §2` names) + `MockMvc` integration test covering 200/201, 400 validation, 403/404 authorization, 409/422 business cases.
6. springdoc annotations (`@Operation`, `@ApiResponse`) so the OpenAPI file regenerates; run `api/mvnw -f api -q verify`.
7. Report: files, test names, audit action, side-effects, doc rows touched.
