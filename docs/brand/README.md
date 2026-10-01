# Caldova Product Theme — HR Agentic Platform

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-01 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Experience |
| **References** | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

Design tokens, Fluent 2 themes and asset guidance for every user-facing surface of the Caldova HR Agentic Platform — the HR Employee Control Plane App, agent cards in Teams, and any Power Apps code app built on this platform.

---

## ⚠️ Provenance — read before using these values

The inherited values are an **interim product palette pending an approved Caldova design standard**.
They are not an official corporate identity.
This migration changes names and provenance wording only; palette values,
contrast targets, semantic-state colours, and dark-mode behavior remain unchanged.

The token layer isolates these inherited values so an approved standard can
replace them without changing component code or accessibility behavior.

---

## 1. Brand colour

**Primary: `#1965A3`** — a deep, confident blue. It carries 6.05:1 contrast against white, which clears WCAG AA for body text *and* for white text on a filled button. That is unusually convenient: the primary works for both text links and filled actions without needing a second tone.

### The ramp

Sixteen steps, Fluent's convention, generated around the primary at step 60.

| Token | Hex | Use |
|---|---|---|
| `--caldova-brand-10` | `#04121E` | Darkest — dark-mode text on brand tint |
| `--caldova-brand-20` | `#08243C` | |
| `--caldova-brand-30` | `#0C3559` | Header bar (dark chrome) |
| `--caldova-brand-40` | `#104776` | Pressed state |
| `--caldova-brand-50` | `#145893` | Hover state |
| **`--caldova-brand-60`** | **`#1965A3`** | **PRIMARY** — filled buttons, links, selected nav, focus ring |
| `--caldova-brand-70` | `#2C76B0` | |
| `--caldova-brand-80` | `#4488BE` | |
| `--caldova-brand-90` | `#5F9ACB` | |
| `--caldova-brand-100` | `#7CACD8` | **Dark-mode primary** — 7.28:1 on dark surface |
| `--caldova-brand-110` | `#99BFE4` | |
| `--caldova-brand-120` | `#B5D1EC` | |
| `--caldova-brand-130` | `#CFE1F3` | Selected row background |
| `--caldova-brand-140` | `#E2EDF8` | Subtle brand tint |
| `--caldova-brand-150` | `#EFF5FB` | Hover tint |
| `--caldova-brand-160` | `#F7FAFD` | Lightest wash |

### Secondary

| Token | Hex | Use |
|---|---|---|
| `--caldova-accent-sky` | `#4AA6E5` | Data visualisation, the *agent reasoning* emphasis |
| `--caldova-accent-bright` | `#33ADFF` | Charts only — too light for UI text |
| `--caldova-ink` | `#000115` | Dark-mode canvas anchor |

> **`#6D3518` (walnut) is deliberately unused.** Its intended role is not
> defined by the current interim guidance, and a warm brown against this blue
> would read as an error state. Leave it out pending the approved standard.

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
| `--caldova-canvas` | `#FAF9F8` | App background |
| `--caldova-surface` | `#FFFFFF` | Cards, panels, tables |
| `--caldova-surface-alt` | `#F3F2F1` | Zebra rows, hover |
| `--caldova-stroke` | `#E1DFDD` | Borders, dividers |
| `--caldova-stroke-strong` | `#C8C6C4` | Input borders |
| `--caldova-text-secondary` | `#605E5C` | Labels, metadata |
| `--caldova-text-tertiary` | `#6E6C6A` | Captions, ghost pills, section labels — **the lightest grey permitted for text** |
| `--caldova-text` | `#242424` | Body text |
| `--caldova-text-strong` | `#1B1A19` | Headings |

---

## 3. Typography

The approved Caldova design standard does not yet define a product typeface.
Rather than guess, this theme uses the platform-native Fluent stack:

```css
font-family: "Segoe UI Variable Display", "Segoe UI Variable Text",
             "Segoe UI", system-ui, -apple-system, sans-serif;
```

That is right for three independent reasons: it is Fluent 2's own type, it is
available on supported Windows desktops, and a Power Apps code app inherits it
without a web-font download.

If the approved Caldova design standard names a product font, add it ahead of
Segoe UI in this stack and keep Segoe as the fallback.

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
| `--caldova-radius-sm` | `2px` — badges, pills |
| `--caldova-radius` | `4px` — buttons, inputs, cards |
| `--caldova-radius-lg` | `8px` — panels, dialogs |
| `--caldova-shadow-2` | `0 1px 2px rgba(0,0,0,.14), 0 0 2px rgba(0,0,0,.12)` |
| `--caldova-shadow-4` | `0 2px 4px rgba(0,0,0,.14), 0 0 2px rgba(0,0,0,.12)` |
| `--caldova-shadow-8` | `0 4px 8px rgba(0,0,0,.14), 0 0 2px rgba(0,0,0,.12)` |
| `--caldova-shadow-64` | `0 32px 64px rgba(0,0,0,.24), 0 0 8px rgba(0,0,0,.20)` — dialogs |

**Spacing is a 4px grid.** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40. Card padding 16–20. Section gaps 24–32.

---

## 5. Logo — a slot, not an asset

No logo asset is included. The mockup uses a typographic `Caldova` wordmark in
the existing 28px slot so layout and accessible text remain stable.

When an approved Caldova design standard supplies light- and dark-background
assets, place them in `docs/brand/assets/` as `caldova-logo.svg` and
`caldova-logo-dark.svg`. Replace the `.caldova-logo` contents without changing
the slot dimensions, and validate the supplied minimum-size and clear-space
rules before use.

---

## 6. Fluent 2 theme

Two files implement everything above:

| File | For |
|---|---|
| [`caldova-tokens.css`](caldova-tokens.css) | CSS custom properties — HTML mockups, Power Pages, any non-React surface |
| [`caldova-fluent-theme.ts`](caldova-fluent-theme.ts) | A `BrandVariants` ramp plus light and dark themes for `@fluentui/react-components` — **this is what the Power Apps code app uses** |

Usage in a code app:

```tsx
import { FluentProvider } from "@fluentui/react-components";
import { caldovaLightTheme, caldovaDarkTheme } from "./caldova-fluent-theme";

<FluentProvider theme={prefersDark ? caldovaDarkTheme : caldovaLightTheme}>
  <App />
</FluentProvider>
```

**Do not hand-write hex values in components.** Every colour comes from a token,
so adopting an approved Caldova design standard remains a token-layer change.

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

The platform supports **EN · DE · IT · FR · ES**. Default is **EN**; the MVP
operates in Switzerland, so **DE** is a first-class locale rather than a
translation afterthought.

Three rules:

1. **German compounds run long.** *Personalstammdaten-Vervollständigung* is 38 characters against 24 for "Master Data Completion". Every layout is tested at German length; nothing is sized to fit English.
2. **Do not translate identifiers.** `UC-0001`, `FR-0013`, `ADR-0007`, `RUN-2026-0923-04`, `caldova_fieldaction`, Workday field names and the approved field list stay in their source form in every locale. A translated identifier cannot be traced.
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
