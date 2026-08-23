# ADR-0010 — Cookie-less refresh-token variant for native clients (`X-Client: mobile`)

- **Status**: accepted
- **Date**: 2026-08-23
- **Deciders**: Mohamad (scope decision in ticket #19) + Claude Code session

## Context
ADR-0004 added the native customer app and stated that the mobile app "reuses the contracts from `06-api.md` 1:1 — no new backend, no schema changes, no new endpoints". The web auth contract, however, transports the refresh token in an HttpOnly browser cookie (`tishreen_rt`), which a React Native app cannot use — `06-api.md` already carried a forward note announcing that a cookie-less variant would be specified before mobile auth is implemented. Ticket #19 delivers that specification.

## Decision
Extend the existing auth endpoints instead of adding new ones: a client sending the header `X-Client: mobile` on `POST /auth/login` / `POST /auth/refresh` receives the refresh token in the **response body** (`refreshToken`, `refreshExpiresIn`) and no cookie; `POST /auth/refresh` accepts `{refreshToken}` in the body. Token format, 7-day lifetime, rotation on every refresh and the `pv` (password-version) claim are identical to the cookie variant — one issuer/validator, two transports. The native client stores the refresh token exclusively in Expo SecureStore, keeps the access token in memory, and never logs either. CORS is unaffected (native requests carry no `Origin`); `app.cors.origins` stays web-only. Normative contract: `06-api.md §1`; app-side rules: `14-mobile.md §5`; implementation task: `12-build-plan.md` M-T3.

## Consequences
- Amends ADR-0004's "contracts reused 1:1": the auth contract gains a second transport (no new endpoints, no schema change — everything else in ADR-0004 stands).
- Docs updated in the same PR: `06-api.md` (§1 native-clients block, §2 auth table, §12 CORS note), `14-mobile.md`, `12-build-plan.md` (M-T3 incl. backend tests).
- Security surface: no cookie ⇒ no CSRF concern for the native path; theft risk shifts to device storage, mitigated by SecureStore (Android Keystore) and unchanged rotation/`pv` invalidation. Web contract untouched.
- Rollback: remove the header branch — web clients never see the body variant, so nothing else changes.
