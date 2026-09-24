# HR Solution Functional Design Intake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconcile the new GF HR solution functional design package (PRD, solution design, journey/RACI, 7 ADRs, BrandKit, 19-item use-case portfolio) into the repository baseline, without touching anything under `infra/`.

**Architecture:** Follow this repository's own Phase 1–3 intake precedent — classify every new/modified path as `Add`, `Merge`, `PreserveTarget`, or `Reject`, execute path-by-path, then validate and record a review document. The new content already sits in the working tree (uncommitted); most tasks edit it in place rather than copying from an external source directory.

**Tech Stack:** Markdown documentation, PowerShell (repository verifier + Pester), git (rename/mv for ADR renumbering), grep/ripgrep for citation verification.

**Spec:** [`docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md`](../specs/2026-09-24-hr-solution-functional-design-intake-design.md)

## Global Constraints

- **`infra/` is untouched, without exception.** No task in this plan modifies, adds, or removes any file under `infra/`. Task 13 explicitly discards the new package's infra-touching changes.
- **Numbers are never reused.** The new ADRs (currently self-numbered 0001–0007) must not collide with the existing `docs/adr/0001`–`0004-*.md`. They are renumbered 0005–0011 (Task 1) before any other task references them.
- **Every repository-owned markdown file added or rewritten by this intake carries the standard six-field metadata table** (`| Field | Value |` / `|---|---|` / six rows: `Version`, `Date`, `Author`, `Status`, `Scope`, `References`, in that order, immediately after the file's single H1, separated from it only by blank lines) — enforced by `.github/cli/modules/DocumentationMetadata.psm1`. Use `Status: Proposed Baseline` for all newly added/rewritten content in this intake (nothing here is separately "Approved" by this intake alone), `Author: docs-agent (Voice of Knowledge)`, `Date: 2026-09-24`, `Version: 1.0` unless a task says otherwise. This table is independent of, and additional to, any ADR's own internal "**Status:** Accepted/Proposed" decision-tracking line.
- **No Accepted/existing ADR content is edited in place.** Superseding uses a banner addition, never a rewrite of the superseded document's substance.
- **This plan commits locally to the current branch only; it does not push or open a PR.** That is a separate, deliberate final step for the repository owner to trigger — not because of the (now resolved) confidentiality question, but as normal practice for a change this size.
- **The real customer name "Georg Fischer" / "GF" is kept as-is in file content.** The repository owner confirmed this is intentional: Tenants 1 & 2 already use the "Caldova" pseudonym for the practice tenants this repository actively bootstraps, and this content specifically describes the eventual Tenant 3 (real customer) handover — no task in this plan renames or masks it.
- **Publisher prefixes are tenant-specific: `calhr` for Tenant 1 & 2, `gfhr` for Tenant 3.** The new package hardcoded a single `gf_` value; Task 12 corrects every occurrence and generalizes the surrounding prose.

---

### Task 1: Rename and renumber the seven new ADRs

**Files:**
- Modify (rename): `docs/adr/adr-0007-workflow-first-process-architecture.md` → `docs/adr/0011-workflow-first-process-architecture.md`
- Modify (rename): `docs/adr/adr-0006-organizational-data-service-as-people-context.md` → `docs/adr/0010-organizational-data-service-as-people-context.md`
- Modify (rename): `docs/adr/adr-0005-workday-access-via-connector-behind-governed-layer.md` → `docs/adr/0009-workday-access-via-connector-behind-governed-layer.md`
- Modify (rename): `docs/adr/adr-0004-human-in-the-loop-and-write-envelope.md` → `docs/adr/0008-human-in-the-loop-and-write-envelope.md`
- Modify (rename): `docs/adr/adr-0003-dataverse-process-state-boundary.md` → `docs/adr/0007-dataverse-process-state-boundary.md`
- Modify (rename): `docs/adr/adr-0002-agentic-toolset-and-hr-control-plane.md` → `docs/adr/0006-agentic-toolset-and-hr-control-plane.md`
- Modify (rename): `docs/adr/adr-0001-workday-as-system-of-record.md` → `docs/adr/0005-workday-as-system-of-record.md`

**Interfaces:**
- Produces: the canonical renumbered ADR filenames and in-document identifiers `ADR-0005`…`ADR-0011` that every later task (2, 3, 5–10) cites.

- [ ] **Step 1: Rename the files with `git mv`, highest number first**

Run, in this exact order (so no target path is overwritten by a later rename in the same batch):

```powershell
cd docs/adr
git mv adr-0007-workflow-first-process-architecture.md 0011-workflow-first-process-architecture.md
git mv adr-0006-organizational-data-service-as-people-context.md 0010-organizational-data-service-as-people-context.md
git mv adr-0005-workday-access-via-connector-behind-governed-layer.md 0009-workday-access-via-connector-behind-governed-layer.md
git mv adr-0004-human-in-the-loop-and-write-envelope.md 0008-human-in-the-loop-and-write-envelope.md
git mv adr-0003-dataverse-process-state-boundary.md 0007-dataverse-process-state-boundary.md
git mv adr-0002-agentic-toolset-and-hr-control-plane.md 0006-agentic-toolset-and-hr-control-plane.md
git mv adr-0001-workday-as-system-of-record.md 0005-workday-as-system-of-record.md
cd ../..
```

Note: these files are currently untracked (new), so `git mv` will report them as a plain filesystem rename staged as an add at the new path — that is expected; there is no history to preserve yet since they were never committed under the old name.

- [ ] **Step 2: Fix each renamed file's own self-referential number**

Each file's first line is `# ADR-000N: <title>` (or similar) and its own body may restate its number (for example in a "Status" or self-citation line). Open each of the 7 renamed files and replace every occurrence of its own old number with its new number, in this exact mapping — old → new: `0001`→`0005`, `0002`→`0006`, `0003`→`0007`, `0004`→`0008`, `0005`→`0009`, `0006`→`0010`, `0007`→`0011`. Apply only within each file to occurrences of *its own* old number (do not touch cross-references to *other* ADRs yet — that is Task 2).

Verify with:

```powershell
Select-String -Path docs/adr/0005-workday-as-system-of-record.md -Pattern 'ADR-0001|adr-0001'
Select-String -Path docs/adr/0011-workflow-first-process-architecture.md -Pattern 'ADR-0007|adr-0007'
```

Expected: both return matches only if the file cites a *different* ADR that happens to still say old-0001/old-0007 — inspect each match manually; a match referring to the file's own number must be gone.

- [ ] **Step 3: Add the required documentation metadata table to each of the 7 files**

Insert immediately after each file's H1 (blank line, then the table, then a blank line, then the file's existing content resumes unchanged):

```markdown
| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Architecture |
| **References** | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |
```

- [ ] **Step 4: Verify each file still has exactly one H1 and the table is well-formed**

```powershell
foreach ($f in Get-ChildItem docs/adr/0005-*.md, docs/adr/0006-*.md, docs/adr/0007-*.md, docs/adr/0008-*.md, docs/adr/0009-*.md, docs/adr/0010-*.md, docs/adr/0011-*.md) {
  $lines = Get-Content $f
  "{0}: H1 count = {1}" -f $f.Name, (@($lines | Select-String '^# ')).Count
}
```

Expected: `H1 count = 1` for every file.

- [ ] **Step 5: Commit**

```bash
git add docs/adr/0005-workday-as-system-of-record.md docs/adr/0006-agentic-toolset-and-hr-control-plane.md docs/adr/0007-dataverse-process-state-boundary.md docs/adr/0008-human-in-the-loop-and-write-envelope.md docs/adr/0009-workday-access-via-connector-behind-governed-layer.md docs/adr/0010-organizational-data-service-as-people-context.md docs/adr/0011-workflow-first-process-architecture.md
git commit -m "docs: renumber new HR solution ADRs to 0005-0011

Avoids colliding with the existing 0001-0004 governance/tooling ADRs.
Cross-references in other files are updated in the next commit."
```

---

### Task 2: Fix every cross-reference to the renumbered ADRs

**Files:**
- Modify: `docs/prd.md`
- Modify: `docs/solution-design.md`
- Modify: `docs/hr-journey-and-raci.md`
- Modify: `docs/README.md`
- Modify: `README.md`
- Modify: `hr/README.md`
- Modify: `data/README.md`
- Modify: `.github/copilot-instructions.md`
- Modify: `.github/pull_request_template.md`
- Modify: `AGENTS.md`
- Modify: `hr/docs/ideas/README.md`
- Modify: `hr/docs/ideas/uc-0003-employee-self-service-assistant.md`
- Modify: `hr/docs/ideas/uc-0018-onboarding-checklist-rebuild.md`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/README.md`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/uc-0001-personal-master-data-completion-agent.md`
- Modify: `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md`

**Interfaces:**
- Consumes: the renumbered ADR identifiers from Task 1 (`ADR-0005`…`ADR-0011`, filenames `0005-workday-as-system-of-record.md`…`0011-workflow-first-process-architecture.md`).
- Produces: a repository with zero remaining citations of the pre-rename `ADR-0001`…`ADR-0007` identifiers or `adr-000N-*.md` filenames outside `docs/adr/0001`–`0004-*.md` (which are the real, untouched, unrelated existing ADRs).

- [ ] **Step 1: Find every file with a stale citation**

```powershell
$mapping = @{ 'ADR-0007'='ADR-0011'; 'ADR-0006'='ADR-0010'; 'ADR-0005'='ADR-0009'; 'ADR-0004'='ADR-0008'; 'ADR-0003'='ADR-0007'; 'ADR-0002'='ADR-0006'; 'ADR-0001'='ADR-0005' }
Select-String -Path docs/prd.md, docs/solution-design.md, docs/hr-journey-and-raci.md, docs/README.md, README.md, hr/README.md, data/README.md, .github/copilot-instructions.md, .github/pull_request_template.md, AGENTS.md, hr/docs/ideas/README.md, hr/docs/ideas/*.md, hr/docs/ideas/uc-0001-personal-master-data-completion-agent/*.md -Pattern 'ADR-000[1-7]\b' | Select-Object Path, LineNumber, Line
```

This lists every line to change. Do not touch any match inside `docs/adr/0001`–`0004-*.md` (there should be none in this file list) or inside `docs/adr/0005`–`0011-*.md` (already handled in Task 1).

- [ ] **Step 2: Apply the substitution, highest number first, in every listed file**

For each file from Step 1, replace text in this exact order (so `ADR-0007`→`ADR-0011` never gets re-matched and shifted again by the `ADR-0001`→`ADR-0005` pass):

1. `ADR-0007` → `ADR-0011`
2. `ADR-0006` → `ADR-0010`
3. `ADR-0005` → `ADR-0009`
4. `ADR-0004` → `ADR-0008`
5. `ADR-0003` → `ADR-0007`
6. `ADR-0002` → `ADR-0006`
7. `ADR-0001` → `ADR-0005`

Also replace filename references, same order and same rule:

1. `adr-0007-workflow-first-process-architecture.md` → `0011-workflow-first-process-architecture.md`
2. `adr-0006-organizational-data-service-as-people-context.md` → `0010-organizational-data-service-as-people-context.md`
3. `adr-0005-workday-access-via-connector-behind-governed-layer.md` → `0009-workday-access-via-connector-behind-governed-layer.md`
4. `adr-0004-human-in-the-loop-and-write-envelope.md` → `0008-human-in-the-loop-and-write-envelope.md`
5. `adr-0003-dataverse-process-state-boundary.md` → `0007-dataverse-process-state-boundary.md`
6. `adr-0002-agentic-toolset-and-hr-control-plane.md` → `0006-agentic-toolset-and-hr-control-plane.md`
7. `adr-0001-workday-as-system-of-record.md` → `0005-workday-as-system-of-record.md`

Any relative link that pointed at `docs/adr/adr-000N-*.md` or `../adr/adr-000N-*.md` etc. must resolve to the new `docs/adr/000(N+4)-*.md` path — check the actual relative depth from each citing file (for example `hr/docs/ideas/uc-0001-.../README.md` links via `../../../../docs/adr/...`).

- [ ] **Step 3: Verify zero stale citations remain**

```powershell
$stale = Select-String -Path docs/prd.md, docs/solution-design.md, docs/hr-journey-and-raci.md, docs/README.md, README.md, hr/README.md, data/README.md, .github/copilot-instructions.md, .github/pull_request_template.md, AGENTS.md, hr/docs/ideas/README.md, hr/docs/ideas/*.md, hr/docs/ideas/uc-0001-personal-master-data-completion-agent/*.md -Pattern 'ADR-000[1-4]\b|adr-000[1-7]-'
$stale
```

Expected: empty result. (A match on literal `ADR-0001`…`ADR-0004` here would mean a citation to the *new* HR content still points at the *old*, unrelated infra ADR numbers — a real bug to fix before proceeding.)

- [ ] **Step 4: Verify every relative link to a renumbered ADR resolves**

```powershell
$files = @('docs/prd.md','docs/solution-design.md','docs/hr-journey-and-raci.md','docs/README.md','README.md','hr/README.md','data/README.md','.github/copilot-instructions.md','.github/pull_request_template.md','AGENTS.md') + (Get-ChildItem hr/docs/ideas -Recurse -Filter *.md | Select-Object -ExpandProperty FullName)
foreach ($f in $files) {
  $dir = Split-Path $f
  Select-String -Path $f -Pattern '\]\(([^)]*0(0(0[5-9]|1[01]))-[a-z-]+\.md)\)' -AllMatches | ForEach-Object {
    foreach ($m in $_.Matches) {
      $target = Join-Path $dir $m.Groups[1].Value
      $resolved = [IO.Path]::GetFullPath($target)
      if (-not (Test-Path $resolved)) { "BROKEN LINK in $f -> $($m.Groups[1].Value)" }
    }
  }
}
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add docs/prd.md docs/solution-design.md docs/hr-journey-and-raci.md docs/README.md README.md hr/README.md data/README.md .github/copilot-instructions.md .github/pull_request_template.md AGENTS.md hr/docs/ideas/
git commit -m "docs: repoint HR solution content citations to renumbered ADRs 0005-0011"
```

---

### Task 3: Rebuild the unified ADR index

**Files:**
- Modify: `docs/adr/README.md` (currently holds the new package's index, which lists only the 7 new — soon-renumbered — ADRs and drops the existing 4)

**Interfaces:**
- Consumes: renumbered ADR filenames/titles from Task 1; existing ADR-0001–0004 titles (`Azure DevOps as the Engineering Control Plane, GitHub as the Digital Factory`, `GitHub-First Bootstrap, and the Role of Azure Repos`, `Bicep and PowerShell for Infrastructure as Code`, `Domain Solution Architecture, Naming and Publisher`).
- Produces: `docs/adr/README.md` as the single authoritative index of all 11 ADRs, consumed by `docs/README.md`'s ADR link (Task 5).

- [ ] **Step 1: Replace the "The records" table**

The current working-tree `docs/adr/README.md` (from the new package) has a table with 7 rows. Replace it with an 11-row table that also lists the 4 existing ADRs. **ADR-0004 is not superseded** — its rule ("adopt the one publisher already present in the tenant's supplied solution zip; never create a second one") is tenant-scoped and remains valid; only the concrete prefix values downstream were wrong and are corrected in Task 11/12:

```markdown
## The records

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-azure-devops-as-engineering-control-plane.md) | Azure DevOps as the Engineering Control Plane, GitHub as the Digital Factory | Proposed Baseline |
| [0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md) | GitHub-First Bootstrap, and the Role of Azure Repos | Proposed Baseline |
| [0003](0003-bicep-and-powershell-for-infrastructure-as-code.md) | Bicep and PowerShell for Infrastructure as Code | Proposed Baseline |
| [0004](0004-domain-solution-architecture-and-publisher.md) | Domain Solution Architecture, Naming and Publisher — adopt the tenant's supplied publisher; realized as `calhr` for Tenant 1 & 2, `gfhr` for Tenant 3 | Proposed Baseline |
| [0005](0005-workday-as-system-of-record.md) | Workday is the system of record for employee master data | Accepted |
| [0006](0006-agentic-toolset-and-hr-control-plane.md) | The agentic toolset and HR control plane split, and why a code app | Accepted |
| [0007](0007-dataverse-process-state-boundary.md) | The Dataverse process-state boundary | Accepted |
| [0008](0008-human-in-the-loop-and-write-envelope.md) | Human in the loop, and the agent write envelope | Accepted |
| [0009](0009-workday-access-via-connector-behind-governed-layer.md) | Workday access through the Microsoft connector, behind a governed access layer | Accepted |
| [0010](0010-organizational-data-service-as-people-context.md) | Organizational Data Service as people context, not an integration path | **Proposed** |
| [0011](0011-workflow-first-process-architecture.md) | Workflow-first process architecture — the workflow owns the process, the agent owns the judgement | Accepted |

ADRs 0001–0004 are Proposed Baseline candidates from the infrastructure/governance intake (Phase 1); they are not yet accepted repository decisions. ADRs 0005–0011 are the HR solution architecture set from the Phase 4 intake; their own "Accepted"/"Proposed" status reflects the design package's internal decision tracking and is likewise pending repository-level ratification.
```

Keep every other section of the file (the "How to read one", "Evidence rules for agents", "The three most consequential, and what they forbid", "Adding a record" sections) exactly as the new package wrote them, since they are HR-ADR-specific commentary that remains accurate — only update any `ADR-000N` citations inside them per Task 2's mapping if Task 2 has not already reached this file (this file was not in Task 2's file list; apply the same 7→11…1→5 substitution here now).

- [ ] **Step 2: Add the required metadata table**

This file's H1 is `` # `docs/adr/` — Architecture Decision Records ``. Insert the standard table immediately after it (Scope: `Cross-cutting (all solution domains)`, References pointing at this phase's spec).

- [ ] **Step 3: Verify every link in the table resolves**

```powershell
Select-String -Path docs/adr/README.md -Pattern '\]\((\d{4}-[a-z-]+\.md)\)' -AllMatches | ForEach-Object {
  foreach ($m in $_.Matches) {
    $target = Join-Path docs/adr $m.Groups[1].Value
    if (-not (Test-Path $target)) { "BROKEN: $($m.Groups[1].Value)" }
  }
}
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add docs/adr/README.md
git commit -m "docs: unify ADR index across governance and HR solution tracks"
```

---

### Task 4: Mark superseded legacy product/HR documents

**Files:**
- Modify: `docs/operating-model/00-north-star.md`
- Modify: `docs/operating-model/01-prd.md`
- Modify: `docs/operating-model/02-system-design.md`
- Modify: `docs/operating-model/03-agent-operating-model.md`
- Modify: `docs/operating-model/04-hitl-governance.md`
- Modify: `docs/operating-model/05-implementation-roadmap.md`
- Modify: `docs/90-microsoft-best-practice-evaluation.md`
- Modify: `hr/docs/20-hr-employee-journey.md`

**Interfaces:**
- Consumes: nothing from earlier tasks (independent of the ADR renumbering).
- Produces: eight documents each carrying a visible "Superseded" notice, still linked from `docs/README.md`'s history section (Task 5) but no longer the active nav.

- [ ] **Step 1: Insert a superseded banner immediately after each file's existing metadata table**

For each of the 8 files, insert this blockquote directly after the existing six-field metadata table (before the file's first content heading), leaving the rest of the file's content untouched:

```markdown
> **Superseded.** This document is retained for history. The current product and solution design is [`docs/prd.md`](../prd.md), [`docs/solution-design.md`](../solution-design.md), and [`docs/hr-journey-and-raci.md`](../hr-journey-and-raci.md), reconciled through the [Phase 4 HR Solution Functional Design Intake](../reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md).
```

Adjust the relative path prefix per file depth: files under `docs/operating-model/` and `docs/90-...md` use `../prd.md` / `./prd.md` as appropriate (operating-model files are one level deeper, so `../prd.md`; `90-microsoft-best-practice-evaluation.md` is directly in `docs/`, so `./prd.md` i.e. just `prd.md`); `hr/docs/20-hr-employee-journey.md` uses `../../docs/prd.md`, `../../docs/solution-design.md`, `../../docs/hr-journey-and-raci.md`, and `../../docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md`.

Also update each file's own metadata table `Status` field to `Superseded` (it currently reads `Proposed Baseline` in all 8 files).

- [ ] **Step 2: Verify the banner's links resolve from each file's location**

```powershell
$targets = @{
  'docs/operating-model/00-north-star.md' = @('../prd.md','../solution-design.md','../hr-journey-and-raci.md','../reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md')
  'docs/90-microsoft-best-practice-evaluation.md' = @('prd.md','solution-design.md','hr-journey-and-raci.md','reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md')
  'hr/docs/20-hr-employee-journey.md' = @('../../docs/prd.md','../../docs/solution-design.md','../../docs/hr-journey-and-raci.md','../../docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md')
}
foreach ($file in $targets.Keys) {
  $dir = Split-Path $file
  foreach ($rel in $targets[$file]) {
    $resolved = [IO.Path]::GetFullPath((Join-Path $dir $rel))
    if (-not (Test-Path $resolved)) { "BROKEN from ${file}: $rel" }
  }
}
```

Expected: no output (the review-document path will not resolve until Task 14 creates it — re-run this check after Task 14, or accept the forward reference for now since the link text and path are already correct).

- [ ] **Step 3: Commit**

```bash
git add docs/operating-model/ docs/90-microsoft-best-practice-evaluation.md hr/docs/20-hr-employee-journey.md
git commit -m "docs: mark Phase 2 product/HR operating model superseded by Phase 4"
```

---

### Task 5: Reconcile `docs/README.md`

**Files:**
- Modify: `docs/README.md`

**Interfaces:**
- Consumes: the unified ADR index (Task 3), the renumbered citations (Task 2), the superseded banners (Task 4).
- Produces: the platform documentation entry point used by every other reconciled README.

- [ ] **Step 1: Keep the new package's structure, nav table, authority rule, evidence rules, and "three claims" sections as already written in the working tree** (after Task 2's citation fixes have already landed on this file). No further change needed to that material.

- [ ] **Step 2: Add back the Infrastructure Domain documentation map, unchanged from the pre-intake committed version**

Insert this section (verbatim from the currently-committed `docs/README.md`, i.e. `git show HEAD:docs/README.md`) after the "Naming convention" section and before "Source material":

```markdown
---

## Infrastructure Domain

The Infrastructure domain is imported as source-derived Proposed Baseline documentation. It describes intended architecture, discovery, trust, validation, ALM, security, and recovery boundaries; it does not prove that tenant configuration, Azure resources, Azure DevOps objects, Power Platform environments, GitHub controls, pipelines, identities, or services currently exist. Task 1 disposition and pending approval are recorded in [Phase 3 Infrastructure and Tenant Bootstrap Intake](reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md).

| Document | Purpose |
|---|---|
| [Infrastructure Domain](../infra/README.md) | Defines domain ownership, current no-payload boundary, planned layout, tool boundaries, and document map. |
| [Tenant Setup and Configuration](../infra/docs/10-tenant-setup-and-configuration.md) | Defines the reviewed tenant metadata, desired manifest, observed evidence, explicit intent, and terminology boundaries. |
| [Identity and Access](../infra/docs/11-identity-and-access.md) | Defines attended administration, per-tenant bootstrap identity, exact OIDC binding, and temporary privilege lifecycle. |
| [Power Platform Environments and ALM](../infra/docs/12-power-platform-environments-and-alm.md) | Defines future DEV-to-TEST-to-PROD ALM, solution ordering, variables, connections, and evidence requirements. |
| [Azure DevOps Engineering Control Plane](../infra/docs/13-azure-devops-engineering-control-plane.md) | Describes the proposed backlog and delivery split, discovery candidates, API constraints, and future pipeline boundary. |
| [GitHub Repository Blueprint](../infra/docs/14-github-repository-blueprint.md) | Defines the shared-repository model, tenant Environments, proposed governance, public-repository safety, and read-back. |
| [Agent and Workload Configuration](../infra/docs/15-agent-workload-configuration.md) | Defines future agent, flow, app, grounding, packaging, release, and data-prohibition contracts. |
| [Security, Governance and Compliance](../infra/docs/16-security-governance-and-compliance.md) | Defines evidence-first security principles and proposed DLP, Dataverse, identity, audit, and compliance controls. |
| [Bootstrap and Provisioning](../infra/docs/17-bootstrap-and-provisioning.md) | Defines the evidence-gated state machine, attended trust, subscription `what-if`, and no-deployment boundary. |
| [Multi-Tenant Provisioning](../infra/docs/18-multi-tenant-provisioning.md) | Defines isolation for exactly three independent tenants using one repository and one-tenant execution. |
| [Bootstrap Recovery](../infra/docs/19-bootstrap-recovery.md) | Defines attended recovery from nine failure states without bypassing validation, approvals, or least privilege. |
| [Infrastructure Solution Sources](../infra/src/solutions/README.md) | Defines ownership and exclusions for future unpacked Infrastructure Power Platform solution source. |

**This map is unchanged by the Phase 4 HR solution intake.** `infra/` remains governed exclusively by the Phase 3 review; see [Bicep Composition](../infra/src/bicep/main.bicep) and [Tenant 1 Manifest](../infra/src/config/tenants/caldova25156897.psd1) for its current state.
```

- [ ] **Step 3: Add a "Superseded (Phase 2)" pointer section**

Insert directly before the "Source material" section:

```markdown
---

## Superseded (Phase 2)

The original Proposed Baseline product/HR operating model is superseded by the documents above, reconciled through the [Phase 4 HR Solution Functional Design Intake](reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md). Retained for history, each carrying its own superseded banner:

| Document | Superseded by |
|---|---|
| [operating-model/00-05](operating-model/00-north-star.md) | `prd.md`, `solution-design.md`, `hr-journey-and-raci.md` |
| [90 Microsoft Best Practice Evaluation](90-microsoft-best-practice-evaluation.md) | A fresh evaluation against the new design is not yet performed — treat this as historical only |
| [HR Employee Journey (Phase 2)](../hr/docs/20-hr-employee-journey.md) | `hr-journey-and-raci.md`, `hr/docs/ideas/` |
```

- [ ] **Step 4: Verify the file still has exactly one H1 and the metadata table is intact**

```powershell
(Get-Content docs/README.md | Select-String '^# ').Count
```

Expected: `1`.

- [ ] **Step 5: Commit**

```bash
git add docs/README.md
git commit -m "docs: restore infra documentation map and add Phase 2 superseded pointer to docs/README.md"
```

---

### Task 6: Reconcile the root `README.md`

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: renumbered ADR citations (Task 2, already applied to this file).

- [ ] **Step 1: Keep the new package's content as already written in the working tree** (product narrative, MVP description, repository map, use-case portfolio, sources) — it is a substantial, coherent improvement and citations are already fixed by Task 2.

- [ ] **Step 2: Add back the "Repository Agent Workflow" section, verbatim from the pre-intake committed version**

Append this section at the end of the file (after whatever the new package's last section is — currently "The three things to settle first"):

```markdown
---

## Repository Agent Workflow

This repository bundles [Superpowers](https://github.com/obra/superpowers) v6.3.0 for GitHub Copilot. Contributors receive the same agent workflows by cloning the repository; no machine-level Superpowers installation is required.

GitHub Copilot discovers the skills under `.github/skills/` in:

- Visual Studio Code chat and agent mode;
- GitHub Copilot CLI when launched from this repository.

Repository instructions require Copilot to begin with the `using-superpowers` skill and load other skills when relevant.

### Verify the Bundle

From the repository root on Windows, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

The command succeeds with `Repository setup validation passed.` when the folder structure, skill metadata, exact runtime file set and SHA-256 hashes, executable Git modes, bootstrap instructions, version metadata, and license are valid.

In VS Code, open **Chat: Open Customizations** and confirm the workspace skills appear without metadata errors. Confirm `using-superpowers` shows its source/path as `.github/skills/using-superpowers/SKILL.md` so repository provenance is checked.

In Copilot CLI, from the repository root run `copilot --no-auto-update -C . skill list --json` and confirm `using-superpowers` has `source` equal to `project`, `enabled` equal to `true`, and a `path` ending in this repository's `.github/skills/using-superpowers`, regardless of whether the host displays `/` or `\` path separators. In an interactive session, `/skills info using-superpowers` can also confirm the repository location. For the behavior smoke test, start `copilot --no-auto-update -C .`, then enter a natural-language prompt such as `Use the /using-superpowers skill to identify which process applies before changing code.` Standalone `/using-superpowers` is supported, but the prompt form is recommended because it provides a verifiable response.

### Pinned Version and License

The vendored runtime is pinned to upstream release v6.3.0 at commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`.

- Source metadata: [`.github/skills/SUPERPOWERS_VERSION`](.github/skills/SUPERPOWERS_VERSION)
- Runtime SHA-256 manifest: [`.github/skills/SUPERPOWERS_SHA256SUMS`](.github/skills/SUPERPOWERS_SHA256SUMS)
- Upstream MIT license: [`.github/skills/LICENSE.superpowers`](.github/skills/LICENSE.superpowers)

### Updating Superpowers

Updates are deliberate and reviewed. To update:

1. Review the newer upstream release and release notes.
2. Replace only the 14 vendored skill directories with the newer release's `skills/` content.
3. Review and update `.github/cli/verify-repository-setup.ps1` fixed contracts for the new upstream release: the expected 14-skill inventory, seven-path executable mode inventory, source release/version/tag/commit, manifest name and metadata, and license attribution checks.
4. Regenerate `SUPERPOWERS_SHA256SUMS` from every file in the 14 reviewed upstream runtime directories using forward-slash relative paths, ordinal path sorting, and lowercase SHA-256 hashes.
5. Preserve the upstream executable Git modes for the reviewed runtime paths.
6. Refresh `LICENSE.superpowers` if the upstream license changed.
7. Update `SUPERPOWERS_VERSION` with the release, tag object, commit, date, manifest name, and included skill list.
8. Run the repository verifier and complete the VS Code and Copilot CLI smoke tests under **Verify the Bundle**.
9. Commit the runtime replacement, manifest, metadata, validator contracts, and any required bootstrap compatibility changes together.

Do not track upstream `main`, use a submodule, or edit vendored skill files for repository-specific behavior.
```

- [ ] **Step 3: Verify `verify-repository-setup.ps1`'s required-content check for `README.md` still passes**

The validator requires `README.md` to contain the strings `Superpowers`, `v6.3.0`, `.github/skills`, and `verify-repository-setup.ps1` (see `.github/cli/verify-repository-setup.ps1:749`). Confirm:

```powershell
$content = Get-Content README.md -Raw
foreach ($needle in @('Superpowers','v6.3.0','.github/skills','verify-repository-setup.ps1')) {
  if ($content -notmatch [regex]::Escape($needle)) { "MISSING: $needle" }
}
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: restore Repository Agent Workflow section in root README.md"
```

---

### Task 7: Reconcile `.github/copilot-instructions.md` and `AGENTS.md`

**Files:**
- Modify: `.github/copilot-instructions.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: renumbered ADR citations (Task 2, already applied to both files).
- Produces: the two files this repository's own tooling requires specific content in (`verify-repository-setup.ps1:722-723` requires both `AGENTS.md` and `.github/copilot-instructions.md` to contain the strings `.github/skills`, `using-superpowers`, and `.github/agents/docs-agent.agent.md`).

- [ ] **Step 1: Prepend the Superpowers bootstrap mandate to `.github/copilot-instructions.md`**

Insert this content as the very first section, immediately after the file's H1 (`# GitHub Copilot instructions — GF HR Agentic Platform`) and before "## What this repository is":

```markdown
## Repository workflow (read this before anything else)

This repository bundles agent skills in `.github/skills/`; no machine-level Superpowers installation is required. Before responding or taking any action, load and follow the `using-superpowers` skill from `.github/skills/using-superpowers/SKILL.md`, check for other applicable skills, and follow the applicable workflow. Repository and user instructions take precedence over a conflicting skill instruction.

Maintained repository documentation is written in English and follows [the documentation policy](../docs/README.md). Use [`.github/agents/docs-agent.agent.md`](agents/docs-agent.agent.md) as the documentation policy owner. Preserve the documented exclusions and never edit vendored Superpowers content to enforce repository metadata.

---
```

- [ ] **Step 2: Remove the duplicate Superpowers/Documentation Policy sections from `AGENTS.md`**

`AGENTS.md`'s current working-tree content (the new package's draft) does not actually contain the old Superpowers/Documentation Policy sections — it already assumes they live in `copilot-instructions.md`. No removal is needed; only confirm this by checking the file does not itself claim to be the bootstrap authority:

```powershell
Select-String -Path AGENTS.md -Pattern 'using-superpowers|Superpowers Workflow'
```

Expected: no output (if there is output, it means the new draft duplicated the instruction — delete that duplicated block, since `copilot-instructions.md` is now the single source after Step 1).

- [ ] **Step 3: Add the required metadata table to both files**

`.github/copilot-instructions.md`: H1 is `# GitHub Copilot instructions — GF HR Agentic Platform`. Insert after it:

```markdown
| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [HR Solution Functional Design Intake](../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |
```

`AGENTS.md`: H1 is `# AGENTS.md — how agents work in this repository`. Insert after it:

```markdown
| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Architecture |
| **References** | [HR Solution Functional Design Intake](docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |
```

- [ ] **Step 4: Verify the repository's own required-content contract**

```powershell
foreach ($pair in @(
  @{ File = 'AGENTS.md'; Needles = @('.github/skills','using-superpowers','.github/agents/docs-agent.agent.md') }
  @{ File = '.github/copilot-instructions.md'; Needles = @('.github/skills','using-superpowers','.github/agents/docs-agent.agent.md') }
)) {
  $content = Get-Content $pair.File -Raw
  foreach ($needle in $pair.Needles) {
    if ($content -notmatch [regex]::Escape($needle)) { "MISSING in $($pair.File): $needle" }
  }
}
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add .github/copilot-instructions.md AGENTS.md
git commit -m "docs: restore Superpowers bootstrap mandate in copilot-instructions.md; AGENTS.md becomes HR agent design rules"
```

---

### Task 8: Reconcile `.github/CODEOWNERS`

**Files:**
- Modify: `.github/CODEOWNERS`

- [ ] **Step 1: Replace file content**

```text
# Ownership mirrors accountability in docs/hr-journey-and-raci.md.
# Tenant 1 & 2 (Caldova) are owned by @urruegg. Tenant 3 (the real
# customer / GF) ownership is intentionally left open here — it is
# decided as part of that tenant's future repository handover, not
# assigned to a placeholder team now.

# Platform design — changes here affect every use case
/docs/                      @urruegg
/docs/adr/                  @urruegg
/docs/prd.md                @urruegg

# HR domain
/hr/                        @urruegg
/hr/docs/ideas/              @urruegg
/hr/src/solutions/          @urruegg

# Infrastructure — unchanged ownership, untouched by this intake
/infra/                     @urruegg

# Data definitions
/data/                      @urruegg

# Repository governance
/.github/                   @urruegg
/AGENTS.md                  @urruegg
```

- [ ] **Step 2: Verify no fictional handles remain**

```powershell
Select-String -Path .github/CODEOWNERS -Pattern '@gf-'
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add .github/CODEOWNERS
git commit -m "docs: bind CODEOWNERS to the real repository owner; leave Tenant 3 ownership open pending handover"
```

---

### Task 9: Reconcile `.gitignore`

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Restore the pre-intake committed baseline**

```powershell
git show HEAD~8:.gitignore | Set-Content -Encoding utf8 .gitignore
```

(Adjust `HEAD~8` to the actual commit before this intake's first commit if the count of preceding commits in this plan differs — identify it with `git log --oneline -- .gitignore | Select-Object -First 5` and pick the revision from before Task 1's first commit.)

- [ ] **Step 2: Append the genuinely new, non-redundant entries from the source package**

The source package's replacement `.gitignore` duplicates several already-present rules (`*.zip`, `.idea/`, `.DS_Store`, `.env`/`.env.*`, and a `.vscode/` rule that the existing file already handles more precisely with an allowlist). Append only what is not already covered:

```gitignore

# Power Platform solution build output (Phase 4 HR solution intake)
**/bin/
**/obj/
!**/solutions/**/*.zip

# Environment and secrets specific to Power Platform config — never commit
infra/src/config/*.local.json
*.secret.json

# Real data — never commit (see data/README.md)
data/**/*.xlsx
data/**/*.csv
!data/**/sample-*.xlsx
!data/**/sample-*.csv

# OS
Thumbs.db
```

- [ ] **Step 3: Verify the load-bearing existing rules survived**

```powershell
foreach ($needle in @('.wt/', '/.superpowers/', '!.vscode/settings.json')) {
  if (-not (Select-String -Path .gitignore -Pattern ([regex]::Escape($needle)) -Quiet)) { "MISSING: $needle" }
}
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: restore existing .gitignore rules and append Phase 4 additions"
```

---

### Task 10: Reconcile `.github/ISSUE_TEMPLATE/config.yml` and `.github/pull_request_template.md`

**Files:**
- Modify: `.github/ISSUE_TEMPLATE/config.yml`
- Modify: `.github/pull_request_template.md` (citations already fixed by Task 2; this task only merges structure)

- [ ] **Step 1: Replace `.github/ISSUE_TEMPLATE/config.yml` content**

```yaml
blank_issues_enabled: false
contact_links:
  - name: Backlog and delivery tracking
    url: https://dev.azure.com/caldova25156897
    about: Work is planned and tracked in Azure Boards. This repository is the build plane.
  - name: Platform design question
    url: https://github.com/urruegg/caldova-hr-frontier/blob/main/docs/README.md
    about: docs/README.md says which document answers which kind of question.
  - name: Open decision
    url: https://github.com/urruegg/caldova-hr-frontier/blob/main/docs/prd.md
    about: Open items live in docs/prd.md section 10 and each use-case PRD section 13. Raise there, not as a new issue.
```

This keeps the existing Azure Boards contact link (infra-owned, in active use for Tenant 1/2 work) and adds the new package's two links with real in-repo targets instead of its placeholder `https://github.com/`.

- [ ] **Step 2: Restore the general checklist items in `.github/pull_request_template.md`**

The current working-tree content (already citation-fixed by Task 2) drops several checks still applicable repository-wide, including to `infra/` PRs. Insert this section after the file's H1-level content and before its "## Checks" section (i.e., between "## Why" and "## Checks"):

```markdown
## Work item

AB#

## Environments affected

The DEV, TEST, and PROD checkboxes describe Power Platform ALM impact, not Azure infrastructure environments.

- [ ] DEV
- [ ] TEST
- [ ] PROD
```

And append these items to the existing "## Checks" list (do not remove any of the new package's HR-specific checks already there):

```markdown
- [ ] No secrets, credentials, access tokens, personal HR data, or unreviewed tenant values introduced
- [ ] Deployment order respected: infrastructure before HR
- [ ] Build, lint, test, and Solution Checker run for affected areas; evidence pasted below rather than claimed

```text
Paste command output here.
```
```

- [ ] **Step 3: Commit**

```bash
git add .github/ISSUE_TEMPLATE/config.yml .github/pull_request_template.md
git commit -m "docs: merge issue-template and PR-template governance with the new HR solution checklist"
```

---

### Task 11: Reconcile `.github/agents/README.md`, `hr/README.md`, `data/README.md`, and add the use-case portfolio

**Files:**
- Modify: `.github/agents/README.md`
- Modify: `hr/README.md` (citations already fixed by Task 2)
- Modify: `data/README.md`
- Add: `hr/docs/ideas/README.md` (citations already fixed by Task 2) and its 18 flat `uc-000N-*.md` files, and the `uc-0001-personal-master-data-completion-agent/` folder (3 files)
- Reject (delete from working tree): `hr/src/solutions/.gitkeep`

- [ ] **Step 1: Keep `.github/agents/README.md`'s new content** (it already correctly delegates repo-work-agent instructions to `copilot-instructions.md`, consistent with Task 7). Add the required metadata table after its H1 (`` # `.github/agents/` — agent definitions for repository work ``), `Scope: Repository`.

- [ ] **Step 2: Keep `hr/README.md`'s new content as already citation-fixed.** Add the required metadata table after its H1 (`` # `hr/` — HR domain ``), `Scope: HR`.

- [ ] **Step 3: Keep `data/README.md`'s new content.** Add the required metadata table after its H1 (`` # `data/` — Data domain ``), `Scope: Data`.

- [ ] **Step 4: Confirm the use-case portfolio files are staged as-is** (already citation-fixed by Task 2). Add the required metadata table to each of the 19 use-case files (`hr/docs/ideas/README.md` plus 18 flat `uc-*.md` files) and the 2 remaining UC-0001 folder files (`uc-0001-personal-master-data-completion-agent.md`, `prd-0001-personal-master-data-completion-agent.md` — the folder's `README.md` is covered here too), using `Scope: HR Use Case Portfolio` for all of them. Use this loop to insert the table mechanically (adjust the H1-detection line count per file if a file has front-matter, which none of these do):

```powershell
$ucFiles = @(Get-ChildItem hr/docs/ideas -Recurse -Filter *.md | Select-Object -ExpandProperty FullName)
$table = @'
| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Use Case Portfolio |
| **References** | [HR Solution Functional Design Intake](../../../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |
'@
foreach ($f in $ucFiles) {
  $lines = Get-Content $f
  $h1Index = ($lines | Select-String '^# ' | Select-Object -First 1).LineNumber - 1
  $depth = ($f.Substring((Get-Location).Path.Length + 1) -split '[\\/]').Count - 1
  $refPrefix = ('../' * $depth) + 'docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md'
  $fileTable = $table -replace '\.\./\.\./\.\./docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md', $refPrefix
  $new = $lines[0..$h1Index] + '' + ($fileTable -split "`n") + '' + $lines[($h1Index+1)..($lines.Count-1)]
  Set-Content -Path $f -Value $new -Encoding utf8
}
```

Verify every file still has exactly one H1 after this loop:

```powershell
foreach ($f in $ucFiles) { if (@(Get-Content $f | Select-String '^# ').Count -ne 1) { "BAD H1 COUNT: $f" } }
```

Expected: no output.

- [ ] **Step 5: Delete the rejected placeholder**

```powershell
git rm --cached hr/src/solutions/.gitkeep 2>$null
Remove-Item hr/src/solutions/.gitkeep -ErrorAction SilentlyContinue
```

(It is currently untracked, so `git rm --cached` will report nothing to remove — the plain `Remove-Item` is what actually matters. `hr/src/solutions/README.md` already documents the no-payload boundary.)

- [ ] **Step 6: Commit**

```bash
git add .github/agents/README.md hr/README.md data/README.md hr/docs/ideas/
git commit -m "docs: add HR use-case portfolio and finish domain README reconciliation"
```

---

### Task 12: Correct the publisher prefix to the confirmed tenant-specific values

**Files:**
- Modify: `docs/solution-design.md` (26 occurrences of `gf_`)
- Modify: `docs/adr/0007-dataverse-process-state-boundary.md` (2 occurrences)
- Modify: `docs/adr/0008-human-in-the-loop-and-write-envelope.md` (1 occurrence)
- Modify: `hr/README.md` (1 occurrence)

**Interfaces:**
- Consumes: the confirmed real values from the repository owner — `calhr` for Tenant 1 & 2 (Caldova practice tenants, verified against the live Power Platform DEV environment for Tenant 1), `gfhr` for Tenant 3 (the real customer / GF).
- Produces: every Dataverse logical-name reference in the HR solution content uses `gfhr_` (the Tenant 3 value, since this content specifically describes the GF/Tenant 3 solution), and every place that asserted a single universal prefix now states both tenant-specific values.

- [ ] **Step 1: Replace every literal table/column identifier**

In `docs/solution-design.md`, `docs/adr/0007-dataverse-process-state-boundary.md`, and `docs/adr/0008-human-in-the-loop-and-write-envelope.md`, replace each of these exact identifiers wherever they appear (backtick-quoted or in prose):

```text
gf_agentrun        → gfhr_agentrun
gf_employeepackage → gfhr_employeepackage
gf_fieldaction      → gfhr_fieldaction
gf_exception        → gfhr_exception
gf_followup         → gfhr_followup
gf_approvedfield    → gfhr_approvedfield
```

- [ ] **Step 2: Generalize the prefix-decision prose**

In `docs/solution-design.md`, the line `Naming uses a GF publisher prefix — `gf_` throughout, decided once before the first table, because a prefix cannot be changed afterwards without rebuilding every component that references it.` becomes:

```markdown
Naming uses a tenant-specific publisher prefix, decided once per tenant before the first table, because a prefix cannot be changed afterwards without rebuilding every component that references it: `calhr` for the Caldova practice tenants (Tenant 1 & 2) and `gfhr` for the real customer tenant (Tenant 3). This design's table names below use the Tenant 3 (`gfhr`) value, since this document describes the GF solution.
```

And the line `**Solution structure:** one publisher, prefix `gf_`. Two solutions, deployed in order:` becomes:

```markdown
**Solution structure:** one publisher per tenant (`calhr` for Tenant 1 & 2, `gfhr` for Tenant 3 — see [ADR-0004](adr/0004-domain-solution-architecture-and-publisher.md)). Two solutions, deployed in order:
```

`ADR-0004` is not renumbered (only the 7 new ADRs from Task 1 moved), so its link target stays `adr/0004-domain-solution-architecture-and-publisher.md`.

- [ ] **Step 3: Fix `hr/README.md`'s single occurrence**

The line `Publisher prefix is `gf_`, decided once — it cannot be changed afterwards without rebuilding every component that references it.` becomes:

```markdown
Publisher prefix is tenant-specific and decided once per tenant before the first table — `calhr` for the Caldova practice tenants (Tenant 1 & 2), `gfhr` for the real customer tenant (Tenant 3) — because it cannot be changed afterwards without rebuilding every component that references it. This domain's solution names below (`GFHRPlatformCore`, `GFHRMasterDataAgent`) are the Tenant 3 build.
```

- [ ] **Step 4: Verify zero remaining `gf_` occurrences outside the corrected set**

```powershell
Select-String -Path docs/solution-design.md, 'docs/adr/0007-dataverse-process-state-boundary.md', 'docs/adr/0008-human-in-the-loop-and-write-envelope.md', hr/README.md -Pattern 'gf_(?!hr)'
```

Expected: no output (the negative lookahead excludes the already-corrected `gfhr_` occurrences).

- [ ] **Step 5: Commit**

```bash
git add docs/solution-design.md docs/adr/0007-dataverse-process-state-boundary.md docs/adr/0008-human-in-the-loop-and-write-envelope.md hr/README.md
git commit -m "docs: correct publisher prefix to confirmed tenant values (calhr / gfhr)

The design package hardcoded a single gf_ prefix. The repository owner
confirmed the real values: calhr for the Caldova practice tenants
(Tenant 1 & 2, verified against the live Tenant 1 DEV environment) and
gfhr for the real customer tenant (Tenant 3). This corrects every
Dataverse logical-name reference to gfhr_ (this content describes the
Tenant 3 / GF solution) and generalizes the prefix-decision prose to
state both tenant-specific values."
```

---

### Task 13: Add the core functional design documents and BrandKit; discard infra-touching changes

**Files:**
- Add: `docs/prd.md`, `docs/hr-journey-and-raci.md` (citations already fixed by Task 2; `docs/solution-design.md` and `hr/README.md` are added/finalized by Task 12 instead, since they needed the prefix correction first)
- Add: `docs/brand/README.md`, `docs/brand/gf-tokens.css`, `docs/brand/gf-fluent-theme.ts`, `docs/brand/hr-control-plane*` (whatever exact filename `git status` shows), `docs/brand/assets/.gitkeep`
- Add: `.github/ISSUE_TEMPLATE/use-case-intake.yml`
- Revert: `infra/README.md`
- Remove (untracked): `infra/docs/30-environment-setup.md`, `infra/docs/README.md`, `infra/src/bicep/.gitkeep`, `infra/src/config/.gitkeep`, `infra/src/scripts/.gitkeep`

- [ ] **Step 1: Add the required metadata table to `docs/brand/README.md`**

Its H1 is `# GF BrandKit — HR Agentic Platform`. Insert after it:

```markdown
| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Experience |
| **References** | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |
```

`gf-tokens.css` and `gf-fluent-theme.ts` are not markdown and are outside the documentation metadata policy's scope — no change needed to either.

- [ ] **Step 2: Stage the straight additions**

```powershell
git add docs/prd.md docs/hr-journey-and-raci.md docs/solution-design.md hr/README.md docs/brand/ .github/ISSUE_TEMPLATE/use-case-intake.yml
```

- [ ] **Step 3: Revert the infra modification and remove the infra-touching new files**

```powershell
git checkout -- infra/README.md
Remove-Item infra/docs/30-environment-setup.md -ErrorAction SilentlyContinue
Remove-Item infra/docs/README.md -ErrorAction SilentlyContinue
Remove-Item infra/src/bicep/.gitkeep -ErrorAction SilentlyContinue
Remove-Item infra/src/config/.gitkeep -ErrorAction SilentlyContinue
Remove-Item infra/src/scripts/.gitkeep -ErrorAction SilentlyContinue
```

- [ ] **Step 4: Verify `infra/` is byte-for-byte unchanged from `main`**

```powershell
git fetch origin main
git diff origin/main -- infra/
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: add HR solution PRD, solution design, journey/RACI, BrandKit, and use-case intake template

Explicitly excludes infra/ — reverted the source package's infra/README.md
change and discarded its infra/docs/30-environment-setup.md,
infra/docs/README.md, and infra/src/*/.gitkeep additions. Tenant 1/2
bootstrap work is untouched."
```

---

### Task 14: Validate and write the Phase 4 review document

**Files:**
- Add: `docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md`

**Interfaces:**
- Consumes: every commit from Tasks 1–12.

- [ ] **Step 1: Run the repository's own validation suite**

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path '.github/cli/tests/WorkflowContract.Tests.ps1', '.github/cli/tests/RepositorySafety.Tests.ps1', 'infra/tests/pester' -Output Detailed -CI
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
az bicep build --file infra/src/bicep/main.bicep --stdout
```

Expected: all Pester tests pass, `Repository safety validation passed.`, and the Bicep build succeeds silently — this confirms `infra/` is untouched and still valid.

- [ ] **Step 2: Run the advisory repository-setup validator and record its outcome (non-blocking, but instructive)**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild
```

This exercises the documentation-metadata check across every tracked markdown file. Fix any reported failure by adding/correcting a metadata table on the flagged file before proceeding (this can happen if a file was missed in Tasks 1–12's metadata-table steps).

- [ ] **Step 3: Run the final citation sweep**

```powershell
Select-String -Path (git ls-files '*.md') -Pattern 'ADR-000[1-4]\b' | Where-Object { $_.Path -notmatch '^docs[\\/]adr[\\/]000[1-4]-' }
```

Expected: no output (any match here is a citation that still points at the old infra ADR numbers from content that should cite the new HR ADRs).

- [ ] **Step 4: Write the review document**

Follow the exact structure of `docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md` (Review Boundary, Inventory Disposition table, Reconciliation Result, Delivery Evidence, Approval Status), populated with:

- Review Boundary: this is a working-tree intake (no separate source directory), reviewed path-by-path against the spec at `docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md`.
- Inventory Disposition: one row per path from the spec's §1–§5, with its classification (`Add`/`Merge`/`PreserveTarget`/`Reject`), and the commit SHA that delivered it (one row per task, Tasks 1–13).
- Reconciliation Result: summarize the ADR renumbering (0001–0007 → 0005–0011, ADR-0004 kept as-is and not superseded), the publisher-prefix correction (`gf_` → confirmed tenant values `calhr`/`gfhr`, Task 12), the CODEOWNERS/`.gitignore`/issue-template/PR-template merges, the 8 superseded legacy documents, and the confirmation that `infra/` is unchanged (cite the `git diff origin/main -- infra/` empty result from Task 13 Step 4).
- Delivery Evidence: list every commit SHA from Tasks 1–13.
- Approval Status: state that this review records implementation-intake disposition; the confidentiality question is resolved (no pseudonymization — see spec §2) and the publisher prefixes are confirmed by the repository owner (see spec's ADR-0004 discussion); this review does not itself push to the remote or open a pull request — that remains a separate, explicit step.

Add the required metadata table (`Status: Approved` is not appropriate here since this is a review record pending human sign-off — use `Status: Draft`, `Scope: Cross-cutting (all solution domains)`, `References` pointing at the spec).

- [ ] **Step 5: Cross-link the review document from `docs/README.md`'s Superseded (Phase 2) section**

The link was added as a forward reference in Task 5 Step 3; re-run the link-resolution check from Task 4 Step 2 now that the file exists:

```powershell
Test-Path docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md
```

Expected: `True`.

- [ ] **Step 6: Commit**

```bash
git add docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md
git commit -m "docs: record Phase 4 HR solution functional design intake review"
```

- [ ] **Step 7: Report completion — push/PR is a separate, explicit follow-up step**

Report to the repository owner: all 14 tasks are committed locally on the current branch; `infra/` is verified unchanged (Task 13 Step 4); the confidentiality question is resolved (real "GF"/"Georg Fischer" naming intentionally kept — spec §2) and publisher prefixes are corrected to the confirmed tenant values (`calhr` Tenant 1 & 2, `gfhr` Tenant 3 — Task 12). Pushing this branch and opening a pull request is deliberately left as a separate action, not bundled into this plan.
