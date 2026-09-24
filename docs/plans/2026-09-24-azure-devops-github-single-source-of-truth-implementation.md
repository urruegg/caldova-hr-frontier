# Azure DevOps and GitHub Single Source of Truth Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Infrastructure (Tenant 1) |
| **References** | [Azure DevOps and GitHub Connection: Single Source of Truth for Source Code](../specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the one evidence gap the approved spec identified as automatable from source: today, Tenant 1's Azure DevOps discovery cannot tell whether the existing Azure Repos Git repository (`Caldova HR Frontier`) is empty or already holds pushed content, so the spec's "content unverified" gap remains open until this is fixed.

**Architecture:** Extend the existing `Get-AzureDevOpsDiscovery.ps1` private function in the `Caldova.HrFrontier.Bootstrap` PowerShell module to read two fields the Azure DevOps Git Repositories REST API already returns per repository (`size` in bytes, `defaultBranch`) and surface them as `Size`/`DefaultBranch` properties on each normalized `AzureDevOpsRepository` resource, exactly like every other field that function already extracts with `Get-DiscoveryPropertyValue`. No new REST call, no new module, no schema-wide change — `New-DiscoveryServiceResult` stores whatever resource objects it is given, so adding two properties to one resource type is additive and safe. `infra/docs/13-azure-devops-engineering-control-plane.md`'s Read-Only Discovery allowlist is updated to name the new field, since it already promised "default branches" without the code delivering them.

**Tech Stack:** PowerShell 5.1+, Pester 5.7.1, the existing `Caldova.HrFrontier.Bootstrap` module (`infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/`).

**Spec:** [`docs/specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md`](../specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md) — see its "Verification Plan" item 1.

## Global Constraints

- **No live Azure DevOps or GitHub configuration is created, modified, or deleted by this plan.** Everything here is read-only discovery normalization plus documentation; the spec's other gap-analysis rows (Azure Repos rename, Azure Boards GitHub App install, GitHub Environment creation, Pipelines service connection) are attended administrator actions and are explicitly out of scope.
- **No new REST call is added.** `size` and `defaultBranch` are already present in the existing `az devops invoke --area git --resource repositories` response; this plan only normalizes fields the code already receives.
- **`New-DiscoveryServiceResult` performs no schema filtering** (`infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-BoundedRetry.ps1:139-168`) — it stores `Resources` verbatim, so adding properties to one resource type cannot break other discovery services.
- Every markdown file created or rewritten carries the repository's required six-field documentation metadata table (`Version`/`Date`/`Author`/`Status`/`Scope`/`References`) immediately after its H1 — enforced by `.github/cli/modules/DocumentationMetadata.psm1`. `infra/docs/13-azure-devops-engineering-control-plane.md` already has this table; do not change it.
- The exact CI verification command for this area is: `Invoke-Pester -Path @('infra/tests/pester','hr/tests/pester') -Output Detailed -CI` (see `.github/workflows/validate-repository.yml:33-36`).

---

### Task 1: Capture Azure Repos repository size and default branch in discovery

**Files:**
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDevOpsDiscovery.ps1:199-206`
- Modify: `infra/tests/pester/DiscoveryNormalization.Tests.ps1` (insert a new `It` block immediately after the one titled `'requests and normalizes the required Azure DevOps discovery surfaces'`, which currently ends at line 1454)

**Interfaces:**
- Consumes: `Get-DiscoveryPropertyValue -InputObject <object> -Name <string>` (existing helper, `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-BoundedRetry.ps1:107-135`) — returns the named property's raw value or `$null` if absent.
- Produces: each `AzureDevOpsRepository` resource object gains two new properties, `Size` (`[int]`, `0` when the API omits `size`) and `DefaultBranch` (`[string]`, `''` when the API omits `defaultBranch`, which happens for a repository that has never received a push). No existing property name, resource `Type`, or function signature changes — this is purely additive.

- [ ] **Step 1: Write the failing test**

Open `infra/tests/pester/DiscoveryNormalization.Tests.ps1`. Find the `It` block that starts with:

```powershell
    It 'requests and normalizes the required Azure DevOps discovery surfaces' {
```

It ends at line 1454 with a closing `}` on its own line, immediately followed by a blank line and then the `Describe` block's closing content. Insert this new `It` block immediately after that closing `}` (keep the blank line separating the two `It` blocks):

```powershell
    It 'captures repository size and default branch, distinguishing an empty Azure Repos repository from a populated one' {
        $fixture = [pscustomobject]@{
            StatusCode = 200
            Headers = @{}
            Body = [ordered]@{
                reviewedUser = [pscustomobject]@{ id = 'ado-user-synthetic'; user = [pscustomobject]@{ descriptor = 'aad.synthetic-descriptor' } }
                project = [pscustomobject]@{ id = 'ado-project-synthetic-33333333-3333-3333-3333-333333333333'; name = 'Caldova HR Frontier'; url = 'https://dev.azure.com/caldova25156897/Caldova%20HR%20Frontier' }
                repositories = @(
                    [pscustomobject]@{ id = 'ado-repo-populated'; name = 'caldova-hr-frontier-config'; webUrl = 'https://dev.azure.com/caldova25156897/_git/caldova-hr-frontier-config'; size = 4096; defaultBranch = 'refs/heads/main' },
                    [pscustomobject]@{ id = 'ado-repo-empty'; name = 'Caldova HR Frontier'; webUrl = 'https://dev.azure.com/caldova25156897/_git/Caldova%20HR%20Frontier'; size = 0 }
                )
                serviceEndpoints = @()
                environments = @()
                pipelines = @()
                checks = @()
                effectivePermissions = @()
                projectUrl = 'https://dev.azure.com/caldova25156897/Caldova%20HR%20Frontier'
            }
        }

        $service = InModuleScope Caldova.HrFrontier.Bootstrap -Parameters @{
            TenantConfiguration = $script:TenantConfiguration
            RunId = $script:RunId
            CollectedUtc = $script:CollectedUtc
            Fixture = $fixture
        } {
            param($TenantConfiguration, $RunId, $CollectedUtc, $Fixture)
            Get-AzureDevOpsDiscovery -TenantConfiguration $TenantConfiguration -RunId $RunId -CollectedUtc $CollectedUtc -Request {
                param($Operation, $Arguments)
                $Fixture
            }
        }

        $repositories = @($service.Resources | Where-Object Type -eq 'AzureDevOpsRepository')
        $repositories.Count | Should -Be 2

        $populated = $repositories | Where-Object Id -eq 'ado-repo-populated'
        $populated.Size | Should -Be 4096
        $populated.DefaultBranch | Should -Be 'refs/heads/main'

        $empty = $repositories | Where-Object Id -eq 'ado-repo-empty'
        $empty.Size | Should -Be 0
        $empty.DefaultBranch | Should -Be ''
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/DiscoveryNormalization.Tests.ps1 -Output Detailed`
Expected: FAIL on the new test with an error such as `The property 'Size' cannot be found on this object` (the `AzureDevOpsRepository` resource does not yet carry `Size` or `DefaultBranch`). All other tests in the file still pass.

- [ ] **Step 3: Implement the minimal change**

Open `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDevOpsDiscovery.ps1`. Find this exact block (currently lines 189-207):

```powershell
    foreach ($item in @(ConvertTo-AzureDevOpsDiscoveryItems -Node (Get-DiscoveryPropertyValue -InputObject $body -Name 'repositories'))) {
        if ($null -eq $item) {
            continue
        }

        $repositoryId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($repositoryId)) {
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDevOpsRepository'
            Id = $repositoryId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            Url = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'webUrl')
            Scope = $organizationScope
            Status = 'Found'
        }
    }
```

Replace it with:

```powershell
    foreach ($item in @(ConvertTo-AzureDevOpsDiscoveryItems -Node (Get-DiscoveryPropertyValue -InputObject $body -Name 'repositories'))) {
        if ($null -eq $item) {
            continue
        }

        $repositoryId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($repositoryId)) {
            continue
        }

        $repositorySize = Get-DiscoveryPropertyValue -InputObject $item -Name 'size'
        $repositoryDefaultBranch = Get-DiscoveryPropertyValue -InputObject $item -Name 'defaultBranch'

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDevOpsRepository'
            Id = $repositoryId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            Url = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'webUrl')
            Scope = $organizationScope
            Status = 'Found'
            Size = if ($null -eq $repositorySize) { 0 } else { [int]$repositorySize }
            DefaultBranch = [string]$repositoryDefaultBranch
        }
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path infra/tests/pester/DiscoveryNormalization.Tests.ps1 -Output Detailed`
Expected: PASS — the new test and every pre-existing test in the file are green.

- [ ] **Step 5: Run the full infra and hr Pester suites (regression check)**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path @('infra/tests/pester','hr/tests/pester') -Output Detailed -CI`
Expected: PASS — 0 failed. This is the exact command `.github/workflows/validate-repository.yml` runs in CI, so a local pass here means CI will not regress.

- [ ] **Step 6: Commit**

```bash
git add infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDevOpsDiscovery.ps1 infra/tests/pester/DiscoveryNormalization.Tests.ps1
git commit -m "feat(infra): capture Azure Repos repository size and default branch in discovery"
```

---

### Task 2: Document the closed evidence gap

**Files:**
- Modify: `infra/docs/13-azure-devops-engineering-control-plane.md:44`

**Interfaces:**
- Consumes: nothing (documentation only).
- Produces: nothing consumed by later tasks — this is the last task in the plan.

- [ ] **Step 1: Update the Read-Only Discovery allowlist**

Open `infra/docs/13-azure-devops-engineering-control-plane.md`. Find this exact line in the "Read-Only Discovery" bulleted list:

```markdown
- repositories and default branches;
```

Replace it with:

```markdown
- repositories, default branches, and repository size in bytes — size distinguishes a repository that has never received a push (size `0`, no default branch) from one that already holds content;
```

- [ ] **Step 2: Verify the documentation metadata check still passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild`
Expected: PASS — the six-field metadata table in `infra/docs/13-azure-devops-engineering-control-plane.md` is unchanged, so the documentation metadata check has nothing new to flag.

- [ ] **Step 3: Commit**

```bash
git add infra/docs/13-azure-devops-engineering-control-plane.md
git commit -m "docs(infra): record repository size in the Azure DevOps discovery allowlist"
```

---

## Out of Scope (Attended Administrator Actions)

The following rows from the spec's gap analysis are **not** implementable from source and are not tasks in this plan. They require an attended Azure DevOps or GitHub administrator, are gated by this repository's existing bootstrap review discipline (`infra/docs/17-bootstrap-and-provisioning.md`, `infra/docs/19-bootstrap-recovery.md`), and should be tracked as separate, explicitly reviewed work when the organisation is ready to act on them:

- Renaming or repurposing the existing Azure Repos default repository to `caldova-hr-frontier-config`.
- Installing the Azure Boards GitHub App and authorizing the GitHub↔Azure DevOps connection.
- Creating the GitHub Environment `bootstrap-caldova25156897`.
- Creating an Azure Pipelines GitHub service connection (only relevant once the Power Platform promotion pipeline is designed).

After Task 1 and Task 2 land, re-running Tenant 1 discovery (an attended run, not part of this plan) will populate `Size`/`DefaultBranch` in `infra/evidence/discovery/caldova25156897.json` and finally answer whether the existing Azure Repos repository already holds content.
