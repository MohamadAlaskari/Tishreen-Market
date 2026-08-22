# 13 — Quality: Definition of Done, Tests, Reviews

## 1. Definition of Done (every task)
- [ ] Works in **RTL and LTR**, Arabic and English (fallback verified), light and dark.
- [ ] Server-side validation for every input; errors are localized codes, never stack traces.
- [ ] Unit tests for touched business logic; integration test for new endpoints (MockMvc + Testcontainers); frontend test for new components with logic.
- [ ] No `any`, `@ts-ignore`, `console.log`, `System.out`, commented-out code, `TODO: implement`.
- [ ] Every list endpoint paginated and backed by an index listed in `02 §14` (or a new one added to the migration + doc).
- [ ] Sensitive operation → audited (check the mandatory list in `01 F-04`).
- [ ] Comments explain **why**, not what.
- [ ] Docs updated when behaviour/schema/API changed; ADR when deviating.
- [ ] Hooks pass (`check-frontend-rules`, `check-backend-rules`, `check-secrets`).

## 2. Backend tests (JUnit 5 · Mockito · Testcontainers · ArchUnit)

### Unit — business rules (pure, fast)
| Test class | Cases |
|---|---|
| `OrderStateMachineTest` | every allowed transition from `05 §1` succeeds; every disallowed pair → `ORDER_INVALID_TRANSITION`; terminal states reject everything; `dispatch` requires finalized + DELIVERY; `ready` requires PICKUP |
| `PricingServiceTest` | subtotal rounding per line; option delta folded into unit price; KG step validation (0.250 ok, 0.3 rejected); PIECE integer; min order vs goods subtotal (before discounts); estimate total |
| `FinalizeTest` | line_total = price × actual; PIECE auto actual; missing KG weight → error; FIXED offer capped at actual goods; points value capped; `final_total` never negative; re-finalize idempotent |
| `WeightDeviationTest` | 29.9% no warning, 30.1% warning; warning never blocks |
| `PointsServiceTest` | earn floor(goods/1000); no earn on cancelled; redeem min 100; redeem ≤ balance; redeem value ≤ 50% goods; reversal on cancel restores balance; ADJUST without reason → 422 |
| `OfferEngineTest` | each condition type true/false; nested all/any; unknown type → not eligible (+ log); validity window; total & per-customer limits exclude cancelled; best-offer selection tie → lowest id; FREE_DELIVERY ineligible on pickup; BONUS_POINTS added at earn |
| `OtpServiceTest` | hash stored; expiry → 410; 5 failures → 423 then success impossible; regenerate invalidates old; purpose isolation; never logs code |
| `WhatsAppMessageBuilderTest` | Arabic and English snapshots (golden files) for pickup and delivery orders with options and notes; URL-encoding; store number digits only |
| `StockLedgerTest` | SALE on leaving PREPARING once (idempotent); RETURN on cancel after SALE; cache equals SUM; reason required for WASTE/ADJUSTMENT |
| `PaymentStatusTest` | PAID/PARTIAL/UNPAID derivation; idempotency key replay returns first result |
| `FaqMatcherTest` | normalization (diacritics, alef forms), threshold, tie by sort_order, language fallback, escalation flag |
| `LocalizedTextTest` | en present → en; en null → ar; Accept-Language parsing |
| `ThemeContrastValidatorTest` | each preset passes all four pairs in light and dark; hue rotation that drops a pair below 4.5 → `THEME_CONTRAST_FAILED` with the pair named; invalid preset → `THEME_PRESET_INVALID`; hue outside 0–360 rejected |

### Integration (Spring context + Postgres Testcontainer)
- `FlywayDevMigrationSmokeTest` / `FlywayProdMigrationSmokeTest`: Flyway migrates a fresh Postgres 15 container — dev profile applies V1+V2+V900 (34 tables, core-seed and dev-sample counts); prod profile applies V1+V2 only (no dev seed).
- `AuthFlowIT`: register → login → refresh rotation → blocked user rejected.
- `OrderJourneyIT`: create (assert DB row before WhatsApp URL returned) → confirm → weigh → finalize → ready → picked-up: history rows, stock movements, payment, points earn.
- `DeliveryJourneyIT`: dispatch → failed → retry → delivered with idempotent replay.
- `OwnershipIT`: customer A cannot read B's order/address/ticket (404); driver cannot read another driver's delivery.
- `AuditAspectIT`: each mandatory action writes exactly one row with old/new.
- `ProviderSwitchIT`: change `notification.provider` via settings → next send uses the other bean.
- `NotificationFilterIT`: internal ticket messages never appear in customer endpoints.

### Architecture (ArchUnit)
- No `domain`/`infrastructure` cross-package imports; only `platform` imports provider SDKs; controllers don't access repositories; no `java.util.Date`/`double` in domain; entities are not returned by controllers.

### Contract tests (abstract base per interface)
`NotificationChannelContractTest`, `ImageStorageContractTest`, `PaymentProviderContractTest`, `ChatbotProviderContractTest` — every implementation (including stubs) must pass.

## 3. Frontend tests (Vitest · Testing Library · Playwright)
- Unit: `formatMoney/formatQty/formatDate`, cart store (add/merge/step/limits/persistence/version migration), `describeConditions()`, offline queue (enqueue/replay order/dedupe by key), guards.
- Component: `QtyStepper` (KG/PIECE), `OtpInput` (paste, RTL digits), `StatusTimeline`, `ProductCard` (unavailable state), checkout summary renders server numbers only.
- RTL snapshot: render key screens with `dir=rtl` and `dir=ltr`, assert no physical-direction classes (`toHaveNoPhysicalDirectionClasses` custom matcher).
- E2E (Playwright, against the local dev stack — `tishreen.ps1 -Mode dev`, `09 §4`): customer journey (Phase 4), driver offline replay (Phase 5, using `context.setOffline`), staff OTP desk.

## 4. Review checklists

**Backend PR**
- Transaction boundaries correct; order row locked for transitions.
- Snapshots copied, never joined for historical display.
- Ledger writes (points/stock) accompanied by cache/consistency; no balance columns.
- `@PreAuthorize` present; ownership enforced; DTOs only.
- Localized messages for new error codes in both property files.
- Migration additive; indexes for new queries; `02-data-model.md` updated.

**Frontend PR**
- Only token colours and logical utilities; `text-link` for links.
- All strings through `t()`; keys added to `ar.json` (+ `en.json`).
- Money/qty/date via helpers; `<bdi>` for numbers in Arabic text.
- Loading/empty/error states; pagination; no external URLs.
- Query keys & invalidation precise; forms with zod + server error mapping.
- Works at 360px; dark mode; keyboard focus.

**Security PR (phase end)** — `06 §12` list + secrets scan + dependency audit (`pnpm audit`, `mvn dependency-check` optional).
