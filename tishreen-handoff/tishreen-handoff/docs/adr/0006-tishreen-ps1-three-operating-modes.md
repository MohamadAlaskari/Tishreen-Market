# ADR-0006 — `tishreen.ps1` control script and one database per operating mode

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session c267f784)

## Context
`docs/00-overview.md` §4 (Infra) and `docs/12-build-plan.md` P1-T5 originally specified a single
`infra/docker-compose.yml` with one local Postgres and no notion of operating modes, while
`docs/09-architecture.md` §5 fixes the target deployment as nginx + systemd — not containers. During
#11 the single-database setup proved insufficient: a built jar and the `prod` profile must be testable
locally without touching dev data (dev seed `V900` vs a clean `V1`/`V2` database), and a fresh start
required several manual steps whose failures surfaced as unreadable Compose/Maven errors. Decided by
Mohamad on 2026-08-22 as a scope extension of #11 (model: the proven `eportfolio.ps1` menu script);
recorded retroactively by the 2026-08-22 docs audit (#18). The docs were realigned in #17 (PR #27).

## Decision
`tishreen.ps1` (repo root; Windows PowerShell 5.1 **and** PowerShell 7) is the single entry point to
the local stack; a bare `docker compose up` fails on purpose because there is no default compose file.
Three operating modes map to three separate Compose projects — `tishreen-dev`, `tishreen-nearprod`,
`tishreen-prod`, each `infra/compose.base.yml` + exactly one overlay `compose.{dev,nearprod,prod}.yml`
— with their own volumes and ports (Postgres `5432`/`5532`/`5632`, API `8080`/`8180`/`8280`, web
`3000`/`3100`/`3200`; overridable via `infra/.env`). They can run side by side and share no database.
Docker runs only Postgres; API and web run on the host. Mode semantics: `dev` = source run
(`spring-boot:run` + Vite dev server, profile `dev`) · `nearprod` = built jar + `vite preview` **still
on profile `dev`** — it validates the deliverable, not the production configuration · `prod` = the
same jar on profile `prod` against its own clean database (Flyway `V1`/`V2` only, no Swagger, no dev
seed). The script passes each mode's database to the API env-first (`DB_URL`/`DB_USER`/`DB_PASSWORD`);
the old `infra/docker-compose.yml` was removed.

## Consequences
- Docs updated: `00 §4` (Infra), `09 §4` (entry point + port table), `12` P1-T5 — realigned in #17/PR #27.
- CI is unaffected: Testcontainers starts its own Postgres; `tishreen.ps1 -Check` is the
  non-interactive prerequisites probe.
- The script is interactive by design and its text is ASCII-only (PS 5.1 reads UTF-8 without BOM as
  ANSI); automation uses the manual equivalents documented in `09 §4`.
- Rollback: remove the script and the `nearprod`/`prod` overlays — `compose.base.yml` +
  `compose.dev.yml` alone restore a single-database workflow.
