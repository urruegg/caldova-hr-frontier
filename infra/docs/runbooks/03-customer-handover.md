# Customer Repository Handover Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure customer repository handover |
| **References** | [Operational Runbooks](README.md); [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md); [`New-CustomerRepositoryExport.ps1`](../../src/scripts/runbooks/New-CustomerRepositoryExport.ps1); [`Test-CustomerRepositoryExport.ps1`](../../src/scripts/runbooks/Test-CustomerRepositoryExport.ps1); [`customer-export.schema.json`](../../src/config/schemas/customer-export.schema.json); [`customer-export.sample.json`](../../src/config/runbooks/customer-export.sample.json) |

## Purpose

This runbook prepares a synthetic customer-facing repository export from the reusable source without mutating the source tree. Execution is local, attended, and limited to Windows 11 PowerShell 5.1 or 7. Authentication is `NotApplicable`. Evidence is written only outside Git. Publication is not implemented here and remains a separate attended procedure.

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

Failure leaves the source untouched and does not produce a publish-ready destination. The only removable path is the explicitly named disposable or customer staging directory after a human path review. Any failed validation, digest mismatch, executable-identity change, residual detection, or source-state change requires a new assessment and approval. Recovery never broadens scope and never treats a failed or manual item as verified.

## Definition of Done

The handover is done only when the approved source commit remains unchanged, Apply completed behind `ShouldProcess`, independent validation returned `publishReady = $true`, the export tree contains no `.git` metadata or workflow content, a human reviewer accepted the staged content, and the later publication procedure is approved separately.
