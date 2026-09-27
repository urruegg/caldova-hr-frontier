# Customer Repository Export and Handover Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Infrastructure (all tenants) |
| **References** | [Customer Repository Export and Handover design](../specs/2026-09-27-customer-repository-export-and-handover-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tenant-agnostic clean-up script and two runbooks (Repository Clean-Up, Customer Repository Export and Handover) that let Tenant 2's owner and, later, Tenant 3's owner turn a seeded copy of this repository into their own tenant-dedicated repository — and prove Tenant 1's own manifest/evidence blueprint is internally consistent before anyone follows those runbooks.

**Architecture:** One new PowerShell script (`Remove-OtherTenantArtifacts.ps1`, `-WhatIf`-safe, `SupportsShouldProcess`) removes every other tenant's config manifest, discovery evidence, and Bicep parameter file from a repository, keeping only the named tenant's own files and the shared `_template.psd1` schema. Two new runbooks under `infra/docs/` document how to use it as part of the full export/handover procedure. One new Pester suite proves Tenant 1's manifest `Existing` claims are backed by real discovery evidence, closing the "prove the configuration end-to-end" half of this sprint's goal.

**Tech Stack:** PowerShell 7+ (Windows PowerShell 5.1-compatible), Pester 5.7.1, this repository's existing `infra/src/scripts/` and `infra/tests/pester/` conventions.

**Spec:** [docs/specs/2026-09-27-customer-repository-export-and-handover-design.md](../specs/2026-09-27-customer-repository-export-and-handover-design.md)

## Global Constraints

- PowerShell scripts must run correctly under both PowerShell 7 (`pwsh`) and Windows PowerShell 5.1 (`powershell.exe`, this repository's CI runtime) — verify locally under both, not just `pwsh`.
- No literal non-ASCII character in any tracked source or test file — this repository's Pester files are tracked without a UTF-8 BOM, and Windows PowerShell 5.1 misreads a literal non-ASCII byte in a non-BOM file (see commit `97b39a4` on this branch for the exact failure mode). Use `[char]` codepoints if a non-ASCII character is ever needed.
- Every new/modified script and Markdown file must pass this repository's own validators: `Invoke-Pester -Path infra/tests/pester -Output Detailed -CI` and the documentation-metadata check (`Status` field must use one of `Draft`, `Proposed Baseline`, `Active`, `Approved`, `Superseded`, `Archived` — not bare `Proposed`, not `Accepted`).
- This sprint performs no live GitHub, Azure DevOps, or Entra mutation, and creates no new tenant repository or organization — per the spec's explicit "Out of scope" list. Every script this plan builds only ever touches files inside this repository's own working tree.
- `infra/src/config/tenants/_template.psd1` is schema, not tenant data, and must never be removed by the clean-up script under any tenant alias.

---

### Task 1: `Remove-OtherTenantArtifacts.ps1` script and tests

**Files:**
- Create: `infra/src/scripts/Remove-OtherTenantArtifacts.ps1`
- Test: `infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1`

**Interfaces:**
- Consumes: nothing from earlier tasks (first task).
- Produces: `infra/src/scripts/Remove-OtherTenantArtifacts.ps1`, invoked as `& $scriptPath -TenantAliasToKeep '<alias>' [-RepositoryRootOverride '<path>'] [-WhatIf] [-Confirm:$false]`. Returns (writes to the pipeline) the full list of absolute file paths it removed (or would remove, under `-WhatIf`) as a flat array of strings. Later tasks' runbooks (Task 2, Task 4) reference this exact script path and parameter names.

Confirmed by direct repository search (`git grep`, run 2026-09-27) that today's only tenant-scoped, removable artifacts are:
- `infra/src/config/tenants/<alias>.psd1` (excluding `_template.psd1`)
- `infra/evidence/discovery/<alias>.json`
- `infra/src/bicep/params/<alias>.bicepparam` (none exist yet for any tenant, but `.github/workflows/bootstrap-tenant.yml` already references this path pattern, so the script must handle it defensively)

- [ ] **Step 1: Write the failing tests**

Create `infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1`:

```powershell
Set-StrictMode -Version Latest

Describe 'Remove-OtherTenantArtifacts' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\Remove-OtherTenantArtifacts.ps1'

        function script:New-FixtureRepository {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path (Join-Path $root 'infra\src\config\tenants') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root 'infra\evidence\discovery') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $root 'infra\src\bicep\params') -Force | Out-Null

            Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\_template.psd1') -Value '@{}'
            Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenant-a.psd1') -Value "@{ TenantAlias = 'tenant-a' }"
            Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenant-b.psd1') -Value "@{ TenantAlias = 'tenant-b' }"
            Set-Content -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenant-a.json') -Value '{}'
            Set-Content -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenant-b.json') -Value '{}'
            Set-Content -LiteralPath (Join-Path $root 'infra\src\bicep\params\tenant-a.bicepparam') -Value ''
            Set-Content -LiteralPath (Join-Path $root 'infra\src\bicep\params\tenant-b.bicepparam') -Value ''

            $root
        }
    }

    It 'lists every other tenant''s manifest, evidence, and Bicep parameter file without removing anything under -WhatIf' {
        $root = New-FixtureRepository

        $result = & $script:ScriptPath -TenantAliasToKeep 'tenant-a' -RepositoryRootOverride $root -WhatIf

        @($result).Count | Should -Be 3
        $result | Should -Contain (Join-Path $root 'infra\src\config\tenants\tenant-b.psd1')
        $result | Should -Contain (Join-Path $root 'infra\evidence\discovery\tenant-b.json')
        $result | Should -Contain (Join-Path $root 'infra\src\bicep\params\tenant-b.bicepparam')

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenant-b.psd1') | Should -BeTrue
    }

    It 'never lists the kept tenant''s own files or the _template.psd1 schema file' {
        $root = New-FixtureRepository

        $result = & $script:ScriptPath -TenantAliasToKeep 'tenant-a' -RepositoryRootOverride $root -WhatIf

        $result | Should -Not -Contain (Join-Path $root 'infra\src\config\tenants\tenant-a.psd1')
        $result | Should -Not -Contain (Join-Path $root 'infra\src\config\tenants\_template.psd1')
        $result | Should -Not -Contain (Join-Path $root 'infra\evidence\discovery\tenant-a.json')
    }

    It 'removes only the other tenant''s files when not run with -WhatIf' {
        $root = New-FixtureRepository

        & $script:ScriptPath -TenantAliasToKeep 'tenant-a' -RepositoryRootOverride $root -Confirm:$false

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenant-b.psd1') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenant-b.json') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $root 'infra\src\bicep\params\tenant-b.bicepparam') | Should -BeFalse

        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenant-a.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\src\config\tenants\_template.psd1') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $root 'infra\evidence\discovery\tenant-a.json') | Should -BeTrue
    }

    It 'returns an empty result and removes nothing when only the kept tenant''s files exist' {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $root 'infra\src\config\tenants') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'infra\src\config\tenants\tenant-a.psd1') -Value "@{ TenantAlias = 'tenant-a' }"

        $result = & $script:ScriptPath -TenantAliasToKeep 'tenant-a' -RepositoryRootOverride $root -Confirm:$false

        @($result).Count | Should -Be 0
    }

    It 'rejects a tenant alias containing characters outside the reviewed pattern' {
        $root = New-FixtureRepository

        { & $script:ScriptPath -TenantAliasToKeep 'Tenant-A!' -RepositoryRootOverride $root -WhatIf } | Should -Throw
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Invoke-Pester -Path infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1 -Output Detailed`
Expected: FAIL — `infra/src/scripts/Remove-OtherTenantArtifacts.ps1` does not exist yet, every test errors with a "cannot find path" style failure.

- [ ] **Step 3: Write the script**

Create `infra/src/scripts/Remove-OtherTenantArtifacts.ps1`:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAliasToKeep,

    [string]$RepositoryRootOverride
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-OtherTenantArtifacts {
    param(
        [Parameter(Mandatory)]
        [string]$TenantAliasToKeep,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $manifestRoot = Join-Path $RepositoryRoot 'infra\src\config\tenants'
    $evidenceRoot = Join-Path $RepositoryRoot 'infra\evidence\discovery'
    $bicepParamsRoot = Join-Path $RepositoryRoot 'infra\src\bicep\params'

    $artifacts = [System.Collections.Generic.List[string]]::new()

    if (Test-Path -LiteralPath $manifestRoot) {
        Get-ChildItem -LiteralPath $manifestRoot -Filter '*.psd1' -File |
            Where-Object { $_.BaseName -cne $TenantAliasToKeep -and $_.BaseName -cne '_template' } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    if (Test-Path -LiteralPath $evidenceRoot) {
        Get-ChildItem -LiteralPath $evidenceRoot -Filter '*.json' -File |
            Where-Object { $_.BaseName -cne $TenantAliasToKeep } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    if (Test-Path -LiteralPath $bicepParamsRoot) {
        Get-ChildItem -LiteralPath $bicepParamsRoot -Filter '*.bicepparam' -File |
            Where-Object { $_.BaseName -cne $TenantAliasToKeep } |
            ForEach-Object { $artifacts.Add($_.FullName) }
    }

    @($artifacts)
}

$resolvedRepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRootOverride)) {
    Get-RepositoryRoot
}
else {
    $RepositoryRootOverride
}

$artifacts = Get-OtherTenantArtifacts -TenantAliasToKeep $TenantAliasToKeep -RepositoryRoot $resolvedRepositoryRoot

foreach ($artifact in $artifacts) {
    $relativePath = $artifact.Substring($resolvedRepositoryRoot.Length).TrimStart('\', '/')
    if ($PSCmdlet.ShouldProcess($relativePath, 'Remove other-tenant artifact')) {
        Remove-Item -LiteralPath $artifact -Force
    }
}

Write-Output -NoEnumerate $artifacts
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Invoke-Pester -Path infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1 -Output Detailed`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Verify under Windows PowerShell 5.1**

Run: `powershell -NoProfile -Command "Invoke-Pester -Path infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1 -Output Detailed"`
Expected: PASS — same 5 tests green under the CI runtime, not just `pwsh`.

- [ ] **Step 6: Commit**

```powershell
git add infra/src/scripts/Remove-OtherTenantArtifacts.ps1 infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1
git commit -m "feat(infra): add Remove-OtherTenantArtifacts script and tests"
```

---

### Task 2: Repository Clean-Up Runbook

**Files:**
- Create: `infra/docs/22-repository-cleanup-runbook.md`

**Interfaces:**
- Consumes: `infra/src/scripts/Remove-OtherTenantArtifacts.ps1` from Task 1 — cites its exact parameter names (`-TenantAliasToKeep`, `-RepositoryRootOverride`, `-WhatIf`, `-Confirm:$false`).
- Produces: a runbook path (`infra/docs/22-repository-cleanup-runbook.md`) that Task 4's Handover Runbook links to as one of its steps.

- [ ] **Step 1: Write the runbook**

Create `infra/docs/22-repository-cleanup-runbook.md`:

```markdown
# Repository Clean-Up Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (all tenants) |
| **References** | [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md), [Customer Repository Export and Handover design](../../docs/specs/2026-09-27-customer-repository-export-and-handover-design.md), [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md) |

This runbook removes every other tenant's configuration manifest, discovery evidence, and Bicep parameter file from a freshly seeded copy of this repository, using `infra/src/scripts/Remove-OtherTenantArtifacts.ps1`. It is tenant-agnostic — the tenant alias to keep is a parameter, not something baked into the runbook — and is reused by every tenant onboarded under [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md), not written as a one-time script for any single tenant.

## Who Can Run This

- Anyone with a local clone of the freshly seeded destination repository and PowerShell 7 or Windows PowerShell 5.1. No Azure, Azure DevOps, or GitHub credentials are required — this runbook only ever touches files already present in the local working tree.
- Run this **after** seeding the destination repository (Step 2 of the [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md)) and **before** committing anything to the new repository's history.

## Prerequisites Checklist

- [ ] You are working in the **destination** repository's local clone — not this source repository. Removing another tenant's files from the wrong repository is not reversible by this runbook.
- [ ] You know the tenant alias to keep (for example `caldova25668747` for Tenant 2). Confirm it matches `infra/src/config/tenants/<alias>.psd1`'s own `TenantAlias` field before proceeding.
- [ ] `Invoke-Pester -Path infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1 -Output Detailed -CI` passes in the destination repository before you begin.

## Steps

1. **Review what would be removed, with zero mutation.**

   ```powershell
   .\infra\src\scripts\Remove-OtherTenantArtifacts.ps1 -TenantAliasToKeep '<your-tenant-alias>' -WhatIf
   ```

   Confirm every listed file belongs to a *different* tenant than the one you are keeping. If a file you expected to see is missing, or a file you did not expect appears, stop and investigate before continuing — do not proceed on a plan you do not fully understand.

2. **Execute the removal.**

   ```powershell
   .\infra\src\scripts\Remove-OtherTenantArtifacts.ps1 -TenantAliasToKeep '<your-tenant-alias>' -Confirm:$false
   ```

   This is a local file deletion, not a Git operation — nothing is committed yet. If you make a mistake here, `git checkout -- .` (before staging anything) restores every removed file from the last commit.

3. **Verify nothing else references the removed tenant.**

   ```powershell
   git grep -l '<removed-tenant-alias>' -- . ':!docs' ':!infra/docs'
   ```

   Expect no output outside `docs/` and `infra/docs/` — those folders describe the whole multi-tenant family's design and correctly continue to mention every tenant by name; they are never scrubbed per-repository. Any match outside those two folders is a genuinely tenant-scoped reference this runbook's script did not yet know to remove — treat it as a defect in this runbook or the script, not something to silently work around.

4. **Run the full test suite to prove nothing broke.**

   ```powershell
   Invoke-Pester -Path .github/cli/tests,infra/tests/pester -Output Detailed -CI
   ```

   Expected: all tests pass. A failure here means the clean-up removed something the destination repository's own tooling still depends on — do not commit until this is green.

5. **Commit the clean-up as its own commit**, separate from any manifest configuration changes made later in the Handover Runbook:

   ```powershell
   git add -A
   git commit -m "chore: remove other-tenant configuration and evidence"
   ```

## What This Runbook Does Not Do

| Not covered here | Where it lives instead |
|---|---|
| Creating the destination repository or seeding it with this repository's content | [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md), Step 2 |
| Correcting the kept tenant's own manifest fields (for example `GitHub.Owner`) | [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md), Step 4 |
| Removing prose mentions of other tenants from `docs/` or `infra/docs/` | Deliberately out of scope — those documents describe the shared multi-tenant design and remain identical across every tenant's repository |

## Troubleshooting

- **The script lists a file you did not expect.** `Remove-OtherTenantArtifacts.ps1` only ever looks at `infra/src/config/tenants/*.psd1`, `infra/evidence/discovery/*.json`, and `infra/src/bicep/params/*.bicepparam`. If you see an unexpected file, check whether a new tenant-scoped artifact type has been added to the repository since this runbook was last reviewed — that is a real gap to fix in the script, not something to remove by hand and move on.
- **`Test-Path` still shows the other tenant's file after Step 2.** Confirm you ran the script without `-WhatIf` and answered any `ShouldProcess` prompt with `Y` (or passed `-Confirm:$false`, as shown above, for a fully unattended run in an already-reviewed context).
- **Step 4's test run fails after removal.** Do not attempt to patch the failure by re-adding the removed file — first read the failing test's name and message; it usually names exactly what still depends on the removed tenant's data.
```

- [ ] **Step 2: Verify the documentation metadata check passes**

Run:
```powershell
Import-Module .\.github\cli\modules\DocumentationMetadata.psm1 -Force
$content = [IO.File]::ReadAllText('infra\docs\22-repository-cleanup-runbook.md')
$failures = @(Test-DocumentationMetadataContent -Content $content -DocumentRelativePath 'infra/docs/22-repository-cleanup-runbook.md')
if ($failures.Count -eq 0) { 'OK' } else { $failures }
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```powershell
git add infra/docs/22-repository-cleanup-runbook.md
git commit -m "docs(infra): add Repository Clean-Up Runbook"
```

---

### Task 3: Tenant 1 Blueprint Verification

**Files:**
- Create: `infra/tests/pester/TenantBlueprintVerification.Tests.ps1`
- Modify: `infra/docs/18-multi-tenant-provisioning.md`

**Interfaces:**
- Consumes: `infra/src/config/tenants/caldova25156897.psd1` and `infra/evidence/discovery/caldova25156897.json`, both already present in this repository — read-only, no earlier task produces these.
- Produces: a passing Pester suite that is itself the evidence the spec's "Tenant 1 Blueprint Verification Runbook" open item calls for; folded into `infra/docs/18` rather than written as a fourth separate document, per the spec's own stated option to fold it in ("both keep the same information; the choice is about document count, not content").

**Confirmed finding (2026-09-27): `Initialize-TenantTrust.ps1` is a complete, gap-free path for Tenant 1's six pending `Create` components.** Direct inspection of the script confirms every one of the six components the spec asked this sprint to check has its own `Add-PlanItem` plan entry, its own `$mutationQueue` entry, and its own `ShouldProcess`-gated execution block:

| Manifest component | Script operation name |
|---|---|
| `EntraApplication` | `EnsureEntraApplication` |
| `EntraServicePrincipal` | `EnsureEntraServicePrincipal` (plus `EnsureApplicationPermissions` and an attended `GrantAdminConsent` checkpoint) |
| `EntraFederatedIdentityCredential` | `EnsureFederatedCredential` |
| `GitHubEnvironment` | `EnsureGitHubEnvironment` (plus `EnsureGitHubEnvironmentVariable` for `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) |
| `AzureDevOpsServicePrincipalEntitlement` | `EnsureAzureDevOpsServicePrincipalEntitlement` |
| `AzureDevOpsReadersMembership` | `EnsureAzureDevOpsReadersMembership` |

No gap was found. This closes the spec's "Confirming `Initialize-TenantTrust.ps1`... is the complete, correct, re-runnable path to these six `Create` items, with no gaps found during this sprint's review" requirement without needing any code change to that script.

Confirmed by direct inspection (2026-09-27) that Tenant 1's manifest currently declares six components `Mode = 'Existing'` with a stable `Id`, and all six IDs are present in the discovery evidence file's `Services.*.Resources[]` array with `Status: 'Found'`:

| Component | Stable ID | Evidence service |
|---|---|---|
| `GitHubRepository` | `1371297722` | `GitHub` |
| `AzureSubscription` | `edb45a24-408d-47c4-bbc7-685b9b3fc017` | (Azure) |
| `AzureDevOpsProject` | `f250378e-597d-487b-854a-fb8338962822` | (Azure DevOps) |
| `PowerPlatformEnvironmentDev` | `346c2cb2-534d-e581-978f-4c293e25a146` | (Power Platform) |
| `PowerPlatformEnvironmentTest` | `86fb2f33-4145-e23a-b064-5e0850aba258` | (Power Platform) |
| `PowerPlatformEnvironmentProd` | `c5d83095-c8bf-ec78-94dd-b4e62f34c85e` | (Power Platform) |

- [ ] **Step 1: Write the failing test**

Create `infra/tests/pester/TenantBlueprintVerification.Tests.ps1`:

```powershell
Set-StrictMode -Version Latest

Describe 'Tenant 1 blueprint verification' {
    BeforeAll {
        $script:ManifestPath = Join-Path $PSScriptRoot '..\..\src\config\tenants\caldova25156897.psd1'
        $script:EvidencePath = Join-Path $PSScriptRoot '..\..\evidence\discovery\caldova25156897.json'

        function script:Get-EvidenceResources {
            param([Parameter(Mandatory)] [object]$Evidence)

            $resources = [System.Collections.Generic.List[object]]::new()
            foreach ($serviceProperty in $Evidence.Services.PSObject.Properties) {
                $service = $serviceProperty.Value
                if ($null -eq $service.Resources) { continue }
                foreach ($resource in @($service.Resources)) {
                    $resources.Add($resource)
                }
            }
            @($resources)
        }
    }

    It 'has a reviewed manifest and a discovery evidence file at their expected paths' {
        Test-Path -LiteralPath $script:ManifestPath | Should -BeTrue
        Test-Path -LiteralPath $script:EvidencePath | Should -BeTrue
    }

    It 'has every Existing component''s stable ID present in discovery evidence with Status Found' {
        $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
        $evidence = Get-Content -Raw -LiteralPath $script:EvidencePath | ConvertFrom-Json
        $evidenceResources = Get-EvidenceResources -Evidence $evidence

        $existingComponents = @($manifest.Components.Keys | Where-Object {
            $manifest.Components[$_].Mode -ceq 'Existing'
        })

        $existingComponents.Count | Should -BeGreaterThan 0

        foreach ($componentName in $existingComponents) {
            $expectedId = [string]$manifest.Components[$componentName].Id
            $expectedId | Should -Not -BeNullOrEmpty -Because "component '$componentName' claims Mode=Existing and must carry a stable Id"

            $matchingResource = $evidenceResources | Where-Object {
                [string]$_.Type -ceq $componentName -and [string]$_.Id -ceq $expectedId
            } | Select-Object -First 1

            $matchingResource | Should -Not -BeNullOrEmpty -Because "no discovery evidence resource of Type '$componentName' with Id '$expectedId' was found"
            [string]$matchingResource.Status | Should -Be 'Found' -Because "component '$componentName' (Id '$expectedId') is not confirmed Found in discovery evidence"
        }
    }

    It 'has the manifest''s own TenantAlias field match the evidence file''s TenantAlias field' {
        $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
        $evidence = Get-Content -Raw -LiteralPath $script:EvidencePath | ConvertFrom-Json

        [string]$manifest.TenantAlias | Should -Be ([string]$evidence.TenantAlias)
    }
}
```

- [ ] **Step 2: Run the test to verify it currently passes**

Run: `Invoke-Pester -Path infra/tests/pester/TenantBlueprintVerification.Tests.ps1 -Output Detailed`
Expected: PASS — all 3 tests green. Unlike Tasks 1 and 2, this test is written against Tenant 1's *already-existing* manifest and evidence, so it should pass immediately; it exists to catch future drift, not to drive new production code. If any test fails here, that is a real, pre-existing inconsistency between Tenant 1's manifest and its evidence — stop and report it rather than editing the test to make it pass.

- [ ] **Step 3: Verify under Windows PowerShell 5.1**

Run: `powershell -NoProfile -Command "Invoke-Pester -Path infra/tests/pester/TenantBlueprintVerification.Tests.ps1 -Output Detailed"`
Expected: PASS — same 3 tests green under the CI runtime.

- [ ] **Step 4: Fold the verification result into `infra/docs/18-multi-tenant-provisioning.md`**

Add a new section immediately after the "Tenant Status" section's explanatory paragraph ("Tenant 2 has one reviewed discovery manifest...") and immediately before the "Future Onboarding Sequence" heading:

```markdown
## Tenant 1 Blueprint Verification

`infra/tests/pester/TenantBlueprintVerification.Tests.ps1` proves Tenant 1's manifest and discovery evidence are consistent: every component the manifest declares `Mode = 'Existing'` has a matching, `Status: 'Found'` resource in `infra/evidence/discovery/caldova25156897.json`, by both `Type` and stable `Id`. Re-run this suite whenever Tenant 1's manifest or evidence file changes, and before pointing Tenant 2's or Tenant 3's owner at this repository as the reference blueprint.

This proves the manifest and evidence agree with each other. It does not prove the underlying Azure, Azure DevOps, or GitHub resources still exist — that requires fresh, live discovery, which remains a separate, attended action.

Separately, `infra/src/scripts/Initialize-TenantTrust.ps1` was reviewed (2026-09-27) against Tenant 1's six remaining `Mode = 'Create'` components (`EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`, `GitHubEnvironment`, `AzureDevOpsServicePrincipalEntitlement`, `AzureDevOpsReadersMembership`) and confirmed complete and gap-free: each has its own plan item, mutation-queue entry, and `ShouldProcess`-gated execution block in that script. Running it live remains a separate, attended activity — this review only confirms the path exists and is correct, not that it has been executed.
```

- [ ] **Step 5: Commit**

```powershell
git add infra/tests/pester/TenantBlueprintVerification.Tests.ps1 infra/docs/18-multi-tenant-provisioning.md
git commit -m "test(infra): add Tenant 1 blueprint verification suite"
```

---

### Task 4: Customer Repository Export and Handover Runbook

**Files:**
- Create: `infra/docs/23-customer-repository-export-and-handover-runbook.md`

**Interfaces:**
- Consumes: `infra/src/scripts/Remove-OtherTenantArtifacts.ps1` (Task 1) and `infra/docs/22-repository-cleanup-runbook.md` (Task 2) by exact path — this runbook's Step 3 hands off to that runbook rather than repeating its content.
- Produces: the parent runbook referenced by `infra/docs/18-multi-tenant-provisioning.md` and by `infra/docs/14-github-repository-blueprint.md`, both already updated on this branch to point forward to "the Customer Repository Export and Handover design" — this task adds the runbook those references were written in anticipation of.

- [ ] **Step 1: Write the runbook**

Create `infra/docs/23-customer-repository-export-and-handover-runbook.md`:

```markdown
# Customer Repository Export and Handover Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (all tenants) |
| **References** | [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md), [Customer Repository Export and Handover design](../../docs/specs/2026-09-27-customer-repository-export-and-handover-design.md), [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md) |

This runbook is the end-to-end procedure a new tenant owner follows to turn a copy of Tenant 1's repository into their own tenant-dedicated repository, per [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md). Tenant 2's owner (Andrea Rizzi) runs this runbook first, as a genuine, unassisted execution — not a second reading — so any gap found is fixed here before Tenant 3 (Georg Fischer) receives it.

## Who Can Run This

- The new tenant's owner, with **repository creation permission** on the destination account (a personal GitHub account, or Owner/Admin on the destination GitHub Organization).
- **Azure DevOps role:** at least **Project Administrator** on the tenant's own Azure DevOps organization/project, to install the Azure Boards GitHub App connection in Step 5.
- No access to any *other* tenant's Azure, Azure DevOps, GitHub, or Entra resources is required or should be used at any point in this runbook.

## Prerequisites Checklist

- [ ] You know your tenant's alias (matching `infra/src/config/tenants/<alias>.psd1`'s own `TenantAlias` field in the source repository) and your tenant's Azure DevOps organization URL and project name.
- [ ] You have decided your account type per [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) — personal account or GitHub Organization — before Step 1, since this cannot be changed later without repeating this runbook.
- [ ] `git`, PowerShell 7 or Windows PowerShell 5.1, and the Azure CLI with the `azure-devops` extension are installed locally.

## Steps

1. **Create the destination repository.**

   Using GitHub's "Use this template" (if the source repository is marked as a template) or by forking the source repository and then transferring/detaching it to the destination account — either produces a repository with the source's full current history and content, owned by your account, with no ongoing live link back to the source repository. Name it to match the source repository unless you have a specific reason not to.

2. **Clone the new repository locally and confirm it is the destination, not the source.**

   ```powershell
   git clone https://github.com/<your-account>/<your-repository>.git
   cd <your-repository>
   git remote -v
   ```

   Confirm the `origin` remote points at your new repository, not the source repository you copied from. Every remaining step in this runbook assumes you are working inside this clone.

3. **Run the Repository Clean-Up Runbook.**

   Follow [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md) in full now, passing your own tenant alias as `-TenantAliasToKeep`. Do not proceed to Step 4 below until that runbook's own Step 4 (full test suite) passes and its clean-up commit (Step 5) is made.

4. **Correct your tenant's own manifest to match the new repository.**

   Open `infra/src/config/tenants/<your-alias>.psd1` and update at minimum:

   ```powershell
   $manifestPath = 'infra\src\config\tenants\<your-alias>.psd1'
   $content = Get-Content -Raw -LiteralPath $manifestPath
   $content = $content -replace "Owner = '[^']*'", "Owner = '<your-github-account-or-org>'"
   $content = $content -replace "Repository = '[^']*'", "Repository = '<your-repository-name>'"
   Set-Content -LiteralPath $manifestPath -Value $content -NoNewline
   ```

   `RepositoryId` cannot be corrected this way — it is the *new* repository's own immutable numeric ID, obtained live:

   ```powershell
   gh api repos/<your-account>/<your-repository> --jq '.id'
   ```

   Paste that value into the manifest's `GitHub.RepositoryId` field by hand, then re-run the Tenant 1 Blueprint Verification suite's pattern against your own manifest and evidence once your own discovery evidence exists (see Step 6).

   Commit this correction as its own commit, separate from the clean-up commit:

   ```powershell
   git add infra/src/config/tenants/<your-alias>.psd1
   git commit -m "chore: correct tenant manifest for new repository"
   ```

5. **Install the Azure Boards GitHub App, connected to your own Azure DevOps organization.**

   From `https://github.com/marketplace/azure-boards`, install and authorize the app against your new repository, then complete the Azure DevOps side by selecting **your own** organization and project — never a different tenant's. Full step-by-step detail (GitHub Marketplace install, organization access grant, third-party OAuth app policy) is in this platform's existing guidance for installing the Azure Boards app; the values are tenant-specific, the procedure is not.

6. **Verify the connection live.**

   ```powershell
   az login --tenant <your-tenant-id> --allow-no-subscriptions --use-device-code
   az rest --method get --uri "https://dev.azure.com/<your-org>/<your-project-id>/_apis/githubconnections?api-version=7.1-preview.1" --resource "499b84ac-1321-427f-aa17-267ca6975798"
   ```

   Expect `"count": 1` and `"isConnectionValid": true`, with a `gitHubRepositoryUrl` matching your new repository — the same live check this platform used to confirm Tenant 1's connection. Log out afterward:

   ```powershell
   az logout
   ```

7. **Run the full test suite one final time in the new repository, and record the result.**

   ```powershell
   Invoke-Pester -Path .github/cli/tests,infra/tests/pester -Output Detailed -CI
   ```

   Record the pass/fail count, the date, and your tenant alias in your own copy of this runbook's execution — for example as a dated entry appended to this file in your repository, or as a short note in your own repository's first pull request. This is the record Tenant 3's onboarding points to as evidence the runbook works, not merely that it exists.

## What This Runbook Does Not Do

| Not covered here | Where it lives instead |
|---|---|
| Removing other tenants' configuration and evidence | [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md) — referenced as Step 3 above, not duplicated |
| Activating your tenant's trust (Entra Application, Service Principal, Federated Identity Credential) | [Tenant Trust Activation Runbook](./20-tenant-trust-activation-runbook.md) |
| Populating your tenant's Azure Boards with HR use-case Epics | [Azure Boards Population Runbook](./21-azure-boards-population-runbook.md) |
| Choosing your account type (personal vs. GitHub Organization) | [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md) — must already be decided before Step 1 |

## Troubleshooting

- **Step 3's clean-up runbook lists a file for a tenant you don't recognize.** The source repository may have onboarded a tenant after this runbook was written. Do not remove it blindly — confirm with the source repository's own `infra/docs/18-multi-tenant-provisioning.md` Tenant Status table before proceeding.
- **Step 6's live check shows `"count": 0` after apparently completing Step 5.** The GitHub App installation and the Azure DevOps side's project/organization selection are two separate actions — confirm both were completed, not just the GitHub-side install. See the Repository Clean-Up Runbook's own Troubleshooting section for the equivalent pattern if the connection still will not register.
- **You are not sure whether you're looking at your own tenant's Azure DevOps organization or another tenant's.** Run `az account show` before any tenant-scoped command and confirm the authenticated tenant ID matches your own manifest's `TenantId` field exactly — never proceed on an assumption here.
```

- [ ] **Step 2: Verify the documentation metadata check passes**

Run:
```powershell
Import-Module .\.github\cli\modules\DocumentationMetadata.psm1 -Force
$content = [IO.File]::ReadAllText('infra\docs\23-customer-repository-export-and-handover-runbook.md')
$failures = @(Test-DocumentationMetadataContent -Content $content -DocumentRelativePath 'infra/docs/23-customer-repository-export-and-handover-runbook.md')
if ($failures.Count -eq 0) { 'OK' } else { $failures }
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```powershell
git add infra/docs/23-customer-repository-export-and-handover-runbook.md
git commit -m "docs(infra): add Customer Repository Export and Handover Runbook"
```

---

### Task 5: Cross-link and final verification pass

**Files:**
- Modify: `infra/docs/18-multi-tenant-provisioning.md`
- Modify: `docs/specs/2026-09-27-customer-repository-export-and-handover-design.md`

**Interfaces:**
- Consumes: `infra/docs/22-repository-cleanup-runbook.md` and `infra/docs/23-customer-repository-export-and-handover-runbook.md`, both now existing (Tasks 2 and 4) — this task only adds links to them, no new behavior.
- Produces: nothing new for later tasks — this is the plan's final task.

- [ ] **Step 1: Add forward references from `infra/docs/18-multi-tenant-provisioning.md` to both new runbooks**

Find the "Future Onboarding Sequence" section (numbered list, steps 1–11) and add a note immediately before it:

```markdown
For the concrete, tenant-agnostic procedure — not just the sequence below — see the [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md), which in turn uses the [Repository Clean-Up Runbook](./22-repository-cleanup-runbook.md).
```

- [ ] **Step 2: Resolve the spec's "Open Items" now that they are closed**

In `docs/specs/2026-09-27-customer-repository-export-and-handover-design.md`, replace the "Open Items" section's content with:

```markdown
## Open Items (resolved)

- Runbook numbering: assigned as `infra/docs/22-repository-cleanup-runbook.md` and `infra/docs/23-customer-repository-export-and-handover-runbook.md`.
- The Tenant 1 Blueprint Verification was folded into `infra/docs/18-multi-tenant-provisioning.md` (a new "Tenant 1 Blueprint Verification" section) plus a dedicated Pester suite (`infra/tests/pester/TenantBlueprintVerification.Tests.ps1`), rather than becoming a fourth standalone document.
- The Repository Clean-Up Runbook's artifact list is exhaustive as of 2026-09-27: tenant config manifests, discovery evidence files, and Bicep parameter files. No other tenant-scoped, removable file type exists in this repository today; `infra/src/scripts/Remove-OtherTenantArtifacts.ps1` checks all three defensively even though Bicep parameter files do not yet exist for any tenant.
```

- [ ] **Step 3: Run the complete test suite**

Run: `Invoke-Pester -Path .github/cli/tests,infra/tests/pester -Output Detailed -CI`
Expected: PASS — every suite green, including the two new ones added in Tasks 1 and 3.

- [ ] **Step 4: Run the documentation-metadata check across every file touched by this plan**

```powershell
Import-Module .\.github\cli\modules\DocumentationMetadata.psm1 -Force
$files = @(
    'infra/docs/18-multi-tenant-provisioning.md',
    'infra/docs/22-repository-cleanup-runbook.md',
    'infra/docs/23-customer-repository-export-and-handover-runbook.md',
    'docs/specs/2026-09-27-customer-repository-export-and-handover-design.md'
)
foreach ($f in $files) {
    $content = [IO.File]::ReadAllText(($f -replace '/','\'))
    $failures = @(Test-DocumentationMetadataContent -Content $content -DocumentRelativePath $f)
    if ($failures.Count -eq 0) { "OK: $f" } else { "FAIL: $f -> $($failures -join '; ')" }
}
```
Expected: `OK` for every file.

- [ ] **Step 5: Commit**

```powershell
git add infra/docs/18-multi-tenant-provisioning.md docs/specs/2026-09-27-customer-repository-export-and-handover-design.md
git commit -m "docs(infra): cross-link new runbooks and resolve spec open items"
```
