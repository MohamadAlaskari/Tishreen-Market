---
name: review-rtl
description: Run the RTL + i18n review on the current diff (or given paths) using the rtl-i18n-reviewer agent and the frontend hook; prints a findings table and a go/no-go.
argument-hint: [paths…] (default: git diff against main)
disable-model-invocation: true
---
Run an RTL/i18n review for: **$ARGUMENTS** (empty = `git diff --name-only main...HEAD` filtered to `apps/web` and `packages/ui`).

1. For each file run `printf '{"tool_input":{"file_path":"<path>"}}' | bash .claude/hooks/check-frontend-rules.sh` and collect violations.
2. Delegate the deep review to the `rtl-i18n-reviewer` subagent with the same file list; merge its table with the hook output (dedupe by file:line).
3. Check `ar.json`/`en.json` parity and that every order/user/ticket status and every API error code has a key.
4. Print: findings table (severity, file:line, problem, fix) → summary → "RTL sign-off: yes/no". Do not fix anything unless the user asks in the next message.
