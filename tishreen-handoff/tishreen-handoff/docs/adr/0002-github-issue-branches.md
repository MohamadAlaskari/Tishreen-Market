# ADR-0002 — GitHub issue branches off `main` instead of phase/feat hierarchy

- **Status**: accepted
- **Date**: 2026-08-22
- **Deciders**: Mohamad (+ Claude Code session 449aec6a)

## Context
`docs/12-build-plan.md` prescribes the branching model `main` (protected) ← `phase/<n>-<slug>` ← `feat/<task-id>-<slug>`. For ticket #2 the owner created the branch directly from the GitHub issue ("create a branch for this issue"), producing `2-chorerepo-scaffold-monorepo-workspace-p1-t1` off `main`. Issue-linked branches keep ticket ↔ branch ↔ PR wired automatically: merging the PR closes the ticket, which drives the `ticket` skill's unblock step for dependent tickets.

## Decision
Work happens on **GitHub issue branches created from the ticket** (`<n>-<slug>`, base `main`); one branch and one PR per ticket, PR base `main`. The intermediate `phase/<n>-<slug>` collector branches from `docs/12` are dropped. Conventional commit format and the one-task-per-session rule from `docs/12` remain unchanged.

## Consequences
- Docs updated: `docs/12-build-plan.md` §Branching line.
- Merging a ticket PR auto-closes the issue; the `ticket` skill then updates `Blocked by:`/`Blocks:` mirrors and the `blocked` label on dependents.
- Phase completion is tracked by the phase checklist in `docs/12` and the `phase-<n>` issue label instead of a phase branch.
- Risk: `main` receives task-sized merges instead of phase-sized ones — acceptable while CI (#6) gates every PR; revisit if a release branch becomes necessary.
