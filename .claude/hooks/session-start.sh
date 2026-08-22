#!/usr/bin/env bash
# SessionStart hook — stdout is added to Claude's context.
cat <<'EOF'
Tishreen Mall session. Docs are the spec (tishreen-handoff/tishreen-handoff/docs/00..13). Workflow skills: /phase <n>, /new-module, /new-migration, /new-endpoint, /new-route, /review-rtl, /review-tokens, /preflight, /ticket.
Reviewer agents: architect, code-reviewer, rtl-i18n-reviewer, design-token-guardian, security-reviewer, syria-constraints-reviewer, test-engineer.
Tooling: pnpm workspace + Turborepo (pnpm -F web ...); API builds from the repo root via api/mvnw -f api ...; local stack (DB in Docker) via ./tishreen.ps1 -Mode dev|nearprod|prod, never a bare "docker compose up".
Rules that hooks enforce: logical CSS only, token colours only, i18n keys only, no CDNs, BigDecimal money, module boundaries, no secrets.
EOF
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Branch: $(git branch --show-current 2>/dev/null) · last commit: $(git log -1 --pretty=%s 2>/dev/null)"
fi
exit 0
