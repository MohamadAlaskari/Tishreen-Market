---
name: preflight
description: Pre-commit gate for Tishreen — runs hooks on changed files, typecheck/lint/tests for the touched workspaces, secret scan, doc-conformance grep (invented names), and prints a commit-ready summary.
argument-hint: [--quick]
disable-model-invocation: true
---
Run the pre-commit gate ($ARGUMENTS; `--quick` skips integration tests).

1. `git status --porcelain` and `git diff --name-only` → touched files; refuse to continue if `.env` or any file matching `*.pem|*.key|*secret*` is staged.
2. Hooks: pipe every changed file into `.claude/hooks/check-frontend-rules.sh` / `check-backend-rules.sh`; stop on violations.
3. Name conformance: extract identifiers used in the diff (table names in SQL/JPA, endpoint paths, route paths, permission codes, status strings, settings keys) and grep them in `docs/02`, `06`, `07`, `04`, `CLAUDE.md`; list any that do not appear ("invented name").
4. Workspaces: if `apps/web` or `packages/ui` changed → `pnpm -F web typecheck && pnpm lint && pnpm -F web test`; if `api/` changed → `./mvnw -q test` (`./mvnw -q verify` unless `--quick`).
5. Hygiene grep: `TODO: implement`, `console.log(`, `System.out`, `: any`, `@ts-ignore`, `printStackTrace`, `debugger`.
6. Docs: if schema/API/route behaviour changed, confirm the matching doc file is in the diff; otherwise flag.
7. Print a commit message proposal following `docs/12 §7` (`feat(ordering): …`, `fix(web): …`) and "gate: pass/fail".
