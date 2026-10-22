# Tenant Lifecycle Child Summary Envelope Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-19 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Corrective implementation of the Approved child-summary envelope on the existing blocked Tenant 1 lifecycle-core branch |
| **References** | [Approved Child Summary Envelope Design](../specs/2026-10-03-tenant-lifecycle-child-summary-envelope-design.md), [Approved Coordinate-Only Simplification Design](../specs/2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md), [Draft Coordinate-Only Correction Plan](2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md), [Implementation Plan Catalogue](README.md), [Infrastructure Operational Runbooks](../../infra/docs/runbooks/README.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the residual child-summary substitution and execution-manifest embedded-digest gaps without widening the Assess/Plan/Verify umbrella or exposing provider evidence.

**Architecture:** Evolve the existing canonical `Summary` contract in place, keep provider-specific extras only at the summary root, and validate one shared reserved envelope against the canonical stage result and current run coordinates. Both Verify and Assess/Plan prerequisite dispatch call the same exported summary-envelope interface, which also proves the final manifest file SHA and independently recomputes its existing embedded digest before returning a provider-free shared validation record.

**Tech Stack:** Windows PowerShell 5.1 (authoritative), PowerShell 7.6.6 (compatible), Pester 5.7.1, JSON Schema draft 2020-12, canonical UTF-8 JSON without BOM, SHA-256, Git, and the existing `Caldova.HrFrontier.Bootstrap` module.

**Spec:** [`docs/specs/2026-10-03-tenant-lifecycle-child-summary-envelope-design.md`](../specs/2026-10-03-tenant-lifecycle-child-summary-envelope-design.md)

## Baseline and Global Constraints

- Execute only in `C:\Users\urruegg\AppData\Local\CaldovaHR\wt\caldova-hr-frontier\t1-core` on `feat/tenant-lifecycle-core`. At plan creation the branch was reported at `e119aac`; `2b9ab63` is the implementation state this plan was checked against.
- Do not create a replacement branch, rebase, amend, squash, reset, or rewrite history. Recover the original 15 lifecycle commits from `2b9ab63`, record them oldest first, and prove after every implementation commit that every object ID remains an ancestor of `HEAD`.
- Each implementation task has its own RED/GREEN cycle, focused review, commit, and reviewer acceptance gate. Do not start the next task until the current task's diff and focused evidence are accepted.
- Keep the umbrella signature and authority exactly Assess/Plan/Verify. Do not add Apply, approval, `ShouldProcess`, provider authority, current-binding correlation, resource correlation, or provider read-back to the umbrella.
- Keep `stage-results/<stage>.json` authoritative. Preserve the existing second Verify validation pass and evidence-drift comparison.
- The summary has no self-digest. `phaseSummaryDigest` exists only in the stage result and is lowercase SHA-256 over the exact final canonical summary-file bytes.
- Provider-specific extras are allowed only at the summary root. They remain opaque to shared validation, errors, control records, and projection. Existing shared nested structures remain closed.
- Keep the existing secret, credential, token, private-path, raw-output, and unreviewed-provider-output boundary. Root opacity is not permission to store prohibited data.
- Legacy summaries fail closed. Do not add compatibility parsing, fallback schema versions, inference, repair, normalization, migration-in-place, or envelope injection.
- Do not authenticate or contact GitHub, Entra, Azure, Azure DevOps, PAC, Power Platform, a tenant, or another provider. Do not queue a pipeline, run deployment/WhatIf against Azure, import a solution, or mutate live state.
- Use synthetic identifiers and reserved example domains only. Windows PowerShell 5.1 is authoritative; all changed lifecycle behavior must also pass on PowerShell 7.6.6 with Pester 5.7.1.
- Leave `.github/workflows`, `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1`, and `infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1` unchanged.
- Keep all original child manifest, approval, action, state-adoption, read-back, and evidence helpers available. This plan changes shared evidence validation, not child mutation ownership.
- No task may claim merge readiness, push, merge, live execution, or provider execution. The corrective branch remains blocked until reviewed implementation is merged and then-current `main` is green.

## Exact Contract and Responsibility Split

The required summary root contains exactly these shared names plus optional provider-specific root extras:

```text
schemaVersion
runId
stage
sourceCommit
publicTenantKey
intentDigest
stateDigest
phaseManifestDigest
status
classification
completedAtUtc
startedAtUtc
counts
prerequisites
actions
nonClaims
```

Responsibility is assigned as follows and must not be duplicated through a permissive fallback:

| Layer | Exact responsibility |
|---|---|
| `tenant-lifecycle-summary.schema.json` | Requires all 16 exact shared names; validates their JSON types, formats, enums, outcome pairs, and closed shared nested structures; permits provider-specific root extras with root `additionalProperties: true`. It does not claim to detect duplicate JSON tokens or ordinal-ignore-case collisions after deserialization. |
| Raw JSON tokenizer in `Read-TenantLifecycleCanonicalJsonFile.ps1` | Rejects exact duplicate property tokens at every object depth before `ConvertFrom-Json`; for a `Summary`, rejects any root names that collide under `StringComparer.OrdinalIgnoreCase` and rejects a shared name unless its spelling is byte-exact. It never includes a property name or value in an error. |
| `Test-TenantLifecycleContract.ps1` | Requires each shared root property as an exact gettable `NoteProperty`, permits only non-colliding extra root `NoteProperty` members, validates shared values and allowed status/classification pairs, keeps `counts`, `prerequisites`, `actions`, and `nonClaims` closed, and preserves recursive prohibited-data validation in the writer. |
| `Test-TenantLifecycleSummaryEnvelope.ps1` | Reads the fixed canonical summary and manifest files, proves exact file digests, recomputes the manifest embedded `digest`, correlates all reserved summary fields to the stage result and current coordinates, and returns only a closed provider-free validation record. |

The three digest definitions are immutable:

1. Manifest embedded `digest`: `Get-TenantLifecycleExecutionManifestDigest` over the existing manifest digest input, excluding the final `digest` member.
2. `phaseManifestDigest`: lowercase SHA-256 over the exact final canonical `execution-manifest.json` bytes, including its populated embedded `digest`.
3. `phaseSummaryDigest`: lowercase SHA-256 over the exact final canonical `summary.json` bytes; it is written only to the stage result.

## Stable Shared Interface

Task 3 creates and exports this one interface for both Verify and prerequisite dispatch:

```powershell
function Test-TenantLifecycleSummaryEnvelope {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)]
        [ValidateSet(
            'Workstation',
            'PrivateBoundary',
            'Foundation',
            'DevDelivery',
            'ReadBack',
            'Acceptance',
            'TenantReplica'
        )]
        [string]$Stage,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string]$SourceCommit,
        [Parameter(Mandatory)]
        [ValidateSet('tenant1')]
        [string]$PublicTenantKey,
        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-f]{64}$')]
        [string]$IntentDigest,
        [Parameter(Mandatory)][object]$StageResult
    )
}
```

On success it returns exactly:

```powershell
[pscustomobject][ordered]@{
    stage = [string]$Stage
    manifestStateDigest = [string]$manifest.stateDigest
    selectedStages = [string[]]@($manifest.selectedStages)
    prerequisiteResults = [object[]]@($closedPrerequisiteResults)
}
```

Each returned prerequisite item has exactly `stage`, `status`, `classification`, `phaseManifestDigest`, `phaseSummaryDigest`, `intentDigest`, and `stateDigest`. The function returns no summary object, provider property, manifest action, provider context, path containing private data, or opaque name/value.

The interface exposes only these fixed failure messages and never attaches an inner exception:

```text
TenantLifecycle.SummaryEnvelope.StageResult.Invalid
TenantLifecycle.SummaryEnvelope.Manifest.FileInvalid
TenantLifecycle.SummaryEnvelope.Manifest.EmbeddedDigestMismatch
TenantLifecycle.SummaryEnvelope.Summary.FileInvalid
TenantLifecycle.SummaryEnvelope.schemaVersion.Mismatch
TenantLifecycle.SummaryEnvelope.runId.Mismatch
TenantLifecycle.SummaryEnvelope.stage.Mismatch
TenantLifecycle.SummaryEnvelope.sourceCommit.Mismatch
TenantLifecycle.SummaryEnvelope.publicTenantKey.Mismatch
TenantLifecycle.SummaryEnvelope.intentDigest.Mismatch
TenantLifecycle.SummaryEnvelope.stateDigest.Mismatch
TenantLifecycle.SummaryEnvelope.phaseManifestDigest.Mismatch
TenantLifecycle.SummaryEnvelope.status.Mismatch
TenantLifecycle.SummaryEnvelope.classification.Mismatch
TenantLifecycle.SummaryEnvelope.completedAtUtc.Mismatch
```

The fixed messages identify the shared artifact or reserved rule and failure class without including provider names, provider values, private values, raw JSON, or file-system paths.

---

### Task 1: Shared Summary Contract, Tokenizer, and Runtime Validator

**Files:**
- Modify: `infra/src/config/schemas/tenant-lifecycle-summary.schema.json`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleContract.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Read-TenantLifecycleCanonicalJsonFile.ps1`
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json` (`summary` contract fixture only; Task 2 completes `phaseSummary`)

**Interfaces:**
- Preserves: `Test-TenantLifecycleContract -Kind Summary -InputObject $summary` returning `$true` or throwing `TenantLifecycle.Contract.Summary`.
- Extends the private reader with:

```powershell
[ValidateSet('None', 'StageResult', 'ExecutionManifest', 'Summary')]
[string]$ContractKind = 'None'
```

- Extends the tokenizer entry point with:

```powershell
Assert-TenantLifecycleJsonHasUniqueProperties `
    -Text $text `
    -RootReservedPropertyNames $summarySharedPropertyNames
```

- Produces no compatibility mode and no new schema version; the supported shared summary `schemaVersion` remains `1.0`.

- [ ] **Step 1: Pin and record the immutable baseline**

Run:

```powershell
$ErrorActionPreference = 'Stop'
if ((git branch --show-current).Trim() -cne 'feat/tenant-lifecycle-core') {
    throw 'Wrong branch.'
}
git merge-base --is-ancestor e119aac HEAD
if ($LASTEXITCODE -ne 0) { throw 'Expected planning baseline e119aac is not an ancestor.' }
git cat-file -e '2b9ab63^{commit}'
if ($LASTEXITCODE -ne 0) { throw 'Implementation baseline 2b9ab63 is unavailable.' }
$ImplementationBase = (git merge-base main 2b9ab63).Trim()
$OriginalLifecycleCommits = @(
    git rev-list --reverse "$ImplementationBase..2b9ab63"
)
if ($OriginalLifecycleCommits.Count -ne 15) {
    throw "Expected 15 original lifecycle commits; found $($OriginalLifecycleCommits.Count)."
}
$OriginalLifecycleCommits
git status --short
```

Expected: branch is exact, both pinned commits resolve, 15 object IDs print oldest first, and only this plan's reviewed documentation commit may precede implementation work.

- [ ] **Step 2: Write focused failing contract tests**

Add a `Describe 'Tenant lifecycle child summary envelope contract'` block. Build the valid test value directly so failures are attributable to the new contract:

```powershell
$validSummary = [pscustomobject][ordered]@{
    schemaVersion = '1.0'
    runId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
    stage = 'Foundation'
    sourceCommit = 'a' * 40
    publicTenantKey = 'tenant1'
    intentDigest = '1' * 64
    stateDigest = '2' * 64
    phaseManifestDigest = '3' * 64
    status = 'Passed'
    classification = 'NoChange'
    startedAtUtc = '2026-10-02T12:00:00.0000000Z'
    completedAtUtc = '2026-10-02T12:11:00.000Z'
    counts = [pscustomobject][ordered]@{
        NoChange = 1
        Create = 0
        Update = 0
        Manual = 0
        Blocked = 0
        Refused = 0
    }
    prerequisites = @()
    actions = @()
    nonClaims = @('Synthetic evidence only.')
    syntheticProviderExtension = [pscustomobject][ordered]@{
        resultCode = 'SyntheticPassed'
    }
}
```

Assert all of the following:

- the schema requires the 16 shared fields, uses root `additionalProperties: true`, removes `manifestDigest`, adds `phaseManifestDigest`, and keeps every shared nested object at `additionalProperties: false`;
- runtime and JSON Schema accept the valid object and its root provider extension;
- runtime rejects a missing, wrong-case, wrong-type, or malformed in-memory shared member;
- only the seven stage-result outcome pairs are accepted;
- `completedAtUtc` uses exact `yyyy-MM-dd'T'HH:mm:ss.fff'Z'`, is not earlier than `startedAtUtc`, and remains a string;
- an extra property inside `counts`, a prerequisite, or an action is rejected;
- raw JSON with duplicate names at any depth is rejected before deserialization;
- raw summary JSON containing both `runId` and `RunId`, or both `actions` and `Actions`, is rejected without echoing either extension names or values;
- existing prohibited-data cases still fail through `Write-TenantLifecycleEvidence`.

Update only the fixture's `summary` member to the valid envelope so the generic runtime/schema contract cases stay green. Keep `phaseSummary` for Task 2.

- [ ] **Step 3: Run RED and inspect the reason**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleContracts.Tests.ps1' -FullNameFilter '*child summary envelope contract*','*complete synthetic summary contract*' -Output Detailed"
```

Expected RED: the schema still requires `manifestDigest`, closes the root, omits the reserved coordinates, the runtime requires the old 11-field shape, or the tokenizer accepts an ordinal-ignore-case root collision. A syntax, fixture-loading, or Pester discovery error is not acceptable RED and must be corrected before implementation.

- [ ] **Step 4: Implement the exact shared contract**

Set the schema root to `additionalProperties: true`, require all 16 shared fields, and define these reserved properties:

```json
{
  "schemaVersion": { "const": "1.0" },
  "runId": { "$ref": "#/$defs/runId" },
  "stage": { "$ref": "#/$defs/stage" },
  "sourceCommit": { "$ref": "#/$defs/sourceCommit" },
  "publicTenantKey": { "const": "tenant1" },
  "intentDigest": { "$ref": "#/$defs/digest" },
  "stateDigest": { "$ref": "#/$defs/digest" },
  "phaseManifestDigest": { "$ref": "#/$defs/digest" },
  "status": { "enum": ["Passed", "Failed", "Blocked", "Refused", "Manual"] },
  "classification": { "enum": ["NoChange", "Changed", "Manual", "Blocked", "Refused"] },
  "completedAtUtc": {
    "type": "string",
    "format": "date-time",
    "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$"
  }
}
```

Use the stage-result schema's five `oneOf` branches to encode the seven valid pairs. Keep the existing `startedAtUtc`, `counts`, `prerequisites`, `actions`, and `nonClaims` definitions and closed nested objects.

In the runtime validator, replace the Summary call to `Assert-TenantLifecycleProperties` with an exact-required-plus-extra root validator. Validate all required properties before enumerating extras, use `StringComparer.OrdinalIgnoreCase` to reject collisions, require exact spelling with `StringComparer.Ordinal`, and never evaluate a non-`NoteProperty` getter. Validate the same fields, formats, pair set, and time ordering as the schema.

In the raw tokenizer, retain ordinal duplicate detection at every depth. When `ContractKind` is `Summary`, pass the 16 shared names and reject any root collision under `StringComparer.OrdinalIgnoreCase` before `ConvertFrom-TenantLifecycleJson`. Preserve the existing canonical-byte, UTF-8, LF, containment, regular-file, and reparse checks.

- [ ] **Step 5: Run GREEN on both supported hosts**

Run:

```powershell
$Filter = @(
  '*child summary envelope contract*',
  '*complete synthetic summary contract*'
)
$FilterLiteral = ($Filter | ForEach-Object { "'$_'" }) -join ','
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleContracts.Tests.ps1' -FullNameFilter @($FilterLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell summary contract tests failed.' }
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path 'infra/tests/pester/TenantLifecycleContracts.Tests.ps1' -FullNameFilter @($FilterLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 summary contract tests failed.' }
```

Expected GREEN: both hosts accept the exact envelope and safe root extension, reject legacy/collision/nested-extension cases, and emit no provider name or value in errors.

- [ ] **Step 6: Review and commit Task 1**

Review the responsibility split, schema/runtime pair parity, tokenizer-before-deserializer order, exact spelling, nested closure, and unchanged prohibited-data boundary. Prove the 15 recorded commits remain ancestors, then commit:

```powershell
$OriginalLifecycleCommits | ForEach-Object {
    git merge-base --is-ancestor $_ HEAD
    if ($LASTEXITCODE -ne 0) { throw "Original lifecycle commit was rewritten: $_" }
}
git diff --check
git add infra/src/config/schemas/tenant-lifecycle-summary.schema.json
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleContract.ps1
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Read-TenantLifecycleCanonicalJsonFile.ps1
git add infra/tests/pester/TenantLifecycleContracts.Tests.ps1
git add infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json
git commit -m "fix(runbooks): define child summary envelope contract" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**Independent review gate:** A reviewer must accept Task 1's schema/tokenizer/runtime responsibility split and focused dual-host evidence before Task 2 starts.

---

### Task 2: Child Writer, Fixture, and Canonical Digest Migration

**Files:**
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-TenantLifecycleEvidence.ps1`
- Modify: `infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json`
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`

**Interfaces:**
- Preserves:

```powershell
$summaryPath = Write-TenantLifecycleEvidence `
    -RunDirectory $phaseDirectory `
    -RelativePath 'summary.json' `
    -Kind Summary `
    -InputObject $summary
```

- Returns the absolute written path as `[string]`.
- Writes canonical ordinal-key-sorted, array-order-preserving JSON at depth 30, UTF-8 without BOM, exactly one trailing LF, through `Write-TenantLifecycleAtomicFile`.
- Rejects an existing target; it never overwrites or repairs a summary.

- [ ] **Step 1: Write failing child write-protocol tests**

Add `Describe 'Tenant lifecycle child summary writer and cross-host golden'` with tests that:

1. create a complete manifest through `New-TenantLifecycleExecutionManifest`;
2. write it with `Write-TenantLifecycleEvidence -Kind ExecutionManifest`;
3. compute `phaseManifestDigest` from `[IO.File]::ReadAllBytes()` with `SHA256`;
4. construct the final envelope-bearing summary after terminal outcome and output state are known;
5. write it once with `Write-TenantLifecycleEvidence -Kind Summary`;
6. compute `phaseSummaryDigest` from the exact summary bytes;
7. create and immutably write the stage result last.

Use this summary construction shape in fixture helpers:

```powershell
$summary = [pscustomobject][ordered]@{
    schemaVersion = '1.0'
    runId = $RunId.ToString('D').ToLowerInvariant()
    stage = $Stage
    sourceCommit = $SourceCommit
    publicTenantKey = 'tenant1'
    intentDigest = $IntentDigest
    stateDigest = $OutputStateDigest
    phaseManifestDigest = $phaseManifestDigest
    status = $Status
    classification = $Classification
    startedAtUtc = '2026-10-03T08:30:00.0000000Z'
    completedAtUtc = '2026-10-03T08:31:00.000Z'
    counts = $SharedCounts
    prerequisites = [object[]]@($SharedPrerequisites)
    actions = [object[]]@($SharedActions)
    nonClaims = @('Synthetic evidence only.')
    syntheticProviderEvidence = $SyntheticProviderEvidence
}
```

Move provider-specific action details below the `syntheticProviderEvidence` root extra. Keep shared `actions` entries closed with exactly `id`, `classification`, `status`, and `evidenceRelativePath`.

Assert:

- the write order is manifest, summary, stage result;
- summary `phaseManifestDigest` is the exact final manifest-file SHA, not its embedded `digest`;
- stage-result `phaseSummaryDigest` is the exact final summary-file SHA;
- no `phaseSummaryDigest` exists in summary bytes;
- a changed timestamp, outcome, state digest, or provider extension produces different exact summary bytes and requires a new run;
- an overwrite attempt throws `TenantLifecycle.Evidence.Exists`;
- old `manifestDigest` or any incomplete legacy summary throws `TenantLifecycle.Evidence.Invalid`;
- Windows PowerShell 5.1 and PowerShell 7.6.6 write byte-identical manifest, summary, and stage-result files and calculate identical digests.

Use a literal canonical golden object with fixed synthetic values and compare each host's bytes to:

```powershell
$expectedSummaryBytes = [Text.UTF8Encoding]::new($false).GetBytes(
    (ConvertTo-TenantLifecycleCanonicalJson -InputObject $expectedSummary)
)
[Convert]::ToBase64String([IO.File]::ReadAllBytes($summaryPath)) |
    Should -BeExactly ([Convert]::ToBase64String($expectedSummaryBytes))
```

The expected object is built independently from fixture constants; do not regenerate it by reading the file under test.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1') -FullNameFilter '*child summary writer*','*summary write protocol*','*cross-host summary golden*' -Output Detailed"
```

Expected RED: `phaseSummary` and helper-built summaries still omit reserved fields, use provider-shaped shared `actions`, use `manifestDigest`, or do not prove the ordered exact-byte digest transition.

- [ ] **Step 3: Implement the minimum writer and fixture migration**

Keep the writer signature and atomic implementation. For `Kind Summary`, require the Task 1 runtime contract and prohibited-data boundary before canonicalization, retain the exact `summary.json` relative path, and preserve write-once behavior.

Migrate both fixture summary forms and all current lifecycle test builders. Use `New-TenantLifecycleExecutionManifest` so every manifest contains a valid embedded `digest`; never create a hand-written manifest with an arbitrary digest. Compute the final manifest-file SHA only after writing the canonical file. Populate summary envelope fields from trusted child values, not from the stage result. Compute summary-file SHA only after the immutable write, then pass it to `New-TenantLifecycleStageResult`.

Do not add a summary self-digest, a legacy constructor, a fallback writer, or a writer mode that overwrites an existing file.

- [ ] **Step 4: Run GREEN and the full contract suite**

Run:

```powershell
$Tests = @(
  'infra/tests/pester/TenantLifecycleContracts.Tests.ps1',
  'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1'
)
$TestsLiteral = ($Tests | ForEach-Object { "'$_'" }) -join ','
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($TestsLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell lifecycle contracts failed.' }
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($TestsLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 lifecycle contracts failed.' }
```

Expected GREEN: both full lifecycle files pass, both hosts produce byte-identical goldens, and all legacy summaries fail closed.

- [ ] **Step 5: Review and commit Task 2**

Review the manifest-summary-result ordering, exact-byte digest sources, immutable writes, fixture safety, cross-host literals, and absence of inference. Prove ancestry and commit:

```powershell
$OriginalLifecycleCommits | ForEach-Object {
    git merge-base --is-ancestor $_ HEAD
    if ($LASTEXITCODE -ne 0) { throw "Original lifecycle commit was rewritten: $_" }
}
git diff --check
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-TenantLifecycleEvidence.ps1
git add infra/tests/fixtures/runbooks/tenant-lifecycle.synthetic.json
git add infra/tests/pester/TenantLifecycleContracts.Tests.ps1
git add infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1
git commit -m "fix(runbooks): write canonical child summary envelopes" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**Independent review gate:** A reviewer must accept the immutable write order, exact digest definitions, legacy rejection, and cross-host bytes before Task 3 starts.

---

### Task 3: Shared Verify and Prerequisite Enforcement

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleSummaryEnvelope.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleStageResultSet.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1`
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`

**Interfaces:**
- Produces the exact exported `Test-TenantLifecycleSummaryEnvelope` signature and four-field return record defined in this plan's Stable Shared Interface section.
- Consumes `Read-TenantLifecycleCanonicalJsonFile`, `Test-TenantLifecycleContract`, and the existing `Get-TenantLifecycleExecutionManifestDigest`.
- `Test-TenantLifecycleStageResultSet` keeps its current public signature unchanged.
- `Invoke-TenantLifecycle.ps1` keeps its exact current public signature unchanged.

- [ ] **Step 1: Write failing shared-enforcement tests**

Add `Describe 'Tenant lifecycle shared summary envelope enforcement'`. Assert that direct helper use:

- accepts a valid completed stage and returns exactly `stage`, `manifestStateDigest`, `selectedStages`, and `prerequisiteResults`;
- returns no summary object or provider extra;
- rejects every reserved-field mismatch with the stage result or supplied current coordinate;
- rejects a wrong fixed summary path;
- rejects a summary SHA mismatch;
- rejects a manifest final-file SHA mismatch;
- rejects an embedded manifest `digest` mismatch even when the exact final-file SHA in summary and result is updated;
- maps failures to the fixed public messages in the Stable Shared Interface section without an inner exception or provider marker.

Add equivalent integration cases proving:

- Verify reaches the helper through `Test-TenantLifecycleStageResultSet`;
- Assess/Plan prerequisite loading reaches the same exported helper before dispatching the later child;
- Verify invocation count remains zero on success and failure;
- prerequisite failure leaves the later-child invocation count zero;
- no projection exists after failure;
- the existing second Verify pass still calls `Test-TenantLifecycleStageResultSet` twice and rejects between-pass drift.

- [ ] **Step 2: Run RED**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1') -FullNameFilter '*shared summary envelope enforcement*','*second Verify pass*','*prerequisite summary envelope*' -Output Detailed"
```

Expected RED: no exported shared interface exists, Verify remains digest-only, prerequisite dispatch uses separate digest-only code, or the manifest final-file SHA is accepted without recomputing its embedded `digest`.

- [ ] **Step 3: Implement the shared validator**

Implement `Test-TenantLifecycleSummaryEnvelope` in this exact order:

1. validate `StageResult` with `Test-TenantLifecycleContract -Kind StageResult`;
2. compare result `runId`, `stage`, `sourceCommit`, `publicTenantKey`, `intentDigest`, and fixed `evidenceRelativePath` to parameters;
3. read `phases/<stage>/execution-manifest.json` canonically with `ContractKind ExecutionManifest` and expected exact `phaseManifestDigest`;
4. recompute `Get-TenantLifecycleExecutionManifestDigest -Manifest $manifest` and compare it ordinally with `manifest.digest`;
5. compare manifest run/source/tenant/intent coordinates to current parameters;
6. read `phases/<stage>/summary.json` canonically with `ContractKind Summary` and expected exact `phaseSummaryDigest`;
7. compare summary `schemaVersion` to `1.0`;
8. compare summary `runId`, `stage`, `sourceCommit`, `publicTenantKey`, and `intentDigest` to both result and current parameters;
9. compare summary `stateDigest`, `phaseManifestDigest`, `status`, `classification`, and `completedAtUtc` to the stage result;
10. project only the four-field provider-free return record, deep-cloning each prerequisite item to its seven shared fields; and
11. catch each file/contract boundary separately and map it to the fixed public message for that artifact or reserved-field mismatch without attaching the caught exception.

Do not enumerate or copy summary provider extras. Do not put provider names, values, paths, actions, contexts, or raw JSON in errors.

- [ ] **Step 4: Replace both digest-only paths**

In `Test-TenantLifecycleStageResultSet.ps1`, replace its separate manifest/summary reads with one helper call. Use the returned `manifestStateDigest`, `selectedStages`, and closed `prerequisiteResults` for the existing stage order, prerequisite, and input-state/output-state chain checks.

In `Read-TenantLifecyclePrerequisite` inside `Invoke-TenantLifecycle.ps1`, read and validate the stage result, then call the same exported helper. Use only its closed return record for selected-stage, prerequisite, and state-chain checks. Keep literal `Passed` and `NoChange|Changed` prerequisite acceptance.

Delete the local summary digest-only read from prerequisite handling. Do not remove local assessment/plan child-artifact validation. Keep Verify's second `Test-TenantLifecycleStageResultSet` pass and byte comparison unchanged.

- [ ] **Step 5: Run GREEN on both hosts**

Run:

```powershell
$Tests = @(
  'infra/tests/pester/TenantLifecycleContracts.Tests.ps1',
  'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1'
)
$TestsLiteral = ($Tests | ForEach-Object { "'$_'" }) -join ','
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($TestsLiteral) -FullNameFilter '*shared summary envelope enforcement*','*second Verify pass*','*prerequisite summary envelope*' -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell shared enforcement failed.' }
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($TestsLiteral) -FullNameFilter '*shared summary envelope enforcement*','*second Verify pass*','*prerequisite summary envelope*' -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 shared enforcement failed.' }
```

Expected GREEN: Verify and prerequisite dispatch reject the same invalid evidence, manifest embedded-digest tamper fails despite updated exact file SHA, Verify invokes nothing, later-child dispatch is blocked, and no projection is written.

- [ ] **Step 6: Review and commit Task 3**

Review export parity in `.psm1` and `.psd1`, the exact signature and return type, one shared call site per enforcement path, all 11 reserved correlations, both manifest digest checks, provider-free returns/errors, and preservation of the second Verify pass. Prove ancestry and commit:

```powershell
$OriginalLifecycleCommits | ForEach-Object {
    git merge-base --is-ancestor $_ HEAD
    if ($LASTEXITCODE -ne 0) { throw "Original lifecycle commit was rewritten: $_" }
}
git diff --check
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleSummaryEnvelope.ps1
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantLifecycleStageResultSet.ps1
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1
git add infra/src/scripts/runbooks/Invoke-TenantLifecycle.ps1
git add infra/tests/pester/TenantLifecycleContracts.Tests.ps1
git add infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1
git commit -m "fix(runbooks): enforce child summary envelope coordinates" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**Independent review gate:** A reviewer must accept the one-interface implementation, exact correlations, equivalent Verify/prerequisite behavior, and no-invocation/no-projection evidence before Task 4 starts.

---

### Task 4: Coordinated Substitution, Adversarial Integration, and Runbook Documentation

**Files:**
- Modify: `infra/tests/pester/TenantLifecycleContracts.Tests.ps1`
- Modify: `infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/docs/runbooks/01-developer-workstation.md`
- Modify: `infra/docs/runbooks/03-customer-handover.md`
- Modify: `infra/docs/README.md`
- Modify: `infra/README.md`

**Interfaces:**
- No new production interface.
- Preserves the Task 3 signature and provider-free return record exactly.
- Documentation describes Approved behavior but continues to label implementation Draft/blocked until reviewed merge and then-current green `main`.

- [ ] **Step 1: Add the complete reserved-field mutation matrix**

Create a table-driven test with one row for each reserved field and each failure class:

| Field | Malformed value | Mismatch value |
|---|---|---|
| `schemaVersion` | integer `1` | string `2.0` |
| `runId` | `not-a-guid` | `bbbbbbbb-cccc-4ddd-8eee-ffffffffffff` |
| `stage` | `Unknown` | `ReadBack` for a `Foundation` result |
| `sourceCommit` | 40 `g` characters | 40 `b` characters |
| `publicTenantKey` | `tenant/1` | `tenant2` |
| `intentDigest` | 64 `g` characters | 64 `4` characters |
| `stateDigest` | 64 `g` characters | 64 `5` characters |
| `phaseManifestDigest` | 64 `g` characters | 64 `6` characters |
| `status` | `Ready` | valid `Failed` against a `Passed` result |
| `classification` | `Create` | valid `Changed` against a `NoChange` result |
| `completedAtUtc` | `2026-10-03T08:31:00.0000000Z` | `2026-10-03T08:31:00.001Z` |

For each field, run separate missing, malformed, exact-name case drift, and semantic mismatch cases. Keep all non-target fields valid so each RED identifies one requirement. Recalculate canonical bytes and `phaseSummaryDigest` after every mutation so a digest-only validator would accept it.

- [ ] **Step 2: Add coordinated and disclosure adversarial tests**

Add exact cases for:

- duplicate reserved JSON properties;
- ordinal-ignore-case collisions for every reserved/shared root name;
- a complete old-format legacy summary with coordinated updated result digest;
- foreign summary and result substitution with updated `phaseSummaryDigest`;
- changed manifest content with stale embedded `digest`, followed by updated exact `phaseManifestDigest` in both summary and result and updated `phaseSummaryDigest` in result;
- valid opaque root extras containing synthetic provider IDs, names, URLs under `provider.example.invalid`, actions, and nested values;
- the same valid and invalid evidence through Verify and Assess/Plan prerequisite dispatch;
- zero `SubsystemInvoker`, child, provider-runner, or adapter calls from Verify;
- zero later-child invocation after prerequisite failure;
- no creation or update of `<run>/summary.json` after any failure;
- no provider extra property name or value in helper errors, orchestrator errors, control records, or projection bytes.

For coordinated substitution, modify both the canonical summary and stage result, recompute the summary-file SHA, and prove current `RunId`, source, tenant, intent, stage, and private-state coordinates still reject the pair.

For the embedded manifest tamper, change a digest-covered shared manifest value, leave its embedded `digest` stale, rewrite canonical bytes, update summary/result `phaseManifestDigest` to the new exact file SHA, rewrite the summary, and update result `phaseSummaryDigest`. Expected rejection is `TenantLifecycle.SummaryEnvelope.Manifest.EmbeddedDigestMismatch`.

- [ ] **Step 3: Run adversarial RED, then apply only required hardening**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester/TenantLifecycleContracts.Tests.ps1','infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1','infra/tests/pester/RunbookDocumentation.Tests.ps1') -FullNameFilter '*summary envelope adversarial*','*coordinated summary substitution*','*embedded manifest digest tamper*','*opaque provider extras*','*Approved child summary envelope*' -Output Detailed"
```

Expected RED: the new documentation test fails because maintained runbooks still describe summary validation as exact bytes/digest only and do not route to the Approved envelope or Draft residual plan. The adversarial tests may already pass through the reviewed Tasks 1-3 implementation. If an adversarial test fails, return to and reopen its owning Task 1, 2, or 3 review gate; do not bypass an accepted interface in this documentation task.

- [ ] **Step 4: Update maintained runbook documentation and its tests**

Add a `RunbookDocumentation.Tests.ps1` case named `publishes the Approved child summary envelope and residual implementation gate`. Require the five maintained documents to state:

- the shared summary envelope reserves the exact 11 correlation/outcome fields and retains the five standard fields;
- provider-specific extras are root-only, opaque, and absent from projection/errors;
- nested shared structures remain closed;
- the manifest embedded `digest`, exact `phaseManifestDigest`, and exact `phaseSummaryDigest` are distinct;
- summary is written before the stage result and has no self-digest;
- Verify and prerequisite dispatch enforce the same envelope and embedded manifest digest;
- legacy evidence fails closed and requires a new run;
- umbrella authority remains exact Assess/Plan/Verify;
- `stage-results` remains authoritative and the second Verify pass remains;
- Plan 1 and this implementation remain synthetic, Draft, and blocked until reviewed merge and then-current green `main`;
- no live/provider/tenant operation or merge-readiness claim is made.

Apply these exact metadata updates and link both the Approved specification and this Draft plan:

| Document | Version | Date |
|---|---:|---:|
| `infra/docs/runbooks/README.md` | 1.6 | 2026-10-19 |
| `infra/docs/runbooks/01-developer-workstation.md` | 1.5 | 2026-10-19 |
| `infra/docs/runbooks/03-customer-handover.md` | 1.4 | 2026-10-19 |
| `infra/docs/README.md` | 1.4 | 2026-10-19 |
| `infra/README.md` | 1.10 | 2026-10-19 |

Remove stale claims that summaries are validated only as opaque exact bytes, but retain the statement that provider-specific extras are opaque.

- [ ] **Step 5: Run GREEN including documentation**

Run:

```powershell
$Tests = @(
  'infra/tests/pester/TenantLifecycleContracts.Tests.ps1',
  'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1',
  'infra/tests/pester/RunbookDocumentation.Tests.ps1'
)
$TestsLiteral = ($Tests | ForEach-Object { "'$_'" }) -join ','
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($TestsLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell adversarial or documentation tests failed.' }
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($TestsLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 adversarial or documentation tests failed.' }
```

Expected GREEN: the full reserved-field matrix, substitutions, digest tamper, equivalence, opacity, no-invocation, no-projection, and documentation contract pass on both hosts.

- [ ] **Step 6: Review and commit Task 4**

Review every matrix row, prove all mutations recompute outer digests, inspect thrown strings and projection bytes for provider markers, confirm no provider extra is interpreted, validate documentation status language, prove ancestry, and commit:

```powershell
$OriginalLifecycleCommits | ForEach-Object {
    git merge-base --is-ancestor $_ HEAD
    if ($LASTEXITCODE -ne 0) { throw "Original lifecycle commit was rewritten: $_" }
}
git diff --check
git add infra/tests/pester/TenantLifecycleContracts.Tests.ps1
git add infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1
git add infra/tests/pester/RunbookDocumentation.Tests.ps1
git add infra/docs/runbooks/README.md
git add infra/docs/runbooks/01-developer-workstation.md
git add infra/docs/runbooks/03-customer-handover.md
git add infra/docs/README.md
git add infra/README.md
git commit -m "test(runbooks): prove child summary envelope boundaries" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**Independent review gate:** A reviewer must accept the complete adversarial matrix, disclosure assertions, equivalent path evidence, and maintained runbook wording before Task 5 starts.

---

### Task 5: Full Verification and Final Whole-Branch Review

**Files:**
- Verify only; do not create generated evidence or an empty commit.

**Interfaces:**
- Consumes the reviewed Task 1-4 commits.
- Produces terminal command output for review, not a repository artifact or completion claim.

- [ ] **Step 1: Run focused and full lifecycle suites on both hosts**

Run:

```powershell
$ErrorActionPreference = 'Stop'
$LifecycleTests = @(
  'infra/tests/pester/TenantLifecycleContracts.Tests.ps1',
  'infra/tests/pester/TenantLifecycleOrchestration.Tests.ps1',
  'infra/tests/pester/RunbookContracts.Tests.ps1',
  'infra/tests/pester/RunbookStaticSafety.Tests.ps1',
  'infra/tests/pester/RunbookDocumentation.Tests.ps1'
)
$LifecycleLiteral = ($LifecycleTests | ForEach-Object { "'$_'" }) -join ','
$Focused = @(
  '*child summary envelope*',
  '*coordinated summary substitution*',
  '*embedded manifest digest tamper*',
  '*opaque provider extras*'
)
$FocusedLiteral = ($Focused | ForEach-Object { "'$_'" }) -join ','

powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($LifecycleLiteral) -FullNameFilter @($FocusedLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell focused lifecycle tests failed.' }
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($LifecycleLiteral) -FullNameFilter @($FocusedLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 focused lifecycle tests failed.' }

powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($LifecycleLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'Windows PowerShell full lifecycle tests failed.' }
pwsh.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @($LifecycleLiteral) -Output Detailed"
if ($LASTEXITCODE -ne 0) { throw 'PowerShell 7 full lifecycle tests failed.' }
```

Expected: focused and full lifecycle suites pass with zero failures on Windows PowerShell 5.1 and PowerShell 7.6.6.

- [ ] **Step 2: Run all maintained Pester, safety, setup, and documentation validation**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$Maintained = Invoke-Pester -Path @(
  '.github/cli/tests',
  'infra/tests/pester',
  'hr/tests/pester'
) -Output Detailed -PassThru
if ($Maintained.FailedCount -gt 0) {
    throw "$($Maintained.FailedCount) maintained Pester test(s) failed."
}

powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository safety verification failed.' }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository setup verification failed.' }

$Docs = Invoke-Pester -Path @(
  '.github/cli/tests/DocumentationMetadata.Tests.ps1',
  '.github/cli/tests/DocumentationLinks.Tests.ps1',
  '.github/cli/tests/DocumentationNavigation.Tests.ps1',
  'infra/tests/pester/RunbookDocumentation.Tests.ps1'
) -Output Detailed -PassThru
if ($Docs.FailedCount -gt 0) {
    throw "$($Docs.FailedCount) documentation test(s) failed."
}
```

Expected: all maintained Pester, repository safety/setup, metadata, relative-link, catalogue-navigation, and runbook-documentation checks pass with zero failures.

- [ ] **Step 3: Build all Bicep locally without deployment**

Run:

```powershell
Get-ChildItem infra/src/bicep -Filter '*.bicep' -File -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        az bicep build --file $_.FullName --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Bicep build failed: $($_.FullName)"
        }
    }
```

Expected: every Bicep source builds locally. Do not run `az login`, `az deployment`, or any Azure WhatIf/deployment command.

- [ ] **Step 4: Prove workflow, stub, ancestry, whitespace, and worktree invariants**

Run:

```powershell
$ImplementationBase = (git merge-base main 2b9ab63).Trim()
$OriginalLifecycleCommits = @(
    git rev-list --reverse "$ImplementationBase..2b9ab63"
)
if ($OriginalLifecycleCommits.Count -ne 15) {
    throw "Expected 15 original lifecycle commits; found $($OriginalLifecycleCommits.Count)."
}

git diff --check e119aac..HEAD
if ($LASTEXITCODE -ne 0) { throw 'Git diff whitespace validation failed.' }
git diff --exit-code e119aac..HEAD -- .github/workflows
if ($LASTEXITCODE -ne 0) { throw 'GitHub workflows changed.' }
git diff --exit-code e119aac..HEAD -- `
  infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1 `
  infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1
if ($LASTEXITCODE -ne 0) { throw 'Dormant cloud stop stubs changed.' }

$OriginalLifecycleCommits | ForEach-Object {
    git cat-file -e "$_^{commit}"
    if ($LASTEXITCODE -ne 0) { throw "Original lifecycle object is missing: $_" }
    git merge-base --is-ancestor $_ HEAD
    if ($LASTEXITCODE -ne 0) { throw "Original lifecycle commit is no longer an ancestor: $_" }
}

$Status = @(git status --short)
if ($Status.Count -ne 0) {
    throw "Worktree is not clean:`n$($Status -join [Environment]::NewLine)"
}
git log --oneline --decorate "$ImplementationBase..HEAD"
```

Expected: no whitespace defect, workflow diff, stop-stub diff, rewritten original commit, missing ancestor, or uncommitted file exists.

- [ ] **Step 5: Re-run the whole-branch residual-blocker review**

Review the complete `$ImplementationBase..HEAD` diff against both Approved designs and answer every item with a file/test reference:

1. umbrella modes remain exact Assess/Plan/Verify with no Apply, approval, `ShouldProcess`, provider, or resource authority;
2. `stage-results` remains authoritative and the second Verify pass remains;
3. all 16 shared summary fields are exact, required, and correctly owned;
4. root provider extras are allowed, opaque, secret-safe, and absent from errors/projection;
5. shared nested structures are closed;
6. schema, tokenizer, runtime contract, and shared envelope helper responsibilities do not overlap through a permissive fallback;
7. summary has no self-digest and each of the three digest definitions is implemented exactly;
8. Verify and prerequisite dispatch use the same exported interface and recompute manifest embedded `digest`;
9. every reserved field has missing, malformed, case, and mismatch coverage;
10. coordinated substitution and updated-outer-digest manifest tamper fail closed;
11. Verify invokes nothing and writes no projection on failure; prerequisite failure invokes no later child;
12. legacy evidence has no compatibility, inference, repair, or migration path;
13. Windows PowerShell 5.1 and PowerShell 7.6.6 canonical bytes/digests agree;
14. child approval/mutation/read-back/state helpers remain and workflows/stubs are unchanged;
15. docs say Approved design but Draft/blocked implementation and make no live/provider/merge claim; and
16. every original lifecycle commit remains an ancestor.

Any failed item returns to its owning task and keeps the branch blocked. Do not waive, defer, push, merge, or create an empty verification commit.

**Final review gate:** Task 5 is accepted only from fresh command output and an accepted whole-branch review. Passing on the feature branch does not itself make the branch merge-ready; reviewed merge and then-current green `main` remain required.

## Plan Self-Review Record

- **Spec coverage:** Task 1 covers Sections 4.2-4.3 and schema/tokenizer/runtime ownership; Task 2 covers Sections 4.1, 4.4, 5, and 7; Task 3 covers Section 6; Task 4 covers Sections 8-9 plus maintained documentation; Task 5 covers Section 10 and the residual blocker.
- **Placeholder scan:** The plan contains no `TBD`, `TODO`, deferred implementation step, unnamed helper, unspecified error handling, or “same as another task” instruction. Authoritative `<stage>` path notation is retained only where the Approved contract itself uses that variable.
- **Signature and type consistency:** `Test-TenantLifecycleSummaryEnvelope` has one exact signature and one exact four-field return record throughout Tasks 3-5. Existing public signatures remain unchanged.
- **Task dependencies:** Task 1 establishes the contract; Task 2 creates valid immutable artifacts; Task 3 enforces them; Task 4 attacks and documents the integrated behavior; Task 5 verifies the entire branch. Every transition has an independent review gate.
- **Current-code compatibility:** The plan was checked against the `2b9ab63` implementation state: it amends the existing summary schema/runtime validator, canonical tokenizer/reader, evidence writer, exact stage-result set validator, prerequisite reader, module exports, fixture helpers, and second Verify pass rather than assuming replacement components.
- **Repository navigation:** The plan uses the repository `docs/plans` override, is linked from `docs/plans/README.md`, is the successor reference from the Approved specification and corrective plan, and requires metadata, link, navigation, and `RunbookDocumentation` validation.

## Completion Gate

This Draft plan is implemented only after all four implementation commits pass their independent reviews, Task 5 has fresh all-green evidence, the whole-branch review closes the residual blocker, the original 15 commits remain ancestors, workflows and dormant stubs remain unchanged, the worktree is clean, and no live/provider activity occurred. The branch still remains blocked until that reviewed implementation is merged and then-current `main` is green.
