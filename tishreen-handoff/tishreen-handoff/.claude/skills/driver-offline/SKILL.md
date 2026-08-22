---
name: driver-offline
description: Offline-first behaviour of the Tishreen driver app — cached delivery list, IndexedDB mutation queue with Idempotency-Key replay, conflict handling, PWA service worker scope, geo: navigation links, COD collection UI. Load for any /driver work or PWA/service-worker changes.
user-invocable: false
---
# Driver offline (normative: docs/01 F-40…F-46, docs/09 §8, docs/11)

**Why**: intermittent mobile data in Aleppo. The driver must see today's deliveries and complete them without a connection; the server reconciles later.

**Read side**: `GET /driver/deliveries` (own, today) is persisted with TanStack Query `persistQueryClient` (IndexedDB via `idb-keyval`), `gcTime` 24 h; when `navigator.onLine === false` or the request fails the cached list renders with `OfflineBanner` ("لا يوجد اتصال — تُعرض آخر قائمة محفوظة · آخر تحديث {time}"). Detail screens read from the same cache.

**Write side**: every mutation (`start`, `delivered {collectedAmount}`, `failed {reason}`) is enqueued in `idb` store `tishreen.driver.queue` as `{id: uuid (= Idempotency-Key), deliveryId, action, payload, createdAt}` and applied optimistically to the cached list (status badge "بانتظار المزامنة"). `QueueReplayer` runs on `online`, on app focus and every 30 s: sends in creation order, one at a time, with the stored `Idempotency-Key`; `2xx`/`200-replay` → dequeue; `409 ORDER_INVALID_TRANSITION` → dequeue + mark item "needs staff" (the staff already changed it); `401` → refresh then retry; network error → stop and retry later. Never drop a mutation silently; the queue length shows in the header.

**Server expectations**: `POST /driver/deliveries/{id}/delivered|failed|start` require `Idempotency-Key` (UUID) scoped to the driver; replays return the original response; ownership enforced (404 for others' deliveries).

**Navigation & contact**: address card shows text + zone; buttons: call (`tel:`), WhatsApp (`https://wa.me/<customer digits>`), "فتح الموقع في الخرائط" only when `delivery_lat/lng` present → `geo:{lat},{lng}?q={lat},{lng}` (OsmAnd/Maps.me/Google Maps all handle it offline); no embedded map on this screen.

**COD**: `collectedAmount` defaults to `final_total`, editable with numeric keypad, confirmation sheet shows difference; stored in `deliveries.collected_amount` and `payments`.

**PWA**: `manifest.webmanifest` (ar name, RTL start url `/driver/deliveries`), service worker (Workbox) caches app shell + fonts + Leaflet assets; API calls network-first with the query persistence above; no push notifications in v1.

**Tests**: Vitest for queue ordering/dedupe/conflict mapping; Playwright `driver-offline.spec.ts` with `context.setOffline(true)` → complete delivery → `setOffline(false)` → assert replay and server state.
