#!/usr/bin/env bash
# Shared helpers for Tishreen Claude Code hooks.
# Hooks receive a JSON payload on stdin: { tool_name, tool_input: { file_path, content|new_string|edits }, ... }

# UTF-8 locale so \x{0600}-\x{06FF} (Arabic) ranges work in grep -P on every machine.
export LC_ALL=C.UTF-8 LANG=C.UTF-8

hook_read_input() {
  HOOK_INPUT="$(cat)"
  export HOOK_INPUT
}

# Extract tool_input.file_path with jq → python3 → grep fallback.
hook_file_path() {
  local fp=""
  if command -v jq >/dev/null 2>&1; then
    fp="$(printf '%s' "$HOOK_INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    fp="$(printf '%s' "$HOOK_INPUT" | python3 -c 'import sys,json
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception:
    print("")' 2>/dev/null)"
  else
    fp="$(printf '%s' "$HOOK_INPUT" | grep -o '"file_path" *: *"[^"]*"' | head -1 | sed 's/.*: *"//; s/"$//')"
  fi
  printf '%s' "$fp"
}

# Print a violation line (file:line:text) to stderr.
hook_report() {
  printf '%s\n' "$1" >&2
}

# grep -nP wrapper that tolerates missing -P (BSD grep): falls back to -nE.
hook_grep() {
  local pattern="$1" file="$2"
  if grep -qP 'x' <<<'x' 2>/dev/null; then
    grep -nP -- "$pattern" "$file" 2>/dev/null
  else
    grep -nE -- "$pattern" "$file" 2>/dev/null
  fi
}
