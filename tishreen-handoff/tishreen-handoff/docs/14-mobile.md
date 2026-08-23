# 14 — Mobile (`apps/mobile` · Expo customer app)

Scope decided by Mohamad on 2026-08-22 (ADR-0004, ticket #19): `apps/mobile` is the **customer app** — catalogue, cart, ordering, order status — shipped alongside the web PWA. This document is the normative spec for everything mobile. `00`–`13` stay web-normative and are referenced, never duplicated; the mobile-specific rules they carry are: native auth `06 §1`, token transfer `08 §9`, mobile build/release `09 §5`, RN i18n/RTL `10 §7`, distribution constraint `11`, M-track `12`, mobile tests `13 §5`.

## 1. Goal & non-goals

**Goal (v1)**: a native Android-first app that lets a customer complete the full purchase loop — browse, search, fill the cart, check out (pickup or delivery, points & offers included), open the WhatsApp message, follow the order status — plus account basics (register, OTP activation, login, profile, addresses). Arabic-first RTL, same REST API `/api/v1`, no new backend, no schema changes (ADR-0004).

**Non-goals (v1)** — explicitly out, not forgotten:

| Out | Why / where it lives |
|---|---|
| Staff, admin, IT, driver | stay web-only (`00 §1`); the driver offline shell remains the web PWA (P5-T3) |
| Support tickets & FAQ bot, offers browsing page, points statement | web `/support`, `/offers`, `/account/points`; v1.1 candidates (§9). The points **slider in checkout** is in scope (part of F-13) |
| Map pin (`AddressMapPicker`) | Leaflet is DOM-only and Google Maps SDK is blocked (`11`); mobile addresses are zone + mandatory `details` only — a pin can still be set on the website and rides along in the order snapshot. Bundled Leaflet in a WebView is a v1.1 candidate |
| Push notifications | open decision D-M1 (§6) — until decided: polling + WhatsApp, exactly like web |
| Offline mode | the customer app is online-first with graceful error states; offline queues stay a driver-web feature (`01` F-30) |
| iOS distribution | Apple's App Store is unavailable in Syria; the iOS build exists for development only (`11`) |

## 2. Screens & navigation (expo-router)

Navigation is **expo-router** (file-based — mirrors the web's file-route philosophy, Expo's default). Five bottom tabs = the web's `app/BottomTab` (`07 §4`). 14 screens total.

```
apps/mobile/app/
├─ _layout.tsx                 # root stack: providers (i18n, ThemeProvider ← GET /theme, QueryClient, session), RTL bootstrap (10 §7)
├─ (tabs)/
│  ├─ _layout.tsx              # bottom tabs: الرئيسية · الأقسام · السلة · طلباتي · حسابي
│  ├─ index.tsx                # home — GET /home blocks (F-10)
│  ├─ categories.tsx           # category tree (F-11)
│  ├─ cart.tsx                 # cart (F-12)
│  ├─ orders.tsx               # my orders list (guard: CUSTOMER + ACTIVE)
│  └─ account.tsx              # profile, language, password, addresses link (guard: session)
├─ c/[slug].tsx                # category products + filters (F-11)
├─ p/[slug].tsx                # product detail (F-11)
├─ search.tsx                  # dedicated search screen (autofocus input, recent searches local-only)
├─ checkout.tsx                # guard: CUSTOMER + ACTIVE + cart non-empty (F-13, 07 §2)
├─ orders/[nr].tsx             # order detail + status timeline, 30 s polling while non-terminal (F-14)
├─ login.tsx                   # guard: guest (07 §1/§2 _guest semantics)
├─ register.tsx                # guard: guest
├─ activate.tsx                # guard: logged in AND status PENDING|OTP_SENT (07 §1/§2 _activation semantics)
└─ account/addresses.tsx       # address CRUD without map pin (F-15 minus the pin step)
```

Guards replicate `07 §2` semantics client-side (`requireGuest`, `requireAuth`, `requireActive`, `requireRole('CUSTOMER')`; checkout = CUSTOMER + ACTIVE + cart non-empty, as on web); the API stays the real enforcement. Back = native back gesture/button; forward transitions push from the **start** side (RTL). Screen behaviours (loading skeletons, empty states, error toasts with `correlationId`, money/qty/date formatting) follow `07 §3` with the RN formatters from `10 §7`.

## 3. Feature subset & acceptance criteria

Rules and data stay normative in `01`/`05`/`06` — this table binds each mobile feature to its web feature and adds only mobile-specific AC on top.

| ID | Web ref | Mobile scope | Mobile-specific AC (on top of the web AC) |
|---|---|---|---|
| MF-01 | F-01 | Bilingual RTL-first UI | direction changes only via the app-reload prompt (`10 §7`); every screen correct in RTL and LTR on a 360 px-wide device; language persists (AsyncStorage `tishreen.lang` + `PATCH /me` when logged in) |
| MF-02 | F-02, F-03 | Register, OTP activation, login, logout, forgot password | refresh token lives **only** in Expo SecureStore — never AsyncStorage, never logs (`06 §1`); a killed and reopened app restores the session with one silent `POST /auth/refresh`; `PENDING/OTP_SENT` users are redirected to `activate` everywhere except `activate` and read-only account (same rule as web F-02) |
| MF-03 | F-10 | Home from CMS blocks | renders the same `GET /home` payload; unknown `block_type` skipped with a dev-only warning; pull-to-refresh |
| MF-04 | F-11 | Catalogue browsing & search | infinite scroll via `FlatList` `onEndReached` (`size=24`); unavailable products greyed and not addable; `search.tsx` debounces 300 ms against `GET /products?q=`; KG products show the estimate notice |
| MF-05 | F-12 | Cart (guest-capable, local) | same storage schema `tishreen.cart.v1` (zustand + AsyncStorage persister, schema version field); `POST /checkout/quote` re-validation on cart focus and before checkout; unavailable lines block checkout until removed; guest → login → cart kept |
| MF-06 | F-13 | Checkout incl. wa.me flow | order is persisted (`201`) **before** `Linking.openURL(whatsappUrl)` (governing fact 1); if WhatsApp is not installed the URL falls back to the browser; after returning from WhatsApp the app shows `orders/[nr]` with the "إن لم تُفتح رسالة واتساب اضغط هنا" banner; points slider and offer line display server-quoted values only |
| MF-07 | F-14 | My orders & live status | 30 s polling on the detail screen while non-terminal, paused on background (`AppState`), one immediate refetch on foreground; cancel only while `NEW`; reorder fills the cart; "فتح رسالة واتساب" re-opens via `GET …/whatsapp-url` |
| MF-08 | F-15 | Account & addresses (no pin) | profile edit, language, password change; address create/edit/delete/set-default with zone select + mandatory `details`; instead of the map step a hint row (i18n key) explains that a pin can be added on the website |

## 4. App architecture

Mirrors `09 §3` wherever RN allows:

- **Server state**: TanStack Query (same `queryKey` conventions, e.g. `['orders','mine',params]`); no global store for server data.
- **Client state**: cart = zustand + AsyncStorage persister (`tishreen.cart.v1`, same schema + version as web); preferences (`tishreen.lang`, dark-mode override) in AsyncStorage; session = refresh token in **Expo SecureStore**, access token in memory only.
- **API client** (`src/lib/api/client.ts`): base URL from env (`app.json` `extra` / `EXPO_PUBLIC_API_URL`), attaches bearer, `Accept-Language`, `X-Correlation-Id`, `X-Client: mobile`; on `401` one silent refresh then retry; maps `ApiError` → typed `AppError`; error codes localize via `errors.<CODE>` (`10 §2`).
- **Types**: generated from OpenAPI (`openapi-typescript`) like the web — never hand-written DTO duplicates. A shared workspace package for generated types is a v1.1 candidate (needs an ADR; `packages/ui` stays web-only per ADR-0004).
- **Theme & i18n**: normative in `08 §9` and `10 §7`.
- **Components** (`src/components/`): native counterparts keep the web names (`ProductCard`, `QtyStepper`, `OtpInput`, `StatusTimeline`) so the Figma mapping in `07 §9` remains the single mapping table.

## 5. Native auth

Normative contract in `06 §1` ("Native clients", ADR-0010): `X-Client: mobile` on login/refresh → refresh token in the response body, **no cookie**; SecureStore storage; same rotation and `pv` invalidation rules as the cookie variant; CORS untouched because native requests carry no `Origin`. Implementation is cut as M-T3 (`12`).

## 6. Open decision D-M1 — push notifications

> **Status: OPEN — not decided. Ask Mohamad before implementing anything from this section.**

Trigger candidates: order status changes (`CONFIRMED`, `READY_FOR_PICKUP`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED`) — today covered by manual WhatsApp (`01` F-05) plus 30 s polling on the open order detail.

| Option | How | Consequences |
|---|---|---|
| **A — No push in v1 (recommended)** | keep polling + WhatsApp | zero new infrastructure, zero blocked-service risk, schema untouched; the customer must open the app (or WhatsApp) for status |
| B — FCM via Expo Notifications | Expo push service → Firebase Cloud Messaging | **contradicts `11`**: Firebase is on the blocked list, FCM requires Google Play Services (absent or unreliable on sideloaded low-end devices), and Expo's push relay is US-hosted; would need `device_tokens` + a push channel |
| C — Self-hosted push (UnifiedPush / ntfy) | own ntfy server on the VPS; app keeps a subscription | sanctions-safe, but a new moving part: battery drain, Android background-work limits, one more service to operate and back up; would need `device_tokens` + a push channel |

**Recommendation: A.** WhatsApp already is the customer-facing notification channel (governing facts 1 and 3), and B breaks doc `11`. Revisit C when order volume makes the manual WhatsApp flow too slow.

If B or C is ever accepted, the prepared shape is: a `device_tokens` table in `02` (`id BIGINT PK · user_id FK users NOT NULL · platform VARCHAR(10) CHECK IN ('ANDROID','IOS') · token VARCHAR(255) UNIQUE NOT NULL · created_at · last_seen_at · revoked_at NULL`, index `(user_id)`) + additive migration; a push `NotificationChannel` implementation plus endpoints `POST /me/device-tokens` and `DELETE /me/device-tokens/{token}`. Beware: push would send **in addition to** the manual WhatsApp row, but `09 §2` (`ProviderSelector`, single `notification.provider` key) and F-05's "exactly one GENERATED row" AC only model **switching** channels, not stacking them — the accepting ADR must extend the notification dispatch to multi-channel and adjust F-05/`/it/providers` accordingly. None of this exists today — deliberately.

## 7. Distribution & release

Normative in `09 §5` (local Gradle release builds — EAS cloud is optional developer convenience, never a required dependency; one guarded keystore; signed APK hosted on our own domain with SHA-256 checksum) and `11` (distribution constraint + pre-launch checklist item 7). Android-first: the APK sideload from our domain is the primary channel; a Google Play listing is a bonus, never the only path.

## 8. Manual release protocol (every mobile release)

1. `pnpm -F mobile typecheck && pnpm -F mobile lint && pnpm -F mobile test` green.
2. `app.json` has no `updates.url` and OTA stays disabled (`10 §7.3`); no external runtime URLs in the bundle (the `13 §5` static guards cover both).
3. Fresh install of the signed APK on a low-end Android (2 GB RAM class): first start ≤ 5 s to interactive home.
4. RTL walk-through in `ar`; switch to `en` (app reload) and back — no physical-direction slips, no overflow at 360 px.
5. Full journey: register → activate (OTP via staff desk) → browse → cart → checkout → WhatsApp opens with the correct prepared text → order visible with status timeline.
6. Kill the app, reopen: session restored silently, cart intact.
7. Airplane mode: every screen shows its error/empty state, nothing crashes; reconnecting recovers without a restart.
8. `11` pre-launch checklist item 7 from a Syrian connection before wide release.

## 9. v1.1 candidates (each is its own ticket; some need an ADR)

- Support tickets & bot, offers page, points statement — parity with the remaining web customer screens.
- Map pin via bundled Leaflet in a WebView (tiles only from `settings.map.tile_url`).
- Shared workspace package for generated OpenAPI types (ADR — touches the ADR-0004 package layout).
- TanStack Query persistence for catalogue browsing (offline tolerance).
- In-app update check against a version endpoint; Maestro E2E; push per D-M1.
