# Azure Boards Population: Tracking the 19 HR Use Case Ideas as Epics

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (Tenant 1) |
| **References** | [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [Azure DevOps and GitHub Single Source of Truth](2026-09-24-azure-devops-github-single-source-of-truth-design.md), [Tenant Trust Activation Design](2026-09-24-tenant-trust-activation-design.md), [HR Use Case Portfolio](../../hr/docs/ideas/README.md), [`docs/prd.md`](../prd.md) |

## Status

Proposed Baseline, drafted and self-reviewed without a live approval round: the human partner who requested this sub-project was unavailable to answer clarifying questions during brainstorming, and explicitly asked to work autonomously and have the result reviewed later. Every place a normal brainstorming session would have asked a question is instead recorded below as a **Ruling** — the decision made, the reasoning, and what it costs if the reviewer disagrees. Nothing in this document authorizes a live change to Azure Boards; see Runbook.

## Objective

Populate Azure DevOps Boards for Tenant 1 with one work item per HR use case idea (19 total: `UC-0001` through `UC-0019`), so the portfolio already described in `hr/docs/ideas/README.md` is visible and reviewable in the single backlog ADR-0001 designates, each item linked back to its GitHub source document. This is the second of the two sub-projects the original request split into (the first, tenant trust activation, is `docs/plans/2026-09-24-tenant-trust-activation-runbook-implementation.md`, merged in PR #16).

## Context

- **The portfolio, not a backlog.** `hr/docs/ideas/README.md` states plainly: "Most of these are ideas, not requirements." Three (`UC-0001`, `UC-0005`, `UC-0010`) are MVP scope; fifteen are candidates with no commitment; only `UC-0001` has graduated to a folder with a PRD, and even its own Definition of Ready is not yet met per its PRD §13.
- **The repository's evidence rules apply here as much as anywhere.** "Never resolve an open decision by inference" and "do not describe any other use case as planned, scheduled or committed" (`hr/docs/ideas/README.md`) mean Azure Boards must reflect the portfolio's actual, current status — not a work breakdown nobody has approved.
- **No live discovery of Azure Boards' actual configuration exists yet.** Tenant 1's discovery evidence (`infra/evidence/discovery/caldova25156897.json`) captures the Azure DevOps project's identity, repositories, service endpoints, environments, pipelines, checks, and effective permissions — but not its process template or work item type capabilities. `infra/docs/13-azure-devops-engineering-control-plane.md` lists the process as `Agile` only as "Proposed if current evidence supports it; not created or changed here." Whether the project actually uses Agile (whose hierarchy is Epic → Feature → User Story → Task → Bug, matching ADR-0001's language exactly) is unconfirmed.
- **This sub-project depends on Tenant 1 access that does not exist yet.** Azure Boards work-item creation requires an authenticated Azure DevOps session — either the same OIDC trust the tenant-trust-activation runbook establishes, or a human operator's own interactive `az devops` session. Building and testing this sub-project's tooling does not require that access; running it live against Tenant 1 does.

## Ruling 1 — Work item type: one Epic per idea, nothing underneath

**Decision:** Represent each of the 19 ideas as exactly one `Epic` work item. Do not create any `Feature`, `User Story`, `Task`, or `Bug` beneath any of them, including `UC-0001`.

**Reasoning:** Only `UC-0001` has a PRD, and even its Definition of Ready is not met. Creating a work breakdown for the other 18 would invent scheduled work HR never committed to, which is exactly what `hr/docs/ideas/README.md` and this repository's evidence rules forbid. An Epic is the correct Azure Boards work item for "a large body of work that can be broken down" — it names the idea without pretending it is scheduled.

**Cost if wrong:** If the reviewer wants `UC-0001` (or the two other MVP-scope ideas) broken into Features once their PRDs exist, that is a small, additive follow-up — add Features under the existing Epic. Nothing here needs to be undone.

## Ruling 2 — "Linked" means a native Azure DevOps hyperlink relation, not prose text

**Decision:** Each Epic carries a `System.Description` of the idea's own one-line summary (the first non-blank paragraph line immediately following the `## 1. The Idea` heading that every idea file already has — verified present, in that exact form, in all 19 files during this design) as plain text, plus a native Azure DevOps `Hyperlink` relation (the REST API's `relations` array, `rel = "Hyperlink"`, `url` = `https://github.com/urruegg/caldova-hr-frontier/blob/main/hr/docs/ideas/<path>`) pointing at the idea's GitHub source document. This is the literal, verifiable meaning of "linked" that does not depend on the separate, attended-only Azure Boards↔GitHub App connection (`docs/specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md`) being installed.

**Reasoning:** A `Hyperlink` relation is Azure DevOps' own first-class mechanism for exactly this — it shows up as a distinct, clickable entry in the work item's "Links" tab and is queryable via WIQL, unlike a URL embedded in `Description` prose (which is an HTML-rendered rich-text field; comparing a plain string the tool wrote against what Azure DevOps returns after HTML-escaping is fragile and unnecessary to get right when a purpose-built relation type already exists). The GitHub App connection and the `AB#` commit convention link *future commits* to work items — they say nothing about linking an *existing* portfolio of ideas to their *existing* source documents today.

**Cost if wrong:** If the reviewer prefers the URL in `Description` instead of (or as well as) a `Hyperlink` relation, that is a one-line change to the plan/mutation functions' field-mapping, not a redesign — the plan JSON already names both fields independently.

## Ruling 3 — Status metadata is parsed from each idea's own file, not from README prose tables

**Decision:** Each idea document already carries a standard, structured blockquote immediately after its H1 — for example (`hr/docs/ideas/uc-0006-job-description-generator.md`):
```markdown
# UC-0006 — Job Description Generator
...
> **Status:** Idea — draft for review
> **Journey stage:** Hire
```
Parse `UseCaseId` and `Title` from the H1 line (`^#\s+(UC-\d{4})\s*[—-]\s*(.+)$`), and derive each Epic's status tag from the blockquote's `**Status:**` line by substring match, in this priority order — checked against the 19 real files during this design, not assumed:
1. Contains `Selected as MVP` → tag `MVP` (matches only `UC-0001`).
2. Contains `IN MVP SCOPE` → tag `MVP-Candidate` (matches `UC-0005`, `UC-0010`).
3. Contains `Runs alongside the MVP` → tag `MVP-Adjacent` (matches only `UC-0002` — explicitly "recommended, not counted" in the MVP, which is neither `MVP` nor a plain `Candidate`; treating it as either would misrepresent it).
4. Anything else (in practice, always `Idea — draft for review`) → tag `Candidate` (the remaining 15).
The `JourneyStage` tag is the blockquote's `**Journey stage:**` line value verbatim, with ` — ` normalized to ` - ` (e.g. `Cross-cutting - HR Service Delivery`, `Pre-board`) — never truncated or re-categorized, since `hr/docs/ideas/README.md`'s own "By journey stage" table already treats `Cross — Service Delivery`, `Cross — Operations`, and `Cross — Analytics` as three distinct stages, not one.

**Reasoning:** Parsing README.md's prose/table sections would require format-fragile regex against a document meant for humans, and — as this correction shows — `README.md`'s three-way MVP/not-MVP framing does not actually capture `UC-0002`'s distinct "runs alongside, not counted" status; the per-file blockquote is each idea's own primary evidence and is visibly designed to be read this way. Preferring the more specific, primary source over a derived summary is the same evidence discipline this whole session's specs have followed throughout.

**Cost if wrong:** If a reviewer wants different tag values, both the priority list and the normalization rule are five lines of the parsing function to change — the 19 files themselves are not touched.

## Ruling 3a — Every idea also gets its own `UC-nnnn` tag

Each Epic additionally carries a bare `UC-nnnn` tag (from the H1), giving a reviewer a stable, source-verifiable identifier filter independent of title wording, status, or stage.

## Ruling 4 — Discover the process template before assuming Epic exists

**Decision:** Before computing any create/update plan, the new tooling reads the Azure DevOps project's process template and confirms an `Epic` work item type exists in it. If it does not (a non-Agile process, or Agile's Epic type renamed/disabled), the tool fails closed with a clear error naming the actual process found — it does not fall back to a different work item type on its own.

**Reasoning:** `infra/docs/13` was explicit that Agile is only a proposed candidate, not confirmed. Assuming Epic exists without checking would repeat exactly the "resolve an open decision by inference" mistake the tenant-trust-activation spec caught and corrected once already this session (see its Revision Note).

**Cost if wrong:** None — this is a read-only safety check, not a modeling choice; if the process turns out to be Agile as expected, this check costs one extra read-only API call.

## Architecture

Mirrors the already-established pattern in this repository for attended CLI workflows: `infra/src/scripts/Initialize-TenantTrust.ps1` and `infra/src/scripts/Enable-GitHubGovernance.ps1` are each a single, self-contained top-level script — not a set of module Private functions — with their own internal helper functions and injectable adapter parameters (`-AzRequest`, `-GitHubRequest`, `-AzureDevOpsRequest`, `-NativeCommandRunner`, all `[Parameter(DontShow)]`), tested by invoking the script directly (`& $ScriptPath @parameters`, per `infra/tests/pester/TenantTrust.Tests.ps1`) rather than via `InModuleScope`. This sub-project follows that exact convention: one new top-level script, not new module Private files.

```text
hr/docs/ideas/README.md + hr/docs/ideas/*.md + hr/docs/ideas/uc-0001-.../  (source of truth for content)
    |
    v
Initialize-AzureDevOpsWorkItems.ps1 -WhatIf   (new, self-contained, mirrors Initialize-TenantTrust.ps1's shape)
    |  internal: Get-HrIdeaPortfolioItems  -- parses each idea file's H1 + status blockquote (see Ruling 3), no network
    |  internal: Get-AzureDevOpsProcessCapabilities  -- reads process template + Epic type fields via -AzureDevOpsRequest (fails closed if Epic absent)
    |  internal: Get-AzureDevOpsWorkItemPlan  -- WIQL query for existing UC-nnnn-tagged items; Existing vs Create decision per idea
    |  writes: reviewed plan JSON (same allowed-path restriction as Initialize-TenantTrust.ps1)
    v
[human reviews the plan]
    |
    v
Initialize-AzureDevOpsWorkItems.ps1            (same script, no -WhatIf; ShouldProcess-gated, one prompt per Epic)
    |  creates/updates each Create/Update Epic; adds the Hyperlink relation; reads back each one against the reviewed plan
    v
Initialize-AzureDevOpsWorkItems.ps1 -WhatIf    (re-run, zero-mutation)  -- read-back proof, all 19 now Existing
```

## Components

| File | Responsibility |
|---|---|
| `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` (new) | Single self-contained top-level script, sized and structured like `Initialize-TenantTrust.ps1`. Internal functions (not exported, defined at the top of this file): `Get-HrIdeaPortfolioItems` (reads each of the 19 idea files under `-IdeasRoot` and parses `UseCaseId`/`Title` from the H1 line and the `Status`/`JourneyStage` tags from the standard blockquote each file already carries — see Ruling 3 — no network, pure file parsing, testable against a `$TestDrive` fixture tree); `Get-AzureDevOpsProcessCapabilities` (reads the project's process template and work item types via the injectable `-AzureDevOpsRequest` adapter; throws a named error if no `Epic` type exists); `Get-AzureDevOpsWorkItemPlan` (WIQL query for existing work items tagged with each `UC-nnnn`; computes the `Existing`/`Create` decision per idea, mirroring `Add-PlanItem`'s shape). The script's main body wires these together, writes the plan JSON (same temp-directory restriction as `Initialize-TenantTrust.ps1`'s `-PlanOutputPath`), and — only when not `-WhatIf` — creates/updates each `Create`/`Update` Epic (`Title`, `Description`, `Tags` via `az boards work-item create`/`update`, then the `Hyperlink` relation via `az boards work-item relation add`), each behind `$PSCmdlet.ShouldProcess(...)`, then reads every mutated item back (`az boards work-item show --expand all`) and asserts `Title`, `Description`, `Tags`, and the `Hyperlink` URL all match the plan exactly. `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]`, same interactive-context assertion pattern as `Initialize-TenantTrust.ps1`. |
| `infra/tests/pester/AzureBoardsPopulation.Tests.ps1` (new) | Injected-adapter Pester coverage, invoking the script directly (`& $ScriptPath @parameters`, mirroring `TenantTrust.Tests.ps1`) rather than `InModuleScope` — this script is standalone, not a module member. |
| `infra/docs/21-azure-boards-population-runbook.md` (new) | Operator runbook, mirroring `infra/docs/20-tenant-trust-activation-runbook.md`'s structure: prerequisites, plan-review step, execute step, partial-failure handling, final read-back, explicit "what this does not do" table, troubleshooting. |

## Testing

Covered the same way `infra/tests/pester/TenantTrust.Tests.ps1` covers `Initialize-TenantTrust.ps1`: the test file invokes `Initialize-AzureDevOpsWorkItems.ps1` directly (`& $script:ScriptPath @parameters`) with injected `-AzureDevOpsRequest` and `-NativeCommandRunner` scriptblocks, and an injected `-IdeasRoot` path so portfolio parsing can be tested against a `$TestDrive` fixture tree instead of this repository's real `hr/docs/ideas/`. Zero live calls anywhere. Specific cases the plan must cover: process template missing `Epic` (fails closed, named error); a `UC-nnnn` tag matching more than one existing work item (ambiguous, fails closed — never picks the first match, mirroring `Assert-ReviewedStableId`'s pattern); an idea whose source markdown is missing a required section (fails closed rather than writing a blank Description); a full 19-item Create plan; a full 19-item all-`Existing` plan (idempotent re-run); a mutation whose read-back Title/Tags/Hyperlink relation do not match the plan (throws, never silently accepts).

## Runbook (Attended, Not Executed by This Sub-Project)

`infra/docs/21-azure-boards-population-runbook.md` is written but **not run** as part of this sub-project — exactly like the tenant-trust-activation runbook, running it live is an attended human action, for two independent reasons, not one:

1. **Access does not exist yet.** Live execution needs an authenticated Azure DevOps session for Tenant 1, which depends on the tenant-trust-activation runbook (PR #16) actually being run.
2. **Content judgment belongs to a human, deliberately.** Five of the 19 ideas (`UC-0007`, `UC-0008`, `UC-0014`, `UC-0015`, `UC-0019`) touch employment-decision adjacency per `hr/docs/ideas/README.md`'s own observations section. Even though this sub-project only ever copies existing, reviewed text into Azure Boards — it never generates new characterizations of a use case — a human should be the one who triggers the first live write of that portfolio into a system other people at GF will read as authoritative.

## Open Items

- Azure DevOps project configuration (area paths, iterations, delivery plans, repurposing the Azure Repos config repo) remains a separate, not-yet-started sub-project, per the tracking already recorded in `docs/specs/2026-09-24-tenant-trust-activation-design.md`'s Open Items.
- The Azure Boards↔GitHub App connection and the `AB#` commit convention remain attended-only and separate from this sub-project; see `docs/specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md`.
- Whether `UC-0005` and `UC-0010` should be re-tagged from `MVP-Candidate` to `MVP` once they graduate to folders with PRDs is a future, mechanical update to this tooling's tag rule — not a design change.
- Whether Features/Stories should be added under the `UC-0001` Epic once its Definition of Ready is met is out of scope here (Ruling 1) and belongs to whoever picks up implementation of UC-0001 itself.
