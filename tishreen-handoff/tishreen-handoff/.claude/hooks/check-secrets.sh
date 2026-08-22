#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit) — blocks writes that would leak secrets.
# Exit 2 = block the tool call and tell Claude why.
set -u
source "$(dirname "$0")/_lib.sh"
hook_read_input
FILE="$(hook_file_path)"
[ -z "$FILE" ] && exit 0

BASE="$(basename "$FILE")"
case "$BASE" in
  .env|.env.local|.env.development|.env.production|.env.staging)
    hook_report "Blocked: never write real environment files ($BASE). Edit .env.example with placeholder values and document the variable in docs/09-architecture.md."
    exit 2 ;;
esac

# Inspect the content being written (Write: content; Edit: new_string; MultiEdit: edits[].new_string)
CONTENT=""
if command -v jq >/dev/null 2>&1; then
  CONTENT="$(printf '%s' "$HOOK_INPUT" | jq -r '[.tool_input.content?, .tool_input.new_string?, (.tool_input.edits? // [] | .[]?.new_string?)] | map(select(. != null)) | join("\n")' 2>/dev/null)"
elif command -v python3 >/dev/null 2>&1; then
  CONTENT="$(printf '%s' "$HOOK_INPUT" | python3 -c 'import sys,json
d=json.load(sys.stdin).get("tool_input",{})
parts=[d.get("content"),d.get("new_string")]+[e.get("new_string") for e in d.get("edits",[]) or []]
print("\n".join(p for p in parts if p))' 2>/dev/null)"
fi
[ -z "$CONTENT" ] && exit 0
# .env.example holds placeholders by definition — no content scan
case "$BASE" in .env.example) exit 0 ;; esac

check() { # $1 label, $2 regex
  if printf '%s' "$CONTENT" | grep -qE -- "$2"; then
    hook_report "Blocked: $1 detected in content for $FILE. Use environment variables (see .env.example) — never commit secrets."
    FOUND=1
  fi
}
FOUND=0
check "AWS access key"            'AKIA[0-9A-Z]{16}'
check "private key block"         '-----BEGIN (RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----'
check "JWT token literal"         'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}'
check "hard-coded JWT/OTP secret" '(JWT_SECRET|JWT_REFRESH_SECRET|OTP_PEPPER|DB_PASSWORD|MINIO_SECRET_KEY)\s*=\s*[^$<{ ][A-Za-z0-9+/=_-]{7,}'
check "Telegram bot token"        '[0-9]{8,10}:[A-Za-z0-9_-]{35}'

if [ "$FOUND" -eq 1 ]; then exit 2; fi
exit 0
