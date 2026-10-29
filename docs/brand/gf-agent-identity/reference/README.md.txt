# GF HR agent identity package

Version 1.0.0 · 2026-10-28 · proposal for GF approval

Naming convention, colour schema and icons for all **37 HR agents** of the Georg Fischer HR agentic blueprint (6 journeys, MVP 1-3 included), ready to drop into GF's repository and the Copilot Studio harness solution. Every name, colour and icon is generated from one config file and checked by a validator, so GitHub Copilot and the pipelines can't drift from it.

![HR agent family](visuals/gf-hr-agent-family.png)

## The rule in one line

**Display name = `<PO> <Domain> [<Scope>] [DEV | TEST]`** - PO is the process-owner area, Domain is what the agent does, PROD carries no postfix. Technical names (schema, solution, variables, connection references, flows, folders) never carry an environment.

| Icon | MVP | GF working name | DEV | TEST | PROD | Schema name |
|---|---|---|---|---|---|---|
| <img src="agents/hr-policy-assistant/identity/color-192.png" width="40"> | MVP 1 | SSE HR Policy Assistant | `HR Policy Assistant DEV` | `HR Policy Assistant TEST` | **HR Policy Assistant** | `gf_HRPolicyAssistant` |
| <img src="agents/recruiting-job-posting/identity/color-192.png" width="40"> | MVP 2 | Recruiting: Job Requisition and Job Posting agent | `Recruiting Job Posting DEV` | `Recruiting Job Posting TEST` | **Recruiting Job Posting** | `gf_RecruitingJobPosting` |
| <img src="agents/hr-ops-master-data-ch/identity/color-192.png" width="40"> | MVP 3 | HR Operations Agent (Switzerland) | `HR Ops Master Data CH DEV` | `HR Ops Master Data CH TEST` | **HR Ops Master Data CH** | `gf_HROpsMasterDataCH` |

## Colours: one per journey, from GF's own palette

| Journey | Colour | Glyph | Contrast | PO area |
|---|---|---|---|---|
| D1 · Attract & Hire | GF Blue `#00629B` | `#FFFFFF` | 6.52:1 | Recruiting |
| D2 · Joiners, Movers & Leavers | GF Green `#007A53` | `#FFFFFF` | 5.37:1 | HR Ops |
| D3 · HR Operations & Service | GF Orange UI `#BC5A26` | `#FFFFFF` | 4.54:1 | HR Ops, HR Policy |
| D4 · Leadership & Workforce Insights | GF Petrol `#003E51` | `#FFFFFF` | 11.62:1 | People Analytics |
| D5 · Talent & Performance | GF Pale Green `#ADDC91` | `#003E51` | 7.42:1 | Talent |
| D6 · HR Agentic Factory | GF Graphite `#323232` | `#FFFFFF` | 12.82:1 | Factory |

DEV icons carry an orange band, TEST icons a light-blue band, PROD icons are clean. Details: `docs/color-schema.md`.

## What is inside

```text
README.md                         this file
docs/naming-convention.md         the rule, PO vocabulary, limits, where the postfix applies, technical names, decisions
docs/color-schema.md              GF palette sources, journey colours, contrast, usage rules
docs/icons-and-visuals.md         icon requirements, design, files and where to set them
docs/harness-integration.md       where files go in the repo, pipeline stages, DEV checklist, checks in GF DEV
docs/agent-identity-catalog.md    generated catalog of all agents with icons and cards
docs/evidence.md                  evidence and Microsoft documentation used
config/agent-identity.json        SOURCE OF TRUTH: tokens per agent + derived names (37 agents)
config/agent-identity.schema.json JSON schema for the config
config/palette.json               GF theme, journey colours, environment markers
brand/palette.css, gf-logo-*.png  CSS variables and the GF logo
agents/<slug>/identity/           per agent: identity.json, colour 192/32 (PROD, TEST, DEV), outline 32, SVG sources, card
visuals/                          agent family overview, MVP identity sheet, colour schema
scripts/build_identity_assets.py  regenerates names, icons, cards, visuals and the catalog
scripts/validate_identity.py      blocking checks for pull requests
scripts/stamp_identity.py         stamps environment names and icons into an unpacked solution before packing
scripts/tests/                    unit tests with a synthetic unpacked solution
pipelines/                        Azure Pipelines step template and GitHub Actions workflow
github/instructions/              GitHub Copilot instructions (copy to .github/instructions/)
```

## Quick start

```bash
python scripts/validate_identity.py                    # 0 errors expected
python -m unittest discover -s scripts/tests -v        # naming and stamping tests
python scripts/stamp_identity.py --env TEST --solution-dir <unpacked solution>   # dry run shows the changes
```
Change a name or colour: edit `config/agent-identity.json` or `config/palette.json`, then `python scripts/build_identity_assets.py` (needs Node.js and Playwright with Chromium) and validate again.

## Status

- Agents: 3 MVP, 6 Microsoft proposals, 8 factory agents, 17 hypotheses, 1 deferred, 1 later wave, 1 out of scope - as in the blueprint v0.4.
- Verified: Copilot Studio name limit and stamping rule (E44), icon rules (Microsoft Learn), Teams manifest limits, `bot.xml` elements in Microsoft's published samples, GF theme colours (E01).
- To verify in GF DEV: `bot.xml` of GF's first export, Teams/Microsoft 365 icon fields, schema-name suffix, ESS rename and icon (`docs/harness-integration.md` §6).
- Assumption: `<PO>` = process-owner area. Decisions N-1 to N-6 in `docs/naming-convention.md` §8, including the publisher prefix (G5).

No personal data, tenant identifiers or secrets are in this package; the test fixture is synthetic.
