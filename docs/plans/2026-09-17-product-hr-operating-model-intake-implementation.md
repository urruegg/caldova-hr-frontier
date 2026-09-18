# Product, HR, and Operating Model Intake Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR and Data solution domains |
| **References** | [Architecture Baseline Intake and Tenant Bootstrap Design](../specs/2026-09-17-architecture-baseline-intake-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import the reviewed product, HR, data, ADR, and operating-model material as an English Proposed Baseline while preserving repository guidance, traceability, domain placement, and the Phase 1 metadata and validation contracts.

**Architecture:** This phase is content-only. It copies only source files whose path, size, and hash match the approved inventory, inserts the standard metadata header, downgrades unapproved authority claims to Proposed Baseline, repairs local links, replaces comment-only placeholders with owned README files, and updates the root and documentation catalogues. It reuses Phase 1 tooling and introduces no deployable application or infrastructure payload.

**Tech Stack:** Markdown, Windows PowerShell 5.1, Pester 5.7.1, Git

---

## Preconditions

- Complete and review the Governance and GitHub Intake plan first.
- Confirm `Invoke-Pester .github/cli/tests` and `.github/cli/verify-repository-setup.ps1` pass before starting this phase.
- Confirm `docs/reviews/2026-09-17-architecture-baseline-source-inventory.json` still reports 45 files and 485126 bytes.
- Treat `C:\Users\urruegg\Downloads\caldova-hr-frontier` as read-only.
- Do not import `hr/src/solutions/.gitkeep`; create an owned README instead.

### Task 1: Lock the Phase 2 Source Contract

**Files:**
- Create: `.github/cli/tests/Phase2SourceContract.Tests.ps1`
- Create: `docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md`

- [ ] **Step 1: Write the failing source contract test**

Create `.github/cli/tests/Phase2SourceContract.Tests.ps1`:

```powershell
$inventoryPath = Join-Path $PSScriptRoot '..\..\..\docs\reviews\2026-09-17-architecture-baseline-source-inventory.json'
$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json

$expected = [ordered]@{
    'README.md' = '5035ac2b1c59ce776de359ac9592483bf0b9e20572dd1bee8a5aae2638ab8605'
    'data/README.md' = '610ab9bc996f3641b14e0832cc5cfced346f7c88b3f3d7c268bac47498d34c77'
    'docs/90-microsoft-best-practice-evaluation.md' = 'fb4d29d4cf75f7cb659c71b21f83e900a484257e8d2cc06e1a006ec40f1b6031'
    'docs/adr/0001-azure-devops-as-engineering-control-plane.md' = '05ba58d6fb202bb0ac67d936e2cedcf8239a1fbb1c995d2f97035a4eebe02410'
    'docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md' = '515f8c2a3cad2558f8c266228ec33b3df15d9555c3a18aff92044087e2854f9b'
    'docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md' = '549aae2bbca2d792171dd0b947d9f63e1acdec86a93a8a541090b1ca04d03f4b'
    'docs/adr/0004-domain-solution-architecture-and-publisher.md' = 'c32161b150c9fd1be080456362e42a7f01c9e7d7de8d21674831dcf24fae7473'
    'docs/operating-model/00-north-star.md' = '7be5151f04031f4f36e58b80d741ad40c8beb2b26a4dd5ddf8363f318fe9f025'
    'docs/operating-model/01-prd.md' = '7fdc213f864cff3cd0e4755e073b0a23fbf797953132b8a94fab55e8548204a3'
    'docs/operating-model/02-system-design.md' = 'e0b6ff1c43ae0954bb51edf1993ddd9a6d81376834849a756335034bdd1d88e6'
    'docs/operating-model/03-agent-operating-model.md' = '556efcd4af83d221fbe055bbea468d20585112e8d302a4b8ada28514867888a7'
    'docs/operating-model/04-hitl-governance.md' = '8c98c9d1d839d92711b01d651b8277cdd67bf61bb81c29c1defb9a5d6eb1de2b'
    'docs/operating-model/05-implementation-roadmap.md' = '8698e90d24f7f2809c7c4208769395e9296f39fe4323f8edbe33b4ec0fb2c509'
    'hr/README.md' = '9ce61a8ae0e0722091bdbad7820591a4b1dade17edecc5cea3715b76fbcc5010'
    'hr/docs/20-hr-employee-journey.md' = '49d6988c476b9866bc3ca6b70cae3d84b48a5e4c6e2918426c5b2b1614464bca'
    'hr/src/solutions/.gitkeep' = 'b3f560ecbb33867e20f4481b6ed3f8a590f5500940c61b9975f806720b790122'
}

Describe 'Phase 2 source contract' {
    It 'matches every reviewed path and hash' {
        foreach ($entry in $expected.GetEnumerator()) {
            $record = @($inventory.files | Where-Object relativePath -CEQ $entry.Key)
            $record.Count | Should -Be 1
            $record[0].sha256 | Should -Be $entry.Value
        }
    }

    It 'has not imported the source placeholder' {
        Test-Path (Join-Path $PSScriptRoot '..\..\..\hr\src\solutions\.gitkeep') | Should -BeFalse
    }
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/Phase2SourceContract.Tests.ps1 -Output Detailed
```

Expected: the hash contract passes; the target placeholder assertion passes before import. Add a temporary assertion for `docs/operating-model/00-north-star.md` existence and confirm it fails, then remove only that temporary assertion before committing the final test.

- [ ] **Step 3: Create the Phase 2 review record**

Create `docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md` with the standard header:

```markdown
# Phase 2 Product, HR, and Operating Model Intake Review

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR and Data solution domains |
| **References** | [Approved Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](./2026-09-17-architecture-baseline-source-inventory.json) |
```

Add one table row for each of the 16 Phase 2 source paths with source SHA-256, target path, classification, transformation, and review status. Classify `README.md` as `Merge`, 14 substantive domain documents as `Add`, and `hr/src/solutions/.gitkeep` as `Reject` with replacement `hr/src/solutions/README.md`.

- [ ] **Step 4: Commit the Phase 2 contract**

```powershell
git add -- .github/cli/tests/Phase2SourceContract.Tests.ps1 docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md
git commit -m "test: pin product and HR intake sources" -- .github/cli/tests/Phase2SourceContract.Tests.ps1 docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md
```

### Task 2: Import the Cross-Cutting Operating Model

**Files:**
- Create: `docs/operating-model/00-north-star.md`
- Create: `docs/operating-model/01-prd.md`
- Create: `docs/operating-model/02-system-design.md`
- Create: `docs/operating-model/03-agent-operating-model.md`
- Create: `docs/operating-model/04-hitl-governance.md`
- Create: `docs/operating-model/05-implementation-roadmap.md`
- Modify: `docs/README.md`

- [ ] **Step 1: Copy only hash-verified operating-model files**

Run:

```powershell
$source = 'C:\Users\urruegg\Downloads\caldova-hr-frontier\docs\operating-model'
$target = 'docs\operating-model'
New-Item -ItemType Directory -Path $target -Force | Out-Null
Get-ChildItem -LiteralPath $source -File | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $_.Name)
}
```

Immediately verify the copied body files against the source inventory before editing headers:

```powershell
$inventory = Get-Content docs/reviews/2026-09-17-architecture-baseline-source-inventory.json -Raw | ConvertFrom-Json
Get-ChildItem docs/operating-model -File | ForEach-Object {
  $relative = "docs/operating-model/$($_.Name)"
  $expected = ($inventory.files | Where-Object relativePath -CEQ $relative).sha256
  $actual = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -cne $expected) { throw "Copied body differs before adaptation: $relative" }
}
```

Expected: no output.

- [ ] **Step 2: Replace legacy blockquote metadata with the standard header**

For each operating-model document:

1. Remove only the leading legacy metadata lines between the H1 and the first horizontal rule.
2. Insert the standard metadata table after H1 with Version `1.0`, Date `2026-09-17`, Author `docs-agent (Voice of Knowledge)`, Status `Proposed Baseline`, Scope `Cross-cutting (all solution domains)`, and references to the approved design and its owning roadmap or system design.
3. Preserve the English content body.
4. Replace statements that a control already exists with future-tense or design-intent wording when the target repository has no corresponding implementation.
5. Preserve explicit MVP/Horizon 2 distinctions and human-in-the-loop prohibitions.
6. Replace links to absent `infra/docs/` targets with a link to the approved intake design and the phrase `Infrastructure detail enters in Phase 3`; Phase 3 restores infrastructure links atomically with their targets.

- [ ] **Step 3: Add the operating-model catalogue**

Extend `docs/README.md` with an `Operating Model` table containing all six files and one-sentence purposes. Mark the section Proposed Baseline and link to the intake review.

- [ ] **Step 4: Validate metadata and local links**

Run:

```powershell
Invoke-Pester .github/cli/tests/DocumentationMetadata.Tests.ps1 -Output Detailed
git diff --check
```

Expected: metadata tests pass and no whitespace errors are reported. Repository-wide link validation is deferred until the HR targets in Task 4 are present.

- [ ] **Step 5: Commit the operating model**

```powershell
git add -- docs/operating-model docs/README.md
git commit -m "docs: import proposed operating model" -- docs/operating-model docs/README.md
```

### Task 3: Import ADR Candidates and Microsoft Evaluation

**Files:**
- Create: `docs/90-microsoft-best-practice-evaluation.md`
- Create: `docs/adr/0001-azure-devops-as-engineering-control-plane.md`
- Create: `docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md`
- Create: `docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md`
- Create: `docs/adr/0004-domain-solution-architecture-and-publisher.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/README.md`

- [ ] **Step 1: Write a failing Proposed Baseline authority test**

Append to `.github/cli/tests/Phase2SourceContract.Tests.ps1`:

```powershell
Describe 'Imported authority status' {
    It 'does not represent imported ADR candidates as accepted decisions' {
        $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        foreach ($path in @(Get-ChildItem (Join-Path $repositoryRoot 'docs\adr') -Filter '000[1-4]-*.md' -File)) {
            $content = Get-Content -LiteralPath $path.FullName -Raw
            $content | Should -Match '\| \*\*Status\*\* \| Proposed Baseline \|'
            $content | Should -Not -Match '(?m)^- \*\*Status:\*\* Accepted$'
        }
    }
}
```

- [ ] **Step 2: Run the authority test to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/Phase2SourceContract.Tests.ps1 -Output Detailed
```

Expected: FAIL because the imported ADR paths do not exist.

- [ ] **Step 3: Copy and adapt the four ADR candidates**

Copy the four hash-verified source files. For each:

1. Keep the H1 and full option/context/consequence analysis.
2. Remove the leading legacy `Status`, `Date`, `Deciders`, and `Supersedes` list.
3. Insert the standard header with Status `Proposed Baseline`, Scope `Cross-cutting (all solution domains)`, and references to the approved intake design and source inventory.
4. Rename `## Decision` to `## Proposed Decision`.
5. Change imperative acceptance wording such as `Adopt Option C` to `The proposed baseline adopts Option C`.
6. Do not create a new accepted ADR that supersedes the proposal in this phase.

- [ ] **Step 4: Copy and adapt the Microsoft evaluation**

Copy the source evaluation after verifying hash `fb4d29d4cf75f7cb659c71b21f83e900a484257e8d2cc06e1a006ec40f1b6031`. Add the standard header with Status `Proposed Baseline`, Scope `Cross-cutting (all solution domains)`, and references to current Microsoft guidance URLs already cited in the source. Preserve assessment findings but change claims about deployed controls to `planned`, `documented`, or `not yet verified` where no evidence exists in this repository.

- [ ] **Step 5: Catalogue candidate decisions and evaluation**

Update `docs/adr/README.md` to distinguish Proposed Baseline candidates from accepted repository decisions. Update `docs/README.md` with links to all four ADR candidates and the evaluation.

- [ ] **Step 6: Run authority, metadata, and link tests to verify GREEN**

Run:

```powershell
Invoke-Pester .github/cli/tests/Phase2SourceContract.Tests.ps1,.github/cli/tests/DocumentationMetadata.Tests.ps1 -Output Detailed
```

Expected: authority and metadata tests pass. Repository-wide link validation remains deferred until Task 4.

- [ ] **Step 7: Commit decision candidates and evaluation**

```powershell
git add -- docs/90-microsoft-best-practice-evaluation.md docs/adr docs/README.md .github/cli/tests/Phase2SourceContract.Tests.ps1
git commit -m "docs: import proposed architecture decisions" -- docs/90-microsoft-best-practice-evaluation.md docs/adr docs/README.md .github/cli/tests/Phase2SourceContract.Tests.ps1
```

### Task 4: Import HR and Synthetic Data Domain Guidance

**Files:**
- Create: `data/README.md`
- Create: `hr/README.md`
- Create: `hr/docs/20-hr-employee-journey.md`
- Create: `hr/src/solutions/README.md`
- Modify: `docs/README.md`

- [ ] **Step 1: Copy and adapt the substantive source documents**

Verify and copy:

```text
data/README.md  610ab9bc996f3641b14e0832cc5cfced346f7c88b3f3d7c268bac47498d34c77
hr/README.md  9ce61a8ae0e0722091bdbad7820591a4b1dade17edecc5cea3715b76fbcc5010
hr/docs/20-hr-employee-journey.md  49d6988c476b9866bc3ca6b70cae3d84b48a5e4c6e2918426c5b2b1614464bca
```

Insert the standard header into each with Status `Proposed Baseline`. Use Scope `Data` for `data/README.md` and Scope `HR` for both HR documents. Preserve the synthetic-data prohibition, MVP/Horizon 2 labels, managed-solution ALM requirements, and the Infra-before-HR dependency as proposed guidance.

- [ ] **Step 2: Replace the rejected solution placeholder with ownership guidance**

Create `hr/src/solutions/README.md`:

```markdown
# HR Solution Sources

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [HR Employee Journey](../../docs/20-hr-employee-journey.md), [Approved Intake Design](../../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |

This folder will contain unpacked, reviewable Power Platform solution source owned by the HR domain.

Do not commit exported solution ZIP files, environment-specific connection values, secrets, personal data, or generated build output. The Infrastructure solution is imported before the HR solution in each Power Platform ALM stage.

No Power Platform solution payload is present in the assessed source package.
```

Do not copy `hr/src/solutions/.gitkeep`.

- [ ] **Step 3: Update the cross-domain catalogue**

Add Data and HR domain tables to `docs/README.md`, linking the three imported documents and solution-source README. State that no seed JSON or solution payload is imported in this phase.

- [ ] **Step 4: Validate HR and Data content**

Run:

```powershell
Invoke-Pester .github/cli/tests/Phase2SourceContract.Tests.ps1,.github/cli/tests/DocumentationMetadata.Tests.ps1,.github/cli/tests/DocumentationLinks.Tests.ps1 -Output Detailed
if (Test-Path hr/src/solutions/.gitkeep) { throw 'Rejected HR placeholder was imported.' }
git diff --check
```

Expected: all tests pass, placeholder is absent, and diff check is empty.

- [ ] **Step 5: Commit HR and Data guidance**

```powershell
git add -- data hr docs/README.md
git commit -m "docs: import HR and data baseline" -- data hr docs/README.md
```

### Task 5: Merge the Product Map into the Root README

**Files:**
- Modify: `README.md`
- Modify: `docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md`

- [ ] **Step 1: Write a failing root README contract test**

Append to `.github/cli/tests/Phase2SourceContract.Tests.ps1`:

```powershell
Describe 'Root product and agent workflow map' {
    It 'preserves Superpowers and links the imported Proposed Baseline' {
        $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $content = Get-Content -LiteralPath (Join-Path $repositoryRoot 'README.md') -Raw
        foreach ($term in @('Superpowers', 'v6.3.0', '.github/skills', 'verify-repository-setup.ps1',
            'Caldova HR Frontier', 'docs/operating-model/00-north-star.md',
            'docs/operating-model/04-hitl-governance.md', 'hr/docs/20-hr-employee-journey.md')) {
            $content | Should -Match [regex]::Escape($term)
        }
        $content | Should -Match 'Proposed Baseline'
    }
}
```

- [ ] **Step 2: Run the root README test to verify RED**

Run:

```powershell
Invoke-Pester .github/cli/tests/Phase2SourceContract.Tests.ps1 -Output Detailed
```

Expected: FAIL because the target README lacks the product and operating-model map.

- [ ] **Step 3: Semantically merge root README content**

Preserve without weakening:

- bundled Superpowers discovery, version, verification, attribution, and update process;
- the standard metadata header;
- the rule against editing vendored skills.

Add from the hash-verified source README:

- product statement and closed feedback loop;
- audiences and MVP use cases;
- architecture and two-control-plane explanation, marked Proposed Baseline;
- public-repository data and secret prohibitions;
- domain layout for `infra/`, `hr/`, `data/`, and `docs/`;
- links to every imported Phase 2 document;
- current status that distinguishes documented proposals from implemented controls.

Remove or rewrite claims that Azure resources, Power Platform solutions, pipelines, repositories, seed data, or governance controls are already deployed.

- [ ] **Step 4: Complete the intake review disposition**

Set the Phase 2 review Status to `Approved` only after every row has a target commit and successful metadata/link validation reference. Record `README.md` as `Merge` and `hr/src/solutions/.gitkeep` as `Reject` with replacement README.

- [ ] **Step 5: Run the complete Phase 2 suite**

Run:

```powershell
Invoke-Pester .github/cli/tests -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
git diff --check main...HEAD
```

Expected: all tests pass; validator sole output is `Repository setup validation passed.`; diff check is empty.

- [ ] **Step 6: Commit the root documentation merge**

```powershell
git add -- README.md docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md .github/cli/tests/Phase2SourceContract.Tests.ps1
git commit -m "docs: publish proposed product baseline" -- README.md docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md .github/cli/tests/Phase2SourceContract.Tests.ps1
```

### Task 6: Review Phase 2 as an Independent Slice

**Files:**
- Verify: every path introduced or modified by Tasks 1-5

- [ ] **Step 1: Verify no executable payload was imported**

Run:

```powershell
$unexpected = @(Get-ChildItem data,hr,docs/operating-model -Recurse -File | Where-Object Extension -notin @('.md', '.json'))
if ($unexpected.Count -gt 0) { throw "Unexpected Phase 2 payload: $($unexpected.FullName -join ', ')" }
if (Test-Path hr/src/solutions/.gitkeep) { throw 'Rejected placeholder exists.' }
Write-Output 'Phase 2 contains documentation and declared synthetic-data formats only.'
```

Expected: `Phase 2 contains documentation and declared synthetic-data formats only.`

- [ ] **Step 2: Run clean-shell validation**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { Invoke-Pester .github/cli/tests -Output Detailed; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }; & .github/cli/verify-repository-setup.ps1 }"
git diff --check main...HEAD
git status --short
```

Expected: all tests pass, validator prints its sole success line, diff check is empty, and working tree is clean.

- [ ] **Step 3: Request Phase 2 review before infrastructure work**

Post the Phase 2 intake review path and commit list for attended review. Do not begin Phase 3 until the user explicitly approves the imported product, HR, Data, and operating-model content.