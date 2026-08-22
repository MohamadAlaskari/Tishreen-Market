---
name: tanstack-rtl-i18n
description: Frontend conventions for Tishreen — TanStack Start file routes and guards, TanStack Query patterns, react-i18next key rules with Arabic plurals, formatters (money/qty/date with Western digits, Asia/Damascus), RTL logical CSS, bidi isolation, forms (react-hook-form + zod) and error mapping. Load for any screen, component or client-state task.
user-invocable: false
---
# TanStack Start + RTL + i18n (normative: docs/07 §2, docs/08 §4, docs/10)

**Routes** (`apps/web/src/routes/`): `__root.tsx` (html `lang`/`dir`, theme + dark class, providers, toaster) · `_customer/` layout (public + customer guard per route) · `_staff/` (`EMPLOYEE|ADMIN`) · `_driver/` (`DRIVER`) · `_admin/` (`ADMIN`) · `_it/` (`IT|ADMIN`). Guards live in `beforeLoad` using `useSession()` (`/login` redirect with `?next=`; `PENDING|OTP_SENT` customers → `/activate`). Route params: `/c/$slug`, `/p/$slug`, `/orders/$nr`, `/support/$nr`, `/staff/orders/$id`, `/driver/deliveries/$id`.

**Data**: `src/api/client.ts` (fetch wrapper: base `/api/v1`, JSON, `X-Correlation-Id`, `Accept-Language`, refresh-on-401 once, typed `ApiError{code, details, correlationId}`); `src/api/types.ts` DTOs (generated from springdoc OpenAPI when available); per-feature `src/features/<domain>/api.ts` exporting query options `orderQueries.detail(nr)` and mutations. Query keys: `['orders', 'list', filters]`, `['orders', 'detail', nr]` …; invalidate precisely after mutations; `staleTime` 30 s lists, 5 min catalog, `/home`/`/theme`/`/config` 5 min with ETag.

**State**: cart in `zustand` + `persist` (localStorage key `tishreen.cart.v1`; schema `{items:[{productId, optionId?, qty}], version}`; migrations on version bump); never store prices in the cart — quote from the server (`POST /checkout/quote`) before checkout; session in memory + refresh cookie.

**i18n**: `react-i18next`, `ar` default, `en` secondary, namespaces by feature (`common`, `catalog`, `checkout`, `orders`, `staff`, `driver`, `admin`, `it`, `errors`, `status`). Keys `domain.scope.meaning` (`checkout.address.add`), status keys `status.order.READY_FOR_PICKUP`, error keys `errors.PRODUCT_UNAVAILABLE`; Arabic plural forms `_zero _one _two _few _many _other` for counts (`cart.items_count`). Every string through `t()` — JSX text, `placeholder`, `aria-label`, toasts, `alt`. DB content: server already resolved `*_ar`/`*_en` fallback — never re-implement on the client.

**Formatters** (`src/lib/format.ts` only): `formatMoney(v: string)` → `Intl.NumberFormat('ar-SY-u-nu-latn', {maximumFractionDigits:0})` + ` ل.س` / `SYP`; `formatQty(v, unit)` → KG `1.250 كغ`, PIECE `3 قطع`; `formatDate/formatTime` → `Asia/Damascus`, Western digits; `formatPhone` LTR `+963 …`. Wrap numbers in Arabic sentences with `<bdi>`; inputs for phone/OTP/prices get `dir="ltr"` + `inputMode="numeric"`.

**RTL**: `<html dir="rtl">` by default (from `preferred_language`); only logical utilities; direction icons flip with `rtl:-scale-x-100`; `Sheet side="start|end|top"`; sidebar on the right; bottom tabs order as DOM order. Test with `dir="ltr"` too.

**Forms**: `react-hook-form` + `zod` schemas in `src/features/<domain>/schemas.ts`; server `400 details.fields[{field, code}]` mapped with `setError(field, {message: t('errors.'+code)})`; business `422` shown as toast/inline alert with `errors.<CODE>`; `409 ORDER_INVALID_TRANSITION` refetches the order.

**Components**: shadcn primitives from `@workspace/ui/components/*` (added via CLI); project components in `packages/ui/src/` (`QtyStepper`, `OtpInput`, `StatusTimeline`, `ProductCard`, `BottomTab`, `NavItem`, `MapPicker`, `OfflineBanner`, `Money`, `Qty`); icons from `lucide-react` (names = Figma `Icon 60:476`).

**Screens must have**: skeleton while loading, empty state with a primary action, error state with retry + correlation id, 360 px layout, dark mode, focus order. Tables on admin/staff: server pagination, sort via query params, sticky header, 1440/1280 desktop-first.
