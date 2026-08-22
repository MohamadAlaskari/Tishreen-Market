#!/usr/bin/env bash
# Claude Code PostToolUse-Hook: erinnert daran, dass die editierte Datei ins
# GitHub-Wiki (Tishreen-Market.wiki) gespiegelt wird und ein Sync fällig ist.
set -uo pipefail
payload="$(cat)"

if command -v jq >/dev/null 2>&1; then
  f="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
else
  f="$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -z "${f:-}" ] && exit 0

f="${f//\\//}"   # Windows-Backslashes normalisieren
case "$f" in
  */tishreen-handoff/tishreen-handoff/docs/* \
  | */tishreen-handoff/tishreen-handoff/CLAUDE.md \
  | */tishreen-handoff/tishreen-handoff/README.md \
  | */.cursor/rules/* \
  | .cursor/rules/*)
    echo "WIKI-SYNC NÖTIG: '$f' wird ins GitHub-Wiki gespiegelt. Nach Commit+Push auf main synchronisiert die GitHub-Action automatisch; für sofortigen Sync: bash scripts/sync-wiki.sh --push" >&2
    exit 2
    ;;
esac
exit 0
