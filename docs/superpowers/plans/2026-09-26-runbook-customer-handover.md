# Customer Repository Export and Handover Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.5 |
| **Date** | 2026-09-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure customer repository export and handover |
| **References** | [Operational Runbooks Design](../../specs/2026-09-26-operational-runbooks-design.md), [Runbook Foundation Plan](2026-09-26-runbook-foundation-workstation.md), [Documentation Policy](../../README.md), [Infrastructure Domain](../../../infra/README.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a local, attended, digest-bound process that creates and validates a history-free customer repository export in clean external staging while proving that the reusable source repository is unchanged and that every foreign-tenant residual is disposed explicitly.

**Architecture:** A closed JSON manifest allowlists tenant artifacts, exact per-file JSON Pointer or Markdown text replacements, a source marker catalogue, digest-bound synthetic/non-personal classifications, exact residual exceptions, and fixed local validation suites. Thin PowerShell entry points use export-specific helpers in the existing `Caldova.HrFrontier.Bootstrap` module to snapshot immutable source state, discover source markers, classify expected content, produce a deterministic export assessment, and pass that assessment into the shared `New-RunbookExecutionManifest -Kind CustomerExport` contract; no export-specific execution-manifest constructor or validator is introduced. Approved Apply reads tracked blobs from the expected commit into a disposable sibling directory, omits prohibited content and `.github/workflows/`, applies only reviewed structured rules, and promotes staging only after validation. Independent validation rebuilds every expected file in memory from the original commit and byte-compares it with staging. Validation and publication remain separate, no `.git` exists in staging/export, and no code creates a remote, adds a remote, pushes, transfers ownership, or rewrites the source.

**Tech Stack:** Attended Windows 11, Windows PowerShell 5.1, PowerShell 7, Pester 5.7.1, Git CLI, JSON Schema draft 2020-12, canonical UTF-8 JSON, SHA-256, and the existing `Caldova.HrFrontier.Bootstrap` PowerShell module.

**Spec:** `docs/specs/2026-09-26-operational-runbooks-design.md`

## Global Constraints

- This increment covers only customer-export contracts, export creation, export validation, the customer-handover runbook, and its Infrastructure documentation linkage. Workstation initialization, cloud-foundation operations, authentication, customer publication, and remote administration are excluded.
- Run every script locally and attended on Windows 11 in Windows PowerShell 5.1 or PowerShell 7. Refuse CI, GitHub Actions, runners, remoting, scheduled tasks, services, non-interactive hosts, and unattended/headless switches.
- Do not add, remove, or modify any path below `.github/workflows/`. The customer export omits `.github/workflows/` in full, including every workflow, reusable workflow, and workflow template.
- The reusable source working tree, tracked files, `.git` directory, object database, index, refs, reflogs, remotes, remote URLs, configuration, hooks, and workflow files are immutable. Every source Git operation is read-only.
- Require a clean source checkout at exactly `ExpectedSourceCommit`. Refuse staged, unstaged, untracked, conflicted, sparse, or submodule state; symbolic links and Git links are refused rather than followed.
- Copy only regular tracked blobs from the expected commit. Never read an untracked or ignored source file into the export, and never copy source history or `.git`.
- No `.git` file or directory may exist at any point in disposable staging or the completed export. Never initialize a disposable repository; all inventory and validation operate directly on the staged file tree.
- Destination staging must be outside the source repository and every Git working tree, must not exist before Apply, and must resolve without a reparse point. Build in a newly created disposable sibling directory and rename it to the requested destination only after all export checks pass.
- Default invocation is assessment and planning only. It may read Git metadata and tracked blobs and write a canonical plan/report under the approved external evidence path, but it must not create the destination or disposable staging tree.
- Export creation requires explicit `-Apply`, a fresh shared execution manifest, approval matching its exact lowercase SHA-256 digest, unchanged source snapshot and customer-export manifest digest through a freshly recomputed assessment digest, displayed operations, and `ShouldProcess`. `-WhatIf` and declined confirmation always prevent staging writes.
- No script or manifest may accept a password, token, PAT, secret, credential, client secret, certificate secret, authorization header, device code, authentication environment-variable name/value, remote URL, organization credential, or publication target.
- Do not call `gh`, `az`, `azd`, `pac`, a service API, `git init`, `git remote`, `git push`, `git fetch`, `git pull`, `git checkout`, `git switch`, `git reset`, `git clean`, `git filter-branch`, `git filter-repo`, or any source-mutating Git command.
- Tenant-owned artifacts are denied by default. Retain only exact, case-canonical, tracked repository-relative paths named by `retainedTenantArtifacts`; allowed roots are `infra/src/config/tenants/` and `infra/src/bicep/parameters/`. No path under `infra/evidence/` is retainable.
- Evidence and generated reports are always excluded without exception. Paths containing an `evidence` segment and repository `data/` paths are denied. Fixture-bearing paths are denied by default; only an exact regular tracked path below `infra/tests/fixtures/` may be retained when the manifest binds its file digest, `SyntheticFixture` classification, and written reason.
- Structured replacement supports only `Json` and `MarkdownExact`. `Json` identifies one exact tracked `.json` path, RFC 6901 JSON Pointer, exact old JSON value, exact new JSON value, and required count `1`. `MarkdownExact` identifies one exact tracked `.md` path, exact expected old text, exact new text, and an integer required occurrence count of at least `1`; it performs ordinal literal replacement only in that file.
- Replacement paths do not need to be retained tenant artifacts, but every replacement target must be a regular tracked file at the approved source commit and must be outside `.git/`, `.github/workflows/`, `.github/skills/`, `infra/evidence/`, and any other evidence path denied by repository policy. Wildcards, regular expressions, globs, directory paths, extension-wide rules, and global tree replacement are invalid.
- `MarkdownExact` reads and writes BOM-free strict UTF-8, refuses mixed LF/CRLF newlines, atomically preserves the original newline style, verifies the exact pre-write occurrence count, and leaves the file byte-for-byte unchanged on mismatch. Internal validation may retain rule ID/path/format/selector metadata, but serialized replacement evidence contains only the rule digest and replacement count; it never contains paths, selectors, expected-old values, new values, or source text.
- Generic platform and architecture names, including `GitHub`, `Azure`, `Workday`, `Dataverse`, `Power Platform`, and `SharePoint`, are prohibited residual markers and replacement values only when the manifest attempts to classify them as tenant-specific; they are never globally replaced.
- Scan every exported file name, directory segment, and UTF-8 text file for every manifest marker. Reject binary content unless the exact path is allowlisted as an independently inspectable binary with its SHA-256 digest and written reason.
- A residual disposition is valid only for one exact repository-relative path and one exact marker ID with a non-empty written reason. Wildcards, directory rules, extension rules, and category-wide suppression are invalid. Every undisposed match fails validation.
- The manifest contains a closed reviewed `sourceMarkerCatalog`. Its marker projection must equal `residualMarkers` exactly by ID, category, value, and comparison—no missing or additional marker on either side. Every catalogue source assertion is independently verified against committed bytes at its exact path, blob digest, and occurrence count regardless of whether that path is a tenant configuration, documentation file, or another tracked regular file.
- Planning separately and automatically extracts every source tenant alias, stable ID, domain, URL, and email suffix from all selected tenant manifests and all tenant artifacts denied from export. Every automatic tenant-config candidate must be represented by a verified catalogue entry. Verified reviewed entries such as `CompanyName` or `OtherTenantIdentifier` are permitted even when they are not automatic tenant-config candidates; they are not rejected merely for extending the reviewed catalogue.
- Synthetic-data validation is fail closed across every exported UTF-8 file. It scans structured keys and text for identity, person, employee/candidate/worker identifiers, names, contact details, email addresses, phone numbers, postal addresses, and date/date-of-birth patterns. Only manifest-declared reserved synthetic names, reserved domains, and reserved ID prefixes are accepted automatically.
- Any file whose personal-data classification is inconclusive is excluded unless `fileClassifications` contains its exact path, source-commit blob SHA-256, expected post-replacement output SHA-256, classification `ReviewedNonPersonal`, and written reason. An exact fixture exception additionally requires a path below `infra/tests/fixtures/`, both digests, classification `SyntheticFixture`, and reason. Assessment computes expected output in memory and verifies both digests before inclusion. Classification entries and verified digest pairs are bound into the customer-export manifest, assessment digest, and shared execution manifest; wildcard, directory, extension, or digest-free exceptions are invalid.
- Validation includes tracked/export inventory, tenant-artifact allowlisting, prohibited paths and content, structured replacement counts, residuals, UTF-8, Markdown six-field metadata, relative links, fixed local Pester/repository-safety/Bicep suites selected by manifest IDs, and source snapshot equality.
- Evidence and plans default below `%LOCALAPPDATA%\CaldovaHrFrontier\runbook-evidence\<runId>\`, remain outside Git and staging, contain only allowlisted metadata, and never contain replacement new values, raw file content, command output, personal data, or credentials.
- Publication is a hard boundary after successful validation and human review. Export and validation scripts never create a local or remote repository, authenticate to a customer organization, add or change a remote, push, force-push, transfer ownership, or report that publication occurred.
- Use the shared canonical JSON, digest, report-path, evidence, interactive-host, `New-RunbookExecutionManifest`, and `Test-RunbookExecutionManifest` contracts from `2026-09-26-runbook-foundation-workstation.md`; implement that prerequisite plan first. Use `Kind CustomerExport`, target `{ type = 'CustomerExport'; stableId = <destination-stable-id> }`, and only the shared allowlisted action properties. Do not redefine, wrap, or fork the shared execution-manifest constructor or validator. Preserve every existing module export and behavior.
- Shared allowed actions are closed to these exact properties: `action`, `targetId`, `service`, `method`, `uri`, `bodyDigest`, `packageSource`, `packageId`, `scope`, `requiredVersion`, `sourceRelativePath`, `destinationRelativePath`, `replacementRuleId`, and `expectedPostcondition`. Customer export uses only the applicable subset and introduces no additional action property.
- Every native executable is resolved before assessment with `Get-Command -All -CommandType Application` through an injectable resolver, canonicalized to an absolute path, and SHA-256 hashed through an injectable identity provider. Collapse duplicate results only when canonical path and digest are identical; zero matches fail as missing and multiple non-equivalent matches fail as ambiguous. Never select the first PATH result.
- Bind the exact absolute executable path, SHA-256, and display-safe version for Git, Windows PowerShell, and Azure CLI when its validation suite is selected into the customer-export assessment and shared execution manifest `ToolVersions`. Immediately before the first staging write, resolve and hash every required tool again and refuse if path, digest, uniqueness, or availability changed.
- Invoke Git, Windows PowerShell, repository safety validation, Pester, and Azure CLI/Bicep only through the approved absolute executable paths. Neither assessment, Apply, independent validation, nor fixed-suite execution may invoke a bare command name or shell-resolved alias.
- Use the shared evidence interface exactly: `ConvertTo-RunbookEvidenceRecord -RunId <guid> -GeneratedAtUtc <datetime> -SourceCommit <40-hex> -AssessmentDigest <64-hex> [-PlanDigest <64-hex>] [-ManifestDigest <64-hex>] -OperatorId <display-safe string> -Operation <string> -Classification <NoChange|Create|Update|Manual|Blocked|Refused> -Status <Planned|Applied|Verified|Failed|Refused> -ShouldProcessDecision <NotApplicable|Approved|Declined|WhatIf> [-TargetId <string>] [-ToolVersions <object>] [-ReadBack <object>] [-FinalContext <object>] [-ManualItems <string[]>] [-ErrorCategory <string>]`. Every export evidence record supplies all mandatory provenance fields.
- ADR-0001, ADR-0002, and ADR-0003 remain Proposed Baseline. This increment does not approve them and does not alter the stable HR constraints in ADR-0005, ADR-0007, ADR-0009, or ADR-0011.
- Each checkbox is one 2–5 minute action. Stop after each command, compare the stated result, and keep red, green, and commit gates separate.

## File Map

| File | Responsibility |
|---|---|
| `infra/src/config/schemas/customer-export.schema.json` | Closed schema for customer artifact selection, per-file JSON/Markdown replacements, source marker catalogue, exact residual dispositions, synthetic-data policy/classifications, inspectable binaries, and fixed validation-suite IDs. |
| `infra/src/config/runbooks/customer-export.sample.json` | Schema-valid, entirely synthetic example manifest; it is not approved customer intent. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/ConvertFrom-JsonPointer.ps1` | RFC 6901 traversal returning one exact writable JSON property or array element. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Convert-CustomerExportBlob.ps1` | In-memory JSON/Markdown transformation used identically by export creation and independent validation. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-CustomerExportTextKind.ps1` | BOM/UTF-8 and binary classification without lossy decoding. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-CustomerExportSyntheticBytes.ps1` | Per-file structured/text personal-data classification over supplied bytes. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-CustomerExportRelativePath.ps1` | Canonical repository-relative path validation and case-collision detection. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-CustomerExportExecutable.ps1` | Unique absolute native-tool resolution and SHA-256 identity for Git and selected local validation tools. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-CustomerExportManifest.ps1` | Closed semantic validation beyond JSON Schema. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportSourceSnapshot.ps1` | Read-only commit, status, tracked-tree, refs, remotes, configuration, hooks, and workflow digest snapshot. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerSourceMarkerCatalog.ps1` | Deterministic extraction and exact catalogue reconciliation for source tenant markers. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportAssessment.ps1` | Deterministic inventory, exclusions, source snapshot, manifest digest, destination stable ID, allowed actions, and assessment digest consumed by the shared execution-manifest contract. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Invoke-CustomerStructuredReplacement.ps1` | Exact JSON Pointer or per-file Markdown literal replacement and digest/count-only log. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportResidual.ps1` | File/directory-name and content marker scanner with exact dispositions. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-CustomerExportSyntheticData.ps1` | Fail-closed all-text synthetic-data scanner and exact path/digest classification gate. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-CustomerExportContent.ps1` | Complete staged-content and source-immutability validation result. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1` | Adds only the export-specific public function names to the module contract. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1` | Adds the same export-specific names to runtime exports. |
| `infra/src/scripts/runbooks/New-CustomerRepositoryExport.ps1` | Thin assessment/shared-execution-manifest and digest-bound Apply coordinator. |
| `infra/src/scripts/runbooks/Test-CustomerRepositoryExport.ps1` | Read-only export validator and external redacted report writer. |
| `infra/tests/fixtures/runbooks/customer-export.invalid.json` | Closed-schema fixture with a wildcard residual disposition. |
| `infra/tests/pester/CustomerExportManifest.Tests.ps1` | Schema/sample and semantic allowlist tests. |
| `infra/tests/pester/CustomerExportIsolation.Tests.ps1` | Source snapshot, external staging, tracked-only copy, and source immutability tests. |
| `infra/tests/pester/CustomerExportSanitization.Tests.ps1` | Structured replacement, residual, binary, secret, personal-data, UTF-8, metadata, and link tests. |
| `infra/tests/pester/CustomerRepositoryExport.Tests.ps1` | Entry-point default/Apply/WhatIf/approval/idempotency and end-to-end disposable export tests. |
| `infra/tests/pester/CustomerExportStaticSafety.Tests.ps1` | AST/text denial of workflow edits, authentication, publication, remote, and source-mutating surfaces. |
| `infra/docs/runbooks/03-customer-handover.md` | Attended operator procedure, review gates, recovery, evidence, and separate publication boundary. |
| `infra/docs/runbooks/README.md` | Adds the third runbook to the ordered local-only runbook index. |
| `infra/README.md` | Adds the runbook index and customer handover to the Infrastructure documentation map. |

No `.github/workflows/` file is in the map. Do not change source-inventory evidence: these are implementation artifacts, not imported architecture-source evidence.

---

### Task 1: Define the Closed Customer-Export Manifest

**Files:**
- Create: `infra/src/config/schemas/customer-export.schema.json`
- Create: `infra/src/config/runbooks/customer-export.sample.json`
- Create: `infra/tests/fixtures/runbooks/customer-export.invalid.json`
- Create: `infra/tests/pester/CustomerExportManifest.Tests.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-CustomerExportManifest.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`

**Interfaces:**
- Consumes: UTF-8 JSON at an absolute manifest path.
- Produces: `Import-CustomerExportManifest -Path <string>` → a closed object with `schemaVersion`, `tenantAlias`, `customerScope`, `retainedTenantArtifacts`, discriminated `Json|MarkdownExact` `replacements`, `sourceMarkerCatalog`, exactly matching `residualMarkers`, `residualDispositions`, `syntheticDataPolicy`, `fileClassifications`, `inspectableBinaries`, and `validationSuites`.
- Produces validation-suite IDs only from `Pester`, `RepositorySafety`, and `BicepBuild`; no command text or arguments are accepted.

- [ ] **Step 1: Write the failing manifest contract tests**

```powershell
Set-StrictMode -Version Latest

Describe 'Customer export manifest contract' {
    BeforeAll {
        $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Module = Join-Path $script:Root 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:Sample = Join-Path $script:Root 'infra\src\config\runbooks\customer-export.sample.json'
        Import-Module $script:Module -Force
    }

    It 'imports the synthetic closed sample' {
        $manifest = Import-CustomerExportManifest -Path $script:Sample
        $manifest.schemaVersion | Should -Be '1.0'
        $manifest.tenantAlias | Should -Be 'source-lab'
        @($manifest.replacements | Where-Object format -eq 'MarkdownExact').Count | Should -Be 1
        ($manifest.replacements | Where-Object format -eq 'MarkdownExact').requiredCount | Should -Be 2
        @($manifest.sourceMarkerCatalog).Count | Should -Be @($manifest.residualMarkers).Count
        @($manifest.fileClassifications | Where-Object classification -eq 'SyntheticFixture').Count | Should -Be 1
        @($manifest.validationSuites) | Should -Be @('Pester','RepositorySafety','BicepBuild')
    }

    It 'rejects wildcard dispositions and unknown validation commands' {
        { Import-CustomerExportManifest -Path (Join-Path $PSScriptRoot '..\fixtures\runbooks\customer-export.invalid.json') } |
            Should -Throw '*exact path*'
    }

    It 'rejects Markdown wildcard regex and prohibited-path options' {
        $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
        $rule = $value.replacements | Where-Object format -eq 'MarkdownExact'
        $rule.path = 'docs/**/*.md'
        $rule | Add-Member NoteProperty regex $true
        $path = Join-Path $TestDrive 'invalid-markdown-replacement.json'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        { Import-CustomerExportManifest -Path $path } | Should -Throw
    }

    It 'rejects exact Markdown paths in vendored skills workflows and evidence' {
        foreach ($prohibited in @(
            '.github/skills/vendor/README.md',
            '.github/workflows/customer.md',
            'infra/evidence/customer.md'
        )) {
            $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
            ($value.replacements | Where-Object format -eq 'MarkdownExact').path = $prohibited
            $path = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.json')
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
            { Import-CustomerExportManifest -Path $path } | Should -Throw '*prohibited replacement path*'
        }

        It 'rejects evidence retention and marker-set drift' {
            $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
            $value.retainedTenantArtifacts[0].path = 'infra/evidence/discovery/source.json'
            $path = Join-Path $TestDrive 'evidence-retention.json'
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
            { Import-CustomerExportManifest -Path $path } | Should -Throw '*evidence*'

            $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
            $value.residualMarkers = @($value.residualMarkers | Select-Object -First 1)
            $path = Join-Path $TestDrive 'missing-residual-marker.json'
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
            { Import-CustomerExportManifest -Path $path } | Should -Throw '*exactly match*'

            $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
            $value.residualMarkers += [pscustomobject]@{
                id='additional-marker'; category='OtherTenantIdentifier'
                value='synthetic-additional-marker'; comparison='Ordinal'
            }
            $path = Join-Path $TestDrive 'additional-residual-marker.json'
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
            { Import-CustomerExportManifest -Path $path } | Should -Throw '*exactly match*'
        }

        It 'rejects broad or digest-free data classifications' {
            $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
            $value.fileClassifications[0].path = 'infra/tests/fixtures/**'
            $value.fileClassifications[0].PSObject.Properties.Remove('expectedOutputSha256')
            $path = Join-Path $TestDrive 'invalid-classification.json'
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
            { Import-CustomerExportManifest -Path $path } | Should -Throw
        }
    }

    It 'exports the importer from both module declarations' {
        (Test-ModuleManifest $script:Module).ExportedFunctions.Keys | Should -Contain 'Import-CustomerExportManifest'
        Get-Command Import-CustomerExportManifest -Module Caldova.HrFrontier.Bootstrap | Should -Not -BeNullOrEmpty
    }
}
```

- [ ] **Step 2: Run the focused test and verify the red state**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportManifest.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because the manifest, fixture, and exported importer do not exist.

- [ ] **Step 3: Create the closed draft 2020-12 schema**

Define `additionalProperties: false` at every object level. Require:

```json
{
  "schemaVersion": "1.0",
  "tenantAlias": "source-lab",
  "customerScope": "Synthetic customer repository export",
  "retainedTenantArtifacts": [
    {
      "path": "infra/src/config/tenants/customer-synthetic.json",
      "artifactKind": "TenantManifest",
      "customerScope": "Synthetic target tenant intent"
    }
  ],
  "replacements": [
    {
      "id": "tenant-alias-json",
      "path": "infra/src/config/tenants/customer-synthetic.json",
      "format": "Json",
      "selector": "/tenantAlias",
      "expectedOldValue": "source-lab",
      "newValue": "customer-synthetic",
      "requiredCount": 1
    },
    {
      "id": "customer-name-readme",
      "path": "README.md",
      "format": "MarkdownExact",
      "expectedOldText": "Source Reference Organization",
      "newText": "Customer Example Organization",
      "requiredCount": 2
    }
  ],
  "residualMarkers": [
    { "id": "source-alias", "category": "TenantAlias", "value": "source-lab", "comparison": "OrdinalIgnoreCase" },
    { "id": "source-customer-name", "category": "CompanyName", "value": "Source Reference Organization", "comparison": "Ordinal" }
  ],
  "sourceMarkerCatalog": [
    {
      "id": "source-alias",
      "category": "TenantAlias",
      "value": "source-lab",
      "comparison": "OrdinalIgnoreCase",
      "sources": [
        {
          "path": "infra/src/config/tenants/customer-synthetic.json",
          "blobSha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "occurrenceCount": 1
        }
      ]
    },
    {
      "id": "source-customer-name",
      "category": "CompanyName",
      "value": "Source Reference Organization",
      "comparison": "Ordinal",
      "sources": [
        {
          "path": "README.md",
          "blobSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "occurrenceCount": 2
        }
      ]
    }
  ],
  "residualDispositions": [
    {
      "path": "docs/specs/synthetic-provenance.md",
      "markerId": "source-alias",
      "reason": "The source alias is retained only in synthetic provenance."
    }
  ],
  "syntheticDataPolicy": {
    "reservedNames": ["Customer Example Organization", "Synthetic Operator"],
    "reservedDomains": ["example.com", "example.org", "example.net", "example.invalid"],
    "reservedIdPrefixes": ["synthetic-"]
  },
  "fileClassifications": [
    {
      "path": "infra/tests/fixtures/customer-export/synthetic-profile.json",
      "sourceBlobSha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      "expectedOutputSha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      "classification": "SyntheticFixture",
      "reason": "Synthetic profile used only by local export validation."
    },
    {
      "path": "README.md",
      "sourceBlobSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "expectedOutputSha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
      "classification": "ReviewedNonPersonal",
      "reason": "Repository introduction contains organization names and documentation dates only."
    }
  ],
  "inspectableBinaries": [],
  "validationSuites": ["Pester", "RepositorySafety", "BicepBuild"]
}
```

Constrain paths to forward-slash repository-relative paths with no empty, `.`, or `..` segment, wildcard, drive/UNC prefix, or `.git` segment. Require each replacement `id` to match `^[a-z][a-z0-9-]{2,63}$`. Define `replacements.items` with `oneOf` and a required `format` discriminator:

- `Json`: exact keys `id`, `path`, `format`, `selector`, `expectedOldValue`, `newValue`, `requiredCount`; `.json` path, RFC 6901 selector, and `requiredCount` fixed to `1`.
- `MarkdownExact`: exact keys `id`, `path`, `format`, `expectedOldText`, `newText`, `requiredCount`; `.md` path, non-empty distinct text values, and `requiredCount` as integer `minimum: 1` with no fixed maximum.

Neither branch accepts pattern, regex, glob, directory, encoding, recursive, or case-insensitive options. Keep marker categories `TenantAlias|StableId|Domain|Url|EmailSuffix|CompanyName|OtherTenantIdentifier` and comparison `Ordinal|OrdinalIgnoreCase`.

Define `sourceMarkerCatalog` entries with exact keys `id`, `category`, `value`, `comparison`, and non-empty `sources`; each source has exact `path`, lowercase 64-hex `blobSha256`, and integer `occurrenceCount` of at least `1`. Define `syntheticDataPolicy` with only unique non-empty `reservedNames`, reserved domains limited to `example.com|example.org|example.net|example.invalid`, and reserved ID prefixes matching `^synthetic-[a-z0-9-]*$`. Define `fileClassifications` with exact `path`, lowercase 64-hex `sourceBlobSha256`, lowercase 64-hex `expectedOutputSha256`, `classification` in `SyntheticFixture|ReviewedNonPersonal`, and non-empty `reason`. Binary entries remain limited to exact `path`, 64-lowercase-hex `sha256`, and non-empty `reason`.

- [ ] **Step 4: Create the valid sample and invalid fixture**

Use the exact synthetic values above in the sample. In the invalid fixture use `residualDispositions[0].path` equal to `docs/**` and `validationSuites` equal to `["Invoke-CustomerCommand"]`; include no real domain, person, tenant, or customer identifier.

- [ ] **Step 5: Implement strict JSON import and semantic validation**

`Import-CustomerExportManifest.ps1` must decode with strict UTF-8, reject a BOM and duplicate JSON keys, verify the exact top-level and nested key sets, and enforce the schema constraints in PowerShell 5.1 without downloading a validator. Add these semantic checks:

```powershell
$genericTerms = @('GitHub','Azure','Workday','Dataverse','Power Platform','SharePoint')
$allowedRoots = @('infra/src/config/tenants/','infra/src/bicep/parameters/')
$duplicateMarker = @($manifest.residualMarkers | Group-Object id | Where-Object Count -ne 1)
$duplicateReplacementId = @($manifest.replacements | Group-Object id | Where-Object Count -ne 1)
$duplicateReplacement = @($manifest.replacements | Group-Object {
    if ($_.format -eq 'Json') {
        '{0}|Json|{1}' -f $_.path.ToLowerInvariant(), $_.selector
    }
    else {
        '{0}|MarkdownExact|{1}' -f $_.path.ToLowerInvariant(), (Get-RunbookContentDigest -InputObject $_.expectedOldText)
    }
} | Where-Object Count -ne 1)
if ($duplicateMarker -or $duplicateReplacementId -or $duplicateReplacement) { throw 'Marker IDs, replacement IDs, and replacement path/selectors must be unique.' }
if (@($manifest.residualMarkers | Where-Object value -in $genericTerms).Count -gt 0) {
    throw 'Generic platform and architecture terms cannot be tenant residual markers.'
}
```

Require every retained tenant artifact to start with one allowed root; `infra/evidence/` and every evidence path are unconditionally invalid. Replacement paths are independent from `retainedTenantArtifacts`: require an exact file path with the extension matching its format, reject `.git/`, `.github/workflows/`, `.github/skills/`, `infra/evidence/`, and every path containing an `evidence` directory segment, and reject case-insensitive replacement path/ID duplicates. Source-dependent tracked-file, regular-blob, exact-case, and existence checks occur in `Get-CustomerExportAssessment`.

Canonicalize catalog and residual records by `id|category|comparison|value` and require exact set equality. Require unique IDs and unique category/comparison/value tuples, every disposition marker ID to exist, exact unique classification paths, both classification digests, `SyntheticFixture` only below `infra/tests/fixtures/`, and `ReviewedNonPersonal` outside `data/`, evidence, and fixture-bearing paths. Reject wildcard/directory classifications and unreserved domains or ID prefixes.

- [ ] **Step 6: Export the importer from both module files**

Append `'Import-CustomerExportManifest'` to `FunctionsToExport` in the `.psd1` and to `Export-ModuleMember` in the `.psm1`; do not remove or reorder existing exports.

- [ ] **Step 7: Run the focused contract tests**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportManifest.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; the sample imports, the wildcard/command fixture fails closed, and the importer is exported.

- [ ] **Step 8: Commit the manifest contract**

```powershell
git add -- infra/src/config/schemas/customer-export.schema.json infra/src/config/runbooks/customer-export.sample.json infra/tests/fixtures/runbooks/customer-export.invalid.json infra/tests/pester/CustomerExportManifest.Tests.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-CustomerExportManifest.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1
git commit -m "feat(infra): define customer export manifest"
```

Expected: one independently reviewable contract commit and no workflow change.

---

### Task 2: Snapshot the Source and Build a Shared-Contract Export Assessment

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-CustomerExportRelativePath.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-CustomerExportExecutable.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportSourceSnapshot.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerSourceMarkerCatalog.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportAssessment.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Create: `infra/tests/pester/CustomerExportIsolation.Tests.ps1`

**Interfaces:**
- Consumes: `Import-CustomerExportManifest`, `Get-RunbookContentDigest`, `New-RunbookExecutionManifest`, `Test-RunbookExecutionManifest`, canonical external paths, an injectable resolver `param([string]$Name)`, identity provider `param([string]$Path)`, and native runner `param([string]$FilePath,[string[]]$ArgumentList)`.
- Produces: `Resolve-CustomerExportExecutable -Name <git.exe|powershell.exe|az.cmd> [-CommandResolver <scriptblock>] [-FileIdentityProvider <scriptblock>]` → `{ name, path, sha256 }` with one unique absolute executable identity or a terminating missing/ambiguity refusal.
- Produces: `Get-CustomerExportSourceSnapshot -RepositoryRoot <string> -GitExecutable <object> -NativeCommandRunner <scriptblock> -GitBlobReader <scriptblock>` → closed snapshot with `commit`, empty `status`, `trackedFiles` entries `{ path, mode, objectId, blobSha256 }`, `trackedTreeDigest`, `refsDigest`, `remotesDigest`, `configDigest`, `hooksDigest`, and `workflowDigest`.
- Produces: `Get-CustomerSourceMarkerCatalog -RepositoryRoot <string> -ExpectedSourceCommit <40-hex> -TrackedFiles <object[]> -RetainedTenantArtifacts <object[]> -SourceMarkerCatalog <object[]> -GitExecutable <object> -GitBlobReader <scriptblock>` → exact discovered/catalogued marker proof or terminating mismatch.
- Produces: `Get-CustomerExportAssessment -SourceRoot <string> -ExpectedSourceCommit <40-hex> -DestinationRoot <string> -Manifest <object> -ManifestDigest <64-hex> -SourceSnapshot <object> -ToolIdentities <object> -MarkerCatalogProof <object> -GitExecutable <object> -GitBlobReader <scriptblock>` → schema `1.0`, exact copy/exclusion/replacement/classification inventory, marker proof, `destinationStableId`, closed tool identities, shared-contract `allowedActions`, and canonical `digest`.
- Consumes the shared constructor exactly as `New-RunbookExecutionManifest -RunId <guid> -Kind <Workstation|CloudFoundation|CustomerExport> -TargetStableId <string> -SourceCommit <40-hex> -AssessmentDigest <64-hex> -AuthenticationContext <object> -AllowedActions <object[]> -ToolVersions <object> -GeneratedAtUtc <datetime>` and invokes it with `-Kind CustomerExport`.
- Consumes the shared validator exactly as `Test-RunbookExecutionManifest -Manifest <object> -ApprovedDigest <64-hex> -CurrentSourceCommit <40-hex> -CurrentAssessmentDigest <64-hex> -CurrentAuthenticationContext <object> -AllowedActionNames <string[]> [-NowUtc <datetime>] [-MaximumAge <timespan>]`.

- [ ] **Step 1: Write failing clean-source and boundary tests**

```powershell
Describe 'Customer export source isolation' {
    BeforeAll {
        $script:Module = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:Module -Force
    }

    It 'refuses a dirty source and a destination below it' {
        $runner = { param($file,$args)
            if (($args -join ' ') -eq 'status --porcelain=v1 --untracked-files=all') { return "?? decoy.txt" }
            if ($args[0] -eq 'rev-parse') { return ('a' * 40) }
            return ''
        }
        $git = [pscustomobject]@{ name='git.exe'; path='C:\Approved\git.exe'; sha256=('c' * 64) }
        { Get-CustomerExportSourceSnapshot -RepositoryRoot $TestDrive -GitExecutable $git `
            -NativeCommandRunner $runner -GitBlobReader { param($gitPath,$root,$commit,$path) [byte[]]@(0x41) } } |
            Should -Throw '*clean*'
    }

    It 'refuses ambiguous executable resolution without invoking either candidate' {
        $calls = [Collections.Generic.List[string]]::new()
        { Resolve-CustomerExportExecutable -Name git.exe `
            -CommandResolver { param($name) @('C:\Approved\git.exe','C:\Shadow\git.exe') } `
            -FileIdentityProvider { param($path) [pscustomobject]@{
                path=$path
                sha256=if ($path -like 'C:\Approved\*') { ('a' * 64) } else { ('b' * 64) }
            } } } | Should -Throw '*ambiguous*'
        $calls.Count | Should -Be 0
    }

    It 'binds the shared CustomerExport manifest to the assessment and destination target' {
        $assessment = [pscustomobject]@{
            sourceCommit = ('a' * 40)
            digest = ('b' * 64)
            destinationStableId = 'customer-export:synthetic-destination'
            toolIdentities = [ordered]@{
                Git = [ordered]@{ path='C:\Approved\git.exe'; sha256=('c' * 64); version='git version 2.51.0.windows.1' }
                WindowsPowerShell = [ordered]@{ path='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'; sha256=('d' * 64); version='5.1.26100.6584' }
            }
            allowedActions = @(
                [pscustomobject]@{ action='CreateCustomerExport'; targetId='customer-export:synthetic-destination'; service='LocalFileSystem'; method='CreateNewDisposableDirectory'; expectedPostcondition='Disposable staging exists.' },
                [pscustomobject]@{ action='CopyTrackedBlob'; targetId='README.md'; service='Git'; method='ReadCommitBlob'; sourceRelativePath='README.md'; destinationRelativePath='README.md'; expectedPostcondition='Bytes match.' },
                [pscustomobject]@{ action='ApplyStructuredReplacement'; targetId='config.json#tenant-alias-json'; service='LocalFileSystem'; method='JsonPointer'; sourceRelativePath='config.json'; destinationRelativePath='config.json'; replacementRuleId='tenant-alias-json'; expectedPostcondition='The reviewed exact replacement count is satisfied.' },
                [pscustomobject]@{ action='ValidateCustomerExport'; targetId='customer-export:synthetic-destination'; service='LocalValidation'; method='FixedValidationSuites'; expectedPostcondition='Checks pass.' },
                [pscustomobject]@{ action='PromoteCustomerExport'; targetId='customer-export:synthetic-destination'; service='LocalFileSystem'; method='AtomicDirectoryMove'; expectedPostcondition='Destination exists.' }
            )
        }
        $authentication = [pscustomobject]@{
            executionHost = 'InteractiveWindows11PowerShell'
            mode = 'NotApplicable'
        }
        $executionManifest = New-RunbookExecutionManifest -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
            -Kind CustomerExport -TargetStableId $assessment.destinationStableId `
            -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
            -AuthenticationContext $authentication -AllowedActions $assessment.allowedActions `
            -ToolVersions $assessment.toolIdentities `
            -GeneratedAtUtc ([datetime]'2026-09-26T06:00:00Z')

        $executionManifest.target.type | Should -Be 'CustomerExport'
        $executionManifest.target.stableId | Should -Be $assessment.destinationStableId
        Test-RunbookExecutionManifest -Manifest $executionManifest -ApprovedDigest $executionManifest.digest `
            -CurrentSourceCommit $assessment.sourceCommit -CurrentAssessmentDigest $assessment.digest `
            -CurrentAuthenticationContext $authentication `
            -AllowedActionNames @('CreateCustomerExport','CopyTrackedBlob','ApplyStructuredReplacement','ValidateCustomerExport','PromoteCustomerExport') `
            -NowUtc ([datetime]'2026-09-26T06:10:00Z') | Should -BeTrue
    }

    It 'refuses an automatically discovered marker absent from the reviewed catalog' {
        $blobReader = { param($gitPath,$root,$commit,$path)
            [Text.UTF8Encoding]::new($false).GetBytes(@'
@{
    TenantAlias = 'source-lab'
    TenantId = '11111111-2222-3333-4444-555555555555'
    AdminUpn = 'admin@source-lab.example.invalid'
    PowerPlatform = @{ DevUrl = 'https://source-lab.crm.example.invalid/' }
}
'@)
        }
        { Get-CustomerSourceMarkerCatalog -RepositoryRoot $TestDrive -ExpectedSourceCommit ('a' * 40) `
            -TrackedFiles @([pscustomobject]@{path='infra/src/config/tenants/source.psd1';mode='100644'}) `
            -RetainedTenantArtifacts @() -SourceMarkerCatalog @() `
            -GitExecutable ([pscustomobject]@{path='C:\Approved\git.exe';sha256=('b' * 64)}) `
            -GitBlobReader $blobReader } | Should -Throw '*unrepresented source marker*'
    }

    It 'accepts a verified reviewed CompanyName assertion outside tenant configuration' {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
            "Owner: Source Reference Organization`n")
        $sha = [BitConverter]::ToString(
            [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        ).Replace('-', '').ToLowerInvariant()
        $catalog = @([pscustomobject]@{
            id='source-customer-name'; category='CompanyName'
            value='Source Reference Organization'; comparison='Ordinal'
            sources=@([pscustomobject]@{
                path='README.md'; blobSha256=$sha; occurrenceCount=1
            })
        })
        $result = Get-CustomerSourceMarkerCatalog -RepositoryRoot $TestDrive `
            -ExpectedSourceCommit ('a' * 40) `
            -TrackedFiles @([pscustomobject]@{path='README.md';mode='100644';blobSha256=$sha}) `
            -RetainedTenantArtifacts @() -SourceMarkerCatalog $catalog `
            -GitExecutable ([pscustomobject]@{path='C:\Approved\git.exe';sha256=('b' * 64)}) `
            -GitBlobReader ({ param($gitPath,$root,$commit,$path) $bytes }.GetNewClosure())
        $result.reviewedAssertionsVerified | Should -Be 1
        $result.automaticCandidateCount | Should -Be 0
    }

    It 'refuses a stale reviewed assertion even when its marker value exists' {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
            "Owner: Source Reference Organization`n")
        $catalog = @([pscustomobject]@{
            id='source-customer-name'; category='CompanyName'
            value='Source Reference Organization'; comparison='Ordinal'
            sources=@([pscustomobject]@{
                path='README.md'; blobSha256=('f' * 64); occurrenceCount=2
            })
        })
        { Get-CustomerSourceMarkerCatalog -RepositoryRoot $TestDrive `
            -ExpectedSourceCommit ('a' * 40) `
            -TrackedFiles @([pscustomobject]@{path='README.md';mode='100644';blobSha256=('e' * 64)}) `
            -RetainedTenantArtifacts @() -SourceMarkerCatalog $catalog `
            -GitExecutable ([pscustomobject]@{path='C:\Approved\git.exe';sha256=('b' * 64)}) `
            -GitBlobReader ({ param($gitPath,$root,$commit,$path) $bytes }.GetNewClosure()) } |
            Should -Throw '*catalog source assertion*'
    }
}
```

- [ ] **Step 2: Run the isolation tests and verify the red state**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportIsolation.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because the executable resolver, snapshot, and assessment functions are undefined. The shared execution-manifest functions already exist from the prerequisite foundation plan.

- [ ] **Step 3: Implement unique absolute executable resolution**

The default resolver is:

```powershell
param($name)
@(Get-Command $name -All -CommandType Application -ErrorAction SilentlyContinue |
    ForEach-Object Source)
```

The default identity provider returns the canonical full path and lowercase SHA-256 from `Get-FileHash -LiteralPath`. Reject non-rooted paths, missing/non-regular files, and reparse points. De-duplicate only entries with the same ordinal-ignore-case canonical path and identical digest. Return one identity; throw `Required executable is missing.` for zero and `Executable resolution is ambiguous.` for more than one non-equivalent identity. Add tests for one result, identical duplicates, same path with changed digest, and two distinct paths.

After resolution, obtain display-safe versions only through the absolute path: Git with `--version`; Windows PowerShell with `-NoLogo -NoProfile -Command $PSVersionTable.PSVersion.ToString()`; Azure CLI with `version --output json`; and Bicep, when selected, with `bicep version`. Reject nonzero, empty, or malformed version output. Store canonical tool records as `{ path, sha256, version }`, with `bicepVersion` additionally on the Azure CLI record.

- [ ] **Step 4: Implement canonical path and Git-state refusal**

`Test-CustomerExportRelativePath` returns the normalized forward-slash path only after rejecting rooted paths, empty/`.`/`..` segments, `.git`, backslash ambiguity, wildcard characters, invalid file-name characters, and case-insensitive duplicates.

`Get-CustomerExportSourceSnapshot` must invoke only the absolute path in `GitExecutable.path`, after confirming it is rooted and its supplied digest is lowercase SHA-256:

```text
git -C <source> rev-parse --show-toplevel
git -C <source> rev-parse HEAD
git -C <source> status --porcelain=v1 --untracked-files=all
git -C <source> sparse-checkout list
git -C <source> ls-tree -r -z --full-tree HEAD
git -C <source> for-each-ref --format=%(refname)%00%(objectname)
git -C <source> remote -v
git -C <source> config --local --list --null
```

Treat a nonzero `sparse-checkout list` as “not sparse”; any returned sparse path is refusal. Parse tree modes and accept only `100644` and `100755`; refuse `120000` symbolic links and `160000` Git links. Read every tracked blob from the exact commit through `GitBlobReader($GitExecutable.path,$RepositoryRoot,$commit,$path)` and record its SHA-256 beside the Git object ID; separately hash tracked working-tree bytes to prove cleanliness. Hash normalized command results and `.git/hooks` names/bytes without executing them. Refuse non-empty status before any other inventory read.

- [ ] **Step 5: Implement destination isolation**

In `Get-CustomerExportAssessment`, canonicalize source and destination, walk every existing destination ancestor, and refuse reparse points. Reject destination equal to or below source, source below destination, destination inside any working tree discovered by a `.git` file/directory in an ancestor, an existing destination, and a report/staging collision. Use `Test-RunbookPathWithin` from the foundation plan rather than string-prefix comparison.

- [ ] **Step 6: Implement deterministic inventory and exclusions**

Build `copyFiles` from regular tracked paths minus:

```powershell
$alwaysExcluded = @(
    '.github/workflows/',
    'infra/evidence/',
    'data/',
    '.git/'
)
```

Exclude every path containing an `evidence` segment regardless of manifest content. Deny every path below `infra/tests/fixtures/` by default; include only an exact path whose `fileClassifications` entry has matching source blob and expected-output digests, `classification = SyntheticFixture`, and a reason. For every path below an approved tenant-owned root, include it only when it exactly matches `retainedTenantArtifacts.path`. Record exclusions as `{ path, reason }` with reasons `WorkflowBoundary`, `EvidenceAlwaysExcluded`, `DataPathDenied`, `FixtureDeniedByDefault`, or `TenantArtifactDeniedByDefault`. Refuse an allowlisted artifact that is absent, not a regular tracked blob, case-mismatched, duplicated, outside its approved root, or under evidence.

Independently validate every replacement path against the tracked tree. It need not be a retained tenant artifact, but it must be an exact-case regular tracked blob included in `copyFiles`, have the format-specific `.json` or `.md` extension, and remain outside `.git/`, `.github/workflows/`, `.github/skills/`, `infra/evidence/`, and any path with an `evidence` directory segment. Refuse an absent, excluded, symbolic-link, Git-link, directory, wildcard, regex, or case-colliding target.

- [ ] **Step 7: Implement automatic source-marker discovery and exact reconciliation**

Create two explicitly separate collections.

**Reviewed assertions:** For every `sourceMarkerCatalog[*].sources[*]`, regardless of directory, read committed bytes—not working-tree files—from its exact tracked regular-file path. Verify exact path case, `blobSha256`, and ordinal or ordinal-ignore-case `occurrenceCount`. Reject absent paths, links, binaries, digest drift, count drift, and a source assertion in which the catalogued value is absent. A verified `CompanyName` or `OtherTenantIdentifier` assertion in documentation or another non-tenant path is valid reviewed coverage and is not treated as an extra automatic candidate.

**Automatic tenant-config candidates:** Separately read committed bytes for every regular tracked path below `infra/src/config/tenants/` or `infra/src/bicep/parameters/`, whether retained or denied. Decode only strict UTF-8 and refuse an uninspectable tenant artifact. Without executing PSD1, extract:

```text
TenantAlias values
all GUID values and scalar values whose key ends in Id
all absolute https URLs
host/domain values from URLs
email suffixes from email-shaped values
```

Support closed JSON parsing and static JSON/PSD1 key-value lexical extraction; no script evaluation, regex replacement, or inferred normalization is allowed. Emit sorted `{ category, value, comparison, path, blobSha256, occurrenceCount }` automatic candidates. Every automatic candidate must match exactly one already verified catalogue marker and source assertion. The catalogue may contain additional verified reviewed assertions not produced by automatic tenant-config extraction.

Finally compare the canonical `sourceMarkerCatalog` marker projection to `residualMarkers` with exact set equality. Unrepresented automatic candidates, absent/stale reviewed assertions, duplicate or ambiguous catalogue entries, missing residual markers, and additional residual markers refuse planning. Do not reject a catalogue entry solely because it is a verified reviewed `CompanyName` or `OtherTenantIdentifier`.

- [ ] **Step 8: Implement the deterministic assessment and shared allowed actions**

Build the assessment independently from approval:

```powershell
$destinationStableId = 'customer-export:' + (Get-RunbookContentDigest -InputObject ([ordered]@{
    destinationRoot = $canonicalDestination.ToLowerInvariant()
}))
$replacementMetadata = @($Manifest.replacements | Sort-Object path, id | ForEach-Object {
    [ordered]@{
        id = $_.id
        path = $_.path
        format = $_.format
        selector = if ($_.format -eq 'Json') { $_.selector } else { $null }
        requiredCount = $_.requiredCount
        ruleDigest = Get-RunbookContentDigest -InputObject $_
    }
})
$allowedActions = @(
    [pscustomobject]@{
        action = 'CreateCustomerExport'
        targetId = $destinationStableId
        service = 'LocalFileSystem'
        method = 'CreateNewDisposableDirectory'
        expectedPostcondition = 'A new isolated disposable staging directory exists outside every Git working tree.'
    }
)
$allowedActions += @($copyFiles | Sort-Object | ForEach-Object {
    [pscustomobject]@{
        action = 'CopyTrackedBlob'
        targetId = $_
        service = 'Git'
        method = 'ReadCommitBlob'
        sourceRelativePath = $_
        destinationRelativePath = $_
        expectedPostcondition = 'Destination bytes equal the tracked blob at the approved source commit.'
    }
})
$allowedActions += @($replacementMetadata | ForEach-Object {
    [pscustomobject]@{
        action = 'ApplyStructuredReplacement'
        targetId = '{0}#{1}' -f $_.path, $_.id
        service = 'LocalFileSystem'
        method = if ($_.format -eq 'Json') { 'JsonPointer' } else { 'MarkdownExact' }
        sourceRelativePath = $_.path
        destinationRelativePath = $_.path
        replacementRuleId = $_.id
        expectedPostcondition = 'The reviewed exact replacement count is satisfied and the replacement rule digest matches reviewed intent.'
    }
})
$allowedActions += @(
    [pscustomobject]@{
        action = 'ValidateCustomerExport'
        targetId = $destinationStableId
        service = 'LocalValidation'
        method = 'FixedValidationSuites'
        expectedPostcondition = 'All inventory, residual, documentation, source immutability, and selected suite checks pass.'
    },
    [pscustomobject]@{
        action = 'PromoteCustomerExport'
        targetId = $destinationStableId
        service = 'LocalFileSystem'
        method = 'AtomicDirectoryMove'
        expectedPostcondition = 'Validated disposable staging is moved to the approved destination.'
    }
)
$unsignedAssessment = [ordered]@{
    schemaVersion = '1.0'
    sourceRoot = $canonicalSource
    sourceCommit = $ExpectedSourceCommit.ToLowerInvariant()
    destinationRoot = $canonicalDestination
    destinationStableId = $destinationStableId
    manifestDigest = $ManifestDigest
    sourceSnapshot = $SourceSnapshot
    toolIdentities = $ToolIdentities
    markerCatalogProof = $MarkerCatalogProof
    fileClassifications = @($Manifest.fileClassifications | Sort-Object path)
    copyFiles = @($copyFiles | Sort-Object)
    exclusions = @($exclusions | Sort-Object path)
    replacements = $replacementMetadata
    allowedActions = $allowedActions
}
$assessmentDigest = Get-RunbookContentDigest -InputObject $unsignedAssessment
```

Return the assessment plus `digest = $assessmentDigest`. Every action uses only the shared closed properties: `action`, `targetId`, `service`, `method`, `sourceRelativePath`, `destinationRelativePath`, `replacementRuleId`, and `expectedPostcondition`. Do not add an export-specific execution-manifest shape, constructor, validator, expiry, target, or approval digest. Old and new values remain solely in the separately reviewed customer-export manifest bound by `manifestDigest`.

- [ ] **Step 9: Construct and validate the shared execution manifest in the test**

Call `New-RunbookExecutionManifest` with `Kind CustomerExport`, `TargetStableId $assessment.destinationStableId`, `SourceCommit $assessment.sourceCommit`, `AssessmentDigest $assessment.digest`, authentication `{ executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotApplicable' }`, `AllowedActions $assessment.allowedActions`, and `ToolVersions $assessment.toolIdentities`. Assert that JSON rules produce `method = JsonPointer`, Markdown rules produce `method = MarkdownExact`, both use `action = ApplyStructuredReplacement`, and every allowed-action property is in the shared closed list. Adding `arguments`, `destinationRoot`, or `ruleDigest` to an action must make the shared validator refuse it.

- [ ] **Step 10: Export the export-specific resolver/readers and run tests**

Add `Resolve-CustomerExportExecutable`, `Get-CustomerExportSourceSnapshot`, `Get-CustomerSourceMarkerCatalog`, and `Get-CustomerExportAssessment` to both module export lists without changing existing names, then run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportIsolation.Tests.ps1,infra/tests/pester/RunbookContracts.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; missing/ambiguous executables, dirty/sparse/link sources, unsafe destinations, and marker-catalog drift are refused; the assessment digest changes with tool/source/manifest/catalog/classification/destination drift; and the shared constructor/validator accepts the exact `CustomerExport` contract.

- [ ] **Step 11: Commit source isolation and planning**

```powershell
git add -- infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/CustomerExportIsolation.Tests.ps1
git commit -m "feat(infra): add isolated customer export assessment"
```

Expected: one helper commit with no execution-manifest fork, source mutation command, or workflow edit.

---

### Task 3: Implement Structured Replacement and Residual Detection

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/ConvertFrom-JsonPointer.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Convert-CustomerExportBlob.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-CustomerExportTextKind.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Invoke-CustomerStructuredReplacement.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportResidual.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Create: `infra/tests/pester/CustomerExportSanitization.Tests.ps1`

**Interfaces:**
- Consumes: one staged root and validated manifest replacement/marker records.
- Produces: `Convert-CustomerExportBlob -Path <repository-relative string> -OriginalBytes <byte[]> -Rules <object[]>` → `{ bytes, replacementLog }`, applying all exact rules for one path in memory without reading or writing a file.
- Produces: `Invoke-CustomerStructuredReplacement -StagingRoot <string> -Path <repository-relative string> -Rules <object[]>` → replacement-log records `{ ruleId, path, format, selector, replacementCount, oldValueDigest, newValueDigest }`; `selector` is populated only for `Json`, and values themselves are never returned.
- Produces: `Get-CustomerExportResidual -StagingRoot <string> -Markers <object[]> -Dispositions <object[]> -InspectableBinaries <object[]>` → sorted records `{ path, location, markerId, category, disposition, reason }`.

- [ ] **Step 1: Write failing replacement and residual tests**

```powershell
Describe 'Customer export sanitization' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
    }

    It 'changes only one JSON Pointer and logs digests rather than values' {
        $path = Join-Path $TestDrive 'config.json'
        [IO.File]::WriteAllText($path, '{"tenant":{"alias":"source-lab"},"text":"source-lab"}', [Text.UTF8Encoding]::new($false))
        $log = Invoke-CustomerStructuredReplacement -StagingRoot $TestDrive -Path 'config.json' -Rules @([pscustomobject]@{
            id='tenant-alias-json'; path='config.json'; format='Json'; selector='/tenant/alias'
            expectedOldValue='source-lab'; newValue='customer-synthetic'; requiredCount=1
        })
        (Get-Content -Raw $path | ConvertFrom-Json).text | Should -Be 'source-lab'
        $log.replacementCount | Should -Be 1
        ($log | ConvertTo-Json) | Should -Not -Match 'customer-synthetic|source-lab'
    }

    It 'changes the exact reviewed count only in the named Markdown file' {
        $target = Join-Path $TestDrive 'handover.md'
        $other = Join-Path $TestDrive 'other.md'
        $original = "Owner: Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($other, $original, [Text.UTF8Encoding]::new($false))
        $beforeOther = [IO.File]::ReadAllBytes($other)

        $log = Invoke-CustomerStructuredReplacement -StagingRoot $TestDrive -Path 'handover.md' -Rules @([pscustomobject]@{
            id='customer-name-handover'; path='handover.md'; format='MarkdownExact'
            expectedOldText='Source Reference Organization'
            newText='Customer Example Organization'; requiredCount=2
        })

        [IO.File]::ReadAllText($target) | Should -Be "Owner: Customer Example Organization`r`nContact Customer Example Organization`r`n"
        [IO.File]::ReadAllBytes($other) | Should -Be $beforeOther
        $log.replacementCount | Should -Be 2
        ($log | ConvertTo-Json -Compress) | Should -Not -Match 'Source Reference Organization|Customer Example Organization'
    }

    It 'leaves Markdown bytes unchanged when the exact count mismatches' {
        $target = Join-Path $TestDrive 'count-mismatch.md'
        $original = "Source Reference Organization`nSource Reference Organization`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $before = [IO.File]::ReadAllBytes($target)
        { Invoke-CustomerStructuredReplacement -StagingRoot $TestDrive -Path 'count-mismatch.md' -Rules @([pscustomobject]@{
            id='customer-name-count'; path='count-mismatch.md'; format='MarkdownExact'
            expectedOldText='Source Reference Organization'
            newText='Customer Example Organization'; requiredCount=3
        }) } | Should -Throw '*required occurrence count*'
        [IO.File]::ReadAllBytes($target) | Should -Be $before
    }

    It 'reports every undisposed name and content residual' {
        $residualRoot = Join-Path $TestDrive 'residual-case'
        New-Item -ItemType Directory (Join-Path $residualRoot 'source-lab') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $residualRoot 'source-lab\source-lab-note.md'), 'source-lab', [Text.UTF8Encoding]::new($false))
        $matches = Get-CustomerExportResidual -StagingRoot $residualRoot `
            -Markers @([pscustomobject]@{id='source-alias';category='TenantAlias';value='source-lab';comparison='OrdinalIgnoreCase'}) `
            -Dispositions @() -InspectableBinaries @()
        @($matches | Where-Object disposition -eq 'Undisposed').Count | Should -Be 3
    }
}
```

- [ ] **Step 2: Run sanitization tests and verify the red state**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportSanitization.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because both public functions are undefined.

- [ ] **Step 3: Implement exact RFC 6901 traversal**

Decode pointer segments by replacing `~1` with `/` and `~0` with `~`; reject other `~` escapes, empty root pointers, missing properties, ambiguous case-insensitive properties, negative/non-decimal array indexes, and `-`. Return the parent, final property/index, and current value. Compare old and new values by canonical JSON bytes, not PowerShell string coercion.

- [ ] **Step 4: Implement the in-memory JSON replacement branch**

In `Convert-CustomerExportBlob`, read `OriginalBytes` as strict BOM-free UTF-8, reject duplicate JSON keys, traverse each rule's pointer exactly once, require canonical old-value equality and count `1`, assign the exact JSON-compatible new value, and serialize canonical BOM-free UTF-8 bytes. Compute `oldValueDigest` and `newValueDigest` with `Get-RunbookContentDigest`; never put either value into logs, errors, or evidence. Return bytes and log without touching disk.

- [ ] **Step 5: Implement the MarkdownExact replacement branch**

In `Convert-CustomerExportBlob`, require an exact `.md` path already validated as a regular tracked export file. Decode `OriginalBytes` with `[Text.UTF8Encoding]::new($false, $true)`, reject every BOM, classify newline style as `LF`, `CRLF`, or `None`, and refuse mixed bare-LF/CRLF content. Count non-overlapping ordinal occurrences of `expectedOldText`; if the count differs from `requiredCount`, throw without returning transformed bytes. Replace only those exact occurrences in that one file, verify the resulting newline sequence equals the original style, and return BOM-free UTF-8 bytes. Do not normalize whitespace, case, Unicode, or line endings.

Use `IndexOf($oldText, $offset, [StringComparison]::Ordinal)` while advancing by `$oldText.Length` for the pre-write count. `Invoke-CustomerStructuredReplacement` reads the one staged target's current bytes, calls the in-memory transformer with all rules for that path in manifest order, creates a random temporary file in the target's own directory only after successful transformation, writes returned bytes, replaces with `[IO.File]::Replace($temporary, $target, $null)`, and deletes only a remaining temporary file in `finally`.

Return only:

```powershell
[pscustomobject]@{
    ruleId = $Rule.id
    path = $Rule.path
    format = 'MarkdownExact'
    selector = $null
    replacementCount = $count
    oldValueDigest = Get-RunbookContentDigest -InputObject $Rule.expectedOldText
    newValueDigest = Get-RunbookContentDigest -InputObject $Rule.newText
}
```

- [ ] **Step 6: Implement text and binary classification**

`Get-CustomerExportTextKind` reads bytes, rejects UTF-16/UTF-32 BOMs and invalid UTF-8, treats NUL or other disallowed control bytes as binary, permits CRLF or LF, and returns `Utf8Text`, `InspectableBinary`, or a terminating refusal. For a binary, require exact path, SHA-256, and reason from `inspectableBinaries`; never scan or print binary payload.

- [ ] **Step 7: Implement exhaustive residual scanning**

Enumerate every directory and file without following reparse points. Match each path segment and each UTF-8 line using the marker comparison. Emit every occurrence with `location` equal to `DirectoryName:<segment>`, `FileName`, or `Line:<one-based-number>:Column:<one-based-number>`. Apply a disposition only when both normalized path and marker ID match exactly; retain its reason. Sort by path, location, marker ID and never stop at the first match. A `MarkdownExact` rule disposes nothing by itself: every occurrence of its old customer/tenant marker remaining in another file, another path, or the same file after replacement must have its own replacement rule or exact residual disposition.

- [ ] **Step 8: Add negative cases for count, newline, binary, and broad disposition**

Add tests proving that a JSON old-value mismatch, Markdown occurrence-count mismatch, mixed Markdown newline styles, a Markdown BOM, duplicate rule ID/selector, unsupported format, malformed UTF-8, unlisted binary, wrong binary digest, wildcard disposition, and a disposition for the wrong marker all terminate or remain `Undisposed`. Add a positive exact path-and-marker disposition and assert only that match becomes `Disposed`. Seed the old customer name in `other.md` after a successful two-occurrence replacement in `handover.md`; assert residual scanning reports `other.md` as `Undisposed` until an exact `other.md` plus marker-ID disposition is supplied.

```powershell
$marker = [pscustomobject]@{
    id='source-customer-name'; category='CompanyName'
    value='Source Reference Organization'; comparison='Ordinal'
}
$undisposed = Get-CustomerExportResidual -StagingRoot $TestDrive `
    -Markers @($marker) -Dispositions @() -InspectableBinaries @()
@($undisposed | Where-Object { $_.path -eq 'other.md' -and $_.disposition -eq 'Undisposed' }).Count |
    Should -Be 2

$disposed = Get-CustomerExportResidual -StagingRoot $TestDrive -Markers @($marker) `
    -Dispositions @([pscustomobject]@{
        path='other.md'; markerId='source-customer-name'
        reason='Synthetic provenance retained for the handover review.'
    }) -InspectableBinaries @()
@($disposed | Where-Object { $_.path -eq 'other.md' -and $_.disposition -eq 'Disposed' }).Count |
    Should -Be 2
```

- [ ] **Step 9: Export the sanitization functions and rerun tests**

Add `Convert-CustomerExportBlob`, `Invoke-CustomerStructuredReplacement`, and `Get-CustomerExportResidual` to the `.psd1` and `.psm1`, then run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportSanitization.Tests.ps1,infra/tests/pester/CustomerExportManifest.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; only the selected JSON field and exact named Markdown file/count change, line endings are preserved, mismatch leaves bytes unchanged, and every seeded residual elsewhere is reported.

- [ ] **Step 10: Commit sanitization**

```powershell
git add -- infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/CustomerExportSanitization.Tests.ps1
git commit -m "feat(infra): add structured export sanitization"
```

Expected: one independently reviewable sanitization commit.

---

### Task 4: Add Complete Staged-Export Validation

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-CustomerExportSyntheticBytes.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-CustomerExportContent.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-CustomerExportSyntheticData.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportAssessment.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Modify: `infra/tests/pester/CustomerExportIsolation.Tests.ps1`
- Modify: `infra/tests/pester/CustomerExportSanitization.Tests.ps1`

**Interfaces:**
- Consumes: staged root, validated customer-export manifest, digest-matched export assessment including tool identities, shared execution manifest, current source snapshot, replacement log, and injected fixed-suite runner `param([string]$SuiteId,[string]$FilePath,[string[]]$ArgumentList,[string]$StagingRoot)`.
- Produces: `Test-CustomerExportSyntheticData -StagingRoot <string> -SourceCommit <40-hex> -SyntheticDataPolicy <object> -FileClassifications <object[]> -FileDigests <object>` → `{ status, findings, classifications }`, where each `FileDigests` value is `{ sourceBlobSha256, expectedOutputSha256 }` and no inconclusive file is accepted implicitly.
- Produces: `Test-CustomerExportContent -StagingRoot <string> -Manifest <object> -Assessment <object> -ExecutionManifest <object> -CurrentSourceSnapshot <object> -ReplacementLog <object[]> -ValidationRunner <scriptblock>` → closed result with `status`, `publishReady`, inventories, residuals, failures, suite results, and source/tool-immutability comparison.

- [ ] **Step 1: Add a failing aggregate validation test**

```powershell
It 'withholds publish readiness for one undisposed residual' {
    $result = Test-CustomerExportContent -StagingRoot $script:Stage -Manifest $script:Manifest `
        -Assessment $script:Assessment -ExecutionManifest $script:ExecutionManifest `
        -CurrentSourceSnapshot $script:Assessment.sourceSnapshot `
        -ReplacementLog $script:ReplacementLog `
        -ValidationRunner { param($id,$file,$arguments,$root)
            [pscustomobject]@{ suite=$id; executablePath=$file; exitCode=0 }
        }
    $result.publishReady | Should -BeFalse
    $result.status | Should -Be 'Failed'
    @($result.failures | Where-Object category -eq 'UndisposedResidual').Count | Should -Be 1
}
```

- [ ] **Step 2: Run the aggregate test and verify the red state**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportSanitization.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Test-CustomerExportContent` is undefined.

- [ ] **Step 3: Implement inventory and prohibited-content checks**

Compare actual files ordinally to `assessment.copyFiles`; permit no extra or missing file. Require `ExecutionManifest.kind` and `target.type` to equal `CustomerExport`, `target.stableId` to equal `assessment.destinationStableId`, and `assessmentDigest` to equal `assessment.digest`. Assert no `.git` entry, no path equal to or below `.github/workflows/`, no `data` or `evidence` path segment, and no fixture path lacking its exact source/output-digest-bound `SyntheticFixture` classification. Verify retained tenant artifacts exactly, and fail every other path under a tenant-owned root. Scan text with fixed case-insensitive secret patterns for bearer authorization, access/refresh tokens, client secrets, PAT forms, private-key headers, connection strings, and credential assignments.

- [ ] **Step 4: Implement fail-closed synthetic-data classification**

Enumerate every exported UTF-8 file. Reject `data` and `evidence` path segments unconditionally. Reject fixture-bearing paths unless an exact `SyntheticFixture` classification below `infra/tests/fixtures/` matches the source-commit blob SHA-256 and has a reason. For ordinary files, parse JSON/PSD1/YAML key-value shapes where applicable and scan all text with case-insensitive structured-key categories:

```powershell
$identityKeys = '(?i)^(person|worker|employee|candidate|user|account|national|passport|tax|payroll).*(id|number)?$'
$nameKeys = '(?i)^(first|middle|last|full|display|preferred|legal)?name$'
$contactKeys = '(?i)(email|mail|phone|mobile|contact)'
$addressKeys = '(?i)(address|street|city|postal|zip|country)'
$dateKeys = '(?i)(dateofbirth|birthdate|dob|hiredate|terminationdate|startdate|enddate)$'
```

Also scan free text for email addresses, international/domestic phone shapes, postal-address labels plus values, ISO/local date shapes near person-related labels, GUID/numeric identifiers near identity labels, and person-name labels plus values. Values are automatically safe only when they exactly use `syntheticDataPolicy.reservedNames`, a reserved `.example`/`.invalid` domain, a reserved `synthetic-` ID prefix, or documentation IP ranges `192.0.2.0/24`, `198.51.100.0/24`, and `203.0.113.0/24`.

Return `Failed` for a definite non-synthetic match. Return `Inconclusive` for an unparseable structured file, a name-like/contact-like/date-like value not provably reserved, or conflicting indicators. An inconclusive ordinary file passes only when an exact `ReviewedNonPersonal` entry matches its path, original source-commit blob SHA-256, expected post-replacement output SHA-256, and reason. A classification with either mismatched digest, absent path, changed path, directory, or wildcard fails. No classification suppresses a definite non-synthetic match.

Reuse the private byte classifier during `Get-CustomerExportAssessment`: read each candidate's original committed blob, compute `sourceBlobSha256`, apply its reviewed rules in memory with `Convert-CustomerExportBlob`, compute `expectedOutputSha256` over the complete returned bytes, and classify those expected output bytes. Refuse definite non-synthetic content. Exclude an inconclusive unclassified path with reason `ReviewedNonPersonalClassificationRequired`; include it only when its exact classification matches both computed digests. Bind per-file `Synthetic|ReviewedNonPersonal` outcomes and both verified digest values into the assessment before computing its digest and passing that digest into the shared execution manifest. Add isolation tests proving an unclassified inconclusive file is excluded, a source-digest match plus output-digest mismatch refuses, and the same exact path is included only when both digests match.

- [ ] **Step 5: Add concrete synthetic-data policy tests**

```powershell
$script:SyntheticPolicy = [pscustomobject]@{
    reservedNames = @('Synthetic Reviewer','Customer Example Organization')
    reservedDomains = @('example.com','example.org','example.net','example.invalid')
    reservedIdPrefixes = @('synthetic-')
}

function Test-SyntheticClassificationCase {
    param($Classification,[string]$ObservedSourceDigest,[bool]$ExpectedOutputMatches)
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $target = Join-Path $root ($Classification.path -replace '/', '\')
    [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    [IO.File]::WriteAllText($target, 'Reviewer name: Synthetic Reviewer', [Text.UTF8Encoding]::new($false))
    $actualOutputDigest = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $Classification.expectedOutputSha256 = if ($ExpectedOutputMatches) {
        $actualOutputDigest
    }
    else {
        ('f' * 64)
    }
    Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit ('a' * 40) `
        -SyntheticDataPolicy $script:SyntheticPolicy -FileClassifications @($Classification) `
        -FileDigests @{ $Classification.path = [pscustomobject]@{
            sourceBlobSha256=$ObservedSourceDigest
            expectedOutputSha256=$actualOutputDigest
        } }
}

function Test-SyntheticFixtureCase {
    param($Classification)
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $target = Join-Path $root ($Classification.path -replace '/', '\')
    [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    [IO.File]::WriteAllText($target, '{"employeeId":"synthetic-worker-001","email":"worker@example.invalid"}',
        [Text.UTF8Encoding]::new($false))
    $digest = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $Classification.sourceBlobSha256 = $digest
    $Classification.expectedOutputSha256 = $digest
    Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit ('a' * 40) `
        -SyntheticDataPolicy $script:SyntheticPolicy -FileClassifications @($Classification) `
        -FileDigests @{ $Classification.path = [pscustomobject]@{
            sourceBlobSha256=$Classification.sourceBlobSha256
            expectedOutputSha256=$Classification.expectedOutputSha256
        } }
}

It 'rejects personal patterns across JSON Markdown and text' {
    $root = Join-Path $TestDrive 'personal-data'
    [IO.Directory]::CreateDirectory($root) | Out-Null
    [IO.File]::WriteAllText((Join-Path $root 'record.json'),
        '{"employeeId":"4711","personalEmail":"person@corp.example","dateOfBirth":"1988-04-03"}',
        [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $root 'contact.md'),
        "Employee name: Example Person`nPhone: +41 44 555 01 02`nHome address: 1 Example Street",
        [Text.UTF8Encoding]::new($false))
    $fileDigests = @{}
    foreach ($file in Get-ChildItem -LiteralPath $root -File) {
        $digest = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $fileDigests[$file.Name] = [pscustomobject]@{
            sourceBlobSha256=$digest
            expectedOutputSha256=$digest
        }
    }
    $result = Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit ('a' * 40) `
        -SyntheticDataPolicy $script:SyntheticPolicy -FileClassifications @() `
        -FileDigests $fileDigests
    $result.status | Should -Be 'Failed'
    @($result.findings | Select-Object -ExpandProperty category -Unique) |
        Should -Contain 'Identity'
    @($result.findings | Select-Object -ExpandProperty category -Unique) |
        Should -Contain 'Contact'
}

It 'requires an exact digest-bound classification for an inconclusive file' {
    $classification = [pscustomobject]@{
        path='docs/reviewed-example.md'
        sourceBlobSha256=('a' * 64); expectedOutputSha256=('f' * 64)
        classification='ReviewedNonPersonal'
        reason='Synthetic architecture narrative with no person records.'
    }
    (Test-SyntheticClassificationCase -Classification $classification `
        -ObservedSourceDigest ('a' * 64) -ExpectedOutputMatches $false).status |
        Should -Be 'Failed'
    (Test-SyntheticClassificationCase -Classification $classification `
        -ObservedSourceDigest ('c' * 64) -ExpectedOutputMatches $true).status |
        Should -Be 'Failed'
    (Test-SyntheticClassificationCase -Classification $classification `
        -ObservedSourceDigest ('a' * 64) -ExpectedOutputMatches $true).status |
        Should -Be 'Passed'
}

It 'allows only an exact digest-bound synthetic fixture exception' {
    $classification = [pscustomobject]@{
        path='infra/tests/fixtures/customer-export/synthetic-profile.json'
        sourceBlobSha256=('c' * 64); expectedOutputSha256=('c' * 64)
        classification='SyntheticFixture'
        reason='Synthetic local validation profile.'
    }
    (Test-SyntheticFixtureCase -Classification $classification).status | Should -Be 'Passed'
    $classification.path = 'data/synthetic-profile.json'
    (Test-SyntheticFixtureCase -Classification $classification).status | Should -Be 'Failed'
}
```

- [ ] **Step 6: Implement documentation checks**

For every exported Markdown file, require valid UTF-8 and the six exact metadata fields immediately after H1 unless excluded by `docs/README.md`; resolve every relative Markdown link and fail missing targets or links into omitted workflow paths.

- [ ] **Step 7: Implement fixed local suite execution**

Map IDs internally; do not consume command text from the manifest. Obtain executable paths only from the digest-bound `assessment.toolIdentities`:

```powershell
$suiteMap = @{
    Pester = [pscustomobject]@{
        filePath = $Assessment.toolIdentities.WindowsPowerShell.path
        arguments = @('-NoProfile','-Command',
            "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester,hr/tests/pester,.github/cli/tests -Output Detailed -CI")
    }
    RepositorySafety = [pscustomobject]@{
        filePath = $Assessment.toolIdentities.WindowsPowerShell.path
        arguments = @('-NoProfile','-File','.github/cli/verify-repository-safety.ps1')
    }
    BicepBuild = [pscustomobject]@{
        filePath = $Assessment.toolIdentities.AzureCli.path
        arguments = @('bicep','build','--file','infra/src/bicep/main.bicep','--stdout')
    }
}
```

Require every `filePath` to be rooted and equal to the currently re-resolved identity path and digest. Invoke that absolute path through `ValidationRunner`, record only suite ID, executable digest, exit code, and `Passed|Failed`, and reject unknown IDs before execution. No suite may authenticate or write into the source.

- [ ] **Step 8: Implement the fail-closed aggregate result**

Require one exact successful replacement-log entry for every rule ID, matching path, format, optional JSON selector, required count, and old/new value digests. Require exact marker-catalog proof, zero undisposed residuals—including every old customer or tenant marker outside a named Markdown target—synthetic-data status `Passed` for every UTF-8 file, zero prohibited-data/link/metadata/inventory failures, all selected suites passing, and ordinal equality of every source snapshot/tool-identity field. Set `publishReady = $true` only when all conditions hold; otherwise include every sanitized failure and return `publishReady = $false` without claiming partial success.

- [ ] **Step 9: Export the validators and run sanitization tests**

Add `Test-CustomerExportSyntheticData` and `Test-CustomerExportContent` to both module export lists, then run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerExportSanitization.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS for the clean synthetic tree and FAIL-result assertions for every seeded negative case.

- [ ] **Step 10: Commit aggregate validation**

```powershell
git add -- infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/CustomerExportSanitization.Tests.ps1
git commit -m "feat(infra): validate staged customer exports"
```

Expected: one validator commit; validation has no publication function.

---

### Task 5: Implement Digest-Bound Export Creation

**Files:**
- Create: `infra/src/scripts/runbooks/New-CustomerRepositoryExport.ps1`
- Create: `infra/tests/pester/CustomerRepositoryExport.Tests.ps1`

**Interfaces:**
- Consumes: all export helpers; the shared `New-RunbookExecutionManifest`, `Test-RunbookExecutionManifest`, and exact versioned `ConvertTo-RunbookEvidenceRecord` contract; `Resolve-RunbookReportPath` and `Write-CanonicalJson`; injectable Git blob reader `param([string]$GitPath,[string]$RepositoryRoot,[string]$Commit,[string]$Path)` returning `byte[]`; injectable native runner, command resolver, file identity provider, and validation runner.
- Produces: `New-CustomerRepositoryExport.ps1 -SourceRoot <string> -ExpectedSourceCommit <40-hex> -DestinationRoot <string> -ManifestPath <string> [-ReportPath <string>] [-ExecutionManifestPath <string>] [-ApprovedDigest <64-hex>] [-Apply] [-NativeCommandRunner <scriptblock>] [-CommandResolver <scriptblock>] [-FileIdentityProvider <scriptblock>] [-GitBlobReader <scriptblock>] [-ValidationRunner <scriptblock>] [-InteractiveHostProbe <scriptblock>] [-OperatorIdProvider <scriptblock>] [-NowUtc <datetime>] [-Confirm] [-WhatIf]`.
- Produces externally: `customer-export-assessment.json`, `customer-export-execution-manifest.json`, `customer-export-evidence.json`, and, only after approved Apply succeeds, the requested staging directory.

- [ ] **Step 1: Write failing default, WhatIf, and digest tests**

```powershell
Describe 'New-CustomerRepositoryExport gates' {
    BeforeAll {
        $script:Entry = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\New-CustomerRepositoryExport.ps1'
    }

    It 'plans without creating destination' {
        & $script:Entry @script:ValidArguments
        Test-Path $script:Destination | Should -BeFalse
        Test-Path (Join-Path $script:Report 'customer-export-assessment.json') | Should -BeTrue
        Test-Path (Join-Path $script:Report 'customer-export-execution-manifest.json') | Should -BeTrue
        $evidence = Get-Content -Raw (Join-Path $script:Report 'customer-export-evidence.json') | ConvertFrom-Json
        @($evidence.PSObject.Properties.Name) | Should -Contain 'generatedAtUtc'
        $evidence.sourceCommit | Should -Match '^[0-9a-f]{40}$'
        $evidence.assessmentDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.planDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.manifestDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.operatorId | Should -Be 'SYNTHETIC\operator'
        $evidence.shouldProcessDecision | Should -Be 'NotApplicable'
    }

    It 'does not create staging under WhatIf' {
        & $script:Entry @script:ApplyArguments -Apply -WhatIf -Confirm:$false
        Test-Path $script:Destination | Should -BeFalse
        @(Get-ChildItem (Split-Path $script:Destination) -Filter '.customer-export-*').Count | Should -Be 0
    }

    It 'refuses an approval mismatch before writing staging' {
        { & $script:Entry @script:ApplyArguments -Apply -ApprovedDigest ('f' * 64) -Confirm:$false } |
            Should -Throw '*approved digest*'
        Test-Path $script:Destination | Should -BeFalse
    }

    It 'refuses executable identity drift before the first staging write' {
        $identityCalls = [Collections.Generic.List[string]]::new()
        $identityProvider = {
            param($path)
            [void]$identityCalls.Add($path)
            [pscustomobject]@{
                path=$path
                sha256=if ($identityCalls.Count -le 3) { ('a' * 64) } else { ('b' * 64) }
            }
        }.GetNewClosure()
        { & $script:Entry @script:ApplyArguments -Apply -Confirm:$false `
            -CommandResolver { param($name) @("C:\Approved\$name") } `
            -FileIdentityProvider $identityProvider } | Should -Throw '*executable identity changed*'
        Test-Path $script:Destination | Should -BeFalse
    }
}
```

- [ ] **Step 2: Run entry-point tests and verify the red state**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerRepositoryExport.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because the entry point does not exist.

- [ ] **Step 3: Implement parameters and preflight**

Use `[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]`. Set strict mode and stop preference; import the existing module. Verify Windows 11 and the injected/default interactive-host probe before Git reads. Resolve the external report path before writing. Resolve `git.exe` and, according to selected validation suites, `powershell.exe` and `az.cmd` through `Resolve-CustomerExportExecutable`; probe versions only by their absolute paths. The operator-ID provider defaults to `[Security.Principal.WindowsIdentity]::GetCurrent().Name`; reject empty values and control characters, and do not expose an operator-ID override as a normal public parameter. Reject `-Apply` without both `-ExecutionManifestPath` and `-ApprovedDigest`, and reject approval arguments without `-Apply`.

- [ ] **Step 4: Implement assessment/default planning**

Import the customer-export manifest, compute its canonical digest, snapshot source through the approved absolute Git path, compare exact expected commit, call `Get-CustomerSourceMarkerCatalog`, and call `Get-CustomerExportAssessment -ToolIdentities $toolIdentities -MarkerCatalogProof $markerCatalogProof -GitExecutable $git -GitBlobReader $GitBlobReader`. This assessment performs path denial and expected-output synthetic-data classification before approval. Call the shared constructor exactly:

```powershell
$authentication = [pscustomobject]@{
    executionHost = 'InteractiveWindows11PowerShell'
    mode = 'NotApplicable'
}
$executionManifest = New-RunbookExecutionManifest -RunId $runId -Kind CustomerExport `
    -TargetStableId $assessment.destinationStableId `
    -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
    -AuthenticationContext $authentication -AllowedActions $assessment.allowedActions `
    -ToolVersions $assessment.toolIdentities -GeneratedAtUtc $generatedAtUtc
```

Write `customer-export-assessment.json` and `customer-export-execution-manifest.json` atomically. Create planned evidence only through the complete shared signature:

```powershell
$evidence = ConvertTo-RunbookEvidenceRecord -RunId $runId -GeneratedAtUtc $generatedAtUtc `
    -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
    -PlanDigest $executionManifest.digest -ManifestDigest $manifestDigest `
    -OperatorId $operatorId -Operation 'PlanCustomerRepositoryExport' `
    -Classification Create -Status Planned -ShouldProcessDecision NotApplicable `
    -TargetId $assessment.destinationStableId -ToolVersions $assessment.toolIdentities `
    -FinalContext ([pscustomobject]@{ status='SourceSnapshotMatched' })
```

The shared envelope records every provenance field. `PlanDigest` is the shared execution-manifest digest; `ManifestDigest` is the reviewed customer-export manifest digest. Omit paths and replacement values from console evidence.

- [ ] **Step 5: Implement the smallest Apply mutation boundary**

Reload the supplied shared execution manifest, recompute the customer-export manifest digest, source snapshot, and entire assessment, then call:

```powershell
Test-RunbookExecutionManifest -Manifest $executionManifest `
    -ApprovedDigest $ApprovedDigest `
    -CurrentSourceCommit $assessment.sourceCommit `
    -CurrentAssessmentDigest $assessment.digest `
    -CurrentAuthenticationContext $authentication `
    -AllowedActionNames @(
        'CreateCustomerExport',
        'CopyTrackedBlob',
        'ApplyStructuredReplacement',
        'ValidateCustomerExport',
        'PromoteCustomerExport'
    ) -NowUtc ([datetime]::UtcNow) -MaximumAge ([timespan]::FromMinutes(30))
```

Immediately after shared-manifest validation and before `ShouldProcess` or any directory creation, resolve every required executable again. Compare name, canonical absolute path, SHA-256, and version to `assessment.toolIdentities` and the shared manifest's `toolVersions` using ordinal equality; refuse missing, ambiguous, path-changed, hash-changed, or version-changed tools before mutation. Display source commit, destination, counts, exclusions, assessment digest, and shared execution-manifest digest, then call:

```powershell
if (-not $PSCmdlet.ShouldProcess($assessment.destinationRoot, "Create validated customer export for execution manifest $($executionManifest.digest)")) {
    $decision = if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' }
    ConvertTo-RunbookEvidenceRecord -RunId ([guid]$executionManifest.runId) `
        -GeneratedAtUtc $NowUtc -SourceCommit $assessment.sourceCommit `
        -AssessmentDigest $assessment.digest -PlanDigest $executionManifest.digest `
        -ManifestDigest $manifestDigest -OperatorId $operatorId `
        -Operation 'CreateCustomerRepositoryExport' `
        -Classification $(if ($decision -eq 'Declined') { 'Refused' } else { 'Create' }) `
        -Status $(if ($decision -eq 'Declined') { 'Refused' } else { 'Planned' }) `
        -ShouldProcessDecision $decision -TargetId $assessment.destinationStableId `
        -ToolVersions $assessment.toolIdentities `
        -FinalContext ([pscustomobject]@{ status='SourceSnapshotMatched' })
    return
}
$decision = 'Approved'
```

Write a shared evidence envelope for `WhatIf` or `Declined` with every required provenance argument and the matching `ShouldProcessDecision`; then return. Only after `ShouldProcess` returns true, create a random sibling directory named `.customer-export-<guid>`. Refuse if it already exists.

- [ ] **Step 6: Copy only approved committed blobs**

For each ordinally sorted `assessment.copyFiles`, require a matching shared action with `action = CopyTrackedBlob`, exact `sourceRelativePath`, exact `destinationRelativePath`, and no property outside the shared allowlist. Create its parent below disposable staging, call the injected/default reader with the approved absolute Git path, equivalent arguments to `git -C <source> show <commit>:<path>`, and binary-safe output; write bytes with `FileMode.CreateNew`. Never copy from the working tree, invoke a bare `git` name, or invoke a shell command string. Assert each final path remains below disposable staging.

- [ ] **Step 7: Sanitize, validate, and promote**

For each replacement, require exactly one matching shared action whose `replacementRuleId` equals the reviewed replacement `id`, whose source/destination relative paths equal the exact target path, and whose method is `JsonPointer` for `Json` or `MarkdownExact` for `MarkdownExact`. Group rules by exact path and call `Invoke-CustomerStructuredReplacement` once per path so all transformations occur in memory before one atomic write. Resnapshot source through the approved absolute Git path, and call `Test-CustomerExportContent -Assessment $assessment -ExecutionManifest $executionManifest`. Before writing external evidence, project each replacement result to `{ ruleDigest, replacementCount }` using the reviewed rule's canonical digest; do not serialize its rule ID, path, selector, old/new value digests, values, or source text. If `publishReady` is false, write a shared `Failed` evidence envelope with `ShouldProcessDecision Approved` and sanitized `ErrorCategory`, then throw after deleting only the disposable sibling. If true, use `[IO.Directory]::Move($disposable,$destination)` on the same volume, resnapshot source again, require equality, and write a `Verified` envelope with `ShouldProcessDecision Approved` and `FinalContext.status = 'SourceSnapshotMatched'`. Every evidence call supplies run/time/source/assessment/operator provenance plus both digests. In `finally`, remove a still-existing disposable sibling; never remove source or a pre-existing destination.

- [ ] **Step 8: Add source immutability and idempotency tests**

Create a temporary Git repository with synthetic tracked JSON, two Markdown files containing the old synthetic customer name, a denied tenant artifact, a fake remote, refs, an untracked decoy, and `.github/workflows/sentinel.yml`; commit it, record commit/status/refs/remotes/config/hooks/workflow and tracked-file hashes, remove the untracked decoy only for the success case, and assert all values are identical after export. Apply a `MarkdownExact` count-two rule to only one named Markdown file and an exact disposition for the marker in the other file; assert only the named file changes, its original newline style remains, and removing that disposition makes validation fail on the other file. Assert the export has no `.git`, no workflow path, and no excluded tenant artifact. A second Apply to the same destination must refuse without changing either tree.

- [ ] **Step 9: Run the export entry-point suite**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerRepositoryExport.Tests.ps1,infra/tests/pester/CustomerExportIsolation.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; default, WhatIf, declined confirmation, dirty source, mismatch, residual, and collision paths create no destination, while the clean synthetic Apply creates one validated export and leaves source metadata and bytes unchanged.

- [ ] **Step 10: Commit the export entry point**

```powershell
git add -- infra/src/scripts/runbooks/New-CustomerRepositoryExport.ps1 infra/tests/pester/CustomerRepositoryExport.Tests.ps1
git commit -m "feat(infra): create digest-bound customer exports"
```

Expected: one independently reviewable Apply-path commit.

---

### Task 6: Add the Independent Validator and Static Safety Gate

**Files:**
- Create: `infra/src/scripts/runbooks/Test-CustomerRepositoryExport.ps1`
- Create: `infra/tests/pester/CustomerExportStaticSafety.Tests.ps1`
- Modify: `infra/tests/pester/CustomerRepositoryExport.Tests.ps1`

**Interfaces:**
- Consumes: `-SourceRoot`, `-ExpectedSourceCommit`, `-DestinationRoot`, `-ManifestPath`, `-ExecutionManifestPath`, `-ApprovedDigest`, optional external `-ReportPath`, and injectable read-only native runner, command resolver, file identity provider, Git blob reader, validation runner, operator-ID provider, and clock.
- Produces exact parameters: `Test-CustomerRepositoryExport.ps1 -SourceRoot <string> -ExpectedSourceCommit <40-hex> -DestinationRoot <string> -ManifestPath <string> -ExecutionManifestPath <string> -ApprovedDigest <64-hex> [-ReportPath <string>] [-NativeCommandRunner <scriptblock>] [-CommandResolver <scriptblock>] [-FileIdentityProvider <scriptblock>] [-GitBlobReader <scriptblock>] [-ValidationRunner <scriptblock>] [-InteractiveHostProbe <scriptblock>] [-OperatorIdProvider <scriptblock>] [-NowUtc <datetime>]`.
- Produces: `Test-CustomerRepositoryExport.ps1 ...` → closed validation result, external `customer-export-validation.json`, and shared-envelope `customer-export-validation-evidence.json`; it has no `-Apply` and no mutator.
- Produces static policy: no operational/export source path contains prohibited authentication, workflow, Environment, remote, publication, or source-rewrite interfaces.

- [ ] **Step 1: Write a failing independent-validator test**

```powershell
It 'returns publishReady only for a clean export and unchanged source' {
    $result = & $script:Validator -SourceRoot $script:Source -DestinationRoot $script:Destination `
        -ExpectedSourceCommit $script:ExpectedSourceCommit `
        -ManifestPath $script:ManifestPath -ExecutionManifestPath $script:ExecutionManifestPath `
        -ApprovedDigest $script:ApprovedDigest `
        -ReportPath $script:ValidationReport -ValidationRunner $script:PassingRunner
    $result.status | Should -Be 'Passed'
    $result.publishReady | Should -BeTrue
    Test-Path (Join-Path $script:ValidationReport 'customer-export-validation.json') | Should -BeTrue
    $evidence = Get-Content -Raw (Join-Path $script:ValidationReport 'customer-export-validation-evidence.json') | ConvertFrom-Json
    $evidence.sourceCommit | Should -Match '^[0-9a-f]{40}$'
    $evidence.assessmentDigest | Should -Match '^[0-9a-f]{64}$'
    $evidence.planDigest | Should -Be $script:ApprovedDigest
    $evidence.manifestDigest | Should -Match '^[0-9a-f]{64}$'
    $evidence.operatorId | Should -Be 'SYNTHETIC\operator'
    $evidence.shouldProcessDecision | Should -Be 'NotApplicable'
}
```

- [ ] **Step 2: Run the validator test and verify the red state**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerRepositoryExport.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Test-CustomerRepositoryExport.ps1` does not exist.

- [ ] **Step 3: Implement read-only validation orchestration**

The script validates local interactive Windows and the safe report path; uniquely resolves and hashes Git plus every selected validation executable; imports the customer-export manifest; recomputes the current source snapshot, marker-catalog proof, and complete export assessment; and calls the shared `Test-RunbookExecutionManifest` with the supplied approval digest, current source commit, current assessment digest, `NotApplicable` authentication context, and exact five allowed action names. Require `ExpectedSourceCommit` to equal the execution manifest, assessment, current source snapshot, and Git `rev-parse` value. Tool identities must equal both `assessment.toolIdentities` and shared `toolVersions`; all Git and validation calls use those absolute paths.

For each ordinally sorted `assessment.copyFiles` path:

1. read original bytes from `ExpectedSourceCommit` through `GitBlobReader($git.path,$SourceRoot,$ExpectedSourceCommit,$path)`;
2. verify the original blob SHA-256 against the source snapshot;
3. select all reviewed rules whose exact path equals that file;
4. call `Convert-CustomerExportBlob -Path $path -OriginalBytes $originalBytes -Rules $rules`, which rechecks every original expected-old value/count and returns complete expected bytes plus replacement log;
5. read the complete staged file bytes and compare length and every byte to expected bytes; and
6. record a sanitized mismatch without attempting to repair staging.

Files without rules must byte-equal their original committed blobs. Derive the replacement log only from these in-memory transformations of original committed bytes; never infer a successful replacement from fields already mutated in staging. A count/value mismatch in the original blob, staged byte difference, missing/extra file, or `.git` file/directory fails validation. The script then calls `Test-CustomerExportContent`, writes the detailed redacted result to `customer-export-validation.json`, writes the shared provenance envelope to `customer-export-validation-evidence.json`, returns the result, and exits nonzero when `publishReady` is false. It never creates or changes staging content.

- [ ] **Step 4: Add independent byte-reconstruction tests**

```powershell
It 'derives replacement proof from original commit bytes and compares the whole staged file' {
    $original = [Text.UTF8Encoding]::new($false).GetBytes(
        "Owner: Source Reference Organization`r`nContact Source Reference Organization`r`n")
    $expected = [Text.UTF8Encoding]::new($false).GetBytes(
        "Owner: Customer Example Organization`r`nContact Customer Example Organization`r`n")
    $reader = { param($gitPath,$root,$commit,$path) $original }.GetNewClosure()

    $result = & $script:Validator @script:ValidatorArguments `
        -ExpectedSourceCommit ('a' * 40) -GitBlobReader $reader

    $result.publishReady | Should -BeTrue
    $result.replacementLog[0].replacementCount | Should -Be 2
    [IO.File]::ReadAllBytes((Join-Path $script:Destination 'README.md')) | Should -Be $expected
}

It 'fails when staged bytes differ outside the reviewed replacement' {
    [IO.File]::AppendAllText((Join-Path $script:Destination 'README.md'),
        "Unreviewed line`r`n", [Text.UTF8Encoding]::new($false))
    $result = & $script:Validator @script:ValidatorArguments `
        -ExpectedSourceCommit ('a' * 40) -GitBlobReader $script:OriginalBlobReader
    $result.publishReady | Should -BeFalse
    @($result.failures | Where-Object category -eq 'ExpectedOutputMismatch').Count | Should -Be 1
}

It 'fails when the original committed blob does not satisfy the reviewed count' {
    $wrongOriginal = [Text.UTF8Encoding]::new($false).GetBytes(
        "Owner: Source Reference Organization`r`n")
    $reader = { param($gitPath,$root,$commit,$path) $wrongOriginal }.GetNewClosure()
    { & $script:Validator @script:ValidatorArguments `
        -ExpectedSourceCommit ('a' * 40) -GitBlobReader $reader } |
        Should -Throw '*required occurrence count*'
}
```

- [ ] **Step 5: Write validation evidence through the shared envelope**

Write the validation evidence through:

```powershell
ConvertTo-RunbookEvidenceRecord -RunId ([guid]$executionManifest.runId) `
    -GeneratedAtUtc $NowUtc -SourceCommit $assessment.sourceCommit `
    -AssessmentDigest $assessment.digest -PlanDigest $executionManifest.digest `
    -ManifestDigest $manifestDigest -OperatorId $operatorId `
    -Operation 'ValidateCustomerRepositoryExport' -Classification NoChange `
    -Status $(if ($result.publishReady) { 'Verified' } else { 'Failed' }) `
    -ShouldProcessDecision NotApplicable -TargetId $assessment.destinationStableId `
    -ToolVersions $assessment.toolIdentities `
    -FinalContext ([pscustomobject]@{ status='SourceSnapshotMatched' }) `
    -ErrorCategory $(if ($result.publishReady) { $null } else { 'ExportValidationFailed' })
```

All mandatory provenance values are explicit. The validator supplies `NotApplicable` because it has no mutation prompt.

- [ ] **Step 6: Write AST and text safety tests**

Parse `infra/src/scripts/runbooks/*.ps1` and all module PowerShell files. For the two customer-export entry points, assert:

```powershell
$forbiddenParameters = '(?i)token|secret|credential|password|pat|authorization|devicecode|remote|organization'
$forbiddenText = '(?i)(GH_TOKEN|GITHUB_TOKEN|AZURE_DEVOPS_EXT_PAT|SYSTEM_ACCESSTOKEN|--with-token|az\s+devops\s+login|oidc|workload.identity|workflow_dispatch|api/repos/.+/environments|git\s+(init|remote|push|fetch|pull|checkout|switch|reset|clean|filter-branch)|New-GitHubRepository|Publish-Customer)'
```

Permit documentation statements containing “no OIDC” only outside executable `.ps1` files; executable matches fail. Assert `New-CustomerRepositoryExport.ps1` has `SupportsShouldProcess`, calls `ShouldProcess`, and gates directory creation behind it. Assert the validator has no `Apply` parameter and no `New-Item`, `Set-Content`, `Remove-Item`, `Move-Item`, or file-write call except canonical report writing.

Also assert that no export file defines `New-CustomerExportExecutionManifest`, `Test-CustomerExportExecutionManifest`, `New-CustomerExportPlan`, or `Test-CustomerExportPlan`; both entry points must resolve and call the module-exported `New-RunbookExecutionManifest`/`Test-RunbookExecutionManifest` functions instead.

Parse `Convert-CustomerExportBlob.ps1` and `Invoke-CustomerStructuredReplacement.ps1` separately and assert that neither contains recursive `Get-ChildItem`, `Directory.GetFiles`, `Directory.EnumerateFiles`, wildcard path resolution, or `[regex]::Replace`. The converter performs no file write; the invoker's only writable target derives from one validated exact path. Tree enumeration belongs only to read-only residual and synthetic-data validation.

Parse every native invocation in both entry points and `Test-CustomerExportContent.ps1`; assert its file argument comes from a resolved identity's absolute `path`, never a literal/bare `git`, `git.exe`, `powershell`, `powershell.exe`, `az`, or `az.cmd`. Add runtime tests where the resolver returns zero paths, two distinct paths, and a different hash on revalidation; assert no Git/validation runner or staging mutator is called.

For every `ConvertTo-RunbookEvidenceRecord` command AST, assert named arguments include `RunId`, `GeneratedAtUtc`, `SourceCommit`, `AssessmentDigest`, `OperatorId`, `Operation`, `Classification`, `Status`, and `ShouldProcessDecision`. Assert export records also pass `PlanDigest` as the shared execution-manifest digest, `ManifestDigest` as the reviewed customer-export manifest digest, and `FinalContext`; fail static validation when an older positional or incomplete evidence call remains.

- [ ] **Step 7: Add a workflow-tree and no-Git-metadata test**

Hash every source file below `.github/workflows/` before and after a clean disposable export and assert identical path/digest maps. Assert no exported path starts `.github/workflows/`. Recursively assert that no `.git` file or directory exists in disposable staging or the completed export at any point; do not initialize a disposable repository. Also run:

```powershell
git diff --name-status -- .github/workflows
```

Expected: no output.

- [ ] **Step 8: Run focused runtime and static tests**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerRepositoryExport.Tests.ps1,infra/tests/pester/CustomerExportStaticSafety.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; the clean validator reports `publishReady`, every seeded residual or source change reports failure, and static checks find no forbidden interface.

- [ ] **Step 9: Commit validator and static gate**

```powershell
git add -- infra/src/scripts/runbooks/Test-CustomerRepositoryExport.ps1 infra/tests/pester/CustomerRepositoryExport.Tests.ps1 infra/tests/pester/CustomerExportStaticSafety.Tests.ps1
git commit -m "test(infra): enforce customer export safety boundary"
```

Expected: one validator/safety commit with no workflow change.

---

### Task 7: Document the Attended Handover and Link It

**Files:**
- Create: `infra/docs/runbooks/03-customer-handover.md`
- Modify: `infra/docs/runbooks/README.md`
- Modify: `infra/README.md`

**Interfaces:**
- Consumes: the exact script interfaces and evidence names from Tasks 5–6.
- Produces: one independently usable English runbook with the six-field metadata header and links from both Infrastructure maps.

- [ ] **Step 1: Add failing documentation assertions**

Add to `CustomerRepositoryExport.Tests.ps1` checks that the handover runbook has the exact six metadata fields, links to the design and both scripts, and contains headings `Purpose`, `Roles and prerequisites`, `Assessment and shared execution manifest`, `Approve the digest`, `Apply with ShouldProcess`, `Independent validation`, `Human review`, `Publication boundary`, `Evidence`, `Failure and recovery`, and `Definition of Done`.

- [ ] **Step 2: Run the documentation assertions and verify the red state**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerRepositoryExport.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `03-customer-handover.md` and its links do not exist.

- [ ] **Step 3: Write the runbook header and operating boundary**

Use `Version 1.0`, `Date 2026-09-26`, `Author docs-agent (Voice of Knowledge)`, `Status Proposed Baseline`, `Scope Infrastructure customer repository handover`, and references to the design, runbook index, both scripts, schema, and sample. State that the source is reusable and immutable, execution is local/attended, authentication is `NotApplicable`, evidence is outside Git, and publication is not implemented. Explain that every evidence envelope records generation time, source commit, assessment digest, execution-manifest digest as `planDigest`, reviewed customer-export manifest digest, operator ID, operation, classification, status, ShouldProcess decision, target, tool identities, and final local context.

- [ ] **Step 4: Document exact assessment and approval commands**

Use synthetic paths and no personal data:

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

Tell the reviewer to compare source commit, destination stable ID, retained artifacts, exclusions, replacements by ID/path/format/JSON selector or exact Markdown old/new text and required count in the reviewed manifest, assessment rule digests, markers, exact dispositions, fixed validation suites, assessment digest, shared target `{ type = 'CustomerExport'; stableId = $assessment.destinationStableId }`, and execution-manifest digest before recording approval. Evidence and console summaries show only digests/counts, but the reviewer reads the reviewed manifest itself to confirm the selected customer name. The checklist must confirm that each customer-name documentation edit names one tracked `.md` file, uses `MarkdownExact`, has the reviewed occurrence count, preserves that file's newline style, and is not a wildcard, regex, directory, extension-wide, or repository-wide replacement.

The checklist must also map every old customer/tenant marker to either an exact replacement rule or an exact path-and-marker residual disposition with a written reason. A Markdown replacement in one named file never authorizes the same old marker elsewhere.

Review each required tool's unique absolute path, SHA-256, and version in the assessment and shared execution manifest. If resolution is missing or ambiguous, or any path/hash/version changes before Apply, stop and generate a new assessment and approval; never choose the first PATH result.

Review `sourceMarkerCatalog` against the generated reconciliation proof in two parts: every exact reviewed source assertion, regardless of path, must match committed bytes by path/blob digest/count; separately, every alias, ID, domain, URL, and email suffix automatically discovered in retained or denied tenant artifacts must be represented. Confirm that verified reviewed `CompanyName` and `OtherTenantIdentifier` assertions outside tenant configuration remain valid, and that the catalogue marker projection exactly equals `residualMarkers`. Review every `SyntheticFixture` and `ReviewedNonPersonal` exception by exact path, `sourceBlobSha256`, `expectedOutputSha256`, classification, and reason; evidence and `data/` paths cannot be excepted. Confirm the assessment computed expected bytes in memory, verified both digests, bound both into its digest, and excluded every inconclusive unclassified file.

- [ ] **Step 5: Document exact Apply and validation commands**

```powershell
& $hostPowerShell -NoProfile -File "$source\infra\src\scripts\runbooks\New-CustomerRepositoryExport.ps1" `
  -SourceRoot $source -ExpectedSourceCommit $commit -DestinationRoot $stage `
  -ManifestPath $manifest -ReportPath $report `
  -ExecutionManifestPath (Join-Path $report 'customer-export-execution-manifest.json') `
  -ApprovedDigest $executionManifest.digest -Apply -Confirm

& $hostPowerShell -NoProfile -File "$source\infra\src\scripts\runbooks\Test-CustomerRepositoryExport.ps1" `
  -SourceRoot $source -ExpectedSourceCommit $commit -DestinationRoot $stage -ManifestPath $manifest `
  -ExecutionManifestPath (Join-Path $report 'customer-export-execution-manifest.json') `
  -ApprovedDigest $executionManifest.digest `
  -ReportPath (Join-Path $report 'independent-validation')
```

Document `-WhatIf` before Apply, expected pass/fail files, and that any mismatch requires a new assessment and approval rather than `-Force`.

Document that independent validation requires the same `ExpectedSourceCommit`, rereads every original blob from that commit, reapplies all reviewed rules in memory, and compares complete expected bytes with staging. It does not trust fields already changed in staging. Confirm the staged tree and completed export contain no `.git` path before human review.

- [ ] **Step 6: Document recovery and publication boundary**

State that failure leaves source untouched, does not produce a publish-ready destination, and permits removal only of the explicitly named disposable/customer staging directory after human path review. Human review must inspect the redacted report and staged content. A separately approved attended publication procedure may later create a new remote, but these scripts do not authenticate, create a remote, add a remote, push, force-push, transfer, or modify the reusable source remote.

- [ ] **Step 7: Link the runbook from both Infrastructure maps**

In `infra/docs/runbooks/README.md`, add `03-customer-handover.md` after cloud foundation and label it independently runnable after workstation prerequisites. In `infra/README.md`, add the runbook index and customer handover rows without changing existing document status or narrating a change log.

- [ ] **Step 8: Run documentation and link tests**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/CustomerRepositoryExport.Tests.ps1,infra/tests/pester/RunbookDocumentation.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; metadata, English text, required sections, and relative links are valid.

- [ ] **Step 9: Commit the runbook**

```powershell
git add -- infra/docs/runbooks/03-customer-handover.md infra/docs/runbooks/README.md infra/README.md infra/tests/pester/CustomerRepositoryExport.Tests.ps1
git commit -m "docs(infra): add customer handover runbook"
```

Expected: one documentation commit with exactly the planned map changes.

---

### Task 8: Run Full Acceptance and Perform Final Self-Review

**Files:**
- Modify only if a test exposes a defect: files already listed in Tasks 1–7.
- Do not modify: `.github/workflows/**`

**Interfaces:**
- Consumes: the complete customer-export increment.
- Produces: passing source and disposable-export validation, an attended synthetic dry run, clean Git diff, and a review record in Git history only.

- [ ] **Step 1: Run all Infrastructure Pester tests**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester -Output Detailed -CI"
```

Expected: PASS with no live authentication, tenant call, personal data, or repository mutation.

- [ ] **Step 2: Run the complete repository Pester set**

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester .github/cli/tests,infra/tests/pester,hr/tests/pester -Output Detailed -CI"
```

Expected: PASS.

- [ ] **Step 3: Run repository safety and Bicep validation locally**

```powershell
powershell.exe -NoProfile -File .github/cli/verify-repository-safety.ps1
az bicep build --file infra/src/bicep/main.bicep --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep validation failed.' }
```

Expected: both commands exit `0`; neither authenticates or changes a tenant.

- [ ] **Step 4: Perform the attended synthetic end-to-end dry run**

Create a disposable source repository under `$env:TEMP` with only reserved synthetic JSON, two Markdown files containing the old synthetic customer name, a count-two `MarkdownExact` rule naming one of them, an exact disposition for the marker in the other, retained and denied tenant artifacts containing synthetic aliases/IDs/domains/URLs, a complete matching source marker catalogue plus a reviewed documentation `CompanyName` assertion, one exact source/output-digest-bound synthetic fixture, an unclassified inconclusive file, a denied `data/` file, an evidence file, an untracked decoy, fake remote URL `https://example.invalid/source.git`, and a workflow sentinel. First prove missing automatic catalogue markers, stale reviewed assertions, and the untracked decoy block planning; correct the catalogue, remove the decoy, verify the reviewed `CompanyName` is accepted and the inconclusive file is excluded, commit, assess, inspect the shared execution-manifest digest, run `-WhatIf`, run approved `-Apply`, then run the independent validator. Tamper one non-replacement byte and prove complete-byte comparison fails; restore it from a fresh Apply. Change only `expectedOutputSha256` and prove assessment refuses classification drift. Remove the exact disposition and prove the untouched old marker fails residual validation, then restore it and prove validation passes. Delete disposable source/export directories and external evidence afterward.

Expected: catalogue and dirty-source planning refusals occur before staging; `-WhatIf` creates no stage; approved Apply and original-blob independent validation pass; source snapshots match byte-for-byte; evidence/data/unclassified content is absent; and neither disposable staging nor export ever contains `.git` or `.github/workflows/`.

- [ ] **Step 5: Verify no workflow or out-of-scope change**

```powershell
git diff --name-status -- .github/workflows
git status --short
git diff --check
```

Expected: the workflow command prints nothing; status contains only files from the File Map if fixes remain uncommitted; `git diff --check` prints nothing.

- [ ] **Step 6: Self-review spec coverage**

Read `docs/specs/2026-09-26-operational-runbooks-design.md` sections 3, 7.3–7.5, 8, 9, 12–13, 15.1–15.4, and 17. Verify direct tests for source/export isolation, unconditional evidence/data exclusion, exact tenant artifact allowlisting, exact source-plus-expected-output digest classification, separately verified reviewed marker assertions and automatic tenant-config candidates, permission for verified reviewed company/other markers, marker/residual set equality, JSON Pointer replacement, per-file `MarkdownExact` customer-name replacement with exact counts and preserved newlines, independent original-blob transformation and whole-file byte comparison, prohibited replacement locations, exhaustive residual disposition, no `.git` at any staging phase, publication separation, local attended execution, unique absolute digest-bound executable resolution and pre-mutation revalidation, complete shared evidence provenance, static safety, evidence outside Git, the exact shared `CustomerExport` constructor/target/action contract, absence of an export-specific execution-manifest fork, and every customer-export Definition of Done item.

Expected: no uncovered customer-export requirement; unrelated cloud/workstation requirements remain outside this plan.

- [ ] **Step 7: Self-review placeholders and interface consistency**

```powershell
$planPath = 'docs/superpowers/plans/2026-09-26-runbook-customer-handover.md'
$patterns = @(
    (@('T','B','D') -join ''),
    (@('T','O','D','O') -join ''),
    (@('implement','later') -join ' '),
    (@('fill','in','details') -join ' '),
    (@('similar','to','Task') -join ' '),
    (@('appropriate','error','handling') -join ' '),
    (@('write','tests','for','the','above') -join ' ')
)
foreach ($pattern in $patterns) {
    if (Select-String -Path $planPath -SimpleMatch $pattern) {
        throw 'Plan contains a prohibited placeholder.'
    }
}
```

Then compare every function name, parameter, schema property, status, and file path in Tasks 1–7 with the File Map and Interfaces blocks.

Expected: no placeholder match and no signature/property mismatch.

- [ ] **Step 8: Review documentation policy**

Confirm all changed Markdown is English, UTF-8, has valid six-field metadata where eligible, uses supported status language, has valid relative links, remains in the Infrastructure domain, and adds no in-document change log.

Expected: docs-agent checklist passes.

- [ ] **Step 9: Commit acceptance fixes if and only if required**

```powershell
git add -- infra/src/config/schemas/customer-export.schema.json infra/src/config/runbooks/customer-export.sample.json infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/src/scripts/runbooks infra/tests/fixtures/runbooks infra/tests/pester infra/docs/runbooks infra/README.md
git diff --cached --name-only -- .github/workflows
git commit -m "test(infra): complete customer export acceptance"
```

Expected: the workflow-path check prints nothing. Skip this commit when no acceptance fix was needed; otherwise it contains only scoped corrective changes.

## Definition of Done

- The schema and synthetic sample are closed, contain no credential/publication surface or real data, and allow only exact tenant artifacts under `infra/src/config/tenants/` or `infra/src/bicep/parameters/`, per-file `Json` or `MarkdownExact` replacements, an exact source marker catalogue, exact residual dispositions, source-and-expected-output-digest-bound synthetic/non-personal classifications, inspectable binary digests, and fixed local validation-suite IDs.
- Default export invocation creates only an external canonical assessment, shared execution manifest, and evidence record; no destination or disposable staging exists.
- Approved Apply is bound through the shared `CustomerExport` execution manifest to the exact source snapshot, expected commit, customer-export manifest digest, destination stable ID, inventory, replacement rule digests, tool versions, freshness window, assessment digest, and execution-manifest digest; `-WhatIf` and declined confirmation perform no staging mutation.
- Git and every selected native validation tool resolve to one unique absolute regular-file path and SHA-256, their versions are probed through that path, those identities are assessment- and execution-manifest-bound, and Apply revalidates them immediately before its first staging write. Missing, ambiguous, path-drifted, hash-drifted, or version-drifted tools refuse without mutation.
- Every native command is invoked by its approved absolute path; no export or validation operation chooses the first PATH result or invokes a bare executable name.
- Source commit, status, tracked bytes, refs, remotes, local Git configuration, hooks, and workflow bytes are proven unchanged before and after export.
- The export is history-free, contains only regular tracked committed blobs, excludes all `.github/workflows/`, all evidence and `data/` paths, and retains only exact allowlisted tenant artifacts. No `.git` file or directory exists at any time in disposable staging or the completed export.
- JSON rules change only one RFC 6901-selected value with required count `1`. Markdown rules change only exact ordinal text in one named tracked `.md` file, permit a reviewed count greater than one, preserve BOM-free UTF-8 and the original LF/CRLF style, and leave bytes unchanged on count mismatch.
- Replacement targets need not be tenant artifacts, but are exact regular tracked files outside `.git/`, `.github/workflows/`, `.github/skills/`, evidence, and every prohibited location. No wildcard, regex, directory-wide, extension-wide, or repository-global replacement path exists.
- Internal replacement logs contain only validation metadata and digests, never old/new values. Serialized replacement evidence is further projected to rule digest and count only; it contains no path, selector, old/new value, or source text.
- Every old customer/tenant marker occurrence in paths and text is reported after replacement; only an explicit replacement in that exact file or an exact path-and-marker disposition with a reason accounts for it. Any undisposed foreign-tenant residual prevents `publishReady`.
- `sourceMarkerCatalog` and `residualMarkers` have exact marker-set equality. Every reviewed catalogue source assertion is verified against exact committed path/blob digest/count regardless of path; automatic tenant-config discovery separately proves that every alias, stable ID, domain, URL, and email suffix from retained and denied tenant artifacts is represented. Verified reviewed `CompanyName` and `OtherTenantIdentifier` entries are permitted even when not automatic candidates. Unrepresented automatic candidates, stale reviewed assertions, duplicates, or residual-set drift refuse planning.
- Every exported UTF-8 file passes the fail-closed structured-key and free-text synthetic-data scanner. Definite personal data always fails; fixture paths require exact `SyntheticFixture` path/source digest/expected-output digest/classification/reason; inconclusive files are excluded or require exact `ReviewedNonPersonal` path/source digest/expected-output digest/classification/reason; broad exceptions are impossible.
- Assessment reads original committed bytes, applies reviewed rules in memory, hashes complete expected post-replacement bytes, verifies both classification digests, and binds the verified digest pairs into the assessment and shared execution manifest before approval.
- Independent validation rereads every original blob from `ExpectedSourceCommit`, revalidates every expected-old value/count, applies all reviewed rules in memory, derives the replacement log from that transformation, and byte-compares the complete expected output with staging. It never reconstructs success from already-mutated staged fields.
- Unlisted or mismatched binaries, secrets, non-synthetic or inconclusive content, invalid UTF-8, bad Markdown metadata, broken relative links, prohibited paths, inventory drift, failed suites, and source drift all prevent `publishReady`.
- `New-CustomerRepositoryExport.ps1` is local, attended, `-Apply` plus `ShouldProcess` gated, digest-bound, and non-publishing; `Test-CustomerRepositoryExport.ps1` is independently runnable and does not mutate staging.
- Assessments, shared execution manifests, and evidence remain outside Git and staging and contain only allowlisted redacted metadata.
- Every shared evidence envelope supplies `GeneratedAtUtc`, `SourceCommit`, `AssessmentDigest`, `OperatorId`, and `ShouldProcessDecision`, uses `PlanDigest` for the shared execution-manifest digest and `ManifestDigest` for reviewed export intent, and records final local source-context status without raw command output.
- Static tests reject authentication inputs/environment variables, OIDC/workload identity, runners, workflow dispatch, GitHub Environment operations, workflow edits, remote/publication commands, and source-rewrite commands.
- The handover runbook is linked from the runbook index and Infrastructure map, uses the required metadata, documents exact PowerShell commands, recovery, human review, and the separate publication boundary.
- All synthetic Pester, repository safety, Bicep, source, and disposable-export validations pass without live services or real customer/personal data.
- No `.github/workflows/` path is added, removed, or modified.

## Plan Self-Review

- **Spec coverage:** Tasks 1–8 cover the closed export intent, immutable committed-source snapshot, shared execution manifest, exact JSON and Markdown replacement, authoritative marker catalogue, fail-closed synthetic-data classification, independent reconstruction, validation, documentation, and acceptance.
- **Boundary review:** The source repository, Git metadata, remotes, refs, hooks, and workflows remain immutable. The disposable export contains neither `.git` nor `.github/workflows/`, and publication is a separate attended procedure.
- **Interface consistency:** Shared manifest and evidence signatures, target identity, tool identity, assessment digest, replacement rule IDs, marker IDs, classifications, filenames, and script parameters use the same names and types in every task.
- **Placeholder scan:** Runtime values are explicit manifest or command parameters. The plan contains no unresolved implementation placeholder, wildcard replacement, global substitution, inferred tenant marker, or unspecified validation command.
- **Data review:** Every retained fixture or inconclusive text file requires an exact path-and-digest classification. Real or unclassified personal data cannot become publish-ready.

## Execution Handoff

Implement the shared foundation/workstation plan before this plan. After the shared contracts exist, this customer-handover plan may proceed independently of the cloud-foundation plan.

1. **Subagent-Driven (recommended):** use `superpowers:subagent-driven-development`, dispatch a fresh implementation subagent for each task, and complete requirements and quality review before the next task.
2. **Inline Execution:** use `superpowers:executing-plans`, implement in batches, and stop at the documented review checkpoints.
