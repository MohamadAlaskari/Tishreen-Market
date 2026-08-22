# مجمع تشرين — Claude Code / Cursor handoff package

Everything Claude Code needs to build the Tishreen platform (Arabic-first RTL grocery e-commerce for Aleppo): the complete specification, a validated database schema and seed, project memory, nine specialised subagents, nineteen skills and four guard hooks.

```
tishreen-handoff/
├─ CLAUDE.md                 ← project memory Claude Code loads every session
├─ README.md                 ← this file
├─ .env.example              ← all environment variables (placeholders)
├─ .gitignore
├─ docs/                     ← the specification (source of truth)
│  ├─ 00-overview.md         ← scope, roles, governing facts, stack, glossary, working agreements
│  ├─ 01-features.md         ← F-01 … F-64 with rules, data and acceptance criteria
│  ├─ 02-data-model.md       ← 34 tables, every column, constraint, index, decision
│  ├─ 03-schema.sql          ← validated DDL (→ V1__init_schema.sql)
│  ├─ 04-seed.sql            ← validated core seed (→ V2) + dev seed (→ db/dev/V900)
│  ├─ 05-business-rules.md   ← state machine, pricing, points, offers engine, OTP, WhatsApp, stock
│  ├─ 06-api.md              ← REST contract /api/v1 (auth, errors, every endpoint, DTOs)
│  ├─ 07-routes-screens.md   ← 49 routes, file tree, guards, per-screen spec, Figma node index
│  ├─ 08-design-system.md    ← tokens, the 3 audited themes, fonts, RTL rules (verified vs Figma)
│  ├─ 09-architecture.md     ← modular monolith, ports, providers, security, frontend, deploy
│  ├─ 10-i18n.md             ← key rules, formatters, message files
│  ├─ 11-syria-constraints.md← constraint → engineering consequence, pre-launch checklist
│  ├─ 12-build-plan.md       ← 6 phases × numbered tasks, branching, checklists, ADR policy
│  ├─ 13-quality.md          ← definition of done, named tests, review checklists
│  └─ adr/0000-template.md   ← record any deviation from the docs
├─ .claude/
│  ├─ settings.json          ← permissions (allow/deny) + hooks wiring
│  ├─ hooks/                 ← check-frontend-rules · check-backend-rules · check-secrets · session-start
│  ├─ agents/                ← architect · backend-dev · db-engineer · frontend-dev · test-engineer ·
│  │                            code-reviewer · rtl-i18n-reviewer · design-token-guardian ·
│  │                            security-reviewer · syria-constraints-reviewer
│  └─ skills/                ← knowledge: tishreen-domain · tishreen-schema · spring-modular-monolith ·
│                               order-lifecycle · offers-engine · whatsapp-notification · audit-aop ·
│                               tanstack-rtl-i18n · shadcn-tokens · driver-offline · testing
│                               workflows (slash commands): /new-module /new-migration /new-endpoint
│                               /new-route /review-rtl /review-tokens /phase /preflight
└─ .cursor/rules/            ← the same rules for Cursor's own agent (tishreen · frontend · backend)
```

## Install (5 minutes)
> **Note (ADR-0001):** implementation proceeds directly in the `Tishreen-Market` repository (this package stays in `tishreen-handoff/tishreen-handoff/` as the canonical source); steps 1–3 below describe the original standalone setup and are kept for reference.
1. Create the repository root `tishreen/` and copy **everything in this folder** into it (including the hidden `.claude/`, `.cursor/`, `.env.example`, `.gitignore`).
2. `chmod +x .claude/hooks/*.sh` (Linux/macOS/WSL). Hooks need `bash` and `grep -P`; `jq` or `python3` is used to parse hook input if present. On Windows run Claude Code inside WSL or Git Bash.
3. `git init && git add -A && git commit -m "chore: handoff package"`.
4. Open Claude Code in the folder (`claude`), or Cursor with the Claude Code extension. The `SessionStart` hook prints the orientation line; `CLAUDE.md` is loaded automatically.
5. First session: `/phase 1 start` → it lists Phase-1 tasks from `docs/12-build-plan.md` and creates the branch. Then `/phase 1 next` for each task.

## How to work
- **One task per session**, sized by `docs/12`. Say **«weiter» / «كمّل»** to move to the next task.
- Use the slash commands instead of free-form prompts when they fit: `/new-endpoint POST /orders`, `/new-route /staff/orders/:id`, `/new-migration add index …`, `/review-rtl`, `/review-tokens 8:5`, `/preflight` before every commit, `/phase n checklist` at the end of a phase.
- Reviewer agents are read-only; ask for them explicitly ("run security-reviewer on this diff") or let `/phase n checklist` fan them out.
- If Claude proposes something the docs do not say, it must tell you in two lines first; accept by asking for an ADR (`docs/adr/`).
- Keep `docs/` updated as the code evolves — the agents read them, not your memory.

## Verified on 2026-08-22
- DDL + seed executed on PostgreSQL 16: 34 tables, 5 roles, 35 permissions, 59 grants, 42 settings, 7 products, 6 users, stock ledger = cache.
- Figma file `0RLOI0q7lWCK1Rme8JjkKu`: 49 route frames found by name and id (docs/07 §10), component sets and Lucide icon set (65 names), text styles, the `tishreen/theme` collection (49 variables, six modes = three presets × light/dark) — all tokens in `docs/08` copied from the live values.
- Hooks tested against violating and clean sample files (frontend 10 violations detected / clean file passes; backend boundary, money, enum, date, logging, migration and config checks; secrets and `.env` writes blocked).

## Decisions confirmed by Mohamad (2026-08-22)
1. **Branding**: all 2026-08-20 changes were reverted on purpose. Final = «مجمع تشرين», rose preset (orange/sky remain selectable), no slogan yet.
2. **Fonts**: Tajawal for text; **Tufuli Arabic** for main headings. Tufuli is not in Figma (1,938 families checked) — the three heading styles now use **Baloo Bhaijaan 2** as the stand-in (applied in the file, cascades to every screen); code ships the same stand-in as fallback and has the Tufuli `@font-face` slot ready.
3. **Knowledge file**: `syria-store-data-model.html` in the project is v2.0; docs follow v2.1 (optional `addresses.latitude/longitude`, `orders.delivery_lat/lng`). Replace the project file when convenient.
