# ADR-0004 — Add a native mobile app (`apps/mobile`, Expo) alongside the web PWA

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session)

## Context
`00-overview.md` §1/§4 and `12-build-plan.md` define a web-only frontend: one TanStack Start web app, mobile-first, with the driver area shipped as an installable PWA (`vite-plugin-pwa`; see `09-architecture.md` offline section and `11-syria-constraints.md`). Mohamad decided on 2026-08-22 that the project should additionally ship a **native mobile app**. The documented web-only decision is therefore extended — not replaced: the web app **stays a PWA** (including the driver offline shell).

## Decision
Add a third workspace `apps/mobile` to the existing pnpm + Turborepo monorepo (`apps/web`, `apps/mobile`, `packages/ui`), built with **Expo SDK 57** (React Native 0.86, React 19, TypeScript strict, managed workflow, New Architecture). The app is a pure client of the existing REST API `/api/v1` — no new backend, no schema changes, no new endpoints. Arabic-first/RTL and i18n rules apply unchanged (i18next + react-i18next, `ar.json` default, `en.json` optional with Arabic fallback; RTL via `expo-localization` `supportsRTL`). `packages/ui` stays web-only (shadcn/DOM) and is **not** consumed by the mobile app. Mobile feature scope is cut into tickets per feature after the corresponding web phase; contracts from `06-api.md` are reused 1:1.

## Consequences
- Docs updated: `00-overview.md` §1 + §4 (roles intro, tech stack, workspace list), `12-build-plan.md` (new "Mobile track" section), handoff `CLAUDE.md` (stack).
- Migrations / API / i18n keys added: none — mobile i18n resources live in `apps/mobile` and follow `10-i18n.md` conventions.
- Risks / Syria constraints: app distribution must not depend on blocked US services — Google Play availability in Syria varies, so plan APK sideload distribution from the website as fallback; no external runtime CDNs, all assets bundled (rule 12). pnpm isolated `node_modules` are supported from Expo SDK 54; if a native build or library resolution breaks, the documented fallback is `node-linker=hoisted` in the root `.npmrc`.
- Rollback: remove the `apps/mobile` workspace — no other package depends on it; web and API are unaffected.
