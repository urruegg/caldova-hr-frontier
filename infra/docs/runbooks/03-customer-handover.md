# Customer Repository Handover Runbook

| Field | Value |
|---|---|
| **Version** | 1.7 |
| **Date** | 2026-10-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure customer repository handover |
| **References** | [Operational Runbooks](README.md); [Approved Tenant 1 Runbook End-to-End Design](../../../docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md); [Approved Child Summary Envelope Design](../../../docs/specs/2026-10-03-tenant-lifecycle-child-summary-envelope-design.md); [Draft Child Summary Envelope Implementation Plan](../../../docs/plans/2026-10-03-tenant-lifecycle-child-summary-envelope-implementation.md); [Tenant Lifecycle Core Implementation Plan](../../../docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md); [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md); [`New-CustomerRepositoryExport.ps1`](../../src/scripts/runbooks/New-CustomerRepositoryExport.ps1); [`Test-CustomerRepositoryExport.ps1`](../../src/scripts/runbooks/Test-CustomerRepositoryExport.ps1); [`customer-export.schema.json`](../../src/config/schemas/customer-export.schema.json); [`customer-export.sample.json`](../../src/config/runbooks/customer-export.sample.json) |

## Purpose

This runbook prepares a synthetic customer-facing repository export from the reusable source without mutating the source tree. Execution is local, attended, and limited to Windows 11 PowerShell 5.1 or 7. Authentication is `NotApplicable`. Evidence is written only outside Git. Publication is not implemented here and remains a separate attended procedure.

## Profile-contract and shared-library slice (Plan 5, Tasks 1–2 only)

[`repository-export.schema.json`](../../src/config/schemas/repository-export.schema.json)
adds explicit `TenantReplica` and `CustomerHandover` intent profiles.
`Import-RepositoryExportManifest -Path <absolute-local-file> -ExpectedProfile
<TenantReplica|CustomerHandover>` rejects absent, unknown, case-mismatched, or
conflicting profiles. It reads only the manifest, not its referenced source
files, marker sources, private intent, or state.

The canonical `1.0` object reuses the historical manifest fields and adds
`profile`, `profilePolicy`, and `deniedPaths`. Policy values are fixed assertions,
not permission switches: `denyEvidence`, `denyTenantTransitions`,
`denyPrivateState`, `denySourceHistory`, and `denyUntrackedFiles` are always
`true`; `denyWorkflows` is `true` for customer handover and `false` for replica
intent. The shared assessment library can retain committed workflows for replica
intent, subject to the same exact content checks; the existing customer scripts
still exclude them. Exact denied
paths include their descendants; duplicate paths and contradictions with
retained artifacts, replacements, residual dispositions, classifications, or
binary exceptions fail closed, including Windows case and path aliases.

`ConvertTo-CustomerHandoverManifest -LegacyManifest <object>` accepts only the
recognized unprofiled v1 fields, validates them, and returns the fixed canonical
customer profile without modifying the input. `Import-CustomerExportManifest
-Path` remains the compatibility interface for existing consumers and also
accepts the explicitly profiled customer sample. It never accepts replica intent.
It rejects nonempty additional `deniedPaths`, rather than passing rules the
existing customer export engine cannot enforce. The historical
[`customer-export.schema.json`](../../src/config/schemas/customer-export.schema.json)
and invalid fixture are unchanged; the previous customer sample is preserved as
a v1 test fixture. Both file importers require a JSON object at the root, and the
adapter requires an object before normalization; root arrays (including singleton
arrays), primitives, and null are rejected. Nested literal replacement arrays
remain supported. JSON fields are closed and typed, duplicate properties and IDs
are rejected, and input files must be UTF-8 without BOM.

The [customer sample](../../src/config/runbooks/customer-export.sample.json)
and [replica sample](../../src/config/runbooks/tenant-replica.sample.json) are
synthetic contract examples, not approval or accepted retained-tree evidence.
Source/destination binding, run IDs, approvals, and digests remain owned by the
existing execution-manifest boundary, not a parallel intent contract.

### Shared assessment and planning library

`Get-RepositoryExportAssessment -SourceRoot -ExpectedSourceCommit -DestinationRoot
-Manifest -Profile -RepositoryIdentity -ToolIdentities -NativeCommandRunner` is a
library operation, not an export script. Every parameter is required. Its manifest
object must satisfy the same closed canonical profile contract as the importer;
an unprofiled object, a conflicting profile, or weakened policy is not a
compatibility shortcut. Validation precedes source enumeration.

`RepositoryIdentity` is the caller-reviewed expected 64-hex `remotesDigest` from
`Get-CustomerExportSourceSnapshot`. That existing contract hashes the complete
sorted nonempty local `git remote -v` lines, including every fetch record, push
record, additional push URL, and additional remote. The library compares that
expected digest with a fresh observation; it does not choose one remote or URL,
normalize URLs, infer intent from its own observation, or record remote
coordinates. A different commit or remote inventory is rejected before committed
blobs are enumerated. Existing customer callers remain snapshot-bound under their
historical interface; that behavior is not a fallback for this parameter.

The assessment reuses the customer engine's committed-blob inventory,
marker assertions, exact transformations, residual checks, synthetic-data checks,
and digest helpers. It checks source snapshots before and after assessment.
Ignored/untracked values are never read, including ignored workflow files.
Git status uses no optional locks. The destination must be absent, outside source
and Git worktrees, and free of reparse traversal. Assessment creates neither
destination, staging, nor evidence, and does not patch an existing destination.
Successful assessments are classified `Create`; unsafe input fails closed.

Assessment evidence contains counts, statuses, digests, action IDs, fixed suite
IDs, and tool versions, not source text, marker/replacement values, source paths,
or remote coordinates. A digest binds the complete private source snapshot and
the retained/denied inventories; policy digests bind retained artifacts, exact
denials, markers, replacements, residual dispositions, profile, classifications,
binary exceptions, synthetic policy, and fixed suites. Tool executable paths are
represented by path digests alongside verified file hashes and caller-reviewed
versions. Destination and boundary identities are also path digests.

`New-RepositoryExportActionPlan -Assessment -Manifest -RunId -EvidenceRoot -NowUtc`
rechecks assessment integrity and policy bindings and uses the existing
`New-RunbookExecutionManifest` constructor and verifier with kind `CustomerExport`.
This is reuse of the shared local-export contract, not a second manifest schema.
Its sorted `executionManifest.allowedActions` is an **authorization set**. It is
not the execution sequence. The separately exposed `orderedActions` is bound by
the assessment digest and checked against this fixed order for both profiles:

`snapshot-source` → `stage-committed-blobs` → `apply-exact-transformations` →
`validate-profile` → `promote-destination` → `snapshot-source-post` →
`validate-independent`.

The execution manifest binds the assessment, run ID, time, tools, destination,
permissions, and a digest-only evidence-root scope. Planning rejects evidence
inside source, destination, or any Git worktree, and writes nothing. The existing
customer independent validator alone retains its historical
`AllowExistingDestination` assessment behavior; it is not exposed by the canonical
library and cannot enable replica behavior.

The current canonical deny policy covers explicit denied paths and descendants,
customer workflows, evidence, private local state, approvals, backups, run roots,
provider/discovery/transition payloads, source-history metadata, and default-denied
tenant artifacts. Engineering text still requires the existing reviewed
classifications where synthetic inspection is inconclusive. This is not the
complete Task 3 capability map or retained-tree fixture acceptance. The library
records the historical fixed suites (`Pester`, `RepositorySafety`, `BicepBuild`);
it does not execute them against a destination or establish profile-independent
full-tree validation.

This slice adds no canonical Apply, replica export entry point, independent
validator, pipeline delivery, real export, publication, or acceptance. Plan 5
remains Draft; all export, pipeline, and live acceptance gates remain unchanged.

## Lifecycle-core integration boundary

The lifecycle core recognizes `TenantReplica` as a stage identifier but does not invoke [`New-CustomerRepositoryExport.ps1`](../../src/scripts/runbooks/New-CustomerRepositoryExport.ps1), [`Test-CustomerRepositoryExport.ps1`](../../src/scripts/runbooks/Test-CustomerRepositoryExport.ps1), a publication remote, or any handover provider. The local export and independent validator remain directly runnable under this runbook's separate contracts. A later reviewed replica/handover plan must define the digest binding and production subsystem invoker before the umbrella may sequence this stage.

Plan 1's synthetic `TenantReplica` stage is not export, independent-validation, human-review, transfer, or publication evidence. A sanitized lifecycle projection cannot make any of those claims.

The replica/handover child owns its assessment, execution manifest, approval, WhatIf/Apply, `ShouldProcess`, independent full-tree read-back, terminal summary, and immutable `<run>/stage-results/TenantReplica.json` result. Existing `ExecutionManifestPath`, `ApprovedDigest`, and Apply behavior remain child interfaces. The exact future sequence is child `Plan` -> child `approvals.json` -> child `WhatIf` -> child `Apply` -> child read-back -> canonical stage result -> umbrella `Verify`.

Umbrella `Assess` or `Plan` may later dispatch only the matching non-mutating replica child mode through a reviewed invoker. Umbrella `Verify` never invokes the export engine, never publishes a repository, and never interprets destination or file-level evidence; it accepts only an exact canonical stage result with literal `Passed` status. Private lifecycle state remains only in the ignored local state file and is never copied into run or handover evidence. Plan 1 was implemented with local synthetic tests only; no live cloud, provider, or tenant operation was performed.

### Approved child summary envelope and residual gate

The shared child summary envelope reserves exactly `schemaVersion`, `runId`, `stage`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `phaseManifestDigest`, `status`, `classification`, and `completedAtUtc`, and retains the five standard fields `startedAtUtc`, `counts`, `prerequisites`, `actions`, and `nonClaims`.

Provider-specific extras are root-only and opaque, are absent from projections and errors, and cannot enter the closed shared nested structures.

The manifest embedded `digest`, exact-file `phaseManifestDigest`, and exact-file `phaseSummaryDigest` are three distinct checks.

The child writes the summary before the stage result, and the summary has no self-digest.

Umbrella `Verify` and `Assess`/`Plan` prerequisite dispatch enforce the same envelope and embedded manifest digest.

Legacy evidence fails closed and requires a new run; there is no compatibility, inference, or repair path.

Umbrella authority remains exactly `Assess`, `Plan`, and `Verify`; `stage-results` remains authoritative and the second `Verify` pass remains required.

Plan 1 and the child summary envelope implementation remain synthetic evidence.
The profile-contract slice does not change their approval status or establish live acceptance.

No live, provider, or tenant operation was performed, and no merge-readiness claim is made.

## Roles and prerequisites

The service owner reviews the customer-export manifest, confirms every reviewed replacement and residual disposition, and records the approved digest. The workstation administrator performs the local run from a clean reviewed source commit. The source working tree, `.git`, refs, remotes, hooks, workflows, and tracked blobs remain immutable. Every required executable must resolve uniquely to one rooted path with a stable SHA-256 and version.

## Assessment and shared execution manifest

Use synthetic paths only:

```powershell
$source = 'C:\src\caldova-hr-frontier'
$stage = 'D:\customer-staging\customer-synthetic'
$manifest = 'C:\reviewed-intent\customer-export.json'
$report = Join-Path $env:LOCALAPPDATA 'CaldovaHrFrontier\runbook-evidence\11111111-2222-3333-4444-555555555555'
$hostPowerShell = [IO.Path]::GetFullPath((Get-Process -Id $PID).Path)
Import-Module "$source\infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1" -Force
$git = Resolve-CustomerExportExecutable -Name git.exe
$commit = (& $git.path -C $source rev-parse HEAD).Trim()

& $hostPowerShell -NoProfile -File "$source\infra\src\scripts\runbooks\New-CustomerRepositoryExport.ps1" `
  -SourceRoot $source -ExpectedSourceCommit $commit -DestinationRoot $stage `
  -ManifestPath $manifest -ReportPath $report

$assessment = Get-Content -Raw (Join-Path $report 'customer-export-assessment.json') | ConvertFrom-Json
$executionManifest = Get-Content -Raw (Join-Path $report 'customer-export-execution-manifest.json') | ConvertFrom-Json
$assessment.digest
$executionManifest.digest
```

Planning writes `customer-export-assessment.json`, `customer-export-execution-manifest.json`, and `customer-export-evidence.json`. Each evidence envelope records generation time, source commit, assessment digest, execution-manifest digest as `planDigest`, reviewed customer-export manifest digest, operator ID, operation, classification, status, ShouldProcess decision, target, tool identities, and final local context.

## Approve the digest

Before approval, review the exact source commit, destination stable ID, retained artifacts, exclusions, residual markers, residual dispositions, `sourceMarkerCatalog`, fixed validation suites, and every replacement by exact ID, path, format, selector, old/new text in the reviewed manifest, and required count. The reviewer reads the reviewed manifest directly because console summaries and evidence show only digests and counts.

For Markdown customer-name edits, confirm each change targets one tracked `.md` file, uses `MarkdownExact`, preserves that file's newline style, and never acts as a wildcard, regex, directory-wide, extension-wide, or repository-wide replacement. A replacement in one named Markdown file never authorizes the same old marker anywhere else. Every old customer or tenant marker must map either to an exact reviewed replacement rule or to one exact path-and-marker residual disposition with a written reason.

Review each required tool path, SHA-256, and version in both the assessment and the shared execution manifest. Missing, ambiguous, changed-path, changed-version, or changed-hash resolution invalidates approval immediately and requires a new assessment.

Review `sourceMarkerCatalog` in two parts: every reviewed assertion must still match committed bytes by path, blob digest, and count; separately, every automatically discovered alias, ID, domain, URL, and email suffix from retained or denied tenant artifacts must be represented. Confirm that verified reviewed `CompanyName` and `OtherTenantIdentifier` assertions outside tenant configuration remain valid, that `residualMarkers` exactly match the marker projection, and that every `SyntheticFixture` or `ReviewedNonPersonal` exception binds exact `path`, `sourceBlobSha256`, `expectedOutputSha256`, classification, and reason. `data/` and evidence paths are never excepted.

## Apply with ShouldProcess

Use `-WhatIf` first, then apply only the approved digest:

```powershell
& $hostPowerShell -NoProfile -File "$source\infra\src\scripts\runbooks\New-CustomerRepositoryExport.ps1" `
  -SourceRoot $source -ExpectedSourceCommit $commit -DestinationRoot $stage `
  -ManifestPath $manifest -ReportPath $report `
  -ExecutionManifestPath (Join-Path $report 'customer-export-execution-manifest.json') `
  -ApprovedDigest $executionManifest.digest -Apply -Confirm
```

`-WhatIf` must not create a destination or disposable staging directory. Approved Apply rechecks source state, manifest digest, assessment digest, execution-manifest approval, and every executable identity before mutation. The script copies only committed blobs from the approved source commit, applies reviewed replacements in memory per target file, validates the disposable staging tree, and then promotes it atomically.

## Independent validation

Run independent validation before any human publication review:

```powershell
& $hostPowerShell -NoProfile -File "$source\infra\src\scripts\runbooks\Test-CustomerRepositoryExport.ps1" `
  -SourceRoot $source -ExpectedSourceCommit $commit -DestinationRoot $stage -ManifestPath $manifest `
  -ExecutionManifestPath (Join-Path $report 'customer-export-execution-manifest.json') `
  -ApprovedDigest $executionManifest.digest `
  -ReportPath (Join-Path $report 'independent-validation')
```

Independent validation rereads every original blob from the exact approved commit, reapplies the reviewed rules in memory, and compares the complete expected bytes with staging. It does not trust fields already changed in staging. It writes `customer-export-validation.json` and `customer-export-validation-evidence.json`. Any mismatch requires a new assessment and approval rather than `-Force`.

## Human review

Human review inspects the staged export together with the redacted reports. Confirm that the export contains no `.git` path, no `.github/workflows` path, no denied tenant artifact, and no unexpected data or evidence path. Review the exact staged Markdown and JSON output that the reviewed manifest intended to change. Validation success alone does not authorize publication.

## Publication boundary

These scripts do not authenticate to a publication remote, create a remote, add a remote, push, force-push, transfer, or modify the reusable source remote. Publication remains a separate attended procedure with its own approval and evidence. This runbook ends at a validated local export boundary.

## Evidence

The report directory may contain `customer-export-assessment.json`, `customer-export-execution-manifest.json`, `customer-export-evidence.json`, `customer-export-validation.json`, and `customer-export-validation-evidence.json`. Evidence contains only non-secret provenance, digests, counts, statuses, and reviewed identifiers needed for read-back. It never stores tokens, PATs, secrets, raw connection strings, or remote publication targets.

## Failure and recovery

Failure leaves the source untouched and does not produce a publish-ready destination. The only removable path is the explicitly named disposable or customer staging directory after a human path review. Any restart, failed validation, digest mismatch, executable-identity change, residual detection, or source-state change requires a new assessment, manifest, and approval. Prior evidence is preserved but cannot resume an approval bound to the earlier process session. Recovery never broadens scope and never treats a failed or manual item as verified.

## Definition of Done

The handover is done only when the approved source commit remains unchanged, Apply completed behind `ShouldProcess`, independent validation returned `publishReady = $true`, the export tree contains no `.git` metadata or workflow content, a human reviewer accepted the staged content, and the later publication procedure is approved separately.
