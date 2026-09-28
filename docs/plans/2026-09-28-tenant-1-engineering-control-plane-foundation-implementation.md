# Tenant 1 Engineering Control Plane Foundation Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Tenant 1, Slice 1 Engineering Control Plane Foundation only |
| **References** | [Tenant 1 Engineering Platform Remediation Design](../specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md), [Tenant 1 Configuration Review](../reviews/2026-09-28-tenant-1-engineering-platform-configuration-review.md), [Tenant Trust Activation Plan](2026-09-24-tenant-trust-activation-runbook-implementation.md), [Azure Boards Population Plan](2026-09-25-azure-boards-population-implementation.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish and prove Tenant 1's Slice 1 engineering control plane: approved decisions, a tenant-private configuration boundary, bootstrap trust, governed GitHub, an Agile Azure Boards foundation, durable remediation work items, and one real `Fixes AB#` pull request.

**Architecture:** The public repository retains reusable source, closed schemas, and a neutral `tenant1` key. Tenant 1 private values move to the Azure Repo `caldova-hr-frontier-config`; the existing Tenant 2 manifest and discovery evidence remain as an explicit, hash-pinned transition exception until Slice 5. Interactive tooling receives an explicit local path, while trusted Tenant 1 workflows fetch hash-pinned files into `RUNNER_TEMP` with a short-lived Entra token. Existing trust, governance, bootstrap, discovery, and 19-HR-idea population components are extended rather than duplicated; new Azure Boards foundation and remediation-hierarchy scripts use the same deterministic plan-hash, one-mutation/read-back contract.

**Tech Stack:** Windows PowerShell 5.1, Pester 5.7.1, GitHub CLI, Azure CLI with the required commands present, installed `azure-devops` extension 1.0.8, Azure DevOps REST API 7.1, GitHub REST API `2022-11-28`, JSON Schema draft 2020-12, Git.

**Spec:** [`docs/specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md`](../specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md)

## Global Constraints

- Implement only Slice 1. Do not create an Azure Pipeline, service connection, variable group, secure file, managed artifact, Power Platform import, release environment, deployment, mirror, or repository synchronization.
- Preserve GitHub as the sole product source and Azure Boards as the sole durable backlog. The Azure Repo contains no product source.
- Use the neutral public key `tenant1`. A real tenant alias exists only in the private manifest and maps to `tenant1` through its mandatory `PublicTenantKey = 'tenant1'` field.
- Keep `infra/src/config/tenants/_template.psd1` as a synthetic safe example. Remove only the Tenant 1 real manifest and discovery file after private-repository API read-back proves every migrated byte and SHA-256 hash.
- Preserve the existing Tenant 2 manifest and discovery evidence as a temporary, hash-pinned transition exception. The only permitted content change is `PublicTenantKey = 'tenant2'`, required by the explicit-path importer. Do not copy them into Tenant 1's private Azure Repo, use them for Tenant 1 operations, or add another Tenant 2 private artifact. Slice 5 owns their destination handoff and later removal.
- Every real operation requires `-TenantConfigurationPath`; no command may infer a real path under `infra/src/config/tenants`.
- Trust activation is interactive and uses an explicit local private path because the OIDC trust required by workflow retrieval does not exist yet.
- Workflow retrieval occurs only after `azure/login`, uses the Azure DevOps resource audience `499b84ac-1321-427f-aa17-267ca6975798`, writes only below `RUNNER_TEMP`, validates SHA-256 and schema, and never prints, uploads, caches, or commits private content.
- Use Entra/Azure DevOps authentication only. Do not accept, request, read, or document a PAT.
- Every live mutation follows context, stable-ID resolution, pre-state hash, deterministic plan, zero-mutation `WhatIf`, exact plan-hash approval, precondition reread, one mutation, complete read-back, and stop-on-mismatch.
- Preserve `403`, `404`, ambiguity, timeout/indeterminate, and unsupported capability as distinct errors. None means an empty collection or permission to create.
- Do not install dependencies proactively. Run the selected validation command first; install Pester 5.7.1 only when that command proves it absent. The Azure DevOps extension is already installed and its local help is the command contract.
- Use Windows PowerShell 5.1 syntax. Do not use `&&`, `||`, null-coalescing operators, PowerShell 7-only JSON switches, or Unix paths.
- All execution commits are scoped, reviewed commits. Every commit command in this plan includes `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Do not edit `.github/skills/`. Preserve unrelated worktree changes.
- ADR approval is attended. Until Task 1 merges, ADR-0001, ADR-0002, and ADR-0012 remain `Proposed Baseline`.
- `Initialize-AzureDevOpsWorkItems.ps1` retains its separate behavior: exactly 19 HR-idea Epics and no children. Slice 1 remediation hierarchy uses a new desired-state file and script.
- A Basic-to-Agile process change uses Microsoft's attended organization-settings procedure, not an invented CLI or REST endpoint. Automation inventories, blocks unsafe conversion, emits the approved plan, and verifies the operator's supported UI change before continuing.

## Locked Integration Contracts

### Public/private mapping and exact private paths

The public catalogue is `infra/src/config/tenants/catalog.json`:

```json
{
  "$schema": "../schemas/tenant-catalog.schema.json",
  "schemaVersion": "1.0",
  "tenants": [
    {
      "key": "tenant1",
      "githubEnvironment": "bootstrap-tenant1",
      "configurationPath": "config/tenants/tenant1.psd1",
      "discoveryEvidencePath": "evidence/discovery/tenant1.json"
    }
  ]
}
```

The private manifest at `config/tenants/tenant1.psd1` contains both `PublicTenantKey = 'tenant1'` and the private `TenantAlias`. `Import-TenantConfiguration` requires `PublicTenantKey`, validates `GitHub.EnvironmentName = "bootstrap-$PublicTenantKey"`, and returns the private alias to scripts only after schema validation. That is the only public-key/private-alias mapping.

The private repository contains exactly:

```text
private-repository.manifest.json
config/tenants/tenant1.psd1
templates/README.md
runbooks/README.md
schemas/tenant.schema.json
schemas/private-repository-manifest.schema.json
schemas/private-repository-readback.schema.json
evidence/discovery/tenant1.json
```

Future files may be added only by changing the closed manifest schema and reviewing the change. `templates/` and `runbooks/` begin with boundary documents, not pipeline or product content.

Protected Environment variables provide workflow fetch inputs:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
AZURE_DEVOPS_ORGANIZATION_URL
AZURE_DEVOPS_PROJECT_ID
AZURE_DEVOPS_CONFIG_REPOSITORY_ID
AZURE_DEVOPS_CONFIG_REF
TENANT_CONFIGURATION_PATH
TENANT_CONFIGURATION_SHA256
TENANT_DISCOVERY_EVIDENCE_PATH
TENANT_DISCOVERY_EVIDENCE_SHA256
```

`AZURE_DEVOPS_CONFIG_REF` is exactly `refs/heads/main`; the two paths equal the catalogue values. Values are non-secret but protected by the `bootstrap-tenant1` Environment. Tokens are never Environment values.

### New executable interfaces

```powershell
# Get-TenantPrivateConfiguration.ps1
param(
    [Parameter(Mandatory)] [ValidatePattern('^tenant[1-9][0-9]*$')] [string]$PublicTenantKey,
    [Parameter(Mandatory)] [string]$OutputDirectory,
    [switch]$IncludeDiscoveryEvidence,
    [Parameter(DontShow)] [scriptblock]$AzureDevOpsRequest
)

# New-TenantPrivateConfigurationPackage.ps1
param(
    [Parameter(Mandatory)] [ValidatePattern('^tenant[1-9][0-9]*$')] [string]$PublicTenantKey,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$TenantConfigurationPath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$DiscoveryEvidencePath,
    [Parameter(Mandatory)] [string]$OutputDirectory,
    [switch]$Replace
)

# Initialize-TenantPrivateConfigurationRepository.ps1
param(
    [Parameter(Mandatory)] [ValidatePattern('^tenant[1-9][0-9]*$')] [string]$PublicTenantKey,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$TenantConfigurationPath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })] [string]$PackagePath,
    [Parameter(Mandatory)] [string]$PlanOutputPath,
    [Parameter(Mandatory)] [string]$ReadBackOutputPath,
    [ValidatePattern('^[0-9a-f]{64}$')] [string]$ApprovedPlanHash,
    [Parameter(DontShow)] [scriptblock]$AzureDevOpsRequest,
    [Parameter(DontShow)] [scriptblock]$NativeCommandRunner
)

# Initialize-AzureDevOpsBoardsFoundation.ps1
param(
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$TenantConfigurationPath,
    [Parameter(Mandatory)] [datetime]$FirstIterationStartDate,
    [Parameter(Mandatory)] [string]$PlanOutputPath,
    [ValidatePattern('^[0-9a-f]{64}$')] [string]$ApprovedPlanHash,
    [Parameter(DontShow)] [scriptblock]$AzureDevOpsRequest,
    [Parameter(DontShow)] [scriptblock]$NativeCommandRunner
)

# Initialize-EngineeringPlatformWorkItems.ps1
param(
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$TenantConfigurationPath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$DesiredStatePath,
    [Parameter(Mandatory)] [string]$FirstIterationPath,
    [Parameter(Mandatory)] [string]$PlanOutputPath,
    [ValidatePattern('^[0-9a-f]{64}$')] [string]$ApprovedPlanHash,
    [Parameter(DontShow)] [scriptblock]$AzureDevOpsRequest,
    [Parameter(DontShow)] [scriptblock]$NativeCommandRunner
)
```

All three mutating initializers use `SupportsShouldProcess`, return a plan object from `-WhatIf`, require `-ApprovedPlanHash` for a non-`WhatIf` run, recompute the canonical plan immediately before every mutation, mutate one item, read it back completely, and stop before the next item on mismatch.

The package generator is invoked only for `tenant1`. Slice 1 records the post-contract hashes of the retained Tenant 2 manifest and discovery evidence, then verifies that no later Slice 1 task changes them. No Tenant 2 package, repository, seed, synchronization, or custody export is created in this slice.

### Execution and merge boundary

Tasks 1-11 are implemented on one linear execution branch created from current `origin/main`. The reviewed branch SHA is used for private-repository migration and interactive trust activation. Checkpoint B deletes only Tenant 1 public private-state files after private API byte/hash read-back succeeds; Checkpoint C then proves trust with the explicit local private paths, without depending on the deleted public copies. The branch is revalidated after both checkpoints and merged. Successful current-`main` `Repository setup validation` and `Validate tenant bootstrap` runs are then mandatory inputs to `Enable-GitHubGovernance`. Protection is activated only after those current-main runs. Checkpoint F uses Task 12's second, real governed branch and the durable traceability User Story.

---

### Task 1: Wave 0 ADR reconciliation and documentation catalogues

**Files:**
- Modify: `docs/adr/0001-azure-devops-as-engineering-control-plane.md`
- Modify: `docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md`
- Modify: `docs/adr/0012-per-tenant-github-repository-and-account-topology.md`
- Modify: `docs/adr/README.md`
- Modify: `docs/README.md`
- Modify: `infra/README.md`
- Modify: `infra/docs/13-azure-devops-engineering-control-plane.md`
- Modify: `infra/docs/14-github-repository-blueprint.md`
- Modify: `infra/docs/17-bootstrap-and-provisioning.md`
- Modify: `infra/docs/18-multi-tenant-provisioning.md`
- Modify: `README.md`
- Create: `infra/tests/pester/EngineeringControlPlaneDocumentation.Tests.ps1`
- Test: `.github/cli/tests/DocumentationMetadata.Tests.ps1`
- Test: `.github/cli/tests/DocumentationLinks.Tests.ps1`

**Interfaces:**
- Consumes: approved remediation spec and attended Wave 0 decision record.
- Produces: three internally consistent `Approved` ADRs; one-repository/one-project/one-private-config-repo topology; catalogue and narrative references used by every later task.

- [ ] **Step 1: Write the failing Wave 0 contract**

```powershell
Describe 'Engineering control plane documentation' {
    BeforeAll {
        $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:AdrPaths = @(
            'docs\adr\0001-azure-devops-as-engineering-control-plane.md'
            'docs\adr\0002-github-first-bootstrap-and-the-role-of-azure-repos.md'
            'docs\adr\0012-per-tenant-github-repository-and-account-topology.md'
        )
    }

    It 'records all three Wave 0 decisions as Approved and links the remediation design' {
        foreach ($relativePath in $script:AdrPaths) {
            $content = Get-Content -Raw (Join-Path $script:Root $relativePath)
            $content | Should -Match '\|\s+\*\*Status\*\*\s+\|\s+Approved\s+\|'
            $content | Should -Match '2026-09-28-tenant-1-engineering-platform-remediation-design\.md'
        }
    }

    It 'defines no initial mirror synchronization or shared product source' {
        $adr2 = Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[1])
        $adr2 | Should -Match 'contains no product source'
        $adr2 | Should -Match 'no.+initial disaster-recovery mirror'
    }
}
```

- [ ] **Step 2: Run the Wave 0 contract red**

```powershell
Invoke-Pester -Path infra\tests\pester\EngineeringControlPlaneDocumentation.Tests.ps1 -Output Detailed -CI
```

Expected: the status and approved-boundary assertions fail against the current Proposed Baseline ADRs.

- [ ] **Step 3: Record the attended decision before editing status**

Create the review record section in each ADR with this exact shape, using the actual meeting record URL or repository-relative evidence link selected by the architecture decision owner:

```markdown
## Attended Decision

Approved on 2026-09-28 for the Tenant 1 remediation baseline defined by
[Tenant 1 Engineering Platform Remediation Design](../specs/2026-09-28-tenant-1-engineering-platform-remediation-design.md).
Acceptance establishes one tenant-dedicated GitHub product-source repository, one Azure DevOps project and Boards backlog,
and one tenant-private Azure Repo named `caldova-hr-frontier-config`. It does not approve a shared source repository,
an initial mirror, synchronization, or a live mutation whose reviewed plan hash has changed.
```

Set each metadata table to `Version 2.0`, `Date 2026-09-28`, and `Status Approved`. Replace “Proposed Decision” headings with “Decision” and remove sentences that say the record is still a candidate.

- [ ] **Step 4: Reconcile the Azure Repo role**

In ADR-0002, replace the optional-mirror language with this binding decision:

```markdown
The private Azure Repo contains only tenant-private configuration, governed templates, operational runbooks,
configuration schemas, and sanitized evidence. It contains no product source, credential, unrestricted membership export,
bidirectional synchronization, or initial disaster-recovery mirror. A mirror requires a future ADR and is not implicit in this decision.
```

Expected: ADR-0001 names Azure Boards as the single backlog and GitHub as sole product source; ADR-0002 defines the private boundary; ADR-0012 defines one repository and Azure DevOps project per tenant.

- [ ] **Step 5: Update catalogues and affected narratives**

Change the ADR catalogue rows for 0001, 0002, and 0012 to `Approved`; update its explanatory paragraph. In the listed infrastructure and root documents, replace shared-repository, committed-real-manifest, `bootstrap-${tenantAlias}`, pilot-self-review, optional-mirror, and proposed-control language with `tenant1`, `bootstrap-tenant1`, private-path, no-self-review, and no-mirror contracts.

- [ ] **Step 6: Run documentation contracts green**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
  'infra\tests\pester\EngineeringControlPlaneDocumentation.Tests.ps1'
  '.github\cli\tests\DocumentationMetadata.Tests.ps1'
  '.github\cli\tests\DocumentationLinks.Tests.ps1'
) -Output Detailed -CI
```

Expected: both suites pass; every modified maintained document has the six-field metadata table and every relative link resolves. If `Import-Module` reports Pester 5.7.1 missing, install that exact version and rerun; do not install anything otherwise.

- [ ] **Step 7: Commit the Wave 0 slice**

```powershell
git add docs\adr docs\README.md infra\README.md infra\docs\13-azure-devops-engineering-control-plane.md infra\docs\14-github-repository-blueprint.md infra\docs\17-bootstrap-and-provisioning.md infra\docs\18-multi-tenant-provisioning.md infra\tests\pester\EngineeringControlPlaneDocumentation.Tests.ps1 README.md
git commit -m "docs(architecture): accept Tenant 1 control plane topology" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: one documentation-only commit. Do not describe the ADRs as approved until the attended decision owner has approved this exact diff.

### Task 2: Public catalogue and mandatory private configuration contract

**Files:**
- Create: `infra/src/config/schemas/tenant-catalog.schema.json`
- Create: `infra/src/config/schemas/legacy-tenant-transition.schema.json`
- Create: `infra/src/config/tenants/catalog.json`
- Create: `infra/src/config/tenants/legacy-transition.json`
- Modify: `infra/src/config/schemas/tenant.schema.json`
- Modify: `infra/src/config/tenants/_template.psd1`
- Modify/Delete: the current Tenant 1 manifest path resolved and recorded in private pre-state
- Modify: the Tenant 2 transition manifest path resolved from `infra/src/config/tenants/legacy-transition.json`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-TenantConfiguration.ps1`
- Modify: `infra/src/scripts/Initialize-TenantTrust.ps1`
- Modify: `infra/src/scripts/Invoke-TenantDiscovery.ps1`
- Modify: `infra/src/scripts/Invoke-TenantBootstrap.ps1`
- Modify: `infra/src/scripts/Grant-TemporaryBootstrapRoles.ps1`
- Modify: `infra/src/scripts/Get-TemporaryBootstrapRoleState.ps1`
- Modify: `infra/src/scripts/New-TenantBicepParameters.ps1`
- Modify: `infra/src/scripts/New-TenantManifest.ps1`
- Modify: `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`
- Modify: `infra/src/scripts/Remove-OtherTenantArtifacts.ps1`
- Modify: `infra/src/scripts/runbooks/Get-CloudFoundationPlan.ps1`
- Modify: `infra/src/scripts/runbooks/Invoke-CloudFoundation.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerExportAssessment.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-CustomerSourceMarkerCatalog.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-CustomerExportManifest.ps1`
- Modify: `hr/src/scripts/Connect-PowerPlatformEnvironment.ps1`
- Modify: `hr/src/scripts/Sync-HrSolutionSource.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Get-HrTenantPowerPlatformUrl.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Connect-HrPowerPlatformEnvironment.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Export-HrSolutionPackage.ps1`
- Modify: `infra/tests/pester/TenantConfiguration.Tests.ps1`
- Modify: `infra/tests/pester/DiscoveryNormalization.Tests.ps1`
- Modify: `infra/tests/pester/BicepComposition.Tests.ps1`
- Modify: `infra/tests/pester/AzureBoardsPopulation.Tests.ps1`
- Modify: `infra/tests/pester/CloudFoundationInvocation.Tests.ps1`
- Modify: `infra/tests/pester/CloudFoundationPlanning.Tests.ps1`
- Modify: `infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1`
- Modify: `infra/tests/pester/CustomerExportIsolation.Tests.ps1`
- Modify: `infra/tests/pester/CustomerRepositoryExport.Tests.ps1`
- Modify: `infra/tests/pester/Idempotency.Tests.ps1`
- Modify: `infra/tests/pester/Naming.Tests.ps1`
- Modify: `infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1`
- Modify: `infra/tests/pester/SharePointDiscovery.Tests.ps1`
- Modify: `infra/tests/pester/TenantBlueprintVerification.Tests.ps1`
- Modify: `hr/tests/pester/SolutionLifecycle.Tests.ps1`
- Modify: every tracked repository-owned source, fixture, workflow, and maintained document returned by the exact Tenant 1 data inventory in Step 5
- Modify: `infra/docs/10-tenant-setup-and-configuration.md`
- Modify: `infra/docs/19-bootstrap-recovery.md`
- Modify: `infra/docs/runbooks/02-cloud-service-foundation.md`
- Modify: `infra/docs/runbooks/03-customer-handover.md`
- Modify: `hr/src/scripts/README.md`

**Interfaces:**
- Consumes: public `tenant1` key and explicit private `.psd1` path.
- Produces: `Import-TenantConfiguration -Path $path -ValidationStage Bootstrap -ExpectedPublicTenantKey 'tenant1'`; every real entry point has mandatory `[string]$TenantConfigurationPath`; `New-TenantManifest` writes only to an explicit path outside the repository.

- [ ] **Step 1: Write failing public/private boundary tests**

Add these tests to `TenantConfiguration.Tests.ps1`:

```powershell
It 'publishes only the neutral tenant1 catalogue entry' {
    $catalog = Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\config\tenants\catalog.json') | ConvertFrom-Json
    @($catalog.tenants).Count | Should -Be 1
    $catalog.tenants[0].key | Should -BeExactly 'tenant1'
    $catalog.tenants[0].githubEnvironment | Should -BeExactly 'bootstrap-tenant1'
    ($catalog | ConvertTo-Json -Depth 20) | Should -Not -Match 'caldova\d|onmicrosoft\.com|crm\d*\.dynamics\.com|dev\.azure\.com'
}

It 'requires the private manifest public key to match the selected public key' {
    $path = New-FixtureTenantConfiguration -PublicTenantKey 'tenant1' -TenantAlias 'privatealias1'
    { Import-TenantConfiguration -Path $path -ValidationStage Bootstrap -ExpectedPublicTenantKey 'tenant2' } |
        Should -Throw '*PublicTenantKey*tenant2*'
}

It 'pins exactly the two approved Tenant 2 transition files' {
    $transition = Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\config\tenants\legacy-transition.json') |
        ConvertFrom-Json
    @($transition.files).Count | Should -Be 2
    @($transition.files.path | Where-Object { $_ -match '^infra/src/config/tenants/[a-z][a-z0-9]+\.psd1$' }).Count | Should -Be 1
    @($transition.files.path | Where-Object { $_ -match '^infra/evidence/discovery/[a-z][a-z0-9]+\.json$' }).Count | Should -Be 1
    foreach ($file in $transition.files) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $script:RepositoryRoot $file.path) -Algorithm SHA256).Hash.ToLowerInvariant()
        $actual | Should -BeExactly $file.sha256
    }
}
```

For each real entry-point suite, add a named test `requires an explicit TenantConfigurationPath for real operations` that invokes the script without that parameter and expects PowerShell parameter binding to fail before any adapter call.

- [ ] **Step 2: Run the focused tests red**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\TenantConfiguration.Tests.ps1'
  'infra\tests\pester\AzureBoardsPopulation.Tests.ps1'
  'infra\tests\pester\DiscoveryNormalization.Tests.ps1'
  'infra\tests\pester\BicepComposition.Tests.ps1'
  'infra\tests\pester\CloudFoundationInvocation.Tests.ps1'
  'infra\tests\pester\CloudFoundationPlanning.Tests.ps1'
  'infra\tests\pester\CloudFoundationStaticSafety.Tests.ps1'
  'infra\tests\pester\CustomerExportIsolation.Tests.ps1'
  'infra\tests\pester\CustomerRepositoryExport.Tests.ps1'
  'infra\tests\pester\Idempotency.Tests.ps1'
  'infra\tests\pester\Naming.Tests.ps1'
  'infra\tests\pester\RemoveOtherTenantArtifacts.Tests.ps1'
  'infra\tests\pester\SharePointDiscovery.Tests.ps1'
  'infra\tests\pester\TenantBlueprintVerification.Tests.ps1'
  'hr\tests\pester\SolutionLifecycle.Tests.ps1'
) -Output Detailed -CI
```

Expected: failures report absent `catalog.json`, absent `PublicTenantKey`, and optional configuration-path parameters.

- [ ] **Step 3: Add the closed public catalogue schema and data**

Use this complete schema core:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": ["$schema", "schemaVersion", "tenants"],
  "properties": {
    "$schema": { "const": "../schemas/tenant-catalog.schema.json" },
    "schemaVersion": { "const": "1.0" },
    "tenants": {
      "type": "array",
      "minItems": 1,
      "maxItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["key", "githubEnvironment", "configurationPath", "discoveryEvidencePath"],
        "properties": {
          "key": { "const": "tenant1" },
          "githubEnvironment": { "const": "bootstrap-tenant1" },
          "configurationPath": { "const": "config/tenants/tenant1.psd1" },
          "discoveryEvidencePath": { "const": "evidence/discovery/tenant1.json" }
        }
      }
    }
  }
}
```

Create `catalog.json` exactly as shown in Locked Integration Contracts. Add mandatory `PublicTenantKey` with pattern `^tenant[1-9][0-9]*$` to `tenant.schema.json`, and add `PublicTenantKey = 'tenant1'` to `_template.psd1` while keeping every other value synthetic.

Create `legacy-transition.json` under the closed `legacy-tenant-transition.schema.json`. It contains exactly two entries:

```json
{
  "$schema": "../schemas/legacy-tenant-transition.schema.json",
  "schemaVersion": "1.0",
  "ownerSlice": 5,
  "files": [
    {
      "path": "infra/src/config/tenants/legacy00000000.psd1",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    },
    {
      "path": "infra/evidence/discovery/legacy00000000.json",
      "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    }
  ]
}
```

The displayed names are synthetic examples. The implementation discovers the two existing Tenant 2 paths from the reviewed pre-state, writes those exact paths to `legacy-transition.json`, and replaces the example hashes with hashes computed after adding only `PublicTenantKey = 'tenant2'` to the Tenant 2 manifest. The schema fixes `ownerSlice` to `5`, requires exactly one tenant-manifest path and one discovery-evidence path, and requires lowercase SHA-256. Repository validation fails if either file is absent, changed, joined by another real tenant file, or referenced as Tenant 1 configuration.

- [ ] **Step 4: Make import validation explicit**

Change the public function signature and derivation:

```powershell
function Import-TenantConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Path,
        [ValidateSet('Discovery', 'Bootstrap')] [string]$ValidationStage = 'Discovery',
        [Parameter(Mandatory)] [ValidatePattern('^tenant[1-9][0-9]*$')] [string]$ExpectedPublicTenantKey
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $configuration = Import-PowerShellDataFile -LiteralPath $resolvedPath
    Assert-SchemaValue -Value $configuration -Schema (Get-TenantSchema) -Path 'Configuration'
    if ([string]$configuration.PublicTenantKey -cne $ExpectedPublicTenantKey) {
        throw "Configuration.PublicTenantKey must equal '$ExpectedPublicTenantKey'."
    }
    Assert-TenantConfigurationContract -Configuration $configuration -ValidationStage $ValidationStage
    ConvertTo-ReadOnlyValue -Value $configuration
}
```

In `Assert-TenantConfigurationContract`, derive the Environment from `PublicTenantKey`, remove both hard-coded Tenant 2 branches, and validate SharePoint structurally without embedding real URLs:

```powershell
$expectedEnvironmentName = 'bootstrap-{0}' -f $Configuration.PublicTenantKey
if ($Configuration.GitHub.EnvironmentName -cne $expectedEnvironmentName) {
    throw 'GitHub.EnvironmentName must be derived from PublicTenantKey.'
}
```

- [ ] **Step 5: Make every real caller require and forward the path**

Use this parameter pair consistently:

```powershell
[Parameter(Mandatory)]
[ValidatePattern('^tenant[1-9][0-9]*$')]
[string]$PublicTenantKey,

[Parameter(Mandatory)]
[ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
[string]$TenantConfigurationPath
```

Delete every `Get-DefaultTenantConfigurationPath` function and every fallback to `infra\src\config\tenants\$TenantAlias.psd1`. Load with:

```powershell
$configuration = Import-TenantConfiguration `
    -Path ([System.IO.Path]::GetFullPath($TenantConfigurationPath)) `
    -ValidationStage Bootstrap `
    -ExpectedPublicTenantKey $PublicTenantKey
$tenantAlias = [string]$configuration.TenantAlias
```

Before packaging, add `PublicTenantKey = 'tenant1'` to the full Tenant 1 manifest and `PublicTenantKey = 'tenant2'` to the retained Tenant 2 manifest; do not change any other Tenant 2 value. Only the Tenant 1 full manifest moves out of the public repository during Checkpoint B. Record reviewed SHA-256 hashes for the retained Tenant 2 manifest and discovery evidence after this contract update.

The HR module and the existing 19-HR-idea script use the same explicit path and compare any supplied private alias with the imported value. `Initialize-AzureDevOpsWorkItems.ps1` derives organization and project from the private manifest but otherwise preserves its exact 19-Epic behavior. Customer-export and tenant-removal helpers receive explicit private paths or the safe catalogue and retain their existing export/seeding scope; this task does not execute that later slice. `New-TenantManifest.ps1` gains mandatory `-PublicTenantKey` and `-OutputPath`; it rejects any output path under the repository root and never writes into `infra/src/config/tenants`.

Generate the exact Tenant 1 occurrence inventory with:

```powershell
$inventoryPath = Join-Path $env:TEMP 'tenant1-public-occurrences.txt'
git grep -l -I -E 'caldova[0-9]{8}|onmicrosoft\.com|crm[0-9]*\.dynamics\.com|https://dev\.azure\.com/[a-z0-9]+/' -- `
  . ':(exclude).github/skills/**' |
  Set-Content -LiteralPath $inventoryPath -Encoding UTF8
```

Classify every path in that inventory as `SyntheticFixture`, `TransitionException`, `RewriteToPublicKey`, `MoveToPrivateRepo`, or `HistoricalDocumentRedaction`. The classification is reviewed outside Git before edits. Replace real Tenant 1 values in fixtures with deterministic synthetic values; update maintained documentation and workflows to `tenant1` and protected-variable terminology; redact historical implementation documents without changing their decision meaning. Do not suppress a match by adding a broad path exception.

- [ ] **Step 6: Run focused tests green**

Repeat Step 2. Expected: every selected test passes; fixtures use synthetic private aliases and explicit fixture paths; no test reads a real Tenant 1 checked-in manifest.

- [ ] **Step 7: Commit the configuration contract**

```powershell
git add infra\src\config infra\src\scripts infra\tests\pester infra\docs\10-tenant-setup-and-configuration.md infra\docs\19-bootstrap-recovery.md infra\docs\runbooks\02-cloud-service-foundation.md infra\docs\runbooks\03-customer-handover.md hr\src\scripts hr\tests\pester
git commit -m "refactor(config): enforce tenant-private manifest paths" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 3: Tenant-private Azure Repo package, desired state, and atomic initialization

**Files:**
- Create: `infra/src/config/schemas/private-repository-manifest.schema.json`
- Create: `infra/src/config/schemas/private-repository-readback.schema.json`
- Create: `infra/src/config/schemas/tenant-private-repository.schema.json`
- Create: `infra/src/config/azure-devops/tenant-private-repository.json`
- Create: `infra/src/scripts/New-TenantPrivateConfigurationPackage.ps1`
- Create: `infra/src/scripts/Initialize-TenantPrivateConfigurationRepository.ps1`
- Create: `infra/tests/pester/TenantPrivateConfigurationPackage.Tests.ps1`
- Create: `infra/tests/pester/TenantPrivateConfigurationRepository.Tests.ps1`

**Interfaces:**
- Consumes: explicit full private manifest and discovery paths; safe desired state; Azure DevOps Entra access token.
- Produces: outside-Git migration package; canonical plan with `PlanHash`; rename of the one empty repository; one atomic initial Git REST push; exact item/hash read-back.

- [ ] **Step 1: Write failing package-layout and forbidden-content tests**

```powershell
It 'creates only the closed private repository layout' {
    & $script:PackageScript -PublicTenantKey tenant1 -TenantConfigurationPath $manifest `
        -DiscoveryEvidencePath $evidence -OutputDirectory $output
    $relative = @(Get-ChildItem $output -Recurse -File | ForEach-Object {
        $_.FullName.Substring($output.Length).TrimStart('\') -replace '\\','/'
    } | Sort-Object)
    $relative | Should -Be @(
        'config/tenants/tenant1.psd1',
        'evidence/discovery/tenant1.json',
        'private-repository.manifest.json',
        'runbooks/README.md',
        'schemas/private-repository-manifest.schema.json',
        'schemas/private-repository-readback.schema.json',
        'schemas/tenant.schema.json',
        'templates/README.md'
    )
}

It 'rejects a package whose private manifest does not match tenant1' {
    { & $script:PackageScript -PublicTenantKey tenant1 -TenantConfigurationPath $tenant2Manifest `
        -DiscoveryEvidencePath $tenant2Evidence -OutputDirectory $tenant2Output } |
        Should -Throw '*PublicTenantKey*tenant1*'
}

It 'rejects product source credentials mirrors and synchronization material' -ForEach @(
    'src/product/file.txt', 'config/client-secret.txt', '.git/config', 'mirror/main.bundle', 'sync/repository.yml'
) {
    $forbidden = Join-Path $packageRoot $_
    New-Item -ItemType Directory -Path (Split-Path $forbidden) -Force | Out-Null
    Set-Content -LiteralPath $forbidden -Value 'fixture'
    { & $script:InitializeScript -PublicTenantKey tenant1 -TenantConfigurationPath $manifest `
        -PackagePath $packageRoot -PlanOutputPath $plan -WhatIf -AzureDevOpsRequest $request } |
        Should -Throw '*closed private repository layout*'
}
```

- [ ] **Step 2: Run the new tests red**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\TenantPrivateConfigurationPackage.Tests.ps1'
  'infra\tests\pester\TenantPrivateConfigurationRepository.Tests.ps1'
) -Output Detailed -CI
```

Expected: both scripts are missing.

- [ ] **Step 3: Define desired state and manifest shape**

`tenant-private-repository.json`:

```json
{
  "$schema": "../schemas/tenant-private-repository.schema.json",
  "schemaVersion": "1.0",
  "publicTenantKey": "tenant1",
  "repositoryName": "caldova-hr-frontier-config",
  "defaultBranch": "refs/heads/main",
  "allowedRoots": ["config", "templates", "runbooks", "schemas", "evidence"],
  "prohibitedContent": ["product-source", "credential", "membership-export", "mirror", "synchronization"]
}
```

`tenant-private-repository.schema.json` closes and types the public desired-state fields above. The package's `private-repository.manifest.json` uses `private-repository-manifest.schema.json` and this closed `files` array:

```json
{
  "schemaVersion": "1.0",
  "publicTenantKey": "tenant1",
  "repositoryName": "caldova-hr-frontier-config",
  "defaultBranch": "refs/heads/main",
  "files": [
    { "path": "config/tenants/tenant1.psd1", "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "classification": "tenant-private" },
    { "path": "evidence/discovery/tenant1.json", "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "classification": "sanitized-evidence" },
    { "path": "runbooks/README.md", "sha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "classification": "operational-runbook" },
    { "path": "schemas/private-repository-manifest.schema.json", "sha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd", "classification": "schema" },
    { "path": "schemas/private-repository-readback.schema.json", "sha256": "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", "classification": "schema" },
    { "path": "schemas/tenant.schema.json", "sha256": "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", "classification": "schema" },
    { "path": "templates/README.md", "sha256": "1111111111111111111111111111111111111111111111111111111111111111", "classification": "governed-template" }
  ]
}
```

The implementation fills the hash from the bytes; the schema requires `^[0-9a-f]{64}$` and classification enum `tenant-private|governed-template|operational-runbook|schema|sanitized-evidence`.

- [ ] **Step 4: Implement package generation outside Git**

Use an allowlisted file table, copy bytes, calculate SHA-256 with `Get-FileHash`, and reject an output under `Get-RepositoryRoot`:

```powershell
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..')).TrimEnd('\') + '\'
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd('\') + '\'
if ($resolvedOutput.StartsWith($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Private migration packages must be generated outside the Git working tree.'
}
```

Write files through a sibling staging directory, validate the complete staged inventory, then rename the staging directory to `OutputDirectory`. On failure, delete staging and leave an existing destination unchanged.

- [ ] **Step 5: Implement deterministic plan and exact preconditions**

The `WhatIf` plan has this exact top-level shape:

```json
{
  "schemaVersion": "1.0",
  "publicTenantKey": "tenant1",
  "repositoryId": "11111111-1111-1111-1111-111111111111",
  "preStateHash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "packageHash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "operations": [
    {
      "order": 1,
      "operation": "RenameRepository",
      "expected": { "size": 0, "defaultBranch": null },
      "postcondition": { "name": "caldova-hr-frontier-config" }
    },
    {
      "order": 2,
      "operation": "CreateInitialCommit",
      "expected": { "oldObjectId": "0000000000000000000000000000000000000000" },
      "postcondition": { "ref": "refs/heads/main", "treeHash": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc" }
    }
  ],
  "planHash": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
}
```

Resolve exactly one project repository. Block unless it has `size = 0`, a null/empty default branch, no refs, and no items. Block a duplicate target name. Compute canonical JSON with ordered properties and hash UTF-8 bytes.

- [ ] **Step 6: Implement one mutation followed by read-back**

Rename with the locally verified CLI signature:

```powershell
az repos update --repository $repositoryId --name caldova-hr-frontier-config `
  --organization $configuration.AzureDevOps.OrganizationUrl `
  --project $configuration.AzureDevOps.ProjectName --output json --only-show-errors
```

Read the repository immediately and require stable ID, exact name, still-empty size, and no default branch. Then create one initial commit with the documented endpoint:

```powershell
$pushUri = '{0}{1}/_apis/git/repositories/{2}/pushes?api-version=7.1' -f `
    $configuration.AzureDevOps.OrganizationUrl,
    [uri]::EscapeDataString([string]$projectId),
    [uri]::EscapeDataString([string]$repositoryId)
```

Use `refUpdates = [{ name = 'refs/heads/main'; oldObjectId = '0000000000000000000000000000000000000000' }]` and one commit whose `changes` contains every package file as `add`; text content is `rawtext`, binary content is base64. Use the Entra token only in the `Authorization` header. Read back the ref, repository default branch, full recursive item list, each item byte stream, and every expected hash before returning `Verified`.

Write `ReadBackOutputPath` atomically only after complete verification. Its closed schema contains `schemaVersion`, `publicTenantKey`, `organizationUrl`, `projectId`, `repositoryId`, `ref`, and a `files` array of `path`/`sha256`. This private temp record supplies trust activation with exact protected Environment-variable values without introducing a self-hash into the tenant manifest.

```json
{
  "schemaVersion": "1.0",
  "publicTenantKey": "tenant1",
  "organizationUrl": "https://dev.azure.com/example/",
  "projectId": "11111111-1111-1111-1111-111111111111",
  "repositoryId": "22222222-2222-2222-2222-222222222222",
  "ref": "refs/heads/main",
  "files": [
    { "path": "config/tenants/tenant1.psd1", "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
    { "path": "evidence/discovery/tenant1.json", "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }
  ]
}
```

Official contracts: [Repositories - Update](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/repositories/update?view=azure-devops-rest-7.1) and [Pushes - Create](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pushes/create?view=azure-devops-rest-7.1).

- [ ] **Step 7: Cover idempotency, ambiguity, status, timeout, and stale approval**

Add tests named:

```text
returns a zero-operation final plan after exact private read-back
rejects a non-empty source repository before rename
rejects duplicate target repository names
preserves 403 404 timeout and unsupported classifications
rejects an ApprovedPlanHash that differs from the recomputed plan
rereads the empty precondition before rename and before initial push
stops after rename when rename read-back differs
stops after push when any byte hash differs
never requests or passes a PAT
```

Expected: adapters record no mutation in `-WhatIf`; live-mode fakes record at most one mutation before each matching read.

- [ ] **Step 8: Run tests green and commit**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\TenantPrivateConfigurationPackage.Tests.ps1'
  'infra\tests\pester\TenantPrivateConfigurationRepository.Tests.ps1'
) -Output Detailed -CI
git add infra\src\config\schemas\private-repository-manifest.schema.json infra\src\config\schemas\private-repository-readback.schema.json infra\src\config\schemas\tenant-private-repository.schema.json infra\src\config\azure-devops\tenant-private-repository.json infra\src\scripts\New-TenantPrivateConfigurationPackage.ps1 infra\src\scripts\Initialize-TenantPrivateConfigurationRepository.ps1 infra\tests\pester\TenantPrivateConfigurationPackage.Tests.ps1 infra\tests\pester\TenantPrivateConfigurationRepository.Tests.ps1
git commit -m "feat(config): add atomic tenant-private repository migration" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: all private-repository tests pass.

### Task 4: Workflow private-file retrieval

**Files:**
- Create: `infra/src/scripts/Get-TenantPrivateConfiguration.ps1`
- Create: `infra/tests/pester/TenantPrivateConfigurationRetrieval.Tests.ps1`
- Modify: `.github/workflows/bootstrap-tenant.yml`
- Modify: `.github/workflows/discover-tenant.yml`
- Modify: `.github/workflows/validate-repository.yml`
- Modify: `.github/workflows/README.md`
- Modify: `infra/tests/pester/WorkflowContract.Tests.ps1`

**Interfaces:**
- Consumes: OIDC-authenticated Azure CLI context and the eleven protected variables.
- Produces: `RUNNER_TEMP\tenant-private\tenant1.psd1` and, when requested, `RUNNER_TEMP\tenant-private\tenant1.discovery.json`; output object contains paths and verified hashes, never content.

- [ ] **Step 1: Write retrieval and workflow tests red**

```powershell
It 'writes only exact hash-verified private files below the requested temp root' {
    $result = & $script:RetrievalScript -PublicTenantKey tenant1 -OutputDirectory $TestDrive `
        -IncludeDiscoveryEvidence -AzureDevOpsRequest $script:SuccessfulRequest
    $result.TenantConfigurationPath | Should -BeExactly (Join-Path $TestDrive 'tenant1.psd1')
    $result.DiscoveryEvidencePath | Should -BeExactly (Join-Path $TestDrive 'tenant1.discovery.json')
    @($script:Requests.Operation) | Should -Be @('GetRepository','GetItem','GetItem')
}

It 'deletes downloaded bytes when schema or hash validation fails' {
    { & $script:RetrievalScript -PublicTenantKey tenant1 -OutputDirectory $TestDrive `
        -AzureDevOpsRequest $script:WrongHashRequest } | Should -Throw '*SHA-256*'
    @(Get-ChildItem $TestDrive -File -ErrorAction SilentlyContinue).Count | Should -Be 0
}
```

Add workflow tests named `fetches private configuration only after OIDC login`, `never echoes uploads caches or commits private files`, and `uses the protected environment fetch variables exactly`.

- [ ] **Step 2: Run focused tests red**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\TenantPrivateConfigurationRetrieval.Tests.ps1'
  'infra\tests\pester\WorkflowContract.Tests.ps1'
) -Output Detailed -CI
```

Expected: retrieval script and workflow step are absent.

- [ ] **Step 3: Implement safe retrieval**

The script obtains a token with:

```powershell
$token = az account get-access-token `
    --resource '499b84ac-1321-427f-aa17-267ca6975798' `
    --query accessToken --output tsv --only-show-errors
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
    throw 'Azure DevOps access token acquisition failed.'
}
```

Build Azure Repos Items URLs using protected repository/project IDs and exact configured paths, request `includeContent=true`, `versionDescriptor.versionType=branch`, `versionDescriptor.version=main`, and API `7.1`. Write bytes atomically, compare `Get-FileHash -Algorithm SHA256` with the protected lowercase hash, then call `Import-TenantConfiguration -ExpectedPublicTenantKey tenant1`. Return paths only. Clear the local token variable in `finally`.

- [ ] **Step 4: Reorder each workflow**

Both workflows use input choice `tenant1`, Environment `bootstrap-${{ inputs.tenantKey }}`, and this order:

```yaml
- name: Azure OIDC login
  uses: azure/login@a457da9ea143d694b1b9c7c869ebb04ebe844ef5
  with:
    client-id: ${{ env.AZURE_CLIENT_ID }}
    tenant-id: ${{ env.AZURE_TENANT_ID }}
    subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}

- name: Fetch and validate tenant-private configuration
  id: private-config
  shell: powershell
  run: |
    $result = .\infra\src\scripts\Get-TenantPrivateConfiguration.ps1 `
      -PublicTenantKey '${{ inputs.tenantKey }}' `
      -OutputDirectory "$env:RUNNER_TEMP\tenant-private" `
      -IncludeDiscoveryEvidence
    "manifest-path=$($result.TenantConfigurationPath)" >> $env:GITHUB_OUTPUT
    "evidence-path=$($result.DiscoveryEvidencePath)" >> $env:GITHUB_OUTPUT
```

All subsequent scripts receive `-PublicTenantKey '${{ inputs.tenantKey }}' -TenantConfigurationPath '${{ steps.private-config.outputs.manifest-path }}'`. Bootstrap receives the fetched evidence path. Remove artifact upload of tenant discovery; instead validate discovery in `RUNNER_TEMP` and write it to the private repository only through the attended migration/operations path, never from this validation workflow.

In all three modified workflows, replace unconditional Pester installation with a probe-first step:

```yaml
- name: Ensure pinned Pester is available
  shell: powershell
  run: |
    $installed = @(Get-Module -ListAvailable -Name Pester |
      Where-Object Version -eq ([version]'5.7.1'))
    if ($installed.Count -eq 0) {
        Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck
    }
    Import-Module Pester -RequiredVersion 5.7.1 -Force
```

Expected: installation occurs only after the local module inventory proves 5.7.1 absent.

- [ ] **Step 5: Run focused tests green and commit**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\TenantPrivateConfigurationRetrieval.Tests.ps1'
  'infra\tests\pester\WorkflowContract.Tests.ps1'
) -Output Detailed -CI
git add .github\workflows infra\src\scripts\Get-TenantPrivateConfiguration.ps1 infra\tests\pester\TenantPrivateConfigurationRetrieval.Tests.ps1 infra\tests\pester\WorkflowContract.Tests.ps1
git commit -m "feat(workflows): fetch tenant-private configuration with OIDC" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 5: Bootstrap trust readiness and exact Environment contract

**Files:**
- Modify: `infra/src/scripts/Initialize-TenantTrust.ps1`
- Modify: `infra/tests/pester/TenantTrust.Tests.ps1`
- Modify: `infra/docs/20-tenant-trust-activation-runbook.md`

**Interfaces:**
- Consumes: the exact parameter contract below.
- Produces: existing trust resources plus `bootstrap-tenant1`, `main`-only deployment policy, one reviewer, `prevent_self_review = true`, eleven exact non-secret variables, `PlanHash`, and a final zero-operation plan.

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)] [ValidatePattern('^tenant[1-9][0-9]*$')] [string]$PublicTenantKey,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$TenantConfigurationPath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$DiscoveryEvidencePath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$PrivateRepositoryReadBackPath,
    [ValidatePattern('^[0-9a-f]{64}$')] [string]$ApprovedPlanHash,
    [string]$PlanOutputPath,
    [Parameter(DontShow)] [scriptblock]$AzRequest,
    [Parameter(DontShow)] [scriptblock]$GitHubRequest,
    [Parameter(DontShow)] [scriptblock]$AzureDevOpsRequest,
    [Parameter(DontShow)] [scriptblock]$NativeCommandRunner,
    [Parameter(DontShow)] [scriptblock]$HttpRequestRunner
)
```

- [ ] **Step 1: Add only missing trust tests**

Keep existing coverage for application, service principal, federation, entitlement, Readers membership, credentials, ambiguity, and zero mutation. Replace the old self-review expectation and add:

```powershell
It 'plans one main-only reviewer-protected no-self-review Environment with exact non-secret variables' {
    $result = & $script:ScriptPath -PublicTenantKey tenant1 -TenantConfigurationPath $script:Manifest `
        -DiscoveryEvidencePath $script:DiscoveryEvidence `
        -PrivateRepositoryReadBackPath $script:PrivateRepositoryReadBack `
        -PlanOutputPath $script:PlanPath -WhatIf -AzRequest $script:AzRequest `
        -GitHubRequest $script:GitHubRequest -AzureDevOpsRequest $script:AzureDevOpsRequest
    $environment = @($result.Plan | Where-Object Operation -eq 'EnsureGitHubEnvironment')
    $environment.Count | Should -Be 1
    $environment[0].Properties.BranchNamePatterns | Should -Be @('main')
    $environment[0].Properties.PreventSelfReview | Should -BeTrue
    @($result.Plan | Where-Object Operation -eq 'EnsureGitHubEnvironmentVariable').TargetName |
        Should -Be $script:ExpectedEnvironmentVariableNames
}

It 'requires exact ApprovedPlanHash and ends with a zero-mutation read-back plan' {
    { & $script:ScriptPath -PublicTenantKey tenant1 -TenantConfigurationPath $script:Manifest `
        -DiscoveryEvidencePath $script:DiscoveryEvidence `
        -PrivateRepositoryReadBackPath $script:PrivateRepositoryReadBack `
        -PlanOutputPath $script:PlanPath -ApprovedPlanHash ('0' * 64) `
        -AzRequest $script:AzRequest -GitHubRequest $script:GitHubRequest `
        -AzureDevOpsRequest $script:AzureDevOpsRequest -Confirm:$false } |
        Should -Throw '*approved plan hash*'
}
```

- [ ] **Step 2: Run TenantTrust red**

```powershell
Invoke-Pester -Path infra\tests\pester\TenantTrust.Tests.ps1 -Output Detailed -CI
```

Expected: failures identify old `prevent_self_review = false`, three-variable assumption, absent `PublicTenantKey`, and absent approved hash.

- [ ] **Step 3: Extend the existing script rather than create another trust script**

Add mandatory `PublicTenantKey`, `TenantConfigurationPath`, `DiscoveryEvidencePath`, and `PrivateRepositoryReadBackPath`, plus optional validated `ApprovedPlanHash`. Derive Environment from private config's `PublicTenantKey`. Set `prevent_self_review = $true`. Resolve organization, project ID, configuration-repository ID, ref, paths, and expected hashes from the schema-validated private read-back record; independently calculate the manifest and evidence hashes from the two explicit local files and require equality. Generate the eleven variables only from those values. Canonicalize the entire plan and return:

```powershell
[pscustomobject]@{
    SchemaVersion = '1.0'
    PublicTenantKey = $PublicTenantKey
    Plan = @($plan)
    PlanHash = Get-Sha256Hex -Text (ConvertTo-CanonicalJson -Value @($plan))
}
```

For a live run, require hash equality before the first `ShouldProcess`, reread each precondition, and retain the existing per-operation mutation/read-back adapters. After the last mutation, recompute with the same discovery path and throw unless every item is `Existing`.

- [ ] **Step 4: Update the runbook**

Replace real aliases and administrator values with the neutral key and explicit private path. The attended invocation is:

```powershell
$tenantConfigurationPath = (Resolve-Path $env:TENANT_CONFIGURATION_PATH).Path
$discoveryEvidencePath = (Resolve-Path $env:TENANT_DISCOVERY_EVIDENCE_PATH).Path
$privateRepositoryReadBackPath = (Resolve-Path $env:TENANT_PRIVATE_REPOSITORY_READBACK_PATH).Path
$planPath = Join-Path $env:TEMP 'tenant1-trust-plan.json'
$preview = .\infra\src\scripts\Initialize-TenantTrust.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $tenantConfigurationPath `
    -DiscoveryEvidencePath $discoveryEvidencePath `
    -PrivateRepositoryReadBackPath $privateRepositoryReadBackPath `
    -PlanOutputPath $planPath `
    -WhatIf
$approvedPlanHash = $preview.PlanHash
.\infra\src\scripts\Initialize-TenantTrust.ps1 `
    -PublicTenantKey tenant1 `
    -TenantConfigurationPath $tenantConfigurationPath `
    -DiscoveryEvidencePath $discoveryEvidencePath `
    -PrivateRepositoryReadBackPath $privateRepositoryReadBackPath `
    -PlanOutputPath $planPath `
    -ApprovedPlanHash $approvedPlanHash
```

The operator answers `Y` one mutation at a time, never `A`, and runs the `WhatIf` command again expecting zero proposed mutations.

- [ ] **Step 5: Run green and commit**

```powershell
Invoke-Pester -Path infra\tests\pester\TenantTrust.Tests.ps1 -Output Detailed -CI
git add infra\src\scripts\Initialize-TenantTrust.ps1 infra\tests\pester\TenantTrust.Tests.ps1 infra\docs\20-tenant-trust-activation-runbook.md
git commit -m "feat(trust): enforce approved private Tenant 1 trust plan" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 6: Work-item traceability workflow and pull-request contract

**Files:**
- Create: `.github/workflows/work-item-traceability.yml`
- Modify: `.github/pull_request_template.md`
- Modify: `.github/workflows/README.md`
- Modify: `infra/tests/pester/WorkflowContract.Tests.ps1`
- Modify: `.github/cli/tests/IssueFormContract.Tests.ps1`

**Interfaces:**
- Consumes: pull request body from `GITHUB_EVENT_PATH`.
- Produces: GitHub Actions check named exactly `Work item traceability`; accepts a boundary-safe reference such as `AB#42` or `Fixes AB#42`; uses no Azure DevOps credential.

- [ ] **Step 1: Add failing workflow contract tests**

```powershell
It 'defines an unprivileged Work item traceability pull-request check' {
    $workflow = Get-Content -Raw (Join-Path $script:RepositoryRoot '.github\workflows\work-item-traceability.yml')
    $workflow | Should -Match 'name:\s*Work item traceability'
    $workflow | Should -Match 'pull_request:'
    $workflow | Should -Match 'contents:\s*read'
    $workflow | Should -Not -Match 'id-token:\s*write|secrets\.|AZURE_|DEVOPS_|PAT'
}

It 'accepts AB references and rejects empty malformed or zero references' -TestCases @(
    @{ Body = 'AB#42'; Valid = $true }
    @{ Body = 'Fixes AB#42'; Valid = $true }
    @{ Body = 'AB#0'; Valid = $false }
    @{ Body = 'AB#'; Valid = $false }
    @{ Body = ''; Valid = $false }
) {
    param($Body, $Valid)
    ([bool]($Body -match '(?im)(?:^|\s)(?:Fixes\s+)?AB#([1-9][0-9]*)\b')) | Should -Be $Valid
}
```

- [ ] **Step 2: Run red**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\WorkflowContract.Tests.ps1'
  '.github\cli\tests\IssueFormContract.Tests.ps1'
) -Output Detailed -CI
```

Expected: missing workflow and incomplete pull-request guidance fail.

- [ ] **Step 3: Create the check**

```yaml
name: Work item traceability

on:
  pull_request:
    types: [opened, edited, reopened, synchronize]

permissions:
  contents: read

jobs:
  traceability:
    name: Work item traceability
    runs-on: windows-2025
    timeout-minutes: 5
    steps:
      - name: Validate Azure Boards reference
        shell: powershell
        run: |
          $event = Get-Content -Raw -LiteralPath $env:GITHUB_EVENT_PATH | ConvertFrom-Json
          $body = [string]$event.pull_request.body
          if ($body -cnotmatch '(?im)(?:^|\s)(?:Fixes\s+)?AB#([1-9][0-9]*)\b') {
              throw 'Pull request body must contain a positive Azure Boards reference such as AB#42 or Fixes AB#42.'
          }
          Write-Output 'A syntactically valid Azure Boards work-item reference is present.'
```

The workflow validates syntax only. The installed Azure Boards GitHub App creates the actual link and transition, proven at Checkpoint F.

- [ ] **Step 4: Define human and bot policy**

Change the template Work item section to:

```markdown
## Work item

<!-- Use `Fixes AB#123` when this merge must close the delivery item; use `AB#123` when it must remain open. -->

## Dependency automation

<!-- Dependabot and other bot PRs are not exempt. A maintainer adds a reference such as `AB#42` for the durable,
open Dependency Maintenance work item before review. Do not use `Fixes` for that recurring item.
Use a change-specific work item instead when the dependency change belongs to a finite delivery scope. -->
```

- [ ] **Step 5: Run green and commit**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\WorkflowContract.Tests.ps1'
  '.github\cli\tests\IssueFormContract.Tests.ps1'
) -Output Detailed -CI
git add .github\workflows\work-item-traceability.yml .github\workflows\README.md .github\pull_request_template.md infra\tests\pester\WorkflowContract.Tests.ps1 .github\cli\tests\IssueFormContract.Tests.ps1
git commit -m "feat(github): require Azure Boards PR traceability" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 7: GitHub governance desired state and complete read-back

**Files:**
- Modify: `infra/src/config/github/main-ruleset.json`
- Modify: `infra/src/config/schemas/github-ruleset.schema.json`
- Modify: `infra/src/scripts/Enable-GitHubGovernance.ps1`
- Modify: `infra/tests/pester/GitHubGovernance.Tests.ps1`
- Modify: `infra/docs/14-github-repository-blueprint.md`

**Interfaces:**
- Consumes: mandatory `-TenantConfigurationPath`, successful current-main validator/bootstrap run IDs, bootstrap evidence, desired state, exact `-ApprovedPlanHash`.
- Produces: squash-only normal merge, delete-on-merge, Projects disabled, Dependabot security updates enabled, active main ruleset with two required checks and PR-only owner bypass; complete final zero-mutation read-back.

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)] [string]$Repository,
    [Parameter(Mandatory)] [long]$ValidatorRunId,
    [Parameter(Mandatory)] [long]$BootstrapRunId,
    [Parameter(Mandatory)] [string]$BootstrapEvidencePath,
    [Parameter(Mandatory)] [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string]$TenantConfigurationPath,
    [Parameter(Mandatory)] [string]$DesiredStatePath,
    [ValidatePattern('^[0-9a-f]{64}$')] [string]$ApprovedPlanHash
)
```

- [ ] **Step 1: Add failing desired-state and mutation-order tests**

Add tests named:

```text
requires explicit tenant-private configuration and approved plan hash
plans squash-only merge delete-on-merge Projects-off and Dependabot security updates
requires Repository setup validation and Work item traceability
keeps one urruegg pull-request-only bypass
performs one repository setting mutation then complete read-back
performs one Dependabot mutation then complete read-back
performs one ruleset mutation then complete read-back
returns zero mutations after exact final read-back
retains current-main validator bootstrap and temporary-role-absence gates
```

Core assertion:

```powershell
$proposal.RepositorySettings | ConvertTo-Json -Compress | Should -BeExactly (
    [ordered]@{
        allow_merge_commit = $false
        allow_rebase_merge = $false
        allow_squash_merge = $true
        delete_branch_on_merge = $true
        has_projects = $false
    } | ConvertTo-Json -Compress
)
$proposal.RequiredChecks | Should -Be @('Repository setup validation','Work item traceability')
```

- [ ] **Step 2: Run GitHub governance red**

```powershell
Invoke-Pester -Path infra\tests\pester\GitHubGovernance.Tests.ps1 -Output Detailed -CI
```

Expected: current schema rejects repository settings; current ruleset allows three methods and one check; script reads current-main public manifest.

- [ ] **Step 3: Extend the closed desired state**

Add:

```json
"repositorySettings": {
  "allowMergeCommit": false,
  "allowRebaseMerge": false,
  "allowSquashMerge": true,
  "deleteBranchOnMerge": true,
  "hasProjects": false,
  "dependabotSecurityUpdates": true
}
```

Set `allowedMergeMethods` to `["squash"]`. Required status checks are exactly:

```json
[
  { "context": "Repository setup validation", "integrationId": 15368 },
  { "context": "Work item traceability", "integrationId": 15368 }
]
```

Keep deletion, non-fast-forward, one approval, stale dismissal, CODEOWNERS, resolved conversations, strict checks, active enforcement, `refs/heads/main`, and `urruegg` `pull_request` bypass.

- [ ] **Step 4: Replace current-main manifest lookup with explicit private path**

Delete `Import-CurrentMainTenantConfiguration`. Add mandatory `TenantConfigurationPath` and load it with `ExpectedPublicTenantKey tenant1`. During the approval window, hash and re-import the same local private file; reject byte changes. Do not use `gh api .../contents/infra/src/config/tenants/...`.

- [ ] **Step 5: Plan and apply repository settings one at a time**

Use documented GitHub endpoints through `gh api`:

```text
GET/PATCH repos/{owner}/{repo}
GET/PUT repos/{owner}/{repo}/automated-security-fixes
GET/POST/PUT repos/{owner}/{repo}/rulesets
```

Every drifted category is one ordered plan item. Immediately after `PATCH repos/...`, read all five repository settings. Immediately after Dependabot `PUT`, require enabled read-back. Immediately after ruleset POST/PUT, reuse `Test-RulesetReadBack` extended for two checks. Recompute and require the approved canonical plan hash before each mutation.

- [ ] **Step 6: Preserve prerequisite gates and final read-back**

Keep successful current-main run checks for `.github/workflows/validate-repository.yml` and `.github/workflows/bootstrap-tenant.yml`, exact current-main SHA, exact bootstrap evidence, Environment, reviewer, no-self-review, variable, service-principal, and temporary-role-absence checks. Extend `Assert-EnvironmentReadBack` from three to eleven exact variable names. Final `-WhatIf` must return no proposed settings, security-update, or ruleset mutations.

- [ ] **Step 7: Run green and commit**

```powershell
Invoke-Pester -Path infra\tests\pester\GitHubGovernance.Tests.ps1 -Output Detailed -CI
git add infra\src\config\github\main-ruleset.json infra\src\config\schemas\github-ruleset.schema.json infra\src\scripts\Enable-GitHubGovernance.ps1 infra\tests\pester\GitHubGovernance.Tests.ps1 infra\docs\14-github-repository-blueprint.md
git commit -m "feat(github): enforce complete repository governance" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 8: Azure Boards Agile foundation

**Files:**
- Create: `infra/src/config/schemas/azure-boards-foundation.schema.json`
- Create: `infra/src/config/azure-devops/boards-foundation.json`
- Create: `infra/src/scripts/Initialize-AzureDevOpsBoardsFoundation.ps1`
- Create: `infra/tests/pester/AzureBoardsFoundation.Tests.ps1`
- Modify: `infra/docs/13-azure-devops-engineering-control-plane.md`

**Interfaces:**
- Consumes: private tenant config and mandatory explicit first iteration date.
- Produces: preflight inventory, conversion checkpoint, one default team on root area, six inclusive 14-day iterations, deterministic plan/hash, read-back; no child area.

- [ ] **Step 1: Write failing date, inventory, and safety tests**

```powershell
It 'computes six contiguous inclusive fourteen-day iterations from the mandatory date' {
    $plan = & $script:ScriptPath -TenantConfigurationPath $script:Manifest `
        -FirstIterationStartDate ([datetime]'2026-10-05') -PlanOutputPath $script:PlanPath `
        -WhatIf -AzureDevOpsRequest $script:BasicEmptyProjectRequest
    @($plan.Iterations).Count | Should -Be 6
    $plan.Iterations[0].StartDate | Should -BeExactly '2026-10-05'
    $plan.Iterations[0].FinishDate | Should -BeExactly '2026-10-18'
    $plan.Iterations[1].StartDate | Should -BeExactly '2026-10-19'
    $plan.Iterations[5].FinishDate | Should -BeExactly '2026-12-27'
}

It 'blocks process conversion when pre-existing work is not fully classified' {
    { & $script:ScriptPath -TenantConfigurationPath $script:Manifest `
        -FirstIterationStartDate ([datetime]'2026-10-05') -PlanOutputPath $script:PlanPath `
        -WhatIf -AzureDevOpsRequest $script:UnclassifiedWorkRequest } |
        Should -Throw '*safe supported conversion recovery*'
}
```

- [ ] **Step 2: Run red**

```powershell
Invoke-Pester -Path infra\tests\pester\AzureBoardsFoundation.Tests.ps1 -Output Detailed -CI
```

Expected: script missing.

- [ ] **Step 3: Define the closed desired state**

```json
{
  "$schema": "../schemas/azure-boards-foundation.schema.json",
  "schemaVersion": "1.0",
  "process": { "currentAllowed": ["Basic", "Agile"], "desired": "Agile", "conversionMode": "AttendedMicrosoftProcedure" },
  "team": { "count": 1, "useProjectRootArea": true, "createChildAreas": false },
  "iterations": { "count": 6, "durationDays": 14, "nameFormat": "Sprint {0}" }
}
```

- [ ] **Step 4: Implement preflight inventory and process gate**

Read project capabilities, process ID/name, all teams, root and child area nodes, iteration nodes, team field values, team iterations, work item type inventory, and all work item IDs/types/states through WIQL and work-item batch read. Store counts and hashes only in sanitized evidence.

If process is Basic and any work item exists, stop unless every item is in the operator-approved inventory and Microsoft's documented Basic-to-Agile mapping has a recorded forward-recovery owner. There is no scripted rollback claim. If no safe supported reversal or approved forward recovery exists, emit `Blocked` and do not offer process conversion.

- [ ] **Step 5: Represent conversion as an attended checkpoint**

Do not call a process-migration endpoint. Emit:

```json
{
  "operation": "AttendBasicToAgileConversion",
  "status": "AttendedCheckpoint",
  "procedure": "https://learn.microsoft.com/azure/devops/organizations/settings/work/change-process-basic-to-agile",
  "precondition": { "process": "Basic", "inventoryHash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
  "postcondition": { "process": "Agile" },
  "recovery": "Stop; use the recorded forward-recovery owner and exported pre-state. Do not attempt an undocumented reverse conversion."
}
```

The runbook pauses, the project administrator performs the Microsoft UI procedure, and the script is rerun. It must read `Agile` before any team/iteration mutation.

- [ ] **Step 6: Implement root team/area and iterations**

Reject more than one team and any child area; never delete them automatically. Require the one default team and project root area. Create each missing root iteration with the locally verified command:

```powershell
az boards iteration project create --name $iteration.Name `
  --start-date $iteration.StartDate --finish-date $iteration.FinishDate `
  --organization $organizationUrl --project $projectId --output json --only-show-errors
```

Finish date is `start + 13 days`; next start is prior start + 14. After each iteration read-back, assign that exact returned identifier to the one team:

```powershell
az boards iteration team add --id $iterationIdentifier --team $teamId `
  --organization $organizationUrl --project $projectId --output json --only-show-errors
az boards iteration team list --team $teamId `
  --organization $organizationUrl --project $projectId --output json --only-show-errors
```

Require the just-created identifier in the list before continuing. Read the team root area with `az boards area team list --team $teamId --organization $organizationUrl --project $projectId`; if it is not the sole default area, or if any child area exists, stop without mutation. Official REST alternative for project iterations: [Classification Nodes - Create or Update](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/classification-nodes/create-or-update?view=azure-devops-rest-7.1).

- [ ] **Step 7: Add complete fail-closed tests**

Add named tests:

```text
requires an explicit FirstIterationStartDate
rejects a second team
rejects a child area without deleting it
does not invent an API operation for Basic-to-Agile conversion
stops until attended Agile read-back succeeds
rejects noncontiguous existing iteration dates
mutates and reads back one iteration at a time
rejects stale plan hash and changed pre-state
returns zero mutations for exact Agile root-team six-iteration state
```

- [ ] **Step 8: Run green and commit**

```powershell
Invoke-Pester -Path infra\tests\pester\AzureBoardsFoundation.Tests.ps1 -Output Detailed -CI
git add infra\src\config\schemas\azure-boards-foundation.schema.json infra\src\config\azure-devops\boards-foundation.json infra\src\scripts\Initialize-AzureDevOpsBoardsFoundation.ps1 infra\tests\pester\AzureBoardsFoundation.Tests.ps1 infra\docs\13-azure-devops-engineering-control-plane.md
git commit -m "feat(boards): add attended Agile foundation reconciler" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 9: Durable remediation hierarchy, separate from 19 HR ideas

**Files:**
- Create: `infra/src/config/schemas/engineering-platform-work-items.schema.json`
- Create: `infra/src/config/azure-devops/engineering-platform-work-items.json`
- Create: `infra/src/scripts/Initialize-EngineeringPlatformWorkItems.ps1`
- Create: `infra/tests/pester/EngineeringPlatformWorkItems.Tests.ps1`
- Modify: `infra/docs/21-azure-boards-population-runbook.md`

**Interfaces:**
- Consumes: exact Agile foundation and Sprint 1 path.
- Produces: one Epic, one Feature, four User Stories, exact stable tags, parent links, and iteration assignments; output exposes `TraceabilityStoryId`.

- [ ] **Step 1: Write failing hierarchy tests**

```powershell
It 'defines the exact six-item remediation hierarchy' {
    $state = Get-Content -Raw $script:DesiredStatePath | ConvertFrom-Json
    @($state.items).Count | Should -Be 6
    @($state.items | Where-Object type -eq 'Epic').Count | Should -Be 1
    @($state.items | Where-Object type -eq 'Feature').Count | Should -Be 1
    @($state.items | Where-Object type -eq 'User Story').Count | Should -Be 4
    ($state.items.title -join '|') | Should -BeExactly (
        'Engineering Platform|Tenant 1 Control Plane Foundation|GitHub governance|' +
        'Private configuration|Azure Boards baseline|Work item traceability'
    )
}

It 'never reads HR idea files or calls Initialize-AzureDevOpsWorkItems' {
    $source = Get-Content -Raw $script:ScriptPath
    $source | Should -Not -Match 'hr[\\/]docs[\\/]ideas|Initialize-AzureDevOpsWorkItems'
}
```

- [ ] **Step 2: Run red**

```powershell
Invoke-Pester -Path infra\tests\pester\EngineeringPlatformWorkItems.Tests.ps1 -Output Detailed -CI
```

Expected: desired state and script absent.

- [ ] **Step 3: Create exact desired state**

```json
{
  "$schema": "../schemas/engineering-platform-work-items.schema.json",
  "schemaVersion": "1.0",
  "items": [
    { "key": "engineering-platform", "type": "Epic", "title": "Engineering Platform", "stableTag": "HRF-Control-EP", "parentKey": null, "iteration": "ProjectRoot" },
    { "key": "tenant1-control-plane-foundation", "type": "Feature", "title": "Tenant 1 Control Plane Foundation", "stableTag": "HRF-Control-FEAT-T1", "parentKey": "engineering-platform", "iteration": "ProjectRoot" },
    { "key": "github-governance", "type": "User Story", "title": "GitHub governance", "stableTag": "HRF-Control-US-GITHUB", "parentKey": "tenant1-control-plane-foundation", "iteration": "Sprint1" },
    { "key": "private-configuration", "type": "User Story", "title": "Private configuration", "stableTag": "HRF-Control-US-CONFIG", "parentKey": "tenant1-control-plane-foundation", "iteration": "Sprint1" },
    { "key": "boards-baseline", "type": "User Story", "title": "Azure Boards baseline", "stableTag": "HRF-Control-US-BOARDS", "parentKey": "tenant1-control-plane-foundation", "iteration": "Sprint1" },
    { "key": "traceability", "type": "User Story", "title": "Work item traceability", "stableTag": "HRF-Control-US-TRACE", "parentKey": "tenant1-control-plane-foundation", "iteration": "Sprint1" }
  ]
}
```

All items also receive tags `HR Frontier; Engineering Platform; Tenant-1; Slice-1`. The recurring Dependency Maintenance item from Task 6 is policy-owned and not added to this exact remediation hierarchy.

- [ ] **Step 4: Implement deterministic lookup and parent relations**

Lookup by exact stable tag and type. Zero matches means `Create`, one exact match means validate, two means ambiguity failure. Create parent before child through Azure DevOps Work Items REST `POST .../_apis/wit/workitems/$Type?api-version=7.1`; add parent relation to the child in the creation patch:

```powershell
$parentUrl = '{0}{1}/_apis/wit/workItems/{2}' -f `
    $configuration.AzureDevOps.OrganizationUrl,
    [uri]::EscapeDataString([string]$projectId),
    $parentId
$parentPatch = [ordered]@{
    op = 'add'
    path = '/relations/-'
    value = [ordered]@{
        rel = 'System.LinkTypes.Hierarchy-Reverse'
        url = $parentUrl
    }
}
```

Set `System.AreaPath` to the project root. Epic and Feature use project-root iteration; all stories use mandatory `-FirstIterationPath`. Immediately read back type, title, tags, area, iteration, and exactly one expected parent.

- [ ] **Step 5: Add idempotency and error tests**

Add tests named:

```text
creates parent before child and reads each item back
fails on duplicate stable tag
fails when an existing exact tag has the wrong type title parent area or iteration
returns TraceabilityStoryId from the exact traceability story
rejects missing Agile Epic Feature or User Story capabilities
returns a zero-mutation final plan without changing the 19 HR-idea population
```

- [ ] **Step 6: Update the existing runbook boundary**

State explicitly that `Initialize-AzureDevOpsWorkItems.ps1` still owns only 19 idea Epics. Link to the new Slice 1 operator runbook for engineering hierarchy. Do not add Features or stories to the 19-idea script.

- [ ] **Step 7: Run green and commit**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\EngineeringPlatformWorkItems.Tests.ps1'
  'infra\tests\pester\AzureBoardsPopulation.Tests.ps1'
) -Output Detailed -CI
git add infra\src\config\schemas\engineering-platform-work-items.schema.json infra\src\config\azure-devops\engineering-platform-work-items.json infra\src\scripts\Initialize-EngineeringPlatformWorkItems.ps1 infra\tests\pester\EngineeringPlatformWorkItems.Tests.ps1 infra\docs\21-azure-boards-population-runbook.md
git commit -m "feat(boards): add durable control plane hierarchy" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 10: Operator runbook and attended checkpoints A-F

**Files:**
- Create: `.github/cli/tests/PublicTenantBoundary.Tests.ps1`
- Create: `infra/docs/22-engineering-control-plane-foundation-runbook.md`
- Modify: `infra/README.md`
- Modify: `infra/tests/pester/RunbookContracts.Tests.ps1`
- Modify: `infra/tests/pester/RunbookDocumentation.Tests.ps1`
- Modify: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`

**Interfaces:**
- Consumes: Tasks 1-9 tools, reviewed execution-branch SHA, private local manifest path, named accountable owners.
- Produces: ordered attended procedure and sanitized checkpoint evidence; no later-slice resource.

- [ ] **Step 1: Write runbook contract tests red**

```powershell
It 'orders Wave 0 and checkpoints A through F without later-slice operations' {
    $content = Get-Content -Raw $script:RunbookPath
    $positions = @('Wave 0','Checkpoint A','Checkpoint B','Checkpoint C','Merge boundary','Checkpoint D','Checkpoint E','Checkpoint F') |
        ForEach-Object { $content.IndexOf($_, [System.StringComparison]::Ordinal) }
    $positions | ForEach-Object { $_ | Should -BeGreaterThan -1 }
    for ($i = 1; $i -lt $positions.Count; $i++) { $positions[$i] | Should -BeGreaterThan $positions[$i - 1] }
    $content | Should -Not -Match 'az pipelines create|service-endpoint|pac solution import|deployment group'
}
```

- [ ] **Step 2: Run red**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\RunbookContracts.Tests.ps1'
  'infra\tests\pester\RunbookDocumentation.Tests.ps1'
  'infra\tests\pester\RunbookStaticSafety.Tests.ps1'
) -Output Detailed -CI
```

Expected: runbook missing.

- [ ] **Step 3: Write Checkpoint A — context, hashes, and recovery**

The runbook resolves `git rev-parse HEAD`, `gh api user`, `az account show`, private manifest context, Azure DevOps project/repository stable IDs, and stores allowlisted JSON outside Git. It computes:

```powershell
$preStateHash = (Get-FileHash -LiteralPath $preStatePath -Algorithm SHA256).Hash.ToLowerInvariant()
$executionBranchSha = (git rev-parse HEAD).Trim()
if ($executionBranchSha -cnotmatch '^[0-9a-f]{40}$') { throw 'Execution branch SHA is invalid.' }
```

The rollback table names owner, supported action, limit, and forward recovery for repository rename/push, trust objects, GitHub settings/ruleset, process conversion, iterations, and work items. Process conversion says no automatic reverse; unsafe conversion blocks.

- [ ] **Step 4: Write Checkpoint B — package, private migration, read-back, deletion gate**

The operator sets Tenant 1 private paths through interactive selection or an approved secure location and generates one `tenant1` migration package outside Git. Preview Tenant 1 repository initialization, record `PlanHash`, apply that hash, and rerun `WhatIf`. The final Tenant 1 API read-back compares every path and SHA. Record the reviewed hashes of the retained Tenant 2 transition files and verify them before and after every remaining Slice 1 task. Any failed Tenant 1 private-repository read-back or unexpected Tenant 2 hash change leaves the Tenant 1 public files untouched and blocks continuation.

Before deleting Tenant 1 public state, create `PublicTenantBoundary.Tests.ps1`. The test enumerates tracked repository-owned files, excludes `.github/skills/**` and deterministic synthetic fixtures, verifies `legacy-transition.json` against its schema, verifies both transition-file hashes, and scans for:

```powershell
$privatePatterns = @(
    'caldova[0-9]{8}',
    'onmicrosoft\.com',
    'https://[^/\s]+\.crm[0-9]*\.dynamics\.com',
    'https://dev\.azure\.com/[a-z0-9]+/'
)
$allowedExact = @($transition.files.path) + 'infra/src/config/tenants/legacy-transition.json'
```

Run it before deletion. Expected: FAIL and list only the two private Tenant 1 migration paths; every other Tenant 1 occurrence must already have been rewritten, moved, or replaced by a synthetic fixture in Task 2.

After that read-back succeeds, the operator performs the public-boundary transition as one scoped source commit:

```powershell
$transition = Get-Content -Raw -LiteralPath 'infra/src/config/tenants/legacy-transition.json' |
    ConvertFrom-Json
$transitionPaths = @($transition.files.path)
$realManifests = @(git ls-files 'infra/src/config/tenants/*.psd1' |
    Where-Object { $_ -cne 'infra/src/config/tenants/_template.psd1' })
$realEvidence = @(git ls-files 'infra/evidence/discovery/*.json')
$tenant1ManifestCandidates = @($realManifests | Where-Object { $_ -notin $transitionPaths })
$tenant1EvidenceCandidates = @($realEvidence | Where-Object { $_ -notin $transitionPaths })
if ($tenant1ManifestCandidates.Count -ne 1 -or $tenant1EvidenceCandidates.Count -ne 1) {
    throw 'Tenant 1 private-state paths are ambiguous at the migration gate.'
}
$tenant1Manifest = $tenant1ManifestCandidates[0]
$tenant1Evidence = $tenant1EvidenceCandidates[0]
foreach ($path in @($tenant1Manifest, $tenant1Evidence) + $transitionPaths) {
    if (-not (git ls-files --error-unmatch $path 2>$null)) {
        throw "Expected transition file is not tracked: $path"
    }
}
git rm -- $tenant1Manifest $tenant1Evidence
if ($LASTEXITCODE -ne 0) { throw 'Tenant 1 public private-state deletion failed.' }
```

Update `.github/cli/tests/Phase3SourceContract.Tests.ps1`, `.github/cli/verify-repository-setup.ps1`, root `README.md`, and every remaining source/test/runbook reference so Tenant 1 private state is absent, `_template.psd1` and `catalog.json` are safe public contracts, and exactly the hash-pinned Tenant 2 transition manifest/evidence remain as the temporary exception. Add a contract that fails on any other real tenant manifest/evidence or any unexpected Tenant 2 byte change. Run the targeted contracts and verifier:

```powershell
Invoke-Pester -Path @(
  '.github\cli\tests\PublicTenantBoundary.Tests.ps1'
  '.github\cli\tests\Phase3SourceContract.Tests.ps1'
  'infra\tests\pester\TenantConfiguration.Tests.ps1'
  'infra\tests\pester\WorkflowContract.Tests.ps1'
) -Output Detailed -CI
powershell -NoProfile -ExecutionPolicy Bypass -File .github\cli\verify-repository-setup.ps1
```

Expected: all pass and the verifier prints `Repository setup validation passed.` Then:

```powershell
git add .github\cli README.md infra\src\config\tenants infra\evidence\discovery infra\src\scripts infra\tests\pester infra\docs hr\src\scripts hr\tests\pester
git commit -m "refactor(config): complete tenant-private boundary migration" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 5: Write Checkpoint C — trust**

Run Task 5's explicit-path commands. Require `bootstrap-tenant1`, `main`, one approved reviewer, `prevent_self_review = true`, eleven exact non-secret variables, application/service-principal/federation/entitlement/Readers read-back, executed hash equality, and final no-mutation plan.

- [ ] **Step 6: Write the merge boundary**

Before governance activation:

1. Implement and commit Tasks 1-11 on the reviewed linear branch.
2. Execute Checkpoints A, B, and C, including the gated public-boundary transition commit.
3. Rerun Task 11 repository tests and scans against that final branch state.
4. Push and review the branch while current controls permit it.
5. Merge tool changes to `main`.
6. Record the new current-main SHA.
7. Run `Validate repository` successfully on that exact SHA.
8. Run `Validate tenant bootstrap` successfully on that exact SHA with private retrieval.
9. Confirm temporary roles absent and save bootstrap cleanup evidence.
10. Supply both run IDs and the explicit local private manifest to governance.

Protection must not be activated before steps 4-8, because `Enable-GitHubGovernance.ps1` deliberately rejects non-current-main validator/bootstrap evidence.

- [ ] **Step 7: Write Checkpoint D — GitHub governance**

Preview:

```powershell
$governancePreview = .\infra\src\scripts\Enable-GitHubGovernance.ps1 `
  -Repository 'urruegg/caldova-hr-frontier' `
  -ValidatorRunId $validatorRunId `
  -BootstrapRunId $bootstrapRunId `
  -BootstrapEvidencePath $bootstrapEvidencePath `
  -TenantConfigurationPath $tenantConfigurationPath `
  -DesiredStatePath 'infra\src\config\github\main-ruleset.json' `
  -WhatIf
$approvedGovernancePlanHash = $governancePreview.PlanHash
```

Apply with `-ApprovedPlanHash $approvedGovernancePlanHash`, answer one mutation at a time, rerun `-WhatIf`, and use API read-back for all settings, Dependabot state, and ruleset fields. Run negative tests against a disposable branch/ref before attempting direct-main, deletion, force-push, failing-check, missing-AB, and unreviewed-PR cases. Do not damage `main`.

- [ ] **Step 8: Write Checkpoint E — Agile, iterations, hierarchy**

Prompt and strictly parse the attended date:

```powershell
$firstDateText = Read-Host 'Enter the approved first iteration start date (yyyy-MM-dd)'
$firstDate = [datetime]::MinValue
if (-not [datetime]::TryParseExact($firstDateText, 'yyyy-MM-dd',
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None, [ref]$firstDate)) {
    throw 'First iteration start date must use yyyy-MM-dd.'
}
```

Run foundation `WhatIf`. If it emits attended conversion, inventory and approve recovery, perform Microsoft's UI Basic-to-Agile procedure, then rerun. Apply iterations by approved hash and verify. Run hierarchy preview/apply/read-back. Record `TraceabilityStoryId`. Confirm one team, root area, six dates, no child area, one Epic/Feature/four stories, and unchanged 19 idea Epics.

- [ ] **Step 9: Write Checkpoint F — real governed PR**

Create a real branch for the final current-sprint outcome/evidence update. Use the actual traceability story:

```powershell
$traceabilityStoryId = [int]$hierarchyResult.TraceabilityStoryId
if ($traceabilityStoryId -le 0) { throw 'TraceabilityStoryId is invalid.' }
$body = "Fixes AB#$traceabilityStoryId`n`nRecords Slice 1 final evidence and control outcomes."
gh pr create --base main --head $branchName --title 'docs: record Slice 1 control plane acceptance' --body $body
```

Require both status checks, CODEOWNERS approval, stale-review dismissal behavior, resolved threads, normal squash merge, branch deletion, Azure Boards external link, and the predeclared story transition. Read back branch, commit, PR, merge SHA, deleted head ref, Azure Boards relation, and final state.

- [ ] **Step 10: Run runbook suites green and commit**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\RunbookContracts.Tests.ps1'
  'infra\tests\pester\RunbookDocumentation.Tests.ps1'
  'infra\tests\pester\RunbookStaticSafety.Tests.ps1'
) -Output Detailed -CI
git add infra\docs\22-engineering-control-plane-foundation-runbook.md infra\README.md infra\tests\pester\RunbookContracts.Tests.ps1 infra\tests\pester\RunbookDocumentation.Tests.ps1 infra\tests\pester\RunbookStaticSafety.Tests.ps1
git commit -m "docs(runbook): sequence Slice 1 attended execution" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### Task 11: Evidence contract, pre-merge validation, and review gates

**Files:**
- Create: `infra/src/config/schemas/engineering-control-plane-evidence.schema.json`
- Create: `infra/src/config/evidence/engineering-control-plane-evidence-manifest.json`
- Create: `infra/tests/pester/EngineeringControlPlaneEvidence.Tests.ps1`
- Modify: `infra/README.md`
- Modify: `.github/workflows/README.md`
- Modify: `docs/plans/README.md`

**Interfaces:**
- Consumes: sanitized private evidence for Wave 0 and checkpoints A-F.
- Produces: closed sanitized evidence manifest, repository-wide pre-merge test/scan results, and reviewer acceptance package.

- [ ] **Step 1: Write evidence-schema tests red**

```powershell
It 'allows only sanitized checkpoint A through F evidence references' {
    $manifest = Get-Content -Raw $script:ManifestPath | ConvertFrom-Json
    @($manifest.checkpoints.id) | Should -Be @('A','B','C','D','E','F')
    @($manifest.checkpoints | Where-Object { -not $_.sanitized }).Count | Should -Be 0
    ($manifest | ConvertTo-Json -Depth 30) | Should -Not -Match (
        'accessToken|clientSecret|password|privateKey|authorization|onmicrosoft\.com|caldova\d|crm\d*\.dynamics\.com'
    )
}
```

- [ ] **Step 2: Define the sanitized shape**

```json
{
  "$schema": "../schemas/engineering-control-plane-evidence.schema.json",
  "schemaVersion": "1.0",
  "publicTenantKey": "tenant1",
  "sourceCommit": "1111111111111111111111111111111111111111",
  "checkpoints": [
    {
      "id": "A",
      "status": "Verified",
      "sanitized": true,
      "preStateSha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "planSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "postStateSha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
      "records": [
        { "kind": "context", "privatePath": "evidence/control-plane/11111111-1111-1111-1111-111111111111/A-context.json", "sha256": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd" }
      ]
    }
  ],
  "prohibitedOutcomes": {
    "azurePipelinesCreated": 0,
    "serviceConnectionsCreated": 0,
    "powerPlatformImports": 0,
    "deployments": 0
  }
}
```

The checked-in file is a contract fixture with synthetic valid hashes and `status = "ContractOnly"` permitted by the schema. Real evidence uses the private path produced by `Join-Path 'evidence\control-plane' $runId`; the public review records sanitized outcomes, not private paths or values.

- [ ] **Step 3: Add negative evidence tests**

Add tests rejecting secrets/auth headers, unrestricted user/group/membership arrays, real tenant aliases/endpoints/admin identities, missing plan hashes, duplicate/missing checkpoints, false sanitization, and any nonzero prohibited outcome.

- [ ] **Step 4: Run targeted evidence tests**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\EngineeringControlPlaneEvidence.Tests.ps1'
  'infra\tests\pester\EvidenceGate.Tests.ps1'
  'infra\tests\pester\EvidenceSecurity.Tests.ps1'
) -Output Detailed -CI
```

Expected: all pass.

- [ ] **Step 5: Address the known branch-history test deliberately**

`infra/tests/pester/CloudFoundationStaticSafety.Tests.ps1` currently evaluates `HEAD~5..HEAD`. Execute this plan on a normal linear branch created from a repository history with at least five existing ancestors. Before the full suite, run:

```powershell
$ancestor = git rev-parse --verify HEAD~5 2>$null
if ($LASTEXITCODE -ne 0) {
    throw 'The execution branch lacks five real ancestors. Rebase onto current main or change the test to compare the reviewed base SHA; do not add filler commits.'
}
```

If intended semantics are “implementation branch changes did not modify prohibited workflow files,” change the test in its own reviewed commit to accept a recorded base SHA or use `origin/main...HEAD`; add a regression test for a branch with fewer than five new commits. Do not manufacture commits to satisfy the fixed depth.

- [ ] **Step 6: Run the full repository tests**

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
  '.github\cli\tests'
  'infra\tests\pester'
  'hr\tests\pester'
) -Output Detailed -CI
powershell -NoProfile -ExecutionPolicy Bypass -File .github\cli\verify-repository-safety.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .github\cli\verify-repository-setup.ps1
az bicep build --file infra\src\bicep\main.bicep --stdout | Out-Null
git diff --check origin/main...HEAD
```

Expected: all Pester tests pass, both verifiers report success, Bicep exits 0, and `git diff --check` emits no output.

- [ ] **Step 7: Run a scoped tenant/private-data scan**

```powershell
$tracked = @(git ls-files)
$matches = foreach ($path in $tracked) {
  $content = Get-Content -Raw -LiteralPath $path -ErrorAction SilentlyContinue
  if ($null -eq $content) { continue }
  foreach ($pattern in @(
  'caldova[0-9]{8}',
  'onmicrosoft\.com',
  'https://[^/\s]+\.crm[0-9]*\.dynamics\.com',
  'https://dev\.azure\.com/[a-z0-9]+/',
  '(?i)(client[_-]?secret|access[_-]?token|private[_-]?key)\s*[:=]'
  )) {
    if ($content -match $pattern) {
      [pscustomobject]@{ Path = $path -replace '\\','/'; Pattern = $pattern }
    }
  }
}
$allowedSynthetic = @(
  'infra/src/config/tenants/_template.psd1',
  'infra/tests/fixtures/'
)
$transition = Get-Content -Raw -LiteralPath 'infra/src/config/tenants/legacy-transition.json' |
  ConvertFrom-Json
$allowedTransition = @($transition.files.path) + 'infra/src/config/tenants/legacy-transition.json'
foreach ($file in $transition.files) {
  $actual = (Get-FileHash -LiteralPath $file.path -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -cne $file.sha256) {
    throw "Transition file hash mismatch: $($file.path)"
  }
}
$unexpected = @($matches | Where-Object {
  $candidatePath = $_.Path
  $isSynthetic = @($allowedSynthetic | Where-Object {
      $candidatePath.StartsWith($_, [StringComparison]::OrdinalIgnoreCase)
  }).Count -gt 0
  -not $isSynthetic -and $candidatePath -notin $allowedTransition
})
if ($unexpected.Count -gt 0) { $unexpected; throw 'Tracked tenant/private-data scan failed.' }
```

Expected: no unexpected match. Also run `git grep -n -I -E 'caldova[0-9]{8}|onmicrosoft\.com|crm[0-9]*\.dynamics\.com' -- . ':(exclude)docs/reviews/evidence/**'` and review every result; historical review prose may describe sanitized findings but must not contain a real endpoint or identity.

- [ ] **Step 8: Run documentation and link review**

```powershell
Invoke-Pester -Path @(
  '.github\cli\tests\DocumentationMetadata.Tests.ps1'
  '.github\cli\tests\DocumentationLinks.Tests.ps1'
  'infra\tests\pester\RunbookDocumentation.Tests.ps1'
) -Output Detailed -CI
```

Expected: all documentation metadata and links pass; catalogue rows include the runbook and this plan.

- [ ] **Step 9: Commit the implementation acceptance contracts**

```powershell
git add infra\src\config\schemas\engineering-control-plane-evidence.schema.json infra\src\config\evidence\engineering-control-plane-evidence-manifest.json infra\tests\pester\EngineeringControlPlaneEvidence.Tests.ps1 docs\plans\README.md infra\README.md .github\workflows\README.md
git commit -m "test(control-plane): add Slice 1 acceptance evidence" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

- [ ] **Step 10: Review gates before merge and activation**

Require separate reviewers for:

1. ADR and documentation authority;
2. public/private configuration and sanitization;
3. trust and identity scope;
4. GitHub governance and negative tests;
5. Azure DevOps process/iteration/work-item behavior;
6. operator recovery and evidence.

The final branch review records the full command outputs, plan hashes, and execution SHA. A changed plan, stale current-main run, unsafe process conversion, unresolved ambiguity, incomplete read-back, failed negative test, or evidence scan finding blocks merge or the next checkpoint.

### Task 12: Checkpoint F outcome update and final Slice 1 acceptance

**Files:**
- Modify: `docs/reviews/2026-09-28-tenant-1-engineering-platform-configuration-review.md`
- Modify: `docs/reviews/README.md`
- Modify: `infra/src/config/evidence/engineering-control-plane-evidence-manifest.json`
- Modify: `infra/tests/pester/EngineeringControlPlaneEvidence.Tests.ps1`
- Modify: `infra/README.md`
- Modify: `.github/workflows/README.md`

**Interfaces:**
- Consumes: completed live Checkpoints A-E, exact traceability User Story ID, current-main API state, and sanitized private evidence.
- Produces: the real Checkpoint F pull request, updated point-in-time control outcomes, complete A-F evidence manifest, and final Slice 1 acceptance read-back.

- [ ] **Step 1: Create the real governed evidence branch**

```powershell
$branchName = 'docs/slice1-control-plane-acceptance'
git switch -c $branchName origin/main
```

Expected: a new branch from the exact governed current-main SHA, with no unrelated working-tree changes.

- [ ] **Step 2: Write the failing final evidence assertions**

Extend `EngineeringControlPlaneEvidence.Tests.ps1`:

```powershell
It 'records all live checkpoints as Verified and retains zero later-slice outcomes' {
    $manifest = Get-Content -Raw $script:ManifestPath | ConvertFrom-Json
    @($manifest.checkpoints.id) | Should -Be @('A','B','C','D','E','F')
    @($manifest.checkpoints.status | Select-Object -Unique) | Should -Be @('Verified')
    $manifest.prohibitedOutcomes.azurePipelinesCreated | Should -Be 0
    $manifest.prohibitedOutcomes.serviceConnectionsCreated | Should -Be 0
    $manifest.prohibitedOutcomes.powerPlatformImports | Should -Be 0
    $manifest.prohibitedOutcomes.deployments | Should -Be 0
}
```

- [ ] **Step 3: Update the public sanitized manifest and active review**

Replace contract-only hashes with the sanitized private evidence hashes. Update only directly evidenced Slice 1 controls in the review: approved ADRs, transitional Tenant 1 private repository boundary, GitHub settings/ruleset, Agile process/team/iterations, durable hierarchy, and real traceability. Keep the full single-tenant and public/private-boundary controls open because the hash-pinned Tenant 2 transition files remain. Leave pipeline, service-connection, delivery-identity, artifact, approval, import, and deployment controls GAP or NOT EVIDENCED. Update review/catalogue metadata version/date/references and state the new evidence point-in-time.

- [ ] **Step 4: Run final documentation and evidence tests**

```powershell
Invoke-Pester -Path @(
  'infra\tests\pester\EngineeringControlPlaneEvidence.Tests.ps1'
  'infra\tests\pester\EvidenceGate.Tests.ps1'
  'infra\tests\pester\EvidenceSecurity.Tests.ps1'
  '.github\cli\tests\DocumentationMetadata.Tests.ps1'
  '.github\cli\tests\DocumentationLinks.Tests.ps1'
) -Output Detailed -CI
git diff --check origin/main...HEAD
```

Expected: all pass and no whitespace errors.

- [ ] **Step 5: Commit and push the real acceptance update**

```powershell
git add docs\reviews infra\src\config\evidence\engineering-control-plane-evidence-manifest.json infra\tests\pester\EngineeringControlPlaneEvidence.Tests.ps1 infra\README.md .github\workflows\README.md
git commit -m "docs(control-plane): record Slice 1 acceptance evidence" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push --set-upstream origin $branchName
```

- [ ] **Step 6: Open the real traceability pull request**

```powershell
$traceabilityStoryId = [int]$hierarchyResult.TraceabilityStoryId
if ($traceabilityStoryId -le 0) { throw 'TraceabilityStoryId is invalid.' }
$body = "Fixes AB#$traceabilityStoryId`n`nRecords Slice 1 final evidence and control outcomes."
gh pr create --base main --head $branchName `
  --title 'docs: record Slice 1 control plane acceptance' `
  --body $body
```

Expected: `Repository setup validation` and `Work item traceability` appear on the PR. The body contains the real closing reference.

- [ ] **Step 7: Review and merge normally**

Require CODEOWNERS approval, demonstrate stale-review dismissal if a post-approval change is needed, resolve every thread, and merge with normal squash:

```powershell
gh pr merge $branchName --squash --delete-branch
```

Do not use admin bypass or direct push.

- [ ] **Step 8: Read back the final transaction**

Read GitHub PR/merge/check state with `gh pr view` and `gh api`, confirm the head ref returns `404`, and read the Azure Boards story through REST. Require its external GitHub relation, PR URL, merge transaction, and predeclared closed state. Rerun the public evidence test from Step 4 against current `main`.

Expected: one correlated branch, commit, PR, squash merge, deleted branch, external link, and story transition; all later-slice counts remain zero.

## Specification Coverage Map

| Required checkpoint or integration decision | Implemented by |
|---|---|
| Wave 0 ADR reconciliation and catalogues | Task 1 |
| Public `tenant1` catalogue, explicit private paths, safe template, affected callers/docs/tests | Task 2 |
| Tenant 1 private Azure Repo, closed layout, one outside-Git Tenant 1 package, hash-pinned Tenant 2 transition exception, atomic read-back | Tasks 3 and 10 Checkpoint B |
| OIDC workflow retrieval into `RUNNER_TEMP`, exact hashes/schema, no upload/echo/commit | Task 4 |
| Existing trust initializer, main-only Environment, reviewer, no self-review, variables, hash approval, final read-back | Task 5 and Task 10 Checkpoint C |
| `Work item traceability` and human/bot PR contract | Task 6 |
| Repository settings, Dependabot, active ruleset, two required checks, current-main gates | Task 7 and Task 10 Checkpoint D |
| Basic inventory, blocked unsafe conversion, attended Agile change, one team/root area, six iterations | Task 8 and Task 10 Checkpoint E |
| Separate durable Engineering Platform hierarchy and unchanged 19-HR-idea population | Task 9 and Task 10 Checkpoint E |
| Pre-state, rollback/forward recovery, merge boundary, attended A-F sequence | Task 10 |
| Sanitized schema/manifest, negative tests, full tests, branch-history behavior, scoped scan, review gates | Task 11 |
| Real governed `Fixes AB#` pull request, state transition proof, active review outcome update | Task 12 |
| No pipeline, service connection, delivery identity, artifact, import, release, deployment, mirror, sync, or tenant seed | Global Constraints, Tasks 3, 10, 11, and 12 |

## Final Slice 1 Exit Criteria

- Wave 0 ADRs are approved through attended review and catalogue/read-back is consistent.
- Public source exposes no Tenant 1 private values; `tenant1`, safe contracts, and `_template.psd1` remain public, while only the explicitly hash-pinned Tenant 2 transition manifest/evidence remain as a temporary exception. Tenant 1 private bytes hash-match in `caldova-hr-frontier-config`.
- Trust is active for `bootstrap-tenant1`, main-only, one reviewer, no self-review, exact variables, approved plan hash, and final zero-mutation read-back.
- Repository settings and active main ruleset match every approved field, including squash-only merge and both required checks.
- Azure Boards is built-in Agile with one team, root area, six contiguous 14-day iterations, and no speculative area.
- The durable Engineering Platform hierarchy exists exactly and the separate 19-HR-idea population remains unchanged.
- A real governed squash-merged pull request body is built as `"Fixes AB#$traceabilityStoryId"`, links and transitions that story, and deletes its branch.
- Sanitized evidence and API read-back prove checkpoints A-F; later-slice resource counts remain zero.
- Full tests, verifiers, Bicep build, whitespace check, tenant/private-data scan, documentation checks, and negative tests pass.
