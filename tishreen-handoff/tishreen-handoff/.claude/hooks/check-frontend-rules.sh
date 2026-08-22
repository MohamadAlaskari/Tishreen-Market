#!/usr/bin/env bash
# PostToolUse hook (Write|Edit|MultiEdit) — frontend rules for apps/web and packages/ui.
# Exit 2 = report violations back to Claude (the edit already happened; Claude must fix it).
set -u
source "$(dirname "$0")/_lib.sh"
hook_read_input
FILE="$(hook_file_path)"
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

case "$FILE" in
  */apps/web/*|*/packages/ui/*|apps/web/*|packages/ui/*) ;;
  *) exit 0 ;;
esac
case "$FILE" in
  *.tsx|*.ts|*.jsx|*.js|*.css|*.mjs) ;;
  *) exit 0 ;;
esac
# Skip generated / locale / config files
case "$FILE" in
  */locales/*|*/routeTree.gen.ts|*/types.ts|*.d.ts|*/node_modules/*|*/dist/*) exit 0 ;;
esac

VIOLATIONS=0
report() { VIOLATIONS=$((VIOLATIONS+1)); hook_report "  $1"; }

scan() { # $1 = label, $2 = perl regex
  local out
  out="$(hook_grep "$2" "$FILE")"
  if [ -n "$out" ]; then
    hook_report "[$1]"
    while IFS= read -r line; do report "$FILE:$line"; done <<<"$out"
  fi
}

IS_GLOBALS=0
case "$FILE" in */globals.css) IS_GLOBALS=1 ;; esac

# ---- 1. RTL: physical direction utilities ---------------------------------------------
scan "RTL: use logical utilities (ms-/me-/ps-/pe-/start-/end-/text-start/text-end/rounded-s-/rounded-e-/border-s/border-e)" \
  '(?<![\w-])-?(ml|mr|pl|pr|left|right|inset-l|inset-r|scroll-ml|scroll-mr|scroll-pl|scroll-pr)-(?!auto-rtl)[\w\[\]%./-]+|(?<![\w-])(rounded|border)-(l|r)(?![\w])|(?<![\w-])text-(left|right)(?![\w-])|(?<![\w-])float-(left|right)(?![\w-])'

# ---- 2. Colours: tokens only --------------------------------------------------------------
if [ "$IS_GLOBALS" -eq 0 ]; then
  scan "COLOR: raw hex in component (use tokens: bg-primary, text-muted-foreground, text-link, bg-primary-subtle …)" \
    '(?<![\w&/])#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?(?:[0-9a-fA-F]{2})?\b'
  scan "COLOR: raw colour function in component (oklch/rgb/hsl belong only in globals.css)" \
    '\b(oklch|rgba?|hsla?)\('
  scan "COLOR: Tailwind palette colour (not a project token)" \
    '(?<![\w-])(bg|text|border|ring|from|to|via|fill|stroke|outline|divide|shadow|accent|caret|decoration|placeholder)-(red|green|blue|emerald|stone|gray|zinc|neutral|slate|amber|orange|yellow|lime|teal|cyan|sky|indigo|violet|purple|fuchsia|pink|rose|white|black)(-[0-9]{2,3})?(?![\w-])'
  scan "COLOR: arbitrary colour value" \
    '(?<![\w-])(bg|text|border|ring|from|to|via|fill|stroke)-\[(#|oklch|rgb|hsl)'
fi

# ---- 3. Dark-mode links must use text-link -------------------------------------------------
scan "CONTRAST: text-primary on links is unreadable in dark mode — use text-link" \
  '<(a|Link)[^>]*className=["`][^"`]*\btext-primary\b'

# ---- 4. No external runtime resources (Syria: CDNs/Google unreachable) ----------------------
scan "SYRIA: external CDN/Google resource — bundle or self-host instead" \
  'cdnjs\.cloudflare\.com|unpkg\.com|cdn\.jsdelivr\.net|fonts\.googleapis\.com|fonts\.gstatic\.com|maps\.googleapis\.com|maps\.google\.com|googleapis\.com'

# ---- 5. Code hygiene ---------------------------------------------------------------------
case "$FILE" in
  *.ts|*.tsx)
    scan "TS: no 'any'" '(:\s*any\b|\bas\s+any\b|<any>)'
    scan "TS: no @ts-ignore" '@ts-ignore'
    scan "TS: no console.log left behind (use a logger or remove)" '\bconsole\.log\('
    ;;
esac

# ---- 6. i18n: no literal UI text in JSX -----------------------------------------------------
case "$FILE" in
  *.tsx|*.jsx)
    case "$FILE" in *.test.*|*.spec.*|*/__tests__/*|*.stories.*) ;;
      *)
        # Arabic letters anywhere in a component file → must come from t()
        scan "I18N: hard-coded Arabic text in JSX — use t('key') and add it to ar.json" '[\x{0600}-\x{06FF}]'
        # English sentences as JSX text children: >Some words here<
        scan "I18N: hard-coded English UI text in JSX — use t('key')" '>\s*[A-Z][a-z]+(\s+[A-Za-z,.!?'"'"'-]+){2,}\s*<'
        ;;
    esac
    ;;
esac

if [ "$VIOLATIONS" -gt 0 ]; then
  hook_report ""
  hook_report "Tishreen frontend rules: $VIOLATIONS violation(s) in $FILE. Fix them now (see docs/08-design-system.md and docs/10-i18n.md)."
  exit 2
fi
exit 0
