# GF Handover - Historical Snapshot Pointer

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Superseded |
| **Scope** | Historical GF handover routing; not a current Caldova inventory |
| **References** | [Current Caldova handover](2026-10-29-caldova-project-handover-review.md), [Original GF inventory](evidence/2026-10-29-gf-handover/artifact-manifest.json) |

The maintained successor is the [Caldova project handover](2026-10-29-caldova-project-handover-review.md).
The eight project sets have been renamed and repurposed for Caldova. GF remains
explicitly identified source/customer context, not Caldova corporate identity or
approval.

The original full GF handover and its original package paths remain recoverable
at commit `a4e4fbcf2cbf84162c1b2e7d6663fe26ad162cd3`:

```powershell
git --no-pager show 'a4e4fbcf2cbf84162c1b2e7d6663fe26ad162cd3:docs/reviews/2026-10-29-gf-project-handover-review.md'
```

The unchanged [521-record GF inventory](evidence/2026-10-29-gf-handover/artifact-manifest.json)
belongs only to that snapshot. Its old paths/hashes do not certify the current
renamed tree. Do not repair those historical records to match current files or
treat them as missing current deliverables. The separate current
[27-document rename map](evidence/2026-10-29-caldova-document-migration/rename-map.json)
records the migration instead.

This pointer does not approve GF acceptance, public disclosure, source copying,
runtime deployment or any change to the original source/licensing restrictions.
