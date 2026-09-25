# HR Control Plane Mockup — design exploration idea

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md), [BrandKit](../../../docs/brand/README.md) |

**This is an internal design exploration, not one of GF's 19 stated use cases.** It does not appear in `GF_HR AI use case list.xlsx` and carries no `UC-nnnn` identifier for that reason — conflating it with the GF-sourced portfolio would misattribute an internal idea as GF-stated fact, which the evidence rules in [`README.md`](README.md) forbid.

## What this is

[`hr-control-plane-mockup.html`](hr-control-plane-mockup.html) is a static HTML mockup of an HR Employee Control Plane cockpit surface — the kind of operational dashboard [`docs/solution-design.md`](../../../docs/solution-design.md) describes for reviewing agent runs, field actions and exceptions. It is a visual exploration, not a built artefact, and nothing in the platform depends on it.

**Treat it as an idea to explore later.** It is not scheduled, not committed, and not part of the MVP (UC-0001, UC-0010, UC-0005). Revisit it once the control-plane app design in `docs/solution-design.md` §4.1 is ready to move from narrative to a concrete UI pass.

## A known discrepancy, flagged rather than silently fixed

This copy is **not identical** to the mockup already committed at [`docs/brand/hr-control-plane-mockup.html`](../../../docs/brand/hr-control-plane-mockup.html) — same structure and size, but two CSS variables carry older values that the BrandKit document explicitly records as corrected for accessibility:

| Variable | This copy | `docs/brand/` copy (corrected, canonical) |
|---|---|---|
| `--warning` | `#B85C00` | `#AF5700` — the BrandKit records the original as measuring 4.36:1 on its tint, just under WCAG AA |
| `--fg-3` | `#8A8886` | `#6E6C6A` — the BrandKit's documented "lightest grey permitted for text" |

**Do not treat this copy's colours as authoritative.** If this exploration is picked up, start from the `docs/brand/` copy's token values, not this file's.
