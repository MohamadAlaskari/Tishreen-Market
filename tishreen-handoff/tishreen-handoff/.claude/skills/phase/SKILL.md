---
name: phase
description: Start or resume a build phase (1–6) of Tishreen — loads the phase tasks from docs/12-build-plan.md, checks what is already done in the repo, proposes the next task, and at the end runs the phase checklist and the reviewer agents.
argument-hint: <1-6> [start|next|checklist]
disable-model-invocation: true
---
Phase command: **$ARGUMENTS** (format `<n> [start|next|checklist]`, default `next`).

- `start`: read the phase section in `docs/12-build-plan.md`, list its tasks (`P<n>-T<k>`), scan the repo (`git log`, existing files) to mark which are done, create the branch `phase-<n>/<slug>` if it does not exist, and present the ordered task list. Do not implement yet.
- `next`: pick the first unfinished task, restate its acceptance criteria from `docs/12` and the referenced feature ids, then implement it via the right skill (`/new-migration`, `/new-endpoint`, `/new-route`, `/new-module`) — one task per session, stop for review when done, with the test output pasted.
- `checklist`: run the phase checklist from `docs/12` (build, typecheck, `./mvnw -q verify`, `pnpm -F web test`, e2e when applicable), then delegate in parallel to `code-reviewer`, `security-reviewer`, `syria-constraints-reviewer` and, for UI phases, `rtl-i18n-reviewer` + `design-token-guardian`; summarise blockers and produce the phase exit note for the commit message.

Always answer in the user's language; keep the plan numbered and short; never skip a task silently — mark it "deferred" with a reason.
