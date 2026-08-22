# ADR-0008 — Wiki mirror as the authoritative reference (`sync-wiki`)

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session c267f784)

## Context
The canonical docs live in `tishreen-handoff/tishreen-handoff/` (`docs/00…13`, ADRs, rules), a nested
path that is hard to browse on GitHub, where tickets, reviews and day-to-day reading happen. No doc
fixed where the always-current, readable reference lives and how it is produced — the mechanism
existed (`scripts/sync-wiki.sh` + Action) but was undocumented. Backfilled from the 2026-08-22 docs
audit (#18).

## Decision
The GitHub wiki of `MohamadAlaskari/Tishreen-Market` is the **authoritative reference view**; the
repo files remain the **source of truth**. `scripts/sync-wiki.sh` generates every wiki page from the
sources: docs `00…13` (page per file), `03-schema.sql`/`04-seed.sql` (as fenced SQL pages), **all**
ADRs (`adr-NNNN-*` pages — new ADRs appear automatically), project rules
(`tishreen-handoff/tishreen-handoff/CLAUDE.md` → `Rules`), editor rules (`.cursor/rules/*.mdc` →
`Editor-Rules`), plus generated `Home`, `_Sidebar` and `_Footer`. The GitHub Action `sync-wiki` runs
it on every push to `main` that touches those paths (and on `workflow_dispatch`);
`bash scripts/sync-wiki.sh --push` does the same locally. Every page carries an auto-generated banner
naming its source file; the wiki is **never edited directly** — manual wiki edits are overwritten by
the next sync. Limits: `.claude/` (skills, agents, hooks) is deliberately not mirrored — it is
Claude-Code-internal tooling, not specification.

## Consequences
- Recording a decision = adding the ADR under `docs/adr/` and updating the affected doc in the same
  PR (`12` §Deviations policy); the wiki follows on merge with no extra step.
- The rule "never edit the wiki directly" is anchored in the root `CLAUDE.md` workspace rules.
- Risk: the wiki lags until the next push to `main`; on any conflict the repo wins by construction.
- Rollback: disable the Action — the wiki freezes at its last state, the sources stay complete.
