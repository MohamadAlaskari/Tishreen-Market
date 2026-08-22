# ADR-0001 — Implementation lives in the Tishreen-Market repository

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session 449aec6a)

## Context
`README.md` §Install describes copying this handoff package into a fresh repository root `tishreen/` and starting there. In practice the owner set up `MohamadAlaskari/Tishreen-Market` as the working repository: it already carries the handoff package, the GitHub wiki (mirrored from these docs via `scripts/sync-wiki.sh` + the `sync-wiki` Action), the issue tracker with the dependency-tracked tickets, and the `ticket` skill. Splitting implementation into a second repository would disconnect code from tickets, wiki and CI.

## Decision
The application is implemented **inside `MohamadAlaskari/Tishreen-Market`**, at the repository root, following the layout of `docs/09-architecture.md` §1 (`apps/web`, `packages/ui`, `api/`, `infra/`). The handoff package stays in `tishreen-handoff/tishreen-handoff/` as the canonical docs/rules source; no separate `tishreen/` repository is created. Started with ticket #2 (P1-T1 monorepo scaffold, PR #7).

## Consequences
- Docs updated: `README.md` §Install (note pointing here).
- Wiki, tickets, CI and code share one repository; the `sync-wiki` Action keeps the wiki current on every push to `main`.
- The duplicate doc copies at the repo root (`README.md`, `08-design-system.md`, `tishreen-mall-docs/`) remain redundant and can be removed in a later cleanup ticket.
- Rollback: copy `tishreen-handoff/tishreen-handoff/` plus `apps/ packages/ api/ infra/` into a fresh repo and re-point `origin`.
