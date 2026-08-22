#!/usr/bin/env bash
# SessionStart hook — stdout is added to Claude's context.
cat <<'EOF'
Tishreen Mall session. Docs are the spec (docs/00..13). Workflow skills: /phase <n>, /new-module, /new-migration, /new-endpoint, /new-route, /review-rtl, /review-tokens, /preflight.
Reviewer agents: architect, code-reviewer, rtl-i18n-reviewer, design-token-guardian, security-reviewer, syria-constraints-reviewer, test-engineer.
Rules that hooks enforce: logical CSS only, token colours only, i18n keys only, no CDNs, BigDecimal money, module boundaries, no secrets.
EOF
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Branch: $(git branch --show-current 2>/dev/null) · last commit: $(git log -1 --pretty=%s 2>/dev/null)"
fi
exit 0
