# ADR-0007 — CI hardening and scope (SonarCloud, SHA pinning, web-only)

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session c267f784)

## Context
`docs/12-build-plan.md` P1-T8 fixes only the CI scope — "pnpm lint/typecheck/test/build; `./mvnw`
verify with Testcontainers; artifact upload" — and says nothing about static analysis, supply-chain
hardening, the Node version source, or `apps/mobile` (added later by ADR-0004). While closing #6,
SonarCloud flagged S7637 (unpinned third-party action) and S6505 (lifecycle scripts on install), and
the runner deprecated the Node-20 action majors; the decisions taken there were recorded nowhere.
Backfilled from the 2026-08-22 docs audit (#18).

## Decision
`.github/workflows/ci.yml` (P1-T8, #6) is hardened and scoped as follows.
(1) **SonarCloud** automatic analysis runs on every PR as the check `SonarCloud Code Analysis`; its
findings are treated as merge-blocking by working agreement — `main` has **no** branch protection, so
the gate is the Definition of Done (`13 §1`) and review practice, not a technical block.
(2) **Third-party actions are pinned to a full commit SHA** (`pnpm/action-setup@b906aff…` # v4, per
S7637); GitHub-maintained actions ride their major tags (`actions/*@v5`).
(3) Install is `pnpm install --frozen-lockfile --ignore-scripts` (per S6505; esbuild/lightningcss ship
their binaries as `optionalDependencies`, lifecycle scripts are unnecessary).
(4) The workflow token is limited to `permissions: contents: read`.
(5) Versions have single sources: Node 24 via `.nvmrc` (`node-version-file`), pnpm via the root
`packageManager` field — nothing hard-coded in the workflow.
(6) The web job runs `pnpm turbo run <task> --filter=web`: `apps/mobile` is deliberately **not** in CI
yet — a transitional decision, tracked as #20 (`ci(mobile)`).

## Consequences
- Docs updated: `13 §1` (Definition of Done gains the green-checks item), `12` P1-T8 references this ADR.
- Risk: without branch protection nothing technically prevents merging red; mitigation is DoD +
  review. Enable branch protection once more than one person merges.
- The mobile gap is visible and time-boxed (#20); until it lands, `apps/mobile` can break on `main`
  without a red check.
- Every new third-party action must follow the SHA-pinning rule; SHA bumps update the trailing
  version comment.
