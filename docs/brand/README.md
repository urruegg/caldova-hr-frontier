# GF BrandKit — HR Agentic Platform

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Experience |
| **References** | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

> **Version 1.0.0 · 23 September 2026 · Status: Draft, pending GF Corporate Communications review**

Design tokens, Fluent 2 themes and asset guidance for every user-facing surface of the GF HR Agentic Platform — the HR Employee Control Plane App, agent cards in Teams, and any Power Apps code app built on this platform.

---

## ⚠️ Provenance — read before using these values

| What | Where it came from | Confidence |
|---|---|---|
| Primary blue `#1965A3` | Third-party brand aggregators, cross-checked across two independent GF domain entries | **Good, not authoritative** |
| Secondary blues `#4AA6E5`, `#33ADFF` | Same source | Good |
| Dark anchor `#000115` | Same source | Good |
| Heritage accent `#6D3518` | Same source | Low — purpose unclear, not used in this kit |
| Typography | **Not established.** No corporate web font was confirmed | **Unknown — see §3** |
| Logo | **Not included.** See §5 | — |

**These are derived values, not GF's official corporate design manual.** They are close enough to build and demonstrate with, and they must be replaced with the authoritative palette before anything is presented as GF-branded externally. Ask GF Corporate Communications for the CD manual and swap the tokens — the token layer exists precisely so that is a one-file change.

---

## 1. Brand colour

**Primary: `#1965A3`** — a deep, confident blue. It carries 6.05:1 contrast against white, which clears WCAG AA for body text *and* for white text on a filled button. That is unusually convenient: the primary works for both text links and filled actions without needing a second tone.

### The ramp

Sixteen steps, Fluent's convention, generated around the primary at step 60.

| Token | Hex | Use |
|---|---|---|
| `--gf-brand-10` | `#04121E` | Darkest — dark-mode text on brand tint |
| `--gf-brand-20` | `#08243C` | |
| `--gf-brand-30` | `#0C3559` | Header bar (dark chrome) |
| `--gf-brand-40` | `#104776` | Pressed state |
| `--gf-brand-50` | `#145893` | Hover state |
| **`--gf-brand-60`** | **`#1965A3`** | **PRIMARY** — filled buttons, links, selected nav, focus ring |
| `--gf-brand-70` | `#2C76B0` | |
| `--gf-brand-80` | `#4488BE` | |
| `--gf-brand-90` | `#5F9ACB` | |
| `--gf-brand-100` | `#7CACD8` | **Dark-mode primary** — 7.28:1 on dark surface |
| `--gf-brand-110` | `#99BFE4` | |
| `--gf-brand-120` | `#B5D1EC` | |
| `--gf-brand-130` | `#CFE1F3` | Selected row background |
| `--gf-brand-140` | `#E2EDF8` | Subtle brand tint |
| `--gf-brand-150` | `#EFF5FB` | Hover tint |
| `--gf-brand-160` | `#F7FAFD` | Lightest wash |

### Secondary

| Token | Hex | Use |
|---|---|---|
| `--gf-accent-sky` | `#4AA6E5` | Data visualisation, the *agent reasoning* emphasis |
| `--gf-accent-bright` | `#33ADFF` | Charts only — too light for UI text |
| `--gf-ink` | `#000115` | Dark-mode canvas anchor |

> **`#6D3518` (walnut) is deliberately unused.** It appears in aggregator data with no stated purpose, and a warm brown against this blue would read as an error state. Leave it out until GF confirms what it is for.

### Semantic colours — keep Fluent's

Do not brand these. Fluent's semantic set is accessibility-tuned, and users read them faster because they match every other Microsoft surface.

| Meaning | Hex | Contrast on its tint | Use |
|---|---|---|---|
| Success | `#0F7B3F` | 5.02:1 | Completed runs, resolved exceptions |
| Warning | `#AF5700` | 4.76:1 | Low confidence, capacity approaching limit, ageing items |
| Danger | `#A4262C` | 6.67:1 | Blocked, failed, refusal test failing |
| Info | `#0F6CBD` | 4.94:1 | Informational states — **kept distinct from the brand blue** |

> **Two corrections made after building the control plane, recorded rather than quietly changed.**
>
> **Warning was `#B85C00`.** Fluent's own amber, but on its warm tint it measures **4.36:1** — just under AA. Darkened to `#AF5700`, which is visually indistinguishable at pill size and clears at 4.76:1. The original value is still correct on white (4.60:1); it only fails on the tint, which is exactly where the app uses it.
>
> **Info was specified as the brand blue.** That looked elegant on paper — one fewer colour — and it failed in practice. The app uses `pill-brand` for *Live · PROD* and `pill-info` for *Low Confidence*; making them the same blue erased a distinction users need. Info stays Fluent's `#0F6CBD`.

---

## 2. Neutrals

Fluent's grey ramp, unmodified. A branded neutral ramp is the most common way an enterprise app starts to look wrong.

| Token | Hex | Use |
|---|---|---|
| `--gf-canvas` | `#FAF9F8` | App background |
| `--gf-surface` | `#FFFFFF` | Cards, panels, tables |
| `--gf-surface-alt` | `#F3F2F1` | Zebra rows, hover |
| `--gf-stroke` | `#E1DFDD` | Borders, dividers |
| `--gf-stroke-strong` | `#C8C6C4` | Input borders |
| `--gf-text-secondary` | `#605E5C` | Labels, metadata |
| `--gf-text-tertiary` | `#6E6C6A` | Captions, ghost pills, section labels — **the lightest grey permitted for text** |
| `--gf-text` | `#242424` | Body text |
| `--gf-text-strong` | `#1B1A19` | Headings |

---

## 3. Typography

**GF's corporate web font is not established.** Rather than guess, this kit specifies the correct choice for the platform it runs on:

```css
font-family: "Segoe UI Variable Display", "Segoe UI Variable Text",
             "Segoe UI", system-ui, -apple-system, sans-serif;
```

That is right for three independent reasons: it is Fluent 2's own type, it is present on every Windows desktop GF runs, and a Power Apps code app inherits it without a web-font download.

**If GF's CD manual names a corporate font, add it ahead of Segoe UI in this stack and keep Segoe as the fallback** — do not swap it out entirely, because the corporate font may lack the weights Fluent's ramp needs.

### The ramp

| Token | Size / line | Weight | Use |
|---|---|---|---|
| Caption1 | 12 / 16 | 400 | Metadata, timestamps |
| Caption1Strong | 12 / 16 | 600 | Table column headers |
| Body1 | 14 / 20 | 400 | Default body and table cells |
| Body1Strong | 14 / 20 | 600 | Emphasis, row primary values |
| Subtitle2 | 16 / 22 | 600 | Card titles |
| Subtitle1 | 20 / 26 | 600 | Section headings |
| Title3 | 24 / 32 | 600 | Screen titles |
| Title2 | 28 / 36 | 600 | Page hero |

Numerals in data tables use `font-variant-numeric: tabular-nums`. Columns of figures that do not align read as careless, and this app is full of them.

---

## 4. Shape, elevation, spacing

| Token | Value |
|---|---|
| `--gf-radius-sm` | `2px` — badges, pills |
| `--gf-radius` | `4px` — buttons, inputs, cards |
| `--gf-radius-lg` | `8px` — panels, dialogs |
| `--gf-shadow-2` | `0 1px 2px rgba(0,0,0,.14), 0 0 2px rgba(0,0,0,.12)` |
| `--gf-shadow-4` | `0 2px 4px rgba(0,0,0,.14), 0 0 2px rgba(0,0,0,.12)` |
| `--gf-shadow-8` | `0 4px 8px rgba(0,0,0,.14), 0 0 2px rgba(0,0,0,.12)` |
| `--gf-shadow-64` | `0 32px 64px rgba(0,0,0,.24), 0 0 8px rgba(0,0,0,.20)` — dialogs |

**Spacing is a 4px grid.** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40. Card padding 16–20. Section gaps 24–32.

---

## 5. Logo — a slot, not an asset

> **No GF logo file is included in this repository, and none should be added without Corporate Communications' written approval.**

The mark is a registered trademark. Sourcing it from a logo aggregator gives you an unlicensed, often outdated, sometimes visually wrong file — and ships it inside a customer deliverable.

**What is implemented instead:** a typographic wordmark in the brand blue, occupying the exact dimensions the real mark will use. It is a placeholder and reads as one.

### Swapping in the real asset

1. Obtain the official SVG (horizontal lockup, light **and** dark variants) from GF Corporate Communications
2. Place in `docs/brand/assets/` as `gf-logo.svg` and `gf-logo-dark.svg`
3. Replace the `.gf-logo` element's contents; keep the slot dimensions — 28px height, clear space equal to the cap height on all sides
4. Confirm minimum size and clear-space rules against the CD manual

**Never** recolour, stretch, rotate, outline or place the mark on a busy background. In this app it sits on the dark header bar, which is why a dark-background variant is needed.

---

## 6. Fluent 2 theme

Two files implement everything above:

| File | For |
|---|---|
| [`gf-tokens.css`](gf-tokens.css) | CSS custom properties — HTML mockups, Power Pages, any non-React surface |
| [`gf-fluent-theme.ts`](gf-fluent-theme.ts) | A `BrandVariants` ramp plus light and dark themes for `@fluentui/react-components` — **this is what the Power Apps code app uses** |

Usage in a code app:

```tsx
import { FluentProvider } from "@fluentui/react-components";
import { gfLightTheme, gfDarkTheme } from "./theme/gf-fluent-theme";

<FluentProvider theme={prefersDark ? gfDarkTheme : gfLightTheme}>
  <App />
</FluentProvider>
```

**Do not hand-write hex values in components.** Every colour comes from a token, so replacing the derived palette with GF's authoritative one is a single-file change rather than an archaeology project.

---

## 7. Dark mode

Implemented and required — Windows users who set dark at OS level expect apps to follow, and an HR cockpit is often open all day.

| | Light | Dark |
|---|---|---|
| Canvas | `#FAF9F8` | `#1B1A19` |
| Surface | `#FFFFFF` | `#252423` |
| Stroke | `#E1DFDD` | `#3B3A39` |
| Text | `#242424` | `#F3F2F1` |
| Brand | `#1965A3` | `#7CACD8` |

The brand shifts from step 60 to step 100 in dark mode. Using the light-mode blue on a dark surface fails contrast — 2.1:1 against `#1B1A19`.

---

## 8. Language

The platform ships in **EN · DE · IT · FR · ES** — the Swiss national languages, plus English as the corporate language and Spanish for GF's Iberian and Latin American operations. Default is **EN**; the MVP operates in Switzerland, so **DE** is the most likely working language and must be treated as a first-class locale, not a translation afterthought.

Three rules:

1. **German compounds run long.** *Personalstammdaten-Vervollständigung* is 38 characters against 24 for "Master Data Completion". Every layout is tested at German length; nothing is sized to fit English.
2. **Do not translate identifiers.** `UC-0001`, `FR-0013`, `ADR-0007`, `RUN-2026-0923-04`, `gf_fieldaction`, Workday field names and the approved field list stay in their source form in every locale. A translated identifier cannot be traced.
3. **Dates and numbers follow the locale** — `23.09.2026` in DE, `23/09/2026` in FR and IT, `23 September 2026` in EN.

---

## 9. What not to do

| Don't | Why |
|---|---|
| Brand the neutral ramp | The fastest way to make an enterprise app look off. Fluent's greys are calibrated |
| Recolour semantic states to brand blue | Users read success/warning/danger by colour before they read the word |
| Add a gradient hero banner | Not Fluent, and this is a work surface — the data is the hero |
| Use brand blue for large filled areas | At scale a 6:1 colour overwhelms. Chrome, actions and emphasis only |
| Source the logo from an aggregator | Unlicensed, often outdated, sometimes wrong |
| Introduce a sixth accent | Every colour added is one more thing a user has to learn |
