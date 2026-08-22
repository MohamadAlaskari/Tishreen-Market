---
name: shadcn-tokens
description: The Tishreen design tokens and theme mechanics — token names and when to use each, the three audited presets (rose/orange/sky) and data-theme switching, derived tokens (link, primary-subtle, destructive-subtle), radius/spacing scale, fonts (Tajawal/Cairo/IBM Plex Mono) and the shadcn CLI workflow. Load for any styling work.
user-invocable: false
---
# Tokens & themes (normative: tishreen-handoff/tishreen-handoff/docs/08-design-system.md — verified against Figma 2026-08-22)

**Use these utilities, nothing else**
| purpose | utility |
|---|---|
| page / card / popover surfaces | `bg-background` · `bg-card` + `border-border` · `bg-popover` |
| text | `text-foreground` · `text-muted-foreground` (secondary) · `text-link` (links, coloured text, **always** in dark mode) |
| brand action | `bg-primary text-primary-foreground` (buttons, active bottom tab, hero) |
| soft highlight / callout / active pill | `bg-primary-subtle` (+ `text-link` on it) |
| danger | `bg-destructive text-white` (buttons) · `bg-destructive-subtle` + `text-destructive` (alerts) |
| neutral chips, table head | `bg-muted text-muted-foreground` · `bg-secondary text-secondary-foreground` |
| inputs | `border-input bg-background` · focus `ring-ring` |
| admin sidebar | `bg-sidebar text-sidebar-foreground`, active `bg-sidebar-primary text-sidebar-primary-foreground`, hover `bg-sidebar-accent` |
| charts | `chart-1 … chart-5` only |
| radius | `rounded-sm|md|lg|xl|2xl|full` |
| spacing | `1 2 3 4 5 6 8 10 12 16` (= Figma `space/*`) |
| fonts | `font-sans` (Tajawal) · `font-display` (main headings: Tufuli Arabic when licensed → Baloo Bhaijaan 2 stand-in) · `font-label` (Cairo: badges, chips, table heads, prices) · `font-mono` (codes, order numbers) |

**Never**: `#hex`, `oklch()`, `rgb()`, `bg-[…]`, Tailwind palette colours (`red-500`, `zinc-100`, `white`, `black`), `rounded-[…]`, `text-primary` on text in dark mode, `bg-primary-foreground` as a surface, inline `style` colours, Google Fonts, external CSS.

**Themes**: three audited presets — `rose` (default, `--radius .625rem`), `orange`, `sky` (`--radius .875rem`). `<html data-theme="orange" class="dark">`. Preset switching changes `primary accent sidebar-primary link primary-subtle chart-1..5 radius` together; everything else shared. Optional hue-only override from `GET /theme.primaryHue` sets those seven variables inline in `__root.tsx` (`applyTheme(theme)` in `src/lib/theme.ts`). Components must never know which preset is active.

**Contrast facts** (why the rules exist): rose dark `primary #A30037` on `background #0A0A0A` = 1.8:1 → `text-link` (`#FF7B8C`, 8.0:1); `primary-foreground` is light pink in both modes → not a surface; buttons 6.31:1, links 4.90:1, active nav 5.74:1 in every preset (server-gated on theme save).

**shadcn CLI**: init once `pnpm dlx shadcn@latest init --preset b4iTphWki --template start --monorepo --rtl --pointer`; `pnpm dlx shadcn@latest add button badge input card label separator textarea switch avatar select tabs toggle-group input-otp dialog sheet table skeleton sonner dropdown-menu command slider radio-group checkbox form` from `apps/web`; components land in `packages/ui/src/components/`; edit after generation (RTL variants of `Sheet`, `DropdownMenu` alignment `align="start"`); `pnpm dlx shadcn@latest info` / `--diff` before updates. Keep `@workspace/ui` as the import alias.

**Figma ↔ code names**: `Button 39:52` → `button` variants `default secondary destructive outline ghost link`, sizes `default sm lg icon`; `Badge 41:10`; `Input 41:24`; `Card 42:2`; `Label 64:14`; `Separator 64:23`; `Textarea 64:37`; `Switch 64:51`; `Avatar 64:64`; `Select 67:37`; `TabsTrigger 67:47`; `ToggleGroupItem 67:57`; `InputOTPSlot 67:69`; `Icon 60:476`; `app/ProductCard 43:20` (`state=available|out-of-stock`); `app/BottomTab 36:19` (`state=default|active`); `app/NavItem 36:8`.
