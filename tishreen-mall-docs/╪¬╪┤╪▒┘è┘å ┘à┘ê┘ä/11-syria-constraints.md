# 11 — Syria Constraints (engineering consequences)

These are not "nice to have" — each one changes a technical decision. Flag them whenever relevant.

| Constraint | Consequence in this codebase |
|---|---|
| **US-hosted services block Syrian visitors** (sanctions) | Host on a VPS with a non-blocking provider (e.g. EU/Turkey/Gulf). No Vercel/Netlify/Cloudflare-Pages-only deployment. No Google Maps, Firebase, Twilio, Stripe. Test from inside Syria before every release. |
| **CDNs / Google Fonts may not load** | **Zero external runtime imports.** Fonts self-hosted (`public/fonts`). Leaflet, icons, charts bundled via npm. No `<script src="https://cdn…">`, no `@import url(https://fonts.googleapis…)`. The hook blocks `cdnjs`, `unpkg`, `jsdelivr`, `fonts.googleapis`, `googleapis.com` in frontend files. |
| **OSM tiles may be slow/unreachable** | Tile URL is a setting (`map.tile_url`). Map is lazy-loaded and optional. Fallback plan: self-hosted tiles (Protomaps/PMTiles) on the same VPS if the in-Syria test fails. Driver navigation uses `geo:` URIs so OsmAnd/Organic Maps offline maps work. |
| **Intermittent connectivity** (especially drivers on the move) | Driver app = PWA with cached list + queued mutations + `Idempotency-Key`. Staff screens poll instead of websockets (simpler reconnection). Uploads are small (WebP re-encode, ≤ 5 MB input). |
| **WhatsApp Business API not available** | `wa.me` deep links from the **user's own device** (customer → store; employee → customer). The system never sends messages itself; it prepares text + link and records `GENERATED → SENT` on manual confirmation. |
| **No card payments / international gateways** | COD only; `PaymentProvider` abstraction ready for a local gateway later. |
| **SMS gateways unreliable/expensive** | OTP via manual WhatsApp; `sms` channel is a stub behind the interface. |
| **Power cuts / server restarts** | Stateless API, fast restart, DB as single source of truth; nightly `pg_dump` + restore script; app shell works offline for drivers. |
| **Mobile-first, low-end Android** | Customer & driver UIs optimised for 360px, low JS budget (route-level code splitting, no heavy UI libs beyond shadcn), images ≤ 100 KB thumbs. |
| **Arabic addresses without reliable street names** | Free-text `details` + zone (mandatory) + optional map pin. Never require postcode/street fields. |
| **Sanctions on package registries?** | npm/Maven Central are reachable; pin versions in lockfiles; keep a local mirror option documented (`pnpm fetch` cache, Maven `~/.m2` tarball) for deployment from inside Syria. |
| **Currency volatility (SYP)** | Prices are plain numbers with no decimals in UI; admin bulk price update endpoint is **not** in scope now but `PRODUCT_PRICE_EDIT` audit makes frequent changes traceable. |

## Pre-launch checklist (run from a Syrian connection)
1. Load `/`, `/c/:slug`, `/p/:slug` on mobile data — all fonts/icons render, no console network errors.
2. Open the map picker — tiles load within 5s; if not, switch `map.tile_url` to the self-hosted tiles.
3. Driver: load deliveries, enable airplane mode, mark delivered, re-enable — action replays once.
4. Customer: place an order — `wa.me` opens WhatsApp with the prepared text.
5. Staff: generate OTP — link opens WhatsApp to the customer's number.
6. Backups: `/it/backups` shows last night's file; `infra/scripts/restore.sh` tested on a scratch DB.
