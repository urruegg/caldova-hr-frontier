# GF HR Agent Identity Kit - Grounded Repository Intake

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF Copilot Studio agent identity: grounded names, palette, icons, source provenance and adoption gates |
| **References** | [Brand index](../README.md), [Adoption specification](../../specs/2026-10-29-gf-agent-identity-kit-design.md), [Sprint](../../plans/2026-10-29-gf-agent-identity-kit-sprint.md), [Identity configuration](config/agent-identity.json), [Palette](config/palette.json), [Bindings](agent-bindings.json), [Intake manifest](intake-manifest.json) |

## 1. Authority and source fidelity

This is the curated intake of **GF HR agent identity package v1.0.0, dated 2026-10-28**, supplied locally by the repository owner. The owner reports GF's written approval to adapt the kit for the agents. No approval document/reference was supplied. The original source still says "proposal for GF approval" and lists unresolved decisions; those facts are preserved rather than rewritten.

The kit is the required grounded identity reference for current and future **GF Copilot Studio runtime designs**. The four adopted identity mappings below were explicitly confirmed in conversation. Source approval, adaptation approval, technical-name decisions and verified tenant application are separate matters. This README does not certify deployment or close the source's N-1 through N-6/G5 decisions.

The intake keeps 466 source files byte-for-byte, with source/destination paths, size and SHA256 in the manifest: 442 configuration/identity/brand/visual files and 24 inactive reference files. Original Markdown, scripts, fixtures, pipelines and instructions are preserved under `reference/` with a `.txt` suffix. They are **not installed automation or active Copilot instructions**.

Local Git attributes disable line-ending conversion only for these imported
subtrees, so Windows/Unix checkout does not invalidate source hashes. Maintained
guidance and repository-wide Git settings are not changed by that protection.

The existing Caldova CSS/Fluent theme, demo application, mockups and reserved Caldova logo slot remain unchanged. This GF kit does not globally replace the demo theme or establish a corporate design manual.

## 2. Catalogue and reading order

| Resource | Purpose | Authority |
|---|---|---|
| [Bindings](agent-bindings.json) | Connects four repository designs to stable kit identity IDs | Confirmed identity mappings, not approval of deployment or source behavior |
| [Identity configuration](config/agent-identity.json) and [schema](config/agent-identity.schema.json) | Source tokens, derived names, descriptions and full catalogue | Supplied versioned source; generated values are not hand-edited |
| [Palette JSON](config/palette.json) and [CSS](brand/palette.css) | Source colours, journey mapping and environment markers | Derived GF Office-theme/website evidence as reported by the kit, not independently inspected primary brand material |
| [Agent assets](agents/) | Per-agent JSON, PNG/SVG and visual cards | Grounded visual assets with retained source scope/status |
| [Family overview](visuals/gf-hr-agent-family.png), [MVP identity sheet](visuals/gf-hr-mvp-identity-sheet.png), [colour sheet](visuals/gf-hr-colour-schema.png) | Supplied visual reference | Includes hypotheses/deferred/out-of-scope identities; not a committed delivery portfolio |
| [Original README](reference/README.md.txt), [naming](reference/docs/naming-convention.md.txt), [colours](reference/docs/color-schema.md.txt), [icons](reference/docs/icons-and-visuals.md.txt), [evidence](reference/docs/evidence.md.txt) | Original authored guidance, unchanged | Source facts/proposals remain distinct from this repository's integration |
| [Harness integration reference](reference/docs/harness-integration.md.txt) | Source's proposed layout/stamping/ESS paths | Not applied: target GitHub-harness source and immutable-release contracts need verification |
| [Third-party notices](reference/THIRD-PARTY-NOTICES.md.txt) | MIT notice for Fluent glyphs and GF trademark statement | Must accompany copied/adapted assets; not a general license for every package file or GF trademark |
| [Intake manifest](intake-manifest.json) | Exact imported inventory and provenance | Detects byte drift; a matching hash is not approval or a security/tenant proof |

Read this README and the bindings before source-specific guidance. Original `.txt` reference files retain their original relative-path examples; use this maintained catalogue for actual repository locations.

## 3. Adopted identities

| Design / source ID | DEV | TEST | PROD | Journey / glyph |
|---|---|---|---|---|
| Policy / D3-A01 | HR Policy Assistant DEV | HR Policy Assistant TEST | HR Policy Assistant | D3 orange; book-question-mark |
| Recruiting / D1-A01 | Recruiting Job Posting DEV | Recruiting Job Posting TEST | Recruiting Job Posting | D1 blue; megaphone |
| HR Operations / D2-A01 | HR Ops Master Data CH DEV | HR Ops Master Data CH TEST | HR Ops Master Data CH | D2 green; contact-card |
| ESS-equivalent / D3-A02 | HR Ops Self-Service DEV | HR Ops Self-Service TEST | HR Ops Self-Service | D3 orange; person-chat |

Use the corresponding per-agent `identity.json` and `icon.files.<ENV>` paths, not a copied name/hex/string assembled in implementation code. DEV/TEST display names and icon bands distinguish environments; PROD has neither postfix nor band.

The source contains **37 identities: 29 environment-scoped runtime identities and 8 repository-agent identities**, not 37 approved runtime agents. Technical work packages have no Copilot Studio identity. Existing repository-working agents, including Blueprint Maintainer, are not renamed or recoloured by this intake.

The source's `kind: ess`, later-wave status, descriptions and old platform advice do not override current specifications. In particular D3-A02 is the approved identity mapping for the new ESS-equivalent; its six-operation scope and safety gates remain in that specification. Do not copy stale source descriptions into a published agent without content review.

New GF runtime agents must resolve to an explicitly reviewed source identity or an approved extension with generated assets. An unmapped agent is an identity-readiness blocker; never invent a new display name, colour, glyph, stable ID or approval.

## 4. Rules and palette

Source display pattern: `<PO> <Domain> [<Scope>] [DEV | TEST]`. Source limits are 30 characters per display name and 25 for the base name, reserving room for ` TEST`. Domain tokens describe the task, not "Agent"/"Bot"/"Copilot". `<PO>` is source-proposed as process-owner area; its formal interpretation remains a stakeholder decision.

| Journey | Icon background | Glyph | Source-reported contrast |
|---|---|---|---|
| D1 Attract & Hire | `#00629B` | `#FFFFFF` | 6.52:1 |
| D2 Joiners, Movers & Leavers | `#007A53` | `#FFFFFF` | 5.37:1 |
| D3 HR Operations & Service | `#BC5A26` | `#FFFFFF` | 4.54:1 |
| D4 Leadership & Workforce Insights | `#003E51` | `#FFFFFF` | 11.62:1 |
| D5 Talent & Performance | `#ADDC91` | `#003E51` | 7.42:1 |
| D6 HR Agentic Factory | `#323232` | `#FFFFFF` | 12.82:1 |

The imported configuration, not this explanatory table, supplies values. Recompute contrast in validation. Colours identify journeys, not success/warning/failure or release approval. Provide labels and accessible names; the tiny band alone is insufficient to identify an environment. The kit does not establish a complete accessible dark-mode application theme.

Runtime colour icons are supplied as 192x192 and 32x32 PNG with DEV/TEST/PROD variants; outline is 32x32, white with transparency. Source icon payload target is at most 100 KiB. Preserve aspect ratio, flat background, safe glyph area and source files. Card/overview images are visual references, not agent-icon payloads.

Technical identifiers remain environment-neutral. **Do not rename existing schema/solution/connection/workflow names** from this intake. The source's default `gf` is not resolution of N-3/G5 (`gf` versus `gfhr`), and its solution-name examples are not migration instructions.

## 5. Licence, brand and privacy boundary

The Fluent UI System Icons notice is MIT and retained verbatim. GF logos are trademarks according to the supplied notice; source visuals/cards also include GF branding. They are supplied references for authorized GF adaptation/handover, not a public-distribution licence or permission to create new logo variants.

No Caldova logo has been added. Do not claim the GF package is the licensed Caldova corporate identity or use the kit to bypass source/brand-owner review. Production logo/use approval and required notices travel with the handover.

The source evidence register is a reported provenance summary; the underlying GF deck/SOP and brand portal were not inspected here. Do not copy personal data, tenant values, private approval correspondence or credentials into identity records.

## 6. Automation admission and validation

Upstream scripts and pipeline templates are preserved as reference-only text. No workflow was added, no source stamp/regeneration command is installed, and no agent/schema/solution has been renamed.

Before admitting a stamper, prove supported GitHub-harness source/manifest fields, exact unique schema matching, complete required name/icon fields, no missing/unknown component success, atomic all-or-nothing writes, drift detection and unchanged unrelated content. The supplied stamper's broad suffix matching and success/warning behavior do not establish those guarantees.

The source's TEST/PROD stamping and pack-once advice must be reconciled with the reviewed release-artifact policy. Environment-dependent identity bytes mean TEST and PROD packages are not identical; do not silently claim the same artifact was tested/promoted or activate production scope.

Run the local intake test:

```powershell
Import-Module Pester -RequiredVersion 5.7.1
$result = Invoke-Pester -Path '.github\cli\tests\GfAgentIdentity.Tests.ps1' -Output Detailed -PassThru
if ($result.Result -ne 'Passed') { throw 'GF identity intake validation failed.' }
```

It validates actual imported hashes/inventory, supplied JSON schema, names, environment rules, bindings, icon presence/dimensions/size, SVG external-content exclusion and palette contrast. This is **static intake proof**, not icon rendering quality, complete pixel-level opacity certification, host instruction loading, tenant stamping or deployed Teams/M365 read-back.

The older anonymization branding scanner already reported 87 findings before this intake and zero accepted historical exceptions. Its blanket GF-name prohibition conflicts with intentional customer content. This intake does not disable that guard or claim a clean full-repository branding gate; resolve a narrowly reviewed customer-identity scope policy before merge/public handover rather than using fabricated evidence exceptions.

Its unchanged unit suite also has two immutable-evidence exception failures
(18 passed, 2 failed), reproduced with the HEAD-equivalent module/tests in an
isolated scratch copy. These pre-existing failures are not repaired or hidden by
the identity-intake tests.

## 7. Handover

Use the [idea](../../ideas/gf-agent-identity-kit-idea.md), sprint, specification and implementation plan for the eighth handover package. Include imported source hashes, bindings, notices, actual validation results and unresolved decisions. Obtain authorized destination/disclosure review before transfer. No commit, push, tenant application or public publication is performed by this intake.
