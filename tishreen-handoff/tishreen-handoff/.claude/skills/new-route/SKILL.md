---
name: new-route
description: Build one screen of the Tishreen web app from its row in docs/07-routes-screens.md and its Figma node — route file, guard, data hooks, components, i18n keys, states, tests.
argument-hint: <route> e.g. /staff/orders/:id
disable-model-invocation: true
---
Build the screen **$ARGUMENTS** from `docs/07-routes-screens.md` (spec row + node id in §10) using the `tanstack-rtl-i18n` and `shadcn-tokens` skills (`driver-offline` for `/driver/*`).

1. Locate the spec row and feature ids; if a Figma node id exists, read it with the Figma MCP (`get_metadata` → `get_design_context` on the frame) and mirror structure, states and copy — never invent layout. Note the pre-weighing state `154:370` for `/staff/orders/:id` and the failure sheet `17:46` for `/driver/deliveries/:id`.
2. Create the route file under the correct layout (`_customer/`, `_staff/`, `_driver/`, `_admin/`, `_it/`) with `beforeLoad` guard, `loader` using query options, `pendingComponent` skeleton, `errorComponent`.
3. Data: hooks in `src/features/<domain>/api.ts` (DTO types from `docs/06`), precise query keys, mutations with invalidation and error mapping.
4. UI: shadcn primitives via `@workspace/ui`, project components from `packages/ui`, tokens only, logical utilities only, all text via `t()` — add keys to `ar.json` and `en.json` in the same commit (Arabic plurals where counts appear).
5. States: loading, empty (with primary action), error (retry + correlation id), offline where relevant; 360 px and 1440 px checked; dark mode; keyboard focus.
6. Tests: component test for logic + RTL/LTR snapshot with `toHaveNoPhysicalDirectionClasses`; add the route to the Playwright journey if it is on the critical path.
7. `pnpm -F web typecheck && pnpm -F web test && pnpm lint` → fix hook findings → report files, keys, query keys, and any design gap.
