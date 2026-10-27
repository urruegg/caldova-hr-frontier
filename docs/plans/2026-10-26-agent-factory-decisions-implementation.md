# Agent Factory Slice B: Decisions and Evidence Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Agent Factory Slice B: ADR-0013 to ADR-0015 as Proposed records and a dated capability evidence review |
| **References** | [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md), [Agent Factory Slice A Plan](2026-10-26-agent-factory-superpowers-v7-implementation.md), [Agent Factory Part 1 Idea Record](../ideas/agent-factory-common-setup.md), [Architecture Decision Records](../adr/README.md), [Reviews](../reviews/README.md), [Repository-Agent Portfolio Governance Design](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record three Proposed architecture decisions and one dated evidence review so later factory work cites decisions and evidence, and guard both with a small contract test.

**Architecture:** A structural contract test is written first and shown failing. The three ADRs and the evidence review then make it pass. The ADRs state decisions and their limits; the review states what was observed, from which first-party source, and on which date. Anything not proven stays `Not verified`.

**Tech Stack:** Markdown, Windows PowerShell 5.1, Pester 5.7.1, `gh`, the repository verifier.

**Spec:** [`docs/specs/2026-10-26-agent-factory-foundation-design.md`](../specs/2026-10-26-agent-factory-foundation-design.md), section 7. The spec is a Proposed Baseline.

## Status and Authority

This is a draft for owner review alongside the foundation design. It does not record approval, authorize execution, or prove that a task ran. Before Preparation, record the owner's approval of the written design and confirm that both the docs-only review package and Slice A have merged to `main`. Until then, leave every execution step unstarted.

## Global Constraints

- ADR numbers `0013`, `0014`, and `0015` were unused on `main`, on every remote branch, and in open pull requests when the spec was written. Re-check before creating the files (Preparation step 2). Numbers are never reused.
- Every ADR is `Proposed Baseline` in its metadata table and `Proposed` in its decision table. No ADR is marked Accepted or Approved by this plan.
- ADR-0013 states that the source format is not verified in this tenant. ADR-0014 states no credit figure. Do not add one.
- The evidence review is a dated snapshot, not a living register. Every entry has a status label from the concept (`GA`, `Preview`, `Private preview`, `Announced`, `Sample / OSS`, `Not verified`), one https source, and an access date in `yyyy-MM-dd` form.
- An observation that was not made is `Not verified`. A check that was not run is reported as "Not run". Never record a guess as a finding.
- English, UTF-8, six-field metadata header after the first H1 of every document.
- Update the owning catalogue README in the same pull request as each new record.
- Create or change no GitHub Actions workflow, Azure DevOps pipeline, or `copilot-setup-steps.yml`.
- Run Windows PowerShell 5.1 with exact Pester 5.7.1 and `-ExecutionPolicy Bypass` on the process only.
- Work in a sibling worktree under `Source\urruegg\wt\`, on branch `docs/agent-factory-decisions`, with a checkout path below 240 characters.
- Each commit ends with the trailer `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Do not push or open a pull request unless the owner directs it.

**Prerequisites.** Start only after the docs-only pull request holding the foundation design and these plans has merged, and after Slice A has merged, because ADR-0015 names Superpowers v7.0.1 as vendored. If either is unmerged, stop and report.

---

## Preparation (not a task)

- [ ] **Step 1: Create the worktree from the merged `main`**

```powershell
Set-Location -LiteralPath 'C:\Users\urruegg\Source\urruegg\caldova-hr-frontier'
git fetch origin --prune
$worktree = 'C:\Users\urruegg\Source\urruegg\wt\factory-decisions'
if (Test-Path -LiteralPath $worktree) { throw "Worktree path already exists: $worktree" }
git worktree add $worktree -b docs/agent-factory-decisions origin/main
if ($LASTEXITCODE -ne 0) { throw 'git worktree add failed' }
Set-Location -LiteralPath $worktree
Test-Path docs\specs\2026-10-26-agent-factory-foundation-design.md
Select-String -LiteralPath .github\skills\SUPERPOWERS_VERSION -Pattern '^release=v7\.0\.1$' -Quiet
```

Expected: `True` and `True`. If either is `False`, a prerequisite is missing; stop. Prove the current-user write/delete probe and the sub-240-character path budget using the [external worktree prerequisite](../../infra/docs/runbooks/01-developer-workstation.md#external-worktree-prerequisite) with task directory `factory-decisions`.

- [ ] **Step 2: Re-check that the ADR numbers are still free**

```powershell
git fetch origin --prune
$used = foreach ($ref in (git for-each-ref --format='%(refname:short)' refs/remotes/origin | Where-Object { $_ -ne 'origin/HEAD' })) {
    git ls-tree -r --name-only $ref -- docs/adr | Where-Object { $_ -match 'docs/adr/001[3-9]-' } | ForEach-Object { "$ref : $_" }
}
if ($used) { $used; throw 'An ADR number from 0013 upward is already in use. Renumber this plan before continuing.' }
gh pr list --state open --json number,title,headRefName --jq '.[] | "#\(.number) \(.headRefName)"'
```

Expected: no output from the loop and no open pull request touching `docs/adr`. If a number is taken, stop and report; do not reuse it.

- [ ] **Step 3: Fix the review date once**

```powershell
(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
```

Call the output `<review-date>`. Use that exact literal as the document date and as every access date unless a source is read on a later day, in which case use that day's date for that entry.

---

### Task 1: Write the decision-record contract test and watch it fail

**Files:**
- Create: `.github/cli/tests/AgentFactoryDecisions.Tests.ps1`

**Interfaces:**
- Consumes: the ADR file names in Global Constraints, `docs/adr/README.md`, and `docs/reviews/2026-10-26-agent-factory-capability-evidence-review.md`.
- Produces: a test that Tasks 2 and 3 must make pass.

The test names the breaks it catches: an ADR with no Options considered section (the ADR README says a record without it "documents an outcome, not a decision"), an ADR missing from the catalogue, and an evidence entry with no date or source (the spec requires every entry to be dated and sourced). It does not assert any prose.

- [ ] **Step 1: Create the test**

Create `.github/cli/tests/AgentFactoryDecisions.Tests.ps1`:

```powershell
$script:factoryAdrs = @(
    @{ Number = '0013'; File = '0013-canonical-source-format-for-copilot-studio-agents.md' }
    @{ Number = '0014'; File = '0014-harness-selection-and-cost-policy.md' }
    @{ Number = '0015'; File = '0015-developer-tool-supply-chain.md' }
)

BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:adrRoot = Join-Path $script:repositoryRoot 'docs\adr'
    $script:adrCatalogue = Join-Path $script:adrRoot 'README.md'
    $script:reviewPath = Join-Path $script:repositoryRoot 'docs\reviews\2026-10-26-agent-factory-capability-evidence-review.md'
    $script:allowedStatuses = @('GA', 'Preview', 'Private preview', 'Announced', 'Sample / OSS', 'Not verified')
}

Describe 'Agent factory decision records' {
    It 'ADR-<Number> has every section the ADR template requires' -ForEach $script:factoryAdrs {
        $path = Join-Path $script:adrRoot $File
        $path | Should -Exist
        $text = Get-Content -LiteralPath $path -Raw
        foreach ($section in @('## Context', '## Decision', '## Options considered', '## Consequences', '## Compliance')) {
            $text | Should -Match ('(?m)^' + [regex]::Escape($section) + '\s*$') -Because "ADR-$Number must contain '$section'"
        }
    }

    It 'ADR-<Number> is Proposed in both status tables' -ForEach $script:factoryAdrs {
        $text = Get-Content -LiteralPath (Join-Path $script:adrRoot $File) -Raw
        $text | Should -Match '(?m)^\|\s+\*\*Status\*\*\s+\|\s+Proposed Baseline\s+\|\s*$'
        $text | Should -Match '(?m)^\|\s+\*\*Status\*\*\s+\|\s+Proposed\s+\|\s*$'
    }

    It 'ADR-<Number> has exactly one catalogue row that names its status' -ForEach $script:factoryAdrs {
        $rows = @(Get-Content -LiteralPath $script:adrCatalogue | Where-Object { $_ -match [regex]::Escape("[ADR-$Number]($File)") })
        $rows.Count | Should -Be 1
        $rows[0] | Should -Match '\|\s+Proposed Baseline\s+\|'
    }
}

Describe 'Agent factory capability evidence review' {
    BeforeAll {
        $script:entries = @(
            Get-Content -LiteralPath $script:reviewPath |
                Where-Object { $_ -match '^\|\s*CE-\d{2}\s*\|' } |
                ForEach-Object {
                    $cells = @($_.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
                    [pscustomobject]@{ Id = $cells[0]; Status = $cells[4]; Source = $cells[5]; Accessed = $cells[6]; CellCount = $cells.Count }
                }
        )
    }

    It 'records the nine reviewed capabilities CE-01 to CE-09' {
        foreach ($number in 1..9) {
            $script:entries.Id | Should -Contain ('CE-{0:d2}' -f $number)
        }
    }

    It 'records no entry twice' {
        @($script:entries.Id).Count | Should -Be @($script:entries.Id | Select-Object -Unique).Count
    }

    It 'gives every entry seven cells so no column is merged or missing' {
        @($script:entries | Where-Object { $_.CellCount -ne 7 }) | Should -BeNullOrEmpty
    }

    It 'uses only the concept status labels' {
        foreach ($entry in $script:entries) {
            $script:allowedStatuses | Should -Contain $entry.Status -Because "$($entry.Id) status '$($entry.Status)' is not an allowed label"
        }
    }

    It 'cites an https source for every entry' {
        foreach ($entry in $script:entries) {
            $entry.Source | Should -Match '^https://\S+$' -Because "$($entry.Id) needs one https source URL"
        }
    }

    It 'dates every entry with a real calendar date' {
        foreach ($entry in $script:entries) {
            $parsed = [datetime]::MinValue
            [datetime]::TryParseExact($entry.Accessed, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed) |
                Should -BeTrue -Because "$($entry.Id) access date '$($entry.Accessed)' must be yyyy-MM-dd"
        }
    }
}
```

- [ ] **Step 2: Run it and watch it fail (RED)**

```powershell
$validation = @'
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$r = Invoke-Pester -Path '.github\cli\tests\AgentFactoryDecisions.Tests.ps1' -Output None -PassThru
"RESULT total=" + $r.TotalCount + " passed=" + $r.PassedCount + " failed=" + $r.FailedCount + " " + $r.Result
if ($r.Result -ne 'Passed') { exit 1 }
'@
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $validation
```

Expected: `failed` greater than `0` and `Result Failed`, because the ADR files, the catalogue rows, and the review do not exist. A failure that says the Pester module cannot load is an environment fault, not RED; fix it first.

- [ ] **Step 3: Commit the test**

```powershell
git add -- .github/cli/tests/AgentFactoryDecisions.Tests.ps1
git commit -m 'test(adr): add contract for the agent factory decision records' -m 'Require the ADR template sections, Proposed status, one catalogue row each, and a dated, sourced, labelled evidence entry for every reviewed capability. The test is red at this commit and is made green by the records that follow.' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

---

### Task 2: Write ADR-0013 to ADR-0015 and catalogue them

**Files:**
- Create: `docs/adr/0013-canonical-source-format-for-copilot-studio-agents.md`
- Create: `docs/adr/0014-harness-selection-and-cost-policy.md`
- Create: `docs/adr/0015-developer-tool-supply-chain.md`
- Modify: `docs/adr/README.md`

**Interfaces:**
- Consumes: Task 1's test.
- Produces: three Proposed ADRs and their catalogue rows. ADR-0015 links the evidence review that Task 3 creates; the link check passes only after Task 3.

- [ ] **Step 1: Create ADR-0013**

Create `docs/adr/0013-canonical-source-format-for-copilot-studio-agents.md`. Set the `Date` row and the inner `Date` row to `<review-date>`.

````markdown
# ADR-0013 — Canonical source format for Copilot Studio agents and workflows

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md), [Agent Factory Part 1 Idea Record](../ideas/agent-factory-common-setup.md), [ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0004](0004-domain-solution-architecture-and-publisher.md), [ADR-0011](0011-workflow-first-process-architecture.md) |

| | |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-10-26 |
| **Related** | [ADR-0004](0004-domain-solution-architecture-and-publisher.md) · [ADR-0011](0011-workflow-first-process-architecture.md) |
| **Supersedes** | None |

---

## Context

No Copilot Studio agent or workflow source exists in this repository. The [Agent Factory concept](../ideas/agent-factory-common-setup.md) (section 7.5 and decision F01) proposes one canonical format before the first agent is committed, so that source never ends up in two formats. The concept's evidence for that format comes from a different implementation; this repository has not reproduced it.

Three source shapes are available today: the unpacked export of a DEV solution, a `pac copilot` workspace, and the Dataverse Git-integration YAML. They are not interchangeable, and the concept notes that the Git-integration YAML can only be read by `pac solution pack`.

## Decision

**Deployable source is the unpacked DEV solution export. Everything authored by people or generators sits beside it and is checked against it.**

1. **One canonical format per solution.** The deployable source is the DEV export unpacked with `pac solution unpack --packagetype Both`. It is not edited by hand except by generators and normalisers.
2. **An authored layer sits beside it.** Per agent: identity, instructions, tool contract, and evaluation prompts. Native skills are `SKILL.md` files. Workflow definitions are contracts. A source manifest lists approved components and forbidden patterns. Tests compare the authored layer with the deployable layer.
3. **Workflows are generated, not patched.** A deterministic generator produces the workflow files, and a drift test requires its output to match the DEV export byte for byte.
4. **Repository-to-DEV sync is DEV-only.** If it is built, it plans by default, takes a backup before it executes, and never targets a test or production environment.
5. **Authoring tools are accelerators, not sources.** `pac copilot` workspaces, the Copilot Studio extension for VS Code, and the Copilot Studio MCP server may speed up authoring in DEV. Their output enters Git only through the path DEV export, then unpack, then pull request.
6. **No mixed formats.** One solution never combines the unpacked format with Dataverse Git-integration YAML.
7. **Not verified here.** Before any agent source is committed, a solution round-trip spike (concept spike S1) must record a GO or NO-GO from a named approver for the components in scope. A NO-GO stops agent implementation.
8. **Scope.** This decision governs future source only. It creates no source folder, and solution placement follows [ADR-0004](0004-domain-solution-architecture-and-publisher.md).

## Options considered

| Option | Why it was not chosen |
|---|---|
| **A `pac copilot` workspace as the only source** | `pull` and `push` work only inside a workspace, take no environment argument, and `push` changes the live agent. Promotion still needs pack and solution import, so a second format would appear anyway |
| **Dataverse Git-integration YAML** | It cannot be mixed with the unpacked format, and the concept lists GitHub support as preview. This repository is GitHub-first ([ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md)) |
| **Portal-only authoring with no exported source** | Nothing reviewable exists in Git, so a pull request cannot gate a change. The concept's principle P2 is that anything built in the portal is exported, normalised, and reviewed |

## Consequences

### Positive

- One reviewable source per solution, and a drift test that finds a hand edit.
- Workflows can be reviewed as contracts, and their generated output can be compared with the platform's own export.

### Negative

- A generator must be written and maintained.
- Exports carry platform noise, such as a time-zone system field, that normalisers must handle.
- The format depends on `pac solution pack` and `unpack` behaving the same across versions, so the `pac` version must be pinned ([ADR-0015](0015-developer-tool-supply-chain.md)).

### Accepted risk

The format has not been proven in this tenant. If the round-trip spike returns NO-GO, this decision is revisited before any agent source exists.

## Compliance

A future change should be able to answer:

1. Does any solution combine the unpacked format with Git-integration YAML or a `pac copilot` workspace as a second source?
2. Is every workflow in source either generated or exported, and never hand-edited?
3. Did the round-trip spike record a GO from a named approver before agent source was committed?
4. Can the repository-to-DEV sync, if it exists, ever target an environment other than DEV?
5. Does every authoring-accelerator output enter Git only as a pull request built from a DEV export?
````

- [ ] **Step 2: Create ADR-0014**

Create `docs/adr/0014-harness-selection-and-cost-policy.md`. Set both date rows to `<review-date>`.

````markdown
# ADR-0014 — Harness selection and cost policy

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md), [Agent Factory Part 1 Idea Record](../ideas/agent-factory-common-setup.md), [Runtime HR Agent Governance](../../AGENTS.md), [ADR-0006](0006-agentic-toolset-and-hr-control-plane.md), [ADR-0011](0011-workflow-first-process-architecture.md) |

| | |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-10-26 |
| **Related** | [ADR-0006](0006-agentic-toolset-and-hr-control-plane.md) · [ADR-0011](0011-workflow-first-process-architecture.md) |
| **Supersedes** | None |

---

## Context

A Copilot Studio agent runs on one harness, chosen when the agent is created. [`AGENTS.md`](../../AGENTS.md) records that an agent cannot be transferred between harnesses after creation, in either direction, and lists the three harnesses with their billing basis. The [Agent Factory concept](../ideas/agent-factory-common-setup.md) (decision F03) adds that building, testing, evaluating, and running on the GitHub Copilot harness consume Copilot Credits from the first build.

This repository has no credit price, allocation, or estimate. Any figure written here would be invented, so this decision fixes the process and leaves the numbers to the records it requires.

## Decision

**Choose the harness deliberately, record the choice before the agent exists, and attach a cost owner.**

1. **A harness decision record precedes every agent.** It names the harness, the reason, the credit-estimate method, and the owner. The agent is not created until the record exists.
2. **Defaults follow [`AGENTS.md`](../../AGENTS.md).** The Copilot chat harness serves grounded knowledge answers. The standard harness serves rule-based, predictable conversational flows and computer use. The GitHub Copilot harness serves reasoning-heavy, multi-step work across tools and documents.
3. **The GitHub Copilot harness needs technical-owner approval.** The approval records that a rule would not do ([ADR-0011](0011-workflow-first-process-architecture.md): a step that cannot state why it needs reasoning is a workflow step) and that the credit estimate is acceptable.
4. **The estimate is a method, not a number.** The record states how credits will be estimated and measured. No figure appears until it can be sourced.
5. **Mixed needs mean two agents.** `AGENTS.md` records that computer use is documented against the standard harness. A process needing computer use and GitHub Copilot reasoning is two agents joined by a workflow, verified in the tenant before a use case commits to it.
6. **Existing controls are unchanged.** Memory stays off for write-capable agents, Work IQ stays off for HR agents, and connected agents stay blocked until their envelope rule exists, as `AGENTS.md` states. This decision does not alter them.

## Options considered

| Option | Why it was not chosen |
|---|---|
| **One harness for every agent** | Harnesses differ in fit and billing. Using the reasoning harness for a rule-based flow adds cost and removes determinism ([ADR-0011](0011-workflow-first-process-architecture.md)) |
| **No recorded harness decision** | The choice cannot be reversed, so an unrecorded choice leaves no reviewable reason and no cost owner |
| **Rely on the harness upgrade path to correct a wrong choice** | The concept describes an upgrade that creates a copy on the GitHub Copilot harness and omits some components, and labels it preview. It is not a reversal and is not relied upon |

## Consequences

### Positive

- A wrong harness is caught at review, when it is still free to change.
- Every agent has a named cost owner from the start.

### Negative

- An extra record before each agent adds a step.
- Without a price or allocation, early estimates will be coarse.

### Accepted risk

Credit consumption cannot be bounded until a method and an environment allocation exist. Those are outside this decision and are listed as open in the [foundation design](../specs/2026-10-26-agent-factory-foundation-design.md).

## Compliance

A future change should be able to answer:

1. Does a harness decision record exist before this agent was created, and does it name an owner?
2. If the agent uses the GitHub Copilot harness, does the technical owner's approval state why a rule would not do?
3. Does the record state an estimate method and no unsourced number?
4. If the process needs computer use and reasoning, are there two agents joined by a workflow, verified in the tenant?
5. Are memory, Work IQ, and connected agents still configured as `AGENTS.md` requires?
````

- [ ] **Step 3: Create ADR-0015**

Create `docs/adr/0015-developer-tool-supply-chain.md`. Set both date rows to `<review-date>`.

````markdown
# ADR-0015 — Developer-tool supply chain

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md), [Repository-Agent Portfolio Governance Design](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md), [Agent Factory Part 1 Idea Record](../ideas/agent-factory-common-setup.md), [Non-Delegable Work](../../.github/agent-policy/NON_DELEGABLE_WORK.md), [Agent Skills](../../.github/skills/README.md) |

| | |
|---|---|
| **Status** | Proposed |
| **Date** | 2026-10-26 |
| **Related** | [ADR-0013](0013-canonical-source-format-for-copilot-studio-agents.md) · [ADR-0014](0014-harness-selection-and-cost-policy.md) |
| **Supersedes** | None |

---

## Context

Agents that work on this repository run with tools that change quickly: the Superpowers skill set, the Power Platform CLI, editor extensions, plugins, and MCP servers. The [Agent Factory concept](../ideas/agent-factory-common-setup.md) (decision F06) asks for exact pins and allow-lists. The Approved [portfolio design](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) already requires a Capability Admission Record before any product, connector, MCP server, plugin, or preview feature becomes a dependency.

Two facts shape the repository's choices. First, `verify-repository-setup.ps1` rejects any tracked path under `.github/skills/` that is not part of the pinned Superpowers runtime. Second, GitHub Docs and VS Code Docs both list `.agents/skills/` as a project skills location (accessed 2026-10-26; see the [evidence review](../reviews/2026-10-26-agent-factory-capability-evidence-review.md)).

## Decision

**Pin exact versions, admit capabilities through the portfolio's admission record, and keep project-owned skills out of the protected Superpowers folder.**

1. **Exact pins.** Superpowers, the `pac` CLI, editor extensions, plugins, and MCP servers are pinned to exact versions when adopted. Superpowers v7.0.1 is the first application: vendored with a SHA-256 manifest and updated by the procedure in the root README.
2. **Upgrades are pull requests with evidence.** A version change arrives through a reviewed pull request that carries verifier output. The concept proposes a monthly review of pins, which is adopted here as a proposed cadence and not as a commitment.
3. **Admission before adoption.** A capability enters only through a Capability Admission Record under the portfolio design. Whether upgrading an already-vendored dependency needs a record before the record schema exists is open, and the [foundation design](../specs/2026-10-26-agent-factory-foundation-design.md) lists it as an owner question.
4. **No blanket approval.** Agents use scoped allow-lists and deny-lists. `--allow-all-tools`, `--yolo`, and equivalents are not used.
5. **Factory skills live in `.agents/skills/`.** `.github/skills/` is reserved for the pinned Superpowers runtime. The location is documented by GitHub and VS Code, and local discovery is verified by the smoke test recorded in the evidence review before any factory skill is created.
6. **No plugin and no `.github/copilot/settings.json` in this cycle.** Superpowers is vendored, so plugin distribution is deferred.
7. **Guardrails are defense in depth.** A hook-based guard refuses the highest-risk actions. It is not a sandbox, and the written rules remain the baseline.
8. **Diagnostics that leave the repository need a human.** The `diagnosing-superpowers` skill reads session transcripts and can create an upstream issue or export a bundle. Either action is external communication and needs a named human's approval and a personal-data check ([Non-Delegable Work](../../.github/agent-policy/NON_DELEGABLE_WORK.md) sections 6 and 7).

## Options considered

| Option | Why it was not chosen |
|---|---|
| **Floating or latest versions** | A silent upgrade can change agent behavior or the export format without review. Both the verifier and the concept require exact pins |
| **Factory skills inside `.github/skills/` with a verifier exception** | It weakens a protected integrity gate that exists to keep the Superpowers bytes unchanged, and it mixes project-owned and vendored content |
| **Install Superpowers as a marketplace plugin instead of vendoring** | The concept notes that vendoring skips the plugin's session-start hook, which repository instructions already compensate for by requiring `using-superpowers` first. Vendoring keeps every contributor on identical bytes without a machine-level install |
| **Blanket auto-approval for convenience** | A prompt injected through a document or issue could run any command. A scoped list limits what a manipulated agent can do |

## Consequences

### Positive

- A pin change is visible, reviewed, and reversible.
- Project skills can be added without touching the integrity gate.

### Negative

- Each upgrade costs a pull request and a verifier run.
- `.agents/skills/` is a second skills location, so contributors must know both exist.

### Accepted risk

A hook guard cannot see everything an agent does. Commands assembled at run time, script files run through `-File`, and tools with unfamiliar argument names are not inspected. The written rules and human review remain the controls that matter.

## Compliance

A future change should be able to answer:

1. Is every new tool, plugin, extension, or MCP server pinned to an exact version and backed by an admission record?
2. Did the version change arrive as a pull request with verifier output?
3. Does any project-owned skill sit under `.github/skills/`?
4. Does anything enable blanket approval for an agent?
5. Is `diagnosing-superpowers` used without a named human approving any upstream issue or bundle?
````

- [ ] **Step 4: Catalogue the three records**

In `docs/adr/README.md`:

1. In the header table change `| **Version** | 1.4 |` to `| **Version** | 1.5 |`, set the `Date` row to `<review-date>`, and append `, [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md)` to the `References` row.
2. Append these three rows directly after the `ADR-0012` row of the catalogue table:

```markdown
| [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md) | [ADR-0013](0013-canonical-source-format-for-copilot-studio-agents.md) | Proposed Baseline | Proposes the unpacked DEV solution export as the canonical source format for Copilot Studio agents and workflows. | Proposed only; not verified in this tenant, and it creates no source folder. |
| [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md) | [ADR-0014](0014-harness-selection-and-cost-policy.md) | Proposed Baseline | Proposes a recorded harness choice, a named cost owner, and an estimate method for every Copilot Studio agent. | Proposed only; it states no credit figure and changes no `AGENTS.md` control. |
| [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md) | [ADR-0015](0015-developer-tool-supply-chain.md) | Proposed Baseline | Proposes exact pins, admission before adoption, no blanket approval, and `.agents/skills/` for factory skills. | Proposed only; it adds no plugin, MCP server, or settings file. |
```

3. In the paragraph that begins `ADRs 0001, 0002, and 0012 are repository-level **Approved**`, append this sentence at its end:

```markdown
ADRs 0013 to 0015 are Proposed Baseline decisions for the agent factory foundation; they are not independently approved and create no source, agent, or configuration.
```

- [ ] **Step 5: Run the ADR part of the test**

```powershell
$validation = @'
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$r = Invoke-Pester -Path '.github\cli\tests\AgentFactoryDecisions.Tests.ps1' -FullNameFilter '*decision records*' -Output None -PassThru
"RESULT total=" + $r.TotalCount + " passed=" + $r.PassedCount + " failed=" + $r.FailedCount + " " + $r.Result
if ($r.Result -ne 'Passed') { exit 1 }
'@
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $validation
```

Expected: `total=9 passed=9 failed=0 Passed`. The evidence-review tests are excluded by the filter and still fail until Task 3.

- [ ] **Step 6: Commit the ADRs**

```powershell
git add -- docs/adr/0013-canonical-source-format-for-copilot-studio-agents.md docs/adr/0014-harness-selection-and-cost-policy.md docs/adr/0015-developer-tool-supply-chain.md docs/adr/README.md
git commit -m 'docs(adr): propose agent factory decisions 0013 to 0015' -m 'Record the canonical source format, the harness and cost policy, and the developer-tool supply chain as Proposed Baseline decisions with their rejected options and compliance questions. No credit figure is stated and the source format is marked not verified in this tenant.' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

---

### Task 3: Record the dated capability evidence review

**Files:**
- Create: `docs/reviews/2026-10-26-agent-factory-capability-evidence-review.md`
- Modify: `docs/reviews/README.md`

**Interfaces:**
- Consumes: the nine questions below and the status-label rules.
- Produces: the nine dated entries that Task 1's test and ADR-0015's link require.

The review records what a first-party source says today. It is not a decision and authorizes nothing. Observations come from the source pages themselves; do not copy a status from the idea record, because the concept is unverified here.

**Status-label rule.** Use the release label the first-party source states for the capability: `GA`, `Preview`, `Private preview`, `Announced`, or `Sample / OSS`. If the source states none, or the claim could not be tested, use `Not verified` and say why in the Finding. Never infer a label.

- [ ] **Step 1: Read each source and note the answer to its question**

Fetch each page (for example with `gh api` for GitHub content or by opening the URL). If a URL has moved, follow the redirect and record the final URL. Record the access date for each.

| ID | Capability | Question to answer from the source | Source | Plan-time observation (2026-10-26), to be re-checked |
|---|---|---|---|---|
| CE-01 | `.agents/skills/` as a project skills location | Do GitHub Docs and VS Code Docs list `.agents/skills/` as a project skills location, and for which surfaces? | `https://docs.github.com/en/copilot/concepts/customizations/agent-skills` | Both GitHub Docs and VS Code Docs (`https://code.visualstudio.com/docs/agent-customization/agent-skills`) list `.github/skills`, `.claude/skills`, and `.agents/skills` as project locations. Local discovery was not tested |
| CE-02 | Custom agent profiles (`.github/agents/*.agent.md`) | Which frontmatter fields exist, and how does the `tools` field behave when listed or omitted? | `https://docs.github.com/en/copilot/reference/custom-agents-configuration` | Not read at plan time |
| CE-03 | Hooks in Copilot CLI and Copilot cloud agent | Where is `.github/hooks/*.json` loaded, what are the `preToolUse` input and output fields, and how do errors and timeouts behave? | `https://docs.github.com/en/copilot/reference/hooks-reference` | Repository hooks load from `.github/hooks/*.json`. Input is `toolName` and `toolArgs` (or `tool_name` and `tool_input`). A `deny` needs `permissionDecisionReason`. A non-zero exit denies, and a timeout is fail-open. Cloud agent honors only `bash` or `command`, not `powershell` |
| CE-04 | Hooks in VS Code | What release label does VS Code give hooks, and do VS Code, the Copilot app, and the CLI share one hook format? | `https://code.visualstudio.com/docs/agent-customization/hooks` | The page is titled "Preview" and says VS Code, the Copilot app, and Copilot CLI share the harness and its hook format |
| CE-05 | GitHub Copilot harness in Copilot Studio | What release label does Learn give the harness, and can an agent move between harnesses? | `https://learn.microsoft.com/en-us/microsoft-copilot-studio/harnesses-overview` | Page updated 2026-10-22. The release label was not read |
| CE-06 | Work IQ MCP | What is its release label, how does it authenticate, and does it need admin consent? | `https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/work-iq/mcp/overview` | Page updated 2026-10-13. The release label was not read |
| CE-07 | `pac copilot` and the current `pac` version | What is `pac copilot`'s status, what is the current `pac` release, and does Learn state a minimum version for Code Apps? | `https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/copilot` | Page date 2026-10-25, content updated 2026-07-10. The version and minimum were not read. The concept's "2.13 or later" is a field observation and stays `Not verified` unless Learn states it |
| CE-08 | Copilot Studio MCP server | What is its release label, and does it need an interactive sign-in? | `https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/copilot-studio-mcp` | Not read at plan time. The concept reports no status label |
| CE-09 | Superpowers v7.0.1 | Which commit, tag object, and publication date does upstream give, and is the license unchanged? | `https://github.com/obra/superpowers/releases/tag/v7.0.1` | Published 2026-10-21, commit `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b`, tag object `cfd50a286baea35041505ed068c878d389ca9f7f`, license identical to `LICENSE.superpowers` |

For CE-09 confirm with `gh api repos/obra/superpowers/releases/tags/v7.0.1 --jq '{tag: .tag_name, published: .published_at}'` and `gh api repos/obra/superpowers/commits/v7.0.1 --jq .sha`. Record `Sample / OSS` as the label unless the project states another.

- [ ] **Step 2: Run the one local discovery check, if a host is available**

Use a throwaway worktree in the sibling `wt` container, following the [external worktree prerequisite](../../infra/docs/runbooks/01-developer-workstation.md#external-worktree-prerequisite), and never commit its probe. Create `.agents/skills/discovery-probe/SKILL.md` containing only a `name: discovery-probe` and a one-line `description:` in YAML frontmatter. In VS Code run **Chat: Open Customizations** and note whether `discovery-probe` appears. If the Copilot CLI is installed, run `copilot --no-auto-update -C . skill list --json` and note whether it appears.

After the check, remove only the probe file and any empty parent directories created by this check. Confirm `git status --short` is empty, then remove the throwaway worktree with `git worktree remove` without `--force`. Stop if unrelated changes are present; do not delete the worktree directory directly. Do not create the probe inside the review worktree.

Add the result to the CE-01 Finding as "Local discovery: seen in <host>" or "Local discovery: Not run (no host available)". Do not create the probe inside the review worktree.

- [ ] **Step 3: Create the review**

Create `docs/reviews/2026-10-26-agent-factory-capability-evidence-review.md`. Replace every `<...>` marker with what you observed; no `<...>` marker may remain. Set `Date` to `<review-date>`.

```markdown
# Agent Factory Capability Evidence Review

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Capability claims the agent factory foundation relies on |
| **References** | [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md), [Agent Factory Part 1 Idea Record](../ideas/agent-factory-common-setup.md), [ADR-0015](../adr/0015-developer-tool-supply-chain.md), [Repository-Agent Portfolio Governance Design](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) |

## Purpose and authority

This review records what first-party sources said about nine capabilities on the dates shown. The [Agent Factory concept](../ideas/agent-factory-common-setup.md) states capability claims dated 2026-10-25 that this repository has not verified; this review checks only the claims the foundation depends on. It is a point-in-time record. It authorizes no capability, creates no admission record, and is not an approval of any decision.

## Method

Each entry names the question, what the source said, the release label, the source, and the access date. The release label is the one the source states, using the concept's labels: `GA`, `Preview`, `Private preview`, `Announced`, and `Sample / OSS`. Where the source states none, or the claim could not be tested, the label is `Not verified` and the Finding says why. A local check that was not run is recorded as not run.

## Evidence register

| ID | Capability | Question | Finding | Status | Source | Accessed |
|---|---|---|---|---|---|---|
| CE-01 | `.agents/skills/` as a project skills location | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-02 | Custom agent profiles | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-03 | Hooks in Copilot CLI and cloud agent | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-04 | Hooks in VS Code | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-05 | GitHub Copilot harness in Copilot Studio | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-06 | Work IQ MCP | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-07 | `pac copilot` and the current `pac` version | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-08 | Copilot Studio MCP server | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |
| CE-09 | Superpowers v7.0.1 | <question> | <finding> | <label> | <https url> | <yyyy-MM-dd> |

Use no `|` character inside a cell. Put each source URL in the Source cell and nowhere else in the row.

## What this review does not show

- It does not show that any capability works in this tenant, that an admission record exists, or that any guardrail is enforced on every host.
- It does not re-verify the rest of the concept's claims.

## Re-verification

A change in any status label, or a decision that depends on an entry, needs a new dated review. This record is not edited to track the platform.
```

The table above shows the column layout only. Replace each `<...>` cell with the real question text from Step 1, your finding, a label from the allowed set, one https URL, and the access date. Keep exactly seven cells per row.

- [ ] **Step 4: Catalogue the review**

In `docs/reviews/README.md`:

1. Change `| **Version** | 1.4 |` to `| **Version** | 1.5 |` and set the `Date` row to `<review-date>`.
2. Append this row after the last row of the catalogue table:

```markdown
| [Foundation design](../specs/2026-10-26-agent-factory-foundation-design.md) | [Agent Factory Capability Evidence Review](2026-10-26-agent-factory-capability-evidence-review.md) | Draft | Records dated first-party evidence for the capabilities the agent factory foundation relies on. | Draft point-in-time record; each entry carries its own date, source, and status label, and it authorizes nothing. |
```

- [ ] **Step 5: Run the contract test and watch it pass (GREEN)**

```powershell
$validation = @'
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$r = Invoke-Pester -Path '.github\cli\tests\AgentFactoryDecisions.Tests.ps1' -Output None -PassThru
"RESULT total=" + $r.TotalCount + " passed=" + $r.PassedCount + " failed=" + $r.FailedCount + " " + $r.Result
foreach ($f in $r.Failed) { "  FAILED: " + $f.ExpandedName + " :: " + (($f.ErrorRecord.Exception.Message -split "`n")[0]) }
if ($r.Result -ne 'Passed') { exit 1 }
'@
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $validation
```

Expected: `total=15 passed=15 failed=0 Passed`. A failure names the entry and the rule it broke; fix the entry, not the test.

- [ ] **Step 6: Commit the review**

```powershell
git add -- docs/reviews/2026-10-26-agent-factory-capability-evidence-review.md docs/reviews/README.md
git commit -m 'docs(review): record agent factory capability evidence' -m 'Record nine dated, sourced, labelled capability observations that the agent factory foundation relies on. Anything not proven is marked Not verified.' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

---

### Task 4: Full validation and evidence

**Files:**
- No file changes unless a check fails and the cause is found.

**Interfaces:**
- Consumes: the committed branch from Tasks 1 to 3.
- Produces: pasted evidence for the pull request.

- [ ] **Step 1: Run the documentation suites**

```powershell
$validation = @'
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$r = Invoke-Pester -Path @('.github\cli\tests\DocumentationMetadata.Tests.ps1','.github\cli\tests\DocumentationLinks.Tests.ps1','.github\cli\tests\DocumentationNavigation.Tests.ps1','.github\cli\tests\DocsAgentContract.Tests.ps1','.github\cli\tests\AgentFactoryDecisions.Tests.ps1') -Output None -PassThru
"RESULT total=" + $r.TotalCount + " passed=" + $r.PassedCount + " failed=" + $r.FailedCount + " " + $r.Result
foreach ($f in $r.Failed) { "  FAILED: " + $f.ExpandedName }
if ($r.Result -ne 'Passed') { exit 1 }
'@
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $validation
```

Expected: `failed=0 Passed`. The navigation and link suites cover the catalogue rows and every relative link, including ADR-0015's link to the review.

- [ ] **Step 2: Run the repository verifier**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild
```

Expected: `Repository setup validation passed.` and exit code `0`. The verifier checks rules the Pester suites do not (for example one H1 per document), so do not skip it. Then run it in full, without the skip flags, if Azure CLI with Bicep is installed; otherwise record "Bicep build: Not run (tool absent)".

- [ ] **Step 3: Check scope and hygiene**

```powershell
git diff --name-only origin/main...HEAD
git diff --name-only origin/main...HEAD -- .github/workflows
git diff --check
Get-ChildItem -LiteralPath . -Directory -Force | Where-Object { $_.Name.StartsWith('.documentation') } | ForEach-Object Name
Select-String -Path docs\adr\0013-*.md, docs\adr\0014-*.md, docs\adr\0015-*.md, docs\reviews\2026-10-26-agent-factory-capability-evidence-review.md -Pattern '<[^>]+>' | Select-Object -First 5
```

Expected: the changed-file list holds only the files named in this plan, no workflow path, no whitespace error, no leftover `.documentation*` folder, and no unreplaced `<...>` marker. Remove any `.documentation*` test folder with `Remove-Item -LiteralPath <path> -Recurse -Force` after confirming it is empty or a test artifact.

- [ ] **Step 4: Assemble the evidence and stop for review**

Collect the RED output (Task 1 Step 2), the GREEN outputs (Task 2 Step 5, Task 3 Step 5), and Task 4 Steps 1 to 3, with `<review-date>`. State which review entries are `Not verified` and why. Do not push or open a pull request unless the owner directs it. When directed, push `docs/agent-factory-decisions` and open the pull request with `.github/pull_request_template.md`, citing this plan and the design as the governing record and leaving `Board synchronization: Deferred - not synchronized` as written.

---

## Completion Criteria

- The contract test passes (15 of 15) after being shown failing.
- The documentation suites and the repository verifier pass. Every skipped required check is reported as `Not run` and remains outstanding; any failed required check blocks completion.
- Three Proposed ADRs and nine dated evidence entries exist, each catalogued in the same change.
- No ADR is marked Accepted or Approved, no credit figure appears, and every unproven claim is `Not verified`.
- No workflow, pipeline, agent profile, MCP configuration, or settings file was created.
