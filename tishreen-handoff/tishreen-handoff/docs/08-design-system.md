# 08 — Design System (tokens · themes · fonts · RTL · components)

> **Verified against the live Figma file on 2026-08-22** (`0RLOI0q7lWCK1Rme8JjkKu`, collection `tishreen/theme` = `VariableCollectionId:1:4`, 49 variables, six modes: `Light 1:2`, `Dark 1:3`, `برتقالي·فاتح 163:0`, `برتقالي·داكن 163:1`, `سماوي·فاتح 166:0`, `سماوي·داكن 166:1`). The values below are what Figma renders today and match the knowledge file `tishreen-tech-stack-and-theme.md` §3.
>
> **Decision (Mohamad, 2026-08-22):** the 2026-08-20 branding experiments (emerald primary, brand-mark components, name «تشرين مول», slogan) were **reverted on purpose**. Final: name **مجمع تشرين**, **rose** preset by default, Tajawal for text, **Tufuli Arabic** for main headings (Figma stand-in: Baloo Bhaijaan 2 — see §5).

## 1. Brand
- Name on every screen: **مجمع تشرين** (English label "Tishreen Mall"; code name `tishreen`). No slogan for now (`theme_settings.slogan_*` are empty, admin-editable).
- Brand palette supplied by Mohamad (`#06231A` ink · `#0B6B4F` emerald · `#FC9701` orange · `#D3E4DA` mint · `#E2D3B3` cream) lives **in the logo artwork only**; UI colours always come from the tokens in §2. Never type these hexes in components.
- Logo: no logo component exists in Figma yet. The admin uploads the logo (`theme_settings.logo_key`, SVG/PNG ≤ 512 KB, screen `/admin/cms/theme`). Until then the header shows the wordmark text «مجمع تشرين» in `heading/md`. If a brand mark is supplied later, keep its ratio `width = height × 87.5 / 75.6`.

## 2. Theme model (exactly what `/admin/cms/theme` · Figma `130:2389` specifies)
- **Three audited presets**, each checked in light and dark against WCAG AA:

| preset | `theme_preset` | `--primary` (light) | `--radius` | Figma modes |
|---|---|---|---|---|
| وردي (default) | `rose` | `#C1003A` | `0.625rem` | `1:2` / `1:3` |
| برتقالي | `orange` | `#C43E00` | `0.875rem` | `163:0` / `163:1` |
| سماوي | `sky` | `#0069A2` | `0.875rem` | `166:0` / `166:1` |

- Switching a preset changes **`--primary`, `--accent`, `--sidebar-primary`, `--link`, `--primary-subtle`, the `--chart-1..5` chain and `--radius` together**; greys, borders, surfaces and `destructive` are shared (see blocks below — they differ only marginally between presets and are kept verbatim from Figma).
- **Optional hue-only tweak** (`theme_settings.primary_hue`, integer 0–360 or empty): lightness and chroma stay locked to the preset; only the hue rotates. Deriving 30 tokens from one free colour is forbidden — it produced unreadable active-nav pills in all three presets.
- **Contrast gate runs in the server** before saving (`PUT /admin/cms/theme`): button text on primary ≥ 4.5 (rose 6.31), link on background ≥ 4.5 (4.90), active sidebar item ≥ 4.5 (5.74), link on `primary-subtle` ≥ 4.5. One failure ⇒ `422 THEME_CONTRAST_FAILED` with the failing pair and the shortfall. Nothing is saved.
- **Theme is data, not code**: `GET /theme` returns `{preset, primaryHue, tokens}`; `__root.tsx` sets `data-theme="<preset>"` on `<html>` and, only when `primaryHue` is set, overrides the seven derived variables inline. No rebuild, no deploy.
- Dark mode is a class `.dark` on `<html>` (user preference, `prefers-color-scheme` default), orthogonal to the preset.

### 2.1 `apps/web/src/styles/globals.css` (copy verbatim)

```css
@import "tailwindcss";
@import "tw-animate-css";

@custom-variant dark (&:is(.dark *));

/* Tailwind v4 + shadcn/ui: expose CSS variables as utilities (bg-primary, text-link, …) */
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-primary-subtle: var(--primary-subtle);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-destructive-subtle: var(--destructive-subtle);
  --color-link: var(--link);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --color-chart-1: var(--chart-1);
  --color-chart-2: var(--chart-2);
  --color-chart-3: var(--chart-3);
  --color-chart-4: var(--chart-4);
  --color-chart-5: var(--chart-5);
  --color-sidebar: var(--sidebar);
  --color-sidebar-foreground: var(--sidebar-foreground);
  --color-sidebar-primary: var(--sidebar-primary);
  --color-sidebar-primary-foreground: var(--sidebar-primary-foreground);
  --color-sidebar-accent: var(--sidebar-accent);
  --color-sidebar-accent-foreground: var(--sidebar-accent-foreground);
  --color-sidebar-border: var(--sidebar-border);
  --color-sidebar-ring: var(--sidebar-ring);
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
  --radius-2xl: calc(var(--radius) + 8px);
  --font-sans: var(--font-body);
  --font-display: var(--font-display);
  --font-label: var(--font-label);
  --font-mono: var(--font-mono);
}

:root {
  /* وردي (rose) — default. Source: shadcn preset b4iTphWki (knowledge file) = Figma tishreen/theme mode Light 1:2 */
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.145 0 0);
  --primary: oklch(0.514 0.222 16.935);            /* #C1003A */
  --primary-foreground: oklch(0.969 0.015 12.422);
  --primary-subtle: oklch(0.969 0.015 12.422);     /* #FFF1F2 — callouts, active pills (Figma) */
  --secondary: oklch(0.967 0.001 286.375);
  --secondary-foreground: oklch(0.21 0.006 285.885);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.514 0.222 16.935);             /* = primary: emphasis comes from size, not a third colour */
  --accent-foreground: oklch(0.969 0.015 12.422);
  --destructive: oklch(0.577 0.245 27.325);
  --destructive-subtle: oklch(0.982 0.009 17.303); /* #FFF7F7 */
  --link: oklch(0.514 0.222 16.935);               /* = primary in light (6.3:1 on white) */
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --chart-1: oklch(0.808 0.114 19.571);            /* red family — sales charts */
  --chart-2: oklch(0.637 0.237 25.331);
  --chart-3: oklch(0.577 0.245 27.325);
  --chart-4: oklch(0.505 0.213 27.518);
  --chart-5: oklch(0.444 0.177 26.899);
  --radius: 0.625rem;                              /* 10px base: sm 6 · md 8 · lg 10 · xl 14 */
  --sidebar: oklch(0.985 0 0);
  --sidebar-foreground: oklch(0.145 0 0);
  --sidebar-primary: oklch(0.586 0.253 17.585);
  --sidebar-primary-foreground: oklch(0.969 0.015 12.422);
  --sidebar-accent: oklch(0.97 0 0);
  --sidebar-accent-foreground: oklch(0.205 0 0);
  --sidebar-border: oklch(0.922 0 0);
  --sidebar-ring: oklch(0.708 0 0);
  --font-body: "Tajawal", system-ui, sans-serif;
  --font-display: "Tufuli Arabic", "Baloo Bhaijaan 2", "Tajawal", system-ui, sans-serif; /* Tufuli = licensed files from Mohamad; Baloo = OFL stand-in (same as Figma) */
  --font-label: "Cairo", "Tajawal", system-ui, sans-serif;   /* label/sm, label/xs, price/lg (Figma) */
  --font-mono: "IBM Plex Mono", ui-monospace, monospace;     /* order numbers, codes, correlation ids */
}

.dark {
  /* وردي — Dark (Figma mode 1:3) */
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.205 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.205 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.455 0.188 13.697);            /* #A30037 — fine as a button surface, NOT as text */
  --primary-foreground: oklch(0.969 0.015 12.422);
  --primary-subtle: oklch(0.241 0.055 14.873);     /* #351317 */
  --secondary: oklch(0.274 0.006 286.033);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.455 0.188 13.697);
  --accent-foreground: oklch(0.969 0.015 12.422);
  --destructive: oklch(0.704 0.191 22.216);
  --destructive-subtle: oklch(0.239 0.055 25.487); /* #351311 */
  --link: oklch(0.74 0.161 13.845);                /* #FF7B8C — 8.0:1; text-primary would be 1.8:1 */
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.556 0 0);
  --chart-1: oklch(0.808 0.114 19.571);
  --chart-2: oklch(0.637 0.237 25.331);
  --chart-3: oklch(0.577 0.245 27.325);
  --chart-4: oklch(0.505 0.213 27.518);
  --chart-5: oklch(0.444 0.177 26.899);
  --sidebar: oklch(0.21 0.006 285.885);
  --sidebar-foreground: oklch(0.985 0 0);
  --sidebar-primary: oklch(0.645 0.246 16.439);
  --sidebar-primary-foreground: oklch(0.969 0.015 12.422);
  --sidebar-accent: oklch(0.269 0 0);
  --sidebar-accent-foreground: oklch(0.985 0 0);
  --sidebar-border: oklch(1 0 0 / 10%);
  --sidebar-ring: oklch(0.556 0 0);
}

[data-theme="orange"] {
  /* Theme برتقالي (orange) — Light (mode 163:0) */
  --background: oklch(1.0 0 0);                               /* #ffffff */
  --foreground: oklch(0.145 0 0);                             /* #0a0a0a */
  --card: oklch(1.0 0 0);                                     /* #ffffff */
  --card-foreground: oklch(0.145 0 0);                        /* #0a0a0a */
  --popover: oklch(1.0 0 0);                                  /* #ffffff */
  --popover-foreground: oklch(0.145 0 0);                     /* #0a0a0a */
  --primary: oklch(0.553 0.179 38.41);                        /* #c43e00 */
  --primary-foreground: oklch(0.98 0.016 73.684);             /* #fff7ed */
  --secondary: oklch(0.967 0 0);                              /* #f4f4f5 */
  --secondary-foreground: oklch(0.274 0.005 286.033);         /* #27272a */
  --muted: oklch(0.97 0 0);                                   /* #f5f5f5 */
  --muted-foreground: oklch(0.556 0 0);                       /* #737373 */
  --accent: oklch(0.553 0.179 38.41);                         /* #c43e00 */
  --accent-foreground: oklch(0.98 0.016 73.684);              /* #fff7ed */
  --destructive: oklch(0.578 0.236 27.389);                   /* #e40016 */
  --border: oklch(0.922 0 0);                                 /* #e5e5e5 */
  --input: oklch(0.922 0 0);                                  /* #e5e5e5 */
  --ring: oklch(0.709 0 0);                                   /* #a1a1a1 */
  --chart-1: oklch(0.789 0.132 61.006);                       /* #f7a55b */
  --chart-2: oklch(0.679 0.185 45.675);                       /* #f06a16 */
  --chart-3: oklch(0.629 0.188 42.446);                       /* #e15600 */
  --chart-4: oklch(0.553 0.179 38.41);                        /* #c43e00 */
  --chart-5: oklch(0.47 0.157 37.146);                        /* #9f2d00 */
  --sidebar: oklch(0.985 0 0);                                /* #fafafa */
  --sidebar-foreground: oklch(0.145 0 0);                     /* #0a0a0a */
  --sidebar-primary: oklch(0.553 0.179 38.41);                /* #c43e00 */
  --sidebar-primary-foreground: oklch(0.98 0.016 73.684);     /* #fff7ed */
  --sidebar-accent: oklch(0.97 0 0);                          /* #f5f5f5 */
  --sidebar-accent-foreground: oklch(0.205 0 0);              /* #171717 */
  --sidebar-border: oklch(0.922 0 0);                         /* #e5e5e5 */
  --sidebar-ring: oklch(0.709 0 0);                           /* #a1a1a1 */
  --link: oklch(0.553 0.179 38.41);                           /* #c43e00 */
  --primary-subtle: oklch(0.97 0.014 57.591);                 /* #fdf3ec */
  --destructive-subtle: oklch(0.982 0.009 17.303);            /* #fff7f7 */
  --radius: 0.875rem;
}

[data-theme="orange"].dark, [data-theme="orange"] .dark {
  /* برتقالي — Dark (mode 163:1) */
  --background: oklch(0.145 0 0);                             /* #0a0a0a */
  --foreground: oklch(0.985 0 0);                             /* #fafafa */
  --card: oklch(0.205 0 0);                                   /* #171717 */
  --card-foreground: oklch(0.985 0 0);                        /* #fafafa */
  --popover: oklch(0.205 0 0);                                /* #171717 */
  --popover-foreground: oklch(0.985 0 0);                     /* #fafafa */
  --primary: oklch(0.47 0.157 37.146);                        /* #9f2d00 */
  --primary-foreground: oklch(0.98 0.016 73.684);             /* #fff7ed */
  --secondary: oklch(0.274 0.005 286.033);                    /* #27272a */
  --secondary-foreground: oklch(0.985 0 0);                   /* #fafafa */
  --muted: oklch(0.269 0 0);                                  /* #262626 */
  --muted-foreground: oklch(0.709 0 0);                       /* #a1a1a1 */
  --accent: oklch(0.47 0.157 37.146);                         /* #9f2d00 */
  --accent-foreground: oklch(0.98 0.016 73.684);              /* #fff7ed */
  --destructive: oklch(0.704 0.188 22.146);                   /* #ff6568 */
  --border: oklch(1.0 0 0 / 10%);                             /* #ffffff1a */
  --input: oklch(1.0 0 0 / 15%);                              /* #ffffff26 */
  --ring: oklch(0.633 0 0);                                   /* #8a8a8a */
  --chart-1: oklch(0.789 0.132 61.006);                       /* #f7a55b */
  --chart-2: oklch(0.679 0.185 45.675);                       /* #f06a16 */
  --chart-3: oklch(0.629 0.188 42.446);                       /* #e15600 */
  --chart-4: oklch(0.553 0.179 38.41);                        /* #c43e00 */
  --chart-5: oklch(0.47 0.157 37.146);                        /* #9f2d00 */
  --sidebar: oklch(0.205 0 0);                                /* #171717 */
  --sidebar-foreground: oklch(0.985 0 0);                     /* #fafafa */
  --sidebar-primary: oklch(0.47 0.157 37.146);                /* #9f2d00 */
  --sidebar-primary-foreground: oklch(0.98 0.016 73.684);     /* #fff7ed */
  --sidebar-accent: oklch(0.269 0 0);                         /* #262626 */
  --sidebar-accent-foreground: oklch(0.985 0 0);              /* #fafafa */
  --sidebar-border: oklch(1.0 0 0 / 10%);                     /* #ffffff1a */
  --sidebar-ring: oklch(0.633 0 0);                           /* #8a8a8a */
  --link: oklch(0.661 0.157 37.484);                          /* #e16a46 */
  --primary-subtle: oklch(0.221 0.051 38.06);                 /* #2e1108 */
  --destructive-subtle: oklch(0.239 0.055 25.487);            /* #351311 */
}

[data-theme="sky"] {
  /* Theme سماوي (sky) — Light (mode 166:0) */
  --background: oklch(1.0 0 0);                               /* #ffffff */
  --foreground: oklch(0.147 0.004 49.25);                     /* #0c0a09 */
  --card: oklch(1.0 0 0);                                     /* #ffffff */
  --card-foreground: oklch(0.147 0.004 49.25);                /* #0c0a09 */
  --popover: oklch(1.0 0 0);                                  /* #ffffff */
  --popover-foreground: oklch(0.147 0.004 49.25);             /* #0c0a09 */
  --primary: oklch(0.5 0.121 242.967);                        /* #0069a2 */
  --primary-foreground: oklch(0.977 0.012 236.62);            /* #f0f9ff */
  --secondary: oklch(0.967 0 0);                              /* #f4f4f5 */
  --secondary-foreground: oklch(0.21 0.006 285.885);          /* #18181b */
  --muted: oklch(0.96 0.002 17.196);                          /* #f3f1f1 */
  --muted-foreground: oklch(0.547 0.021 43.085);              /* #7c6d67 */
  --accent: oklch(0.5 0.121 242.967);                         /* #0069a2 */
  --accent-foreground: oklch(0.977 0.012 236.62);             /* #f0f9ff */
  --destructive: oklch(0.578 0.236 27.389);                   /* #e40016 */
  --border: oklch(0.922 0.005 34.309);                        /* #e8e4e3 */
  --input: oklch(0.922 0.005 34.309);                         /* #e8e4e3 */
  --ring: oklch(0.714 0.014 41.161);                          /* #aba09c */
  --chart-1: oklch(0.829 0.107 230.092);                      /* #78d4ff */
  --chart-2: oklch(0.684 0.15 237.277);                       /* #00a5ea */
  --chart-3: oklch(0.587 0.139 241.87);                       /* #0084c7 */
  --chart-4: oklch(0.5 0.121 242.967);                        /* #0069a2 */
  --chart-5: oklch(0.443 0.103 240.591);                      /* #005986 */
  --sidebar: oklch(0.986 0 0);                                /* #fbfaf9 */
  --sidebar-foreground: oklch(0.147 0.004 49.25);             /* #0c0a09 */
  --sidebar-primary: oklch(0.5 0.121 242.967);                /* #0069a2 */
  --sidebar-primary-foreground: oklch(0.977 0.012 236.62);    /* #f0f9ff */
  --sidebar-accent: oklch(0.96 0.002 17.196);                 /* #f3f1f1 */
  --sidebar-accent-foreground: oklch(0.214 0.009 43.066);     /* #1d1816 */
  --sidebar-border: oklch(0.922 0.005 34.309);                /* #e8e4e3 */
  --sidebar-ring: oklch(0.714 0.014 41.161);                  /* #aba09c */
  --link: oklch(0.5 0.121 242.967);                           /* #0069a2 */
  --primary-subtle: oklch(0.968 0.017 242.423);               /* #ebf6ff */
  --destructive-subtle: oklch(0.982 0.009 17.303);            /* #fff7f7 */
  --radius: 0.875rem;
}

[data-theme="sky"].dark, [data-theme="sky"] .dark {
  /* سماوي — Dark (mode 166:1) */
  --background: oklch(0.147 0.004 49.25);                     /* #0c0a09 */
  --foreground: oklch(0.986 0 0);                             /* #fbfaf9 */
  --card: oklch(0.214 0.009 43.066);                          /* #1d1816 */
  --card-foreground: oklch(0.986 0 0);                        /* #fbfaf9 */
  --popover: oklch(0.214 0.009 43.066);                       /* #1d1816 */
  --popover-foreground: oklch(0.986 0 0);                     /* #fbfaf9 */
  --primary: oklch(0.443 0.103 240.591);                      /* #005986 */
  --primary-foreground: oklch(0.977 0.012 236.62);            /* #f0f9ff */
  --secondary: oklch(0.274 0.005 286.033);                    /* #27272a */
  --secondary-foreground: oklch(0.985 0 0);                   /* #fafafa */
  --muted: oklch(0.268 0.011 36.494);                         /* #2b2422 */
  --muted-foreground: oklch(0.714 0.014 41.161);              /* #aba09c */
  --accent: oklch(0.443 0.103 240.591);                       /* #005986 */
  --accent-foreground: oklch(0.977 0.012 236.62);             /* #f0f9ff */
  --destructive: oklch(0.704 0.188 22.146);                   /* #ff6568 */
  --border: oklch(1.0 0 0 / 10%);                             /* #ffffff1a */
  --input: oklch(1.0 0 0 / 15%);                              /* #ffffff26 */
  --ring: oklch(0.547 0.021 43.085);                          /* #7c6d67 */
  --chart-1: oklch(0.829 0.107 230.092);                      /* #78d4ff */
  --chart-2: oklch(0.684 0.15 237.277);                       /* #00a5ea */
  --chart-3: oklch(0.587 0.139 241.87);                       /* #0084c7 */
  --chart-4: oklch(0.5 0.121 242.967);                        /* #0069a2 */
  --chart-5: oklch(0.443 0.103 240.591);                      /* #005986 */
  --sidebar: oklch(0.214 0.009 43.066);                       /* #1d1816 */
  --sidebar-foreground: oklch(0.986 0 0);                     /* #fbfaf9 */
  --sidebar-primary: oklch(0.684 0.15 237.277);               /* #00a5ea */
  --sidebar-primary-foreground: oklch(0.293 0.066 242.909);   /* #052f4a */
  --sidebar-accent: oklch(0.268 0.011 36.494);                /* #2b2422 */
  --sidebar-accent-foreground: oklch(0.986 0 0);              /* #fbfaf9 */
  --sidebar-border: oklch(1.0 0 0 / 10%);                     /* #ffffff1a */
  --sidebar-ring: oklch(0.547 0.021 43.085);                  /* #7c6d67 */
  --link: oklch(0.62 0.12 240.963);                           /* #358ec7 */
  --primary-subtle: oklch(0.222 0.045 242.699);               /* #051d2e */
  --destructive-subtle: oklch(0.239 0.055 25.487);            /* #351311 */
}

@layer base {
  * { @apply border-border outline-ring/50; }
  html { @apply bg-background text-foreground font-sans antialiased; }
  h1, h2, h3, .display { @apply font-display; }
  .label { @apply font-label; }
  .num { font-variant-numeric: tabular-nums; unicode-bidi: isolate; }
}

/* Self-hosted fonts — never Google Fonts (unreachable from Syria). Files in apps/web/public/fonts/ */
@font-face { font-family: "Tajawal"; font-weight: 400; font-display: swap; src: url("/fonts/tajawal-400.woff2") format("woff2"); }
@font-face { font-family: "Tajawal"; font-weight: 500; font-display: swap; src: url("/fonts/tajawal-500.woff2") format("woff2"); }
@font-face { font-family: "Tajawal"; font-weight: 700; font-display: swap; src: url("/fonts/tajawal-700.woff2") format("woff2"); }
@font-face { font-family: "Tajawal"; font-weight: 800; font-display: swap; src: url("/fonts/tajawal-800.woff2") format("woff2"); }
@font-face { font-family: "Cairo";   font-weight: 500; font-display: swap; src: url("/fonts/cairo-500.woff2") format("woff2"); }
@font-face { font-family: "Cairo";   font-weight: 600; font-display: swap; src: url("/fonts/cairo-600.woff2") format("woff2"); }
@font-face { font-family: "Cairo";   font-weight: 700; font-display: swap; src: url("/fonts/cairo-700.woff2") format("woff2"); }
@font-face { font-family: "IBM Plex Mono"; font-weight: 500; font-display: swap; src: url("/fonts/ibm-plex-mono-500.woff2") format("woff2"); }
/* Display stand-in until the Tufuli Arabic files arrive (OFL, self-hosted) */
@font-face { font-family: "Baloo Bhaijaan 2"; font-weight: 600; font-display: swap; src: url("/fonts/baloo-bhaijaan2-600.woff2") format("woff2"); }
@font-face { font-family: "Baloo Bhaijaan 2"; font-weight: 700; font-display: swap; src: url("/fonts/baloo-bhaijaan2-700.woff2") format("woff2"); }
@font-face { font-family: "Baloo Bhaijaan 2"; font-weight: 800; font-display: swap; src: url("/fonts/baloo-bhaijaan2-800.woff2") format("woff2"); }
/* When licensed: drop the three files in /fonts and add (weights as delivered) */
/* @font-face { font-family: "Tufuli Arabic"; font-weight: 700; font-display: swap; src: url("/fonts/tufuli-arabic-700.woff2") format("woff2"); } */
```

Orange/sky blocks were converted from the sRGB values stored in Figma (the preset's original OKLCH was gamut-mapped there), so they reproduce the Figma render exactly. Alpha borders in dark mode are `oklch(1 0 0 / 10%)` / `15%` in all presets.

## 3. Token usage rules (enforced by the `check-frontend-rules` hook)
1. Colours **only** through token utilities: `bg-primary`, `text-muted-foreground`, `border-border`, `bg-primary-subtle`, `text-link`, `bg-destructive-subtle`, `bg-sidebar-primary`. Never `#hex`, `oklch()`, `rgb()`, `bg-[#…]`, `text-red-600` or any Tailwind palette colour in components.
2. **Links and coloured text in dark mode use `text-link`, never `text-primary`** — rose dark primary on the page background is 1.8:1. Found on 26 text nodes during the Figma QA; the hook now blocks `<a className="text-primary">`.
3. Callout surfaces use `bg-primary-subtle` / `bg-destructive-subtle`, never `bg-primary-foreground` (it stays light pink in dark mode → glowing white card).
4. Card on page must differ: page `bg-background`, cards `bg-card` + `border-border`.
5. Radii: only `rounded-sm|md|lg|xl|2xl|full` (mapped from `--radius`; the preset decides the base, never the component).
6. Charts: `chart-1..5` only. Status colouring via `primary` / `destructive` / `muted`.
7. `accent` equals `primary` in every preset — use it only where shadcn components expect it (hover states); emphasis comes from size and surface, not a third hue.

## 4. RTL rules (enforced by hook)
- Only logical utilities: `ms-* me-* ps-* pe-* start-* end-* text-start text-end rounded-s-* rounded-e-* border-s border-e inset-s inset-e scroll-ms-*`. Forbidden: `ml- mr- pl- pr- left- right- text-left text-right rounded-l- rounded-r- border-l border-r float-left float-right`.
- Direction-implying icons (arrows, chevrons) flip with `rtl:-scale-x-100`, or use `ChevronStart`/`ChevronEnd` wrappers from `packages/ui`.
- Numbers, phones, codes inside Arabic text: `<bdi>` or `.num` (`unicode-bidi: isolate`); phone and OTP inputs get `dir="ltr"`.
- Flex/grid order: DOM order + `dir`, never manual reversal (Figma needed reversed insertion because it has no RTL mode — the browser does not).
- Sheets/drawers open from the **start** side (`side="start"` in our `Sheet` wrapper); the driver failure sheet opens from the top (`side="top"`).
- Sidebar (staff/admin/IT) sits on the **right**, leading icon on the right of each nav item.

## 5. Typography (Figma local text styles — 100 % of text nodes are bound to them; verified + updated 2026-08-22)

| Style | Font in Figma today | Font in code | Size | Role |
|---|---|---|---|---|
| `display/2xl` | **Baloo Bhaijaan 2 ExtraBold** (stand-in) | `font-display` 800 → Tufuli Arabic | 30 / lh 140 % | hero titles |
| `heading/xl` | **Baloo Bhaijaan 2 Bold** (stand-in) | `font-display` 700 → Tufuli Arabic | 24 / 34 | page titles, KPI numbers |
| `heading/lg` | **Baloo Bhaijaan 2 SemiBold** (stand-in) | `font-display` 600 → Tufuli Arabic | 20 / 30 | section titles |
| `heading/md` | Tajawal Bold | `font-sans` 700 | 16 | card titles, wordmark |
| `body/lg` · `body/md` · `body/md-med` · `body/sm` | Tajawal Regular / Medium | `font-sans` 400 / 500 | 16 · 14 · 14 · 12 | running text |
| `label/sm` · `label/xs` | Cairo SemiBold / Medium | `font-label` 600 / 500 | 12 · 11 | chips, badges, table headers |
| `price/lg` | Cairo Bold | `font-label` 700 `.num` | 18 | prices |
| `mono/sm` | IBM Plex Mono Medium | `font-mono` 500 | 12 | order numbers, codes, correlation ids |
| `kufi/*` | Tajawal (QA experiment only) | — | — | page `10 · Typografie QA`, not used on screens |

Decision: **Tajawal** for text, **Tufuli Arabic** for main headings (display/2xl, heading/xl, heading/lg). Tufuli is a commercial font — not on Google Fonts and not in Figma's library — so:
- Figma uses **Baloo Bhaijaan 2** (rounded, friendly, closest free match) on those three styles; the style descriptions say so. Swapping to Tufuli later is one operation on `figma.getLocalTextStylesAsync()` once the font is installed locally in the desktop app.
- Code ships Baloo Bhaijaan 2 (OFL, self-hosted) as the stand-in *and* the fallback in `--font-display`; when Mohamad supplies the Tufuli files, add the `@font-face` lines (commented in §2.1) — no component changes.
- Display/heading styles must not mix words and prices; prices use `price/lg` (`font-label .num`). KPI numbers in `heading/xl` are acceptable (verified on `/admin` `126:2062`).
- Western digits everywhere (`ar-SY-u-nu-latn`), tabular in tables. Minimum body 14px; labels 12px only in chips/badges.

## 6. Spacing, layout, breakpoints
- Spacing scale = Figma `space/1…16` (4 8 12 16 20 24 32 40 48 64) → Tailwind `1 2 3 4 5 6 8 10 12 16`. Page gutters `px-4` mobile, `px-6` tablet, `px-8` desktop.
- Customer (Figma frames 390×844): mobile-first, `max-w-screen-lg` on desktop. Staff/IT frames 1280×860, Admin 1440×900: desktop-first, tablet ≥ 768 with collapsible sidebar. Driver: mobile only, 44×44 touch targets, primary action sticky bottom.

## 7. shadcn/ui operating rules
- Init once: `pnpm dlx shadcn@latest init --preset b4iTphWki --template start --monorepo --rtl --pointer`, then replace the generated token block with §2.1 (the preset *is* the rose theme; we add the orange/sky blocks and the derived tokens).
- Add components only via `pnpm dlx shadcn@latest add <name>` from `apps/web`; they land in `packages/ui`. Edit after generation, never hand-copy. `pnpm dlx shadcn@latest info` before large UI tasks, `--diff` before updates.
- Component sets that exist in Figma `02 · Components`: `Button 39:52` (24 variants), `Badge 41:10`, `Input 41:24`, `Card 42:2`, `Label 64:14`, `Separator 64:23`, `Textarea 64:37`, `Switch 64:51`, `Avatar 64:64`, `Select 67:37`, `TabsTrigger 67:47`, `ToggleGroupItem 67:57`, `InputOTPSlot 67:69`, `Icon 60:476` (65 Lucide v1.31.0 names — use the same names with `lucide-react`), project components `app/NavItem 36:8`, `app/BottomTab 36:19`, `app/ProductCard 43:20`.

## 8. Accessibility
- Every preset is contrast-audited in both modes; the server gate (§2) keeps it that way after admin changes. Focus ring `ring-ring`. Form errors wired with `aria-describedby`. Status badges carry text, not colour only. OTP input announces remaining attempts. Driver screens readable in sunlight: body ≥ 16px, primary buttons ≥ 48px tall.

## History
- 2026-08-19: rose / orange / sky presets audited and added as Figma modes.
- 2026-08-20: Stone/Green + emerald primary, brand-mark components and the name «تشرين مول» tried — **reverted by Mohamad**; not part of the design.
- 2026-08-22: headings moved to Tufuli Arabic (Baloo Bhaijaan 2 stand-in in Figma and code).
