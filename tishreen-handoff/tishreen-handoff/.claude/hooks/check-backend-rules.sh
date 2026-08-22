#!/usr/bin/env bash
# PostToolUse hook (Write|Edit|MultiEdit) — backend rules for api/.
# Exit 2 = report violations back to Claude.
set -u
source "$(dirname "$0")/_lib.sh"
hook_read_input
FILE="$(hook_file_path)"
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0

case "$FILE" in
  */api/*|api/*) ;;
  *) exit 0 ;;
esac

VIOLATIONS=0
report() { VIOLATIONS=$((VIOLATIONS+1)); hook_report "  $1"; }
scan() {
  local out; out="$(hook_grep "$2" "$FILE")"
  if [ -n "$out" ]; then
    hook_report "[$1]"
    while IFS= read -r line; do report "$FILE:$line"; done <<<"$out"
  fi
}

# ---------------------------------------------------------------- Java sources
case "$FILE" in
  *.java)
    case "$FILE" in */src/test/*) IS_TEST=1 ;; *) IS_TEST=0 ;; esac

    # 1. Module boundaries: importing another module's domain/infrastructure
    MODULE="$(printf '%s' "$FILE" | sed -n 's#.*/com/tishreen/api/\([a-z]*\)/.*#\1#p')"
    if [ -n "$MODULE" ] && [ "$IS_TEST" -eq 0 ]; then
      out="$(grep -nE '^import com\.tishreen\.api\.[a-z]+\.(domain|infrastructure)\.' "$FILE" | grep -vE "^[0-9]+:import com\.tishreen\.api\.$MODULE\." || true)"
      if [ -n "$out" ]; then
        hook_report "[BOUNDARY: module '$MODULE' imports another module's domain/infrastructure — use that module's service interface, dto or a port in $MODULE/ports (docs/09-architecture.md §2)]"
        while IFS= read -r line; do report "$FILE:$line"; done <<<"$out"
      fi
      # Provider SDKs only inside platform
      if [ "$MODULE" != "platform" ]; then
        scan "BOUNDARY: provider SDK outside platform (MinIO/S3/Telegram/HTTP clients belong to platform.*)" \
          '^import (io\.minio|software\.amazon\.awssdk|com\.amazonaws|org\.telegram|com\.twilio)'
      fi
    fi

    # 2. Money / quantities
    scan "MONEY: floating point is forbidden for money/qty — use BigDecimal (scale 2 / 3)" \
      '\b(double|float|Double|Float)\s+\w*(price|amount|total|fee|qty|quantity|cost|points|discount|balance)\w*'
    scan "MONEY: avoid new BigDecimal(double) — use BigDecimal.valueOf or a String literal" \
      'new BigDecimal\(\s*[0-9]+\.[0-9]+\s*\)'

    # 3. JPA conventions
    scan "JPA: use @Enumerated(EnumType.STRING) — statuses are VARCHAR + CHECK" '@Enumerated\(EnumType\.ORDINAL\)'
    scan "JPA: use OffsetDateTime/Instant, never java.util.Date" '\bjava\.util\.Date\b|new Date\('
    scan "JPA: entity must declare @Table(name = \"…\") with the exact snake_case table name" \
      '^@Entity\s*$'
    # (the previous check reports @Entity lines; Claude verifies the next line is @Table — cheap heuristic)

    # 4. Logging & hygiene
    scan "LOG: System.out/err and printStackTrace are forbidden — use the SLF4J logger" \
      'System\.(out|err)\.print|\.printStackTrace\('
    scan "SECURITY: never log OTP codes or passwords" \
      'log\.(info|debug|warn|error)\([^)]*\b(code|otp|password|passwordHash)\b'

    # 5. Security annotations on controllers
    case "$FILE" in
      */api/*Controller.java)
        if ! grep -qE '@PreAuthorize|@PermitAll|// public endpoint' "$FILE"; then
          hook_report "[SECURITY: controller without @PreAuthorize — add method-level authorization (or mark public endpoints with a '// public endpoint' comment)]"
          report "$FILE:1:missing @PreAuthorize"
        fi
        scan "DTO: controllers must not return entities — map to dto records" \
          'ResponseEntity<\s*(Order|OrderItem|User|Product|Category|Offer|Payment|Delivery|SupportTicket|TicketMessage|StockMovement|PurchaseInvoice)\s*>'
        ;;
    esac
    ;;

  # ------------------------------------------------------------- Flyway migrations
  */db/migration/*.sql)
    if command -v git >/dev/null 2>&1 && git -C "$(dirname "$FILE")" rev-parse >/dev/null 2>&1; then
      STATUS="$(git -C "$(dirname "$FILE")" status --porcelain -- "$(basename "$FILE")" 2>/dev/null | cut -c1-2)"
      if git -C "$(dirname "$FILE")" ls-files --error-unmatch "$(basename "$FILE")" >/dev/null 2>&1 && [ "$STATUS" != "??" ] && [ -n "$STATUS" ]; then
        hook_report "[FLYWAY: editing a committed migration ($(basename "$FILE")) — create a new V<n+1>__<desc>.sql instead (migrations are additive)]"
        report "$FILE:1:modified released migration"
      fi
    fi
    scan "SCHEMA: money must be NUMERIC(14,2), quantities NUMERIC(12,3) — never FLOAT/REAL/DOUBLE/MONEY" \
      '\b(FLOAT|REAL|DOUBLE PRECISION|MONEY)\b'
    scan "SCHEMA: use VARCHAR + CHECK for statuses, not CREATE TYPE … AS ENUM" 'CREATE TYPE .* AS ENUM'
    scan "SCHEMA: TIMESTAMP without time zone — use TIMESTAMPTZ" '\bTIMESTAMP\b(?!TZ)'
    ;;

  # ------------------------------------------------------------- Config files
  */application*.yml|*/application*.yaml|*/application*.properties)
    scan "SECRETS: literal secret in config — use \${ENV_VAR} placeholders" \
      '(secret|password|pepper|token)\s*[:=]\s*(?!\$\{)[A-Za-z0-9+/=_-]{8,}'
    ;;
esac

if [ "$VIOLATIONS" -gt 0 ]; then
  hook_report ""
  hook_report "Tishreen backend rules: $VIOLATIONS violation(s) in $FILE. Fix them now (see docs/09-architecture.md and docs/02-data-model.md)."
  exit 2
fi
exit 0
