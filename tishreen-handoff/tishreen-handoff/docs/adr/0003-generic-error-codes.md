# ADR-0003 — Generic error codes for framework-level failures

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session 280e1f74)

## Context
`docs/06-api.md` §Errors fixes the error body shape and names business codes (`ORDER_INVALID_TRANSITION`,
`STORE_CLOSED`, …) but defines no codes for failures that are not a business rule: bean validation, malformed
JSON, unknown route, wrong HTTP method, unexpected exceptions. The `GlobalExceptionHandler` built in P1-T5 (#3)
needs stable codes for these cases; leaving them unnamed would make every later ticket mint its own.

## Decision
The `shared.GlobalExceptionHandler` uses these generic codes, message keys identical to the code in
`messages_ar/_en.properties`: `VALIDATION_FAILED` (400, bean validation and malformed JSON body, field errors in
`details.fields[{field, code}]`), `NOT_FOUND` (404, unknown route), `METHOD_NOT_ALLOWED` (405),
`INTERNAL_ERROR` (500, never leaks the exception). A `ResponseStatusException` passes its status through with
`HttpStatus.name()` as code. Codes without a bundle entry fall back to the localized generic sentence
`REQUEST_FAILED` — the raw code is never shown as a message. Business codes from docs/06 are unaffected.

## Consequences
- Docs updated: `docs/06-api.md` §Errors (generic-codes note under the table).
- i18n keys added: `VALIDATION_FAILED`, `NOT_FOUND`, `METHOD_NOT_ALLOWED`, `INTERNAL_ERROR`, `REQUEST_FAILED` in `messages_ar/_en.properties` (+ base `messages.properties` = Arabic).
- Later tickets must reuse these codes instead of inventing parallel ones; frontend error→i18n mapping can rely on them.
- Rollback: codes live in one class and the bundles; renaming is a contained change while no client depends on them.
