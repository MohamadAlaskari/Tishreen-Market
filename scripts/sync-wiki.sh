#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Spiegelt die kanonischen Tishreen-Dokumente & -Regeln ins GitHub-Wiki.
#
#   bash scripts/sync-wiki.sh <wiki-dir>   # Seiten in eine geklonte Wiki-Arbeitskopie generieren (CI)
#   bash scripts/sync-wiki.sh --push       # klonen + generieren + committen + pushen (lokal)
#
# Quelle der Wahrheit: tishreen-handoff/tishreen-handoff/  (docs/, CLAUDE.md, README.md, .cursor/rules/)
# Wiki:                https://github.com/MohamadAlaskari/Tishreen-Market/wiki
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/tishreen-handoff/tishreen-handoff"
SRC_REL="tishreen-handoff/tishreen-handoff"
REPO_URL="https://github.com/MohamadAlaskari/Tishreen-Market"
WIKI_URL="$REPO_URL.wiki.git"

if [ "${1:-}" = "--push" ]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  git clone --quiet "$WIKI_URL" "$TMP/wiki"
  bash "${BASH_SOURCE[0]}" "$TMP/wiki"
  cd "$TMP/wiki"
  git add -A
  if git diff --cached --quiet; then
    echo "Wiki ist bereits aktuell — nichts zu tun."
  else
    git commit -q -m "docs: sync wiki from $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)"
    git push -q
    echo "Wiki aktualisiert: $REPO_URL/wiki"
  fi
  exit 0
fi

WIKI="${1:?Usage: sync-wiki.sh <wiki-dir> | --push}"
[ -d "$WIKI" ] || { echo "Wiki-Verzeichnis '$WIKI' existiert nicht." >&2; exit 1; }
[ -d "$SRC/docs" ] || { echo "Quelle '$SRC/docs' fehlt." >&2; exit 1; }

note() { # $1 = Quellpfad relativ zum Repo
  printf '> ⚙️ **Automatisch generiert** aus [`%s`](%s/blob/main/%s) — Änderungen bitte dort machen, nicht im Wiki.\n\n' "$1" "$REPO_URL" "$1"
}

md_page() { # $1 = Quelldatei, $2 = Wiki-Seitenname
  { note "$SRC_REL/${1#"$SRC/"}"; cat "$1"; } > "$WIKI/$2"
  echo "  → $2"
}

sql_page() { # $1 = Quelldatei, $2 = Wiki-Seitenname
  { note "$SRC_REL/${1#"$SRC/"}"; printf '```sql\n'; cat "$1"; printf '\n```\n'; } > "$WIKI/$2"
  echo "  → $2"
}

echo "Generiere Wiki-Seiten aus $SRC_REL/ …"

# Spezifikation docs/00…13
for f in "$SRC"/docs/*.md; do
  md_page "$f" "$(basename "$f")"
done
sql_page "$SRC/docs/03-schema.sql" "03-schema-sql.md"
sql_page "$SRC/docs/04-seed.sql"  "04-seed-sql.md"

# Entscheidungen: ALLE ADRs spiegeln (neue Entscheidungen landen automatisch im Wiki)
for f in "$SRC"/docs/adr/*.md; do
  md_page "$f" "adr-$(basename "$f")"
done

# Projektregeln (Claude Code Projektgedächtnis)
md_page "$SRC/CLAUDE.md" "Rules.md"

# Editor-Regeln (.cursor) — als eine Seite gebündelt
{
  note "$SRC_REL/.cursor/rules/"
  printf '# Editor-Regeln (Cursor)\n\nDieselben Regeln, die Claude Code über `CLAUDE.md` und die Hooks erzwingt — als `.mdc`-Dateien für Cursors eigenen Agenten.\n'
  for f in "$SRC"/.cursor/rules/*.mdc; do
    printf '\n## `%s`\n\n````markdown\n' "$(basename "$f")"
    cat "$f"
    printf '\n````\n'
  done
} > "$WIKI/Editor-Rules.md"
echo "  → Editor-Rules.md"

# Home = Index + README des Handoff-Pakets
{
  note "$SRC_REL/README.md"
  printf '# مجمع تشرين · Tishreen Market — Dokumentation\n\n'
  printf '**Regeln:** [[Rules]] · [[Editor-Rules]]\n\n'
  printf '**Spezifikation:** [[00-overview]] · [[01-features]] · [[02-data-model]] · [[03-schema-sql]] · [[04-seed-sql]] · [[05-business-rules]] · [[06-api]] · [[07-routes-screens]] · [[08-design-system]] · [[09-architecture]] · [[10-i18n]] · [[11-syria-constraints]] · [[12-build-plan]] · [[13-quality]] · [[adr-0000-template]]\n\n---\n\n'
  cat "$SRC/README.md"
} > "$WIKI/Home.md"
echo "  → Home.md"

cat > "$WIKI/_Sidebar.md" <<'EOF'
**مجمع تشرين · Tishreen**

- [[Home]]
- [[Rules]]
- [[Editor-Rules]]

**Spezifikation**

- [[00-overview]]
- [[01-features]]
- [[02-data-model]]
- [[03-schema-sql]]
- [[04-seed-sql]]
- [[05-business-rules]]
- [[06-api]]
- [[07-routes-screens]]
- [[08-design-system]]
- [[09-architecture]]
- [[10-i18n]]
- [[11-syria-constraints]]
- [[12-build-plan]]
- [[13-quality]]
EOF
{
  printf '\n**Entscheidungen (ADR)**\n\n'
  for f in "$SRC"/docs/adr/*.md; do
    printf -- '- [[adr-%s]]\n' "$(basename "$f" .md)"
  done
} >> "$WIKI/_Sidebar.md"
echo "  → _Sidebar.md"

cat > "$WIKI/_Footer.md" <<EOF
Automatisch synchronisiert aus [\`$SRC_REL/\`]($REPO_URL/tree/main/$SRC_REL) — Änderungen im Repo machen, nicht im Wiki. Sync: \`scripts/sync-wiki.sh\` + GitHub Action \`sync-wiki\`.
EOF
echo "  → _Footer.md"

echo "Fertig."
