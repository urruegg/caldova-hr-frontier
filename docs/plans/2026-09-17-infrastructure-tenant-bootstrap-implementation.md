# Infrastructure and Tenant Bootstrap Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-19 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Infrastructure |
| **References** | [Architecture Baseline Intake and Tenant Bootstrap Design](../specs/2026-09-17-architecture-baseline-intake-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import and reconcile the infrastructure baseline, implement a secretless and evidence-gated tenant bootstrap for three independent tenants, establish Tenant 1 OIDC trust, and finish with a successful subscription-scope Bicep `what-if` before activating final GitHub governance.

**Architecture:** A versioned tenant `.psd1` is the human-reviewed desired state; a normalized JSON inventory is read-only observed evidence. A focused PowerShell module provides configuration, naming, discovery, intent, trust, retry, and cleanup boundaries. GitHub Actions selects exactly one tenant and binds it to a dedicated Environment and app registration. Bicep models only the approved subscription baseline and is executed with `what-if`, never `create`, in this sprint.

**Tech Stack:** Windows PowerShell 5.1, Pester 5.7.1, Azure CLI, GitHub CLI, Power Platform CLI, Azure DevOps REST API 7.1, Microsoft Graph v1.0, JSON Schema Draft 2020-12, Bicep, GitHub Actions OIDC

---

## Preconditions and Safety Gates

- Complete and receive attended approval for Phases 1 and 2.
- Run this plan from `sprint/architecture-baseline-intake` after rebasing or fast-forwarding from the reviewed Phase 2 tip.
- Confirm interactive authentication as `admin@Caldova25156897.onmicrosoft.com` before Tenant 1 trust operations.
- Before creating a federated credential, query the GitHub repository and OIDC customization APIs read-only and require the manifest owner/repository names and immutable IDs to match the returned `sub_claim_prefix`.
- Never request, display, persist, or route a password, MFA response, access token, refresh token, client secret, certificate private key, PAT, connection string, or personal HR data through an agent.
- Obtain explicit user approval immediately before every live Azure role-assignment deletion, including automatic cleanup. The approved design authorizes the cleanup mechanism; execution still pauses at the destructive-operation gate.
- Do not run `az deployment sub create`, `New-AzSubscriptionDeployment`, or any equivalent Azure platform deployment command.
- Do not provision Tenant 2 or Tenant 3.
- Activate the GitHub `main` ruleset only after all implementation commits are on `main`, the validator workflow succeeds on `main`, Tenant 1 `what-if` succeeds, and temporary Azure roles are confirmed absent.

### Task 1: Import and Reconcile Infrastructure Documentation

**Files:**
- Create: `.github/cli/tests/Phase3SourceContract.Tests.ps1`
- Create: `docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md`
- Create: `infra/README.md`
- Create: `infra/docs/10-tenant-setup-and-configuration.md`
- Create: `infra/docs/11-identity-and-access.md`
- Create: `infra/docs/12-power-platform-environments-and-alm.md`
- Create: `infra/docs/13-azure-devops-engineering-control-plane.md`
- Create: `infra/docs/14-github-repository-blueprint.md`
- Create: `infra/docs/15-agent-workload-configuration.md`
- Create: `infra/docs/16-security-governance-and-compliance.md`
- Create: `infra/docs/17-bootstrap-and-provisioning.md`
- Create: `infra/docs/18-multi-tenant-provisioning.md`
- Create: `infra/docs/19-bootstrap-recovery.md`
- Create: `infra/src/solutions/README.md`
- Modify: `docs/README.md`

- [ ] **Step 1: Write the failing Phase 3 source contract**

Create `.github/cli/tests/Phase3SourceContract.Tests.ps1`:

```powershell
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$inventory = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\reviews\2026-09-17-architecture-baseline-source-inventory.json') -Raw | ConvertFrom-Json
$expected = [ordered]@{
    'infra/README.md' = 'd801eb852feaa319ab4d77c08954a6486d03e16ab416e8adb96b4b86f127b35a'
    'infra/docs/10-tenant-setup-and-configuration.md' = 'f2346001a7a0f98633b9a00d7dc4c5a40845dfe61b02767d0297ecc705db05bd'
    'infra/docs/11-identity-and-access.md' = '56466efda3ca2aabc3f1fc0e4fde8fc755511f5b3125b9606e5a3f8b9d55b30c'
    'infra/docs/12-power-platform-environments-and-alm.md' = '2299472573fa2fbadaddb1b150ce04436ee3e3f6c27c9cf1992c3c4d229b98f4'
    'infra/docs/13-azure-devops-engineering-control-plane.md' = '6d9ffc8c8d809af374a408bfaba9ee896f29e87b3c92b9779784e539a79423cd'
    'infra/docs/14-github-repository-blueprint.md' = '60737982f4778f8a7bc55a277009d086472c325d3052715f28781cb0f878cd85'
    'infra/docs/15-agent-workload-configuration.md' = 'a62e2b5f464162c5de4bd02c02a149ff49862896333a0180ce55f26144b66d43'
    'infra/docs/16-security-governance-and-compliance.md' = 'df64b8e579cc55aafcbf8d9c9fe556f1e1f703e3d54f25aff3789e2e834d887d'
    'infra/docs/17-bootstrap-and-provisioning.md' = '76ff7a5414873e4cc18b95abf11a140d9265a7cec6d8f87a5f174018d9233a24'
    'infra/docs/18-multi-tenant-provisioning.md' = '55af81a81c502e0aa7d928dde4000e73e458ea4857625ccfc957991b74d73d5e'
}

Describe 'Phase 3 source contract' {
    It 'matches all ten substantive source documents' {
        foreach ($entry in $expected.GetEnumerator()) {
            $record = @($inventory.files | Where-Object relativePath -CEQ $entry.Key)
            $record.Count | Should -Be 1
            $record[0].sha256 | Should -Be $entry.Value
        }
    }

    It 'does not import comment-only placeholders' {
        foreach ($path in @('infra/src/bicep/.gitkeep', 'infra/src/config/tenants/.gitkeep',
            'infra/src/scripts/.gitkeep', 'infra/src/solutions/.gitkeep', 'infra/tests/.gitkeep')) {
            Test-Path (Join-Path $repositoryRoot $path) | Should -BeFalse
        }
    }
}
```

- [ ] **Step 2: Verify the source contract and RED existence check**

Run:

```powershell
Invoke-Pester .github/cli/tests/Phase3SourceContract.Tests.ps1 -Output Detailed
if (Test-Path infra/docs/10-tenant-setup-and-configuration.md) { throw 'Expected infrastructure document to be absent before import.' }
```

Expected: source hashes and placeholder checks pass; the existence guard passes because the document is absent.

- [ ] **Step 3: Copy hash-verified infrastructure prose**

Copy only `infra/README.md` and `infra/docs/10-*.md` through `18-*.md` from the assessed source. Verify each copied file hash against the inventory before adaptation.

- [ ] **Step 4: Reconcile every imported document to the approved design**

For all ten copied Markdown files:

1. Preserve the H1 and useful Microsoft references, constraints, trade-offs, and platform facts.
2. Replace leading legacy metadata with the standard header: Version `1.0`, Date `2026-09-17`, Author `docs-agent (Voice of Knowledge)`, Status `Proposed Baseline`, Scope `Infrastructure`, and references to the approved design and source inventory.
3. Replace one-repository-per-tenant guidance with one shared repository, one manifest and one `bootstrap-${tenantAlias}` Environment per independent tenant.
4. Replace managed-identity bootstrap with a dedicated single-tenant Entra app registration and service principal per tenant/repository; reserve managed identities for future Azure workloads.
5. Keep DEV/TEST/PROD exclusively as Power Platform ALM stages.
6. Replace broad live provisioning steps with discovery, reviewed `Existing/Create`, trust bootstrap, OIDC validation, and subscription-scope `what-if` only.
7. Remove stale claims that tenant/subscription IDs may not be versioned; the approved manifest treats them as reviewed non-secret metadata and cross-checks Environment values.
8. Remove claims that resource groups, Key Vault, storage, Power Platform environments, Azure DevOps projects, or solutions are created in this sprint.
9. Describe Tenant 1's existing Azure DevOps organization/project and three supplied Power Platform URLs as discovery-validated existing candidates.

- [ ] **Step 5: Add recovery and solution-source ownership documents**

Create `infra/docs/19-bootstrap-recovery.md` with the standard header and one section per failure state: trust creation, OIDC mismatch, service discovery authorization, stale evidence, ambiguous object, Bicep build, out-of-boundary `what-if`, role cleanup, and GitHub read-back. Each section names last trusted state, operator role, read-only diagnostics, repair, revalidation, and escalation.

Create `infra/src/solutions/README.md` with the standard header and state that this folder will contain unpacked Infrastructure Power Platform solution source; no solution payload exists in the assessed package; ZIP exports, environment values, secrets, and build output are prohibited.

- [ ] **Step 6: Complete the Phase 3 review record and catalogue**

Create `docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md` with one row per 15 source paths. Classify the ten documents as `Add` with semantic reconciliation and the five `.gitkeep` files as `Reject` with owned-file replacements. Update `docs/README.md` with the infrastructure document map.

- [ ] **Step 7: Validate and commit infrastructure documentation**

Run:

```powershell
Invoke-Pester .github/cli/tests/Phase3SourceContract.Tests.ps1,.github/cli/tests/DocumentationMetadata.Tests.ps1,.github/cli/tests/DocumentationLinks.Tests.ps1 -Output Detailed
git diff --check
```

Expected: all tests pass and diff check is empty.

Commit:

```powershell
git add -- infra/README.md infra/docs infra/src/solutions/README.md docs/README.md docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md .github/cli/tests/Phase3SourceContract.Tests.ps1
git commit -m "docs: import infrastructure baseline" -- infra/README.md infra/docs infra/src/solutions/README.md docs/README.md docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md .github/cli/tests/Phase3SourceContract.Tests.ps1
```

### Task 2: Implement Tenant Configuration and Naming

**Files:**
- Create: `infra/src/config/schemas/tenant.schema.json`
- Create: `infra/src/config/tenants/_template.psd1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Import-TenantConfiguration.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-TenantSuffix.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-TenantResourceName.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-GitHubOidcSubject.ps1`
- Create: `infra/src/scripts/New-TenantManifest.ps1`
- Create: `infra/tests/pester/TenantConfiguration.Tests.ps1`
- Create: `infra/tests/pester/Naming.Tests.ps1`

- [ ] **Step 1: Write failing tenant and naming tests**

Create `infra/tests/pester/TenantConfiguration.Tests.ps1`:

```powershell
$module = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $module -Force

Describe 'Tenant configuration' {
    It 'accepts the Tenant 1 contract and exact ALM URLs' {
        $config = Import-TenantConfiguration -Path (Join-Path $PSScriptRoot '..\..\src\config\tenants\caldova25156897.psd1') -ValidationStage Discovery
        $config.TenantAlias | Should -Be 'caldova25156897'
        $config.PrimaryLocation | Should -Be 'switzerlandnorth'
        $config.PowerPlatform.DevUrl | Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        $config.PowerPlatform.TestUrl | Should -Be 'https://hrfrontiertest.crm17.dynamics.com/'
        $config.PowerPlatform.ProdUrl | Should -Be 'https://hrfrontier.crm17.dynamics.com/'
        $config.UniqueSuffix | Should -Match '^[a-z0-9]{6}$'
        $config.NamingRoot | Should -Be "cal-hr-agentic-$($config.UniqueSuffix)"
    }

    It 'rejects executable expressions and unknown top-level keys' {
        $path = Join-Path $TestDrive 'unsafe.psd1'
        Set-Content -LiteralPath $path -Value "@{ TenantAlias = (Get-Date); Unknown = 'x' }"
        { Import-TenantConfiguration -Path $path } | Should -Throw
    }
}
```

Create `infra/tests/pester/Naming.Tests.ps1`:

```powershell
Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force

Describe 'Tenant naming' {
    It 'generates six lowercase alphanumeric characters' {
        New-TenantSuffix | Should -Match '^[a-z0-9]{6}$'
    }

    It 'derives deterministic Azure names within resource constraints' {
        Get-TenantResourceName -NamingRoot 'cal-hr-agentic-a7k29x' -ResourceType ResourceGroup |
            Should -Be 'rg-cal-hr-agentic-a7k29x-platform'
        Get-TenantResourceName -NamingRoot 'cal-hr-agentic-a7k29x' -ResourceType LogAnalytics |
            Should -Be 'log-cal-hr-agentic-a7k29x'
        Get-TenantResourceName -NamingRoot 'cal-hr-agentic-a7k29x' -ResourceType DeploymentValidationRole |
            Should -Be 'cal-hr-agentic-a7k29x-deployment-validation'
    }

    It 'derives the exact environment-bound OIDC subject' {
      Get-GitHubOidcSubject `
        -Owner urruegg `
        -OwnerId '46865858' `
        -Repository caldova-hr-frontier `
        -RepositoryId '1371297722' `
        -TenantAlias caldova25156897 |
        Should -Be 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897'
    }
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
Invoke-Pester infra/tests/pester/TenantConfiguration.Tests.ps1,infra/tests/pester/Naming.Tests.ps1 -Output Detailed
```

Expected: FAIL because the module and Tenant 1 manifest do not exist.

- [ ] **Step 3: Define the closed tenant schema**

Create `infra/src/config/schemas/tenant.schema.json` as Draft 2020-12 with `additionalProperties: false` at every object. Require:

```json
{
  "SchemaVersion": "1.0",
  "TenantAlias": "^[a-z0-9]+$",
  "DisplayName": "non-empty string",
  "TenantId": "UUID",
  "AdminUpn": "UPN",
  "SubscriptionId": "UUID",
  "PrimaryLocation": "lowercase Azure location",
  "CompanyTla": "^[a-z]{3}$",
  "WorkloadName": "hr-agentic",
  "UniqueSuffix": "^[a-z0-9]{6}$",
  "NamingRoot": "^[a-z]{3}-hr-agentic-[a-z0-9]{6}$",
  "LifecycleState": "DiscoveryRequired or IntentReviewed",
  "GitHub": {
    "Owner": "urruegg",
    "OwnerId": "46865858",
    "Repository": "caldova-hr-frontier",
    "RepositoryId": "1371297722",
    "EnvironmentName": "bootstrap-${tenantAlias}"
  },
  "AzureDevOps": {
    "OrganizationUrl": "HTTPS URL",
    "ProjectName": "non-empty string"
  },
  "PowerPlatform": {
    "DevUrl": "HTTPS URL",
    "TestUrl": "HTTPS URL",
    "ProdUrl": "HTTPS URL"
  },
  "Components": "closed map of component name to Mode and stable ID"
}
```

The schema and importer reject `Auto`, duplicate URLs, an Environment name not derived from alias, and an inconsistent NamingRoot. `Import-TenantConfiguration -ValidationStage Discovery` permits `LifecycleState = 'DiscoveryRequired'` with an empty `Components` map. `-ValidationStage Bootstrap` requires `LifecycleState = 'IntentReviewed'`, explicit `Existing` or `Create` for every managed component, and a stable ID for each `Existing` entry.

- [ ] **Step 4: Implement the focused module functions**

`New-TenantSuffix` uses `RandomNumberGenerator.GetInt32(36)` six times over `abcdefghijklmnopqrstuvwxyz0123456789`.

`Get-TenantResourceName` accepts only the enum-like values `ResourceGroup`, `LogAnalytics`, and `DeploymentValidationRole`, returns the exact names in the tests, and validates Azure length/character constraints.

`Get-GitHubOidcSubject` accepts reviewed owner and repository names plus positive decimal ID strings, lowercases neither name, and returns the exact case-sensitive immutable subject from the test.

`Import-TenantConfiguration`:

1. reads the PSD1 with `Import-PowerShellDataFile`;
2. compares keys recursively with the closed schema contract and applies the selected `Discovery` or `Bootstrap` validation stage;
3. validates GUIDs, URLs, modes, IDs, suffix, root, and cross-field derivations;
4. returns a read-only `PSCustomObject` graph;
5. never invokes or evaluates expressions.

Dot-source only `Public/*.ps1` from `Caldova.HrFrontier.Bootstrap.psm1`, export the four public functions from the module manifest, and require PowerShell 5.1.

- [ ] **Step 5: Add a template and generate Tenant 1 atomically**

Create `_template.psd1` using syntactically valid example values and a header comment stating that it is non-secret configuration. Create `New-TenantManifest.ps1` so it:

1. refuses to overwrite an existing tenant manifest;
2. calls `New-TenantSuffix` exactly once;
3. writes BOM-free UTF-8 using a fixed property order;
4. writes Tenant 1's supplied IDs, UPN, region, Azure DevOps values, Power Platform URLs, and the read-only verified GitHub owner and repository IDs;
5. stores the Azure DevOps project name and Power Platform URLs as discovery hints, sets `LifecycleState = 'DiscoveryRequired'`, and leaves `Components` empty rather than claiming `Existing` before stable IDs are observed;
6. validates the written file immediately and removes it if validation fails.

Run:

```powershell
./infra/src/scripts/New-TenantManifest.ps1 -TenantAlias caldova25156897
```

Expected: creates `infra/src/config/tenants/caldova25156897.psd1`, prints the assigned suffix and naming root, and never prints credential material.

- [ ] **Step 6: Run tenant tests to verify GREEN**

Run:

```powershell
Invoke-Pester infra/tests/pester/TenantConfiguration.Tests.ps1,infra/tests/pester/Naming.Tests.ps1 -Output Detailed
```

Expected: 5 tests passed, 0 failed.

- [ ] **Step 7: Commit tenant configuration foundation**

```powershell
git add -- infra/src/config infra/src/scripts/modules infra/src/scripts/New-TenantManifest.ps1 infra/tests/pester/TenantConfiguration.Tests.ps1 infra/tests/pester/Naming.Tests.ps1
git commit -m "feat: add tenant configuration contract" -- infra/src/config infra/src/scripts/modules infra/src/scripts/New-TenantManifest.ps1 infra/tests/pester/TenantConfiguration.Tests.ps1 infra/tests/pester/Naming.Tests.ps1
```

### Task 3: Implement Normalized Multi-Service Discovery

**Files:**
- Create: `infra/src/config/schemas/discovery.schema.json`
- Create: `infra/src/scripts/Invoke-TenantDiscovery.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-DiscoveryEvidence.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-DiscoveryEvidence.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-TenantIntent.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-ProhibitedData.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Invoke-BoundedRetry.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-GitHubDiscovery.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-EntraDiscovery.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDiscovery.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-AzureDevOpsDiscovery.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Get-PowerPlatformDiscovery.ps1`
- Create: `infra/tests/fixtures/discovery/github.json`
- Create: `infra/tests/fixtures/discovery/entra.json`
- Create: `infra/tests/fixtures/discovery/azure.json`
- Create: `infra/tests/fixtures/discovery/azure-devops.json`
- Create: `infra/tests/fixtures/discovery/power-platform.json`
- Create: `infra/tests/pester/DiscoveryNormalization.Tests.ps1`
- Create: `infra/tests/pester/EvidenceSecurity.Tests.ps1`
- Create: `infra/tests/pester/EvidenceGate.Tests.ps1`
- Create: `infra/tests/pester/IntentGate.Tests.ps1`

- [ ] **Step 1: Create synthetic fixtures and failing normalization tests**

Each fixture uses synthetic identifiers and contains one expected resource plus fields that must never enter normalized output (`accessToken`, `clientSecret`, `authorizationHeader`, `connectionString`, and an unapproved email address).

Create `DiscoveryNormalization.Tests.ps1` to assert that `ConvertTo-DiscoveryEvidence` returns exactly five services named `GitHub`, `Entra`, `Azure`, `AzureDevOps`, and `PowerPlatform`; each service has `Found`, `Missing`, `Unauthorized`, `Unavailable`, or `Ambiguous` status, stable IDs, source API, collected UTC time, and response SHA-256.

Create `EvidenceSecurity.Tests.ps1` to serialize normalized output and assert it does not match:

```regex
(?i)(access[_-]?token|refresh[_-]?token|client[_-]?secret|authorization:\s*bearer|AccountKey=|SharedAccessSignature=|-----BEGIN .*PRIVATE KEY-----|sig=)
```

Create `EvidenceGate.Tests.ps1` to assert that evidence older than 24 hours, mixed run IDs, or any required service with `Unauthorized`, `Unavailable`, or `Ambiguous` is rejected.

Create `IntentGate.Tests.ps1` to assert that `Existing` requires an exact stable-ID match and `Create` is rejected when discovery finds a conflicting or ambiguous object.

- [ ] **Step 2: Run discovery tests to verify RED**

Run:

```powershell
Invoke-Pester infra/tests/pester/DiscoveryNormalization.Tests.ps1,infra/tests/pester/EvidenceSecurity.Tests.ps1,infra/tests/pester/EvidenceGate.Tests.ps1,infra/tests/pester/IntentGate.Tests.ps1 -Output Detailed
```

Expected: FAIL because discovery functions and schema do not exist.

- [ ] **Step 3: Implement the allowlisted discovery schema and gates**

`discovery.schema.json` uses Draft 2020-12 and `additionalProperties: false`. Require `SchemaVersion`, `ToolVersion`, `RunId`, `CollectionStartedUtc`, `CollectionCompletedUtc`, `TenantAlias`, `TenantId`, `Principal`, and the five named service results. A resource record permits only `Type`, `Id`, `Name`, `Url`, `Scope`, `Status`, and `EvidenceReference`.

`ConvertTo-DiscoveryEvidence` constructs this allowlisted shape from each service adapter. It never serializes arbitrary response objects. `Test-ProhibitedData` performs the secondary denylist scan before any write. `Test-DiscoveryEvidence` implements the 24-hour and service-completeness gates. `Test-TenantIntent` compares stable IDs and explicit modes.

- [ ] **Step 4: Implement read-only service adapters**

Each adapter accepts a tenant configuration and injected request scriptblock for testing. Production request paths are:

- GitHub: `gh api repos/urruegg/caldova-hr-frontier`, the repository OIDC customization endpoint, rulesets, environments, variables, actions permissions, workflows, and collaborator permission; normalize the owner ID, repository ID, immutable-subject settings, and `sub_claim_prefix`, and do not request secret values.
- Entra: Microsoft Graph v1.0 application, service-principal, and federated-identity-credential reads filtered by reviewed IDs.
- Azure: Azure Resource Graph for resources plus Azure ARM reads for role assignments, policy assignments, diagnostic settings, provider state, and subscription identity.
- Azure DevOps: organization connection data and Project `Caldova HR Frontier` through API `7.1`, plus repositories, service endpoints, environments, pipelines, checks, and effective permissions available to the principal.
- Power Platform: interactive local discovery uses supported administration API reads for environment IDs, URLs, types, states, Managed Environment status, and tenant governance metadata. OIDC discovery consumes three allowlisted `who-am-i` probe results and compares their URLs with the stable environment IDs from committed evidence. If app-only access is unsupported or unconsented, return `Unauthorized` and fail closed rather than falling back to a credential.

Use `Invoke-BoundedRetry` only for `408`, `429`, and `5xx`, honor `Retry-After`, cap at five attempts, and never retry authorization failures.

- [ ] **Step 5: Add the local and OIDC-compatible discovery entry point**

`Invoke-TenantDiscovery.ps1` accepts `-TenantAlias`, `-AuthenticationMode Interactive|ExistingContext`, optional `-PowerPlatformProbePath`, and `-OutputPath`. Interactive mode runs `az login --tenant $configuration.TenantId` and verifies the resulting account UPN equals the configured AdminUpn; it must not use device-code or username/password flow. ExistingContext verifies tenant, subscription, and service-principal client IDs already established by GitHub OIDC and requires the workflow-generated Power Platform probe file.

The script calls all adapters, normalizes, validates, serializes BOM-free UTF-8, and writes only to `infra/evidence/discovery/${tenantAlias}.json` or a caller-supplied temporary path. It does not commit or push.

- [ ] **Step 6: Run discovery tests to verify GREEN**

Run:

```powershell
Invoke-Pester infra/tests/pester/DiscoveryNormalization.Tests.ps1,infra/tests/pester/EvidenceSecurity.Tests.ps1,infra/tests/pester/EvidenceGate.Tests.ps1,infra/tests/pester/IntentGate.Tests.ps1 -Output Detailed
```

Expected: all discovery tests pass.

- [ ] **Step 7: Commit discovery implementation**

```powershell
git add -- infra/src/config/schemas/discovery.schema.json infra/src/scripts/Invoke-TenantDiscovery.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/fixtures/discovery infra/tests/pester/DiscoveryNormalization.Tests.ps1 infra/tests/pester/EvidenceSecurity.Tests.ps1 infra/tests/pester/EvidenceGate.Tests.ps1 infra/tests/pester/IntentGate.Tests.ps1
git commit -m "feat: add evidence-based tenant discovery" -- infra/src/config/schemas/discovery.schema.json infra/src/scripts/Invoke-TenantDiscovery.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/fixtures/discovery infra/tests/pester/DiscoveryNormalization.Tests.ps1 infra/tests/pester/EvidenceSecurity.Tests.ps1 infra/tests/pester/EvidenceGate.Tests.ps1 infra/tests/pester/IntentGate.Tests.ps1
```

### Task 4: Implement Attended Entra and GitHub Trust Setup

**Files:**
- Create: `infra/src/scripts/Initialize-TenantTrust.ps1`
- Create: `infra/tests/pester/TenantTrust.Tests.ps1`

- [ ] **Step 1: Write failing trust-plan tests**

Create `TenantTrust.Tests.ps1` with mocked `az` and `gh` command adapters. Assert that `Initialize-TenantTrust.ps1 -WhatIf` plans exactly:

1. a single-tenant app registration;
2. its service principal;
3. no password or certificate credential;
4. one federated credential with issuer `https://token.actions.githubusercontent.com`, audience `api://AzureADTokenExchange`, and exact immutable Environment subject derived from the reviewed GitHub owner and repository names and IDs;
5. one `bootstrap-${tenantAlias}` GitHub Environment restricted to `main`;
6. required reviewer `urruegg` with `prevent_self_review = false`;
7. Dynamics CRM `user_impersonation` and Microsoft Graph `Application.Read.All` app permissions with attended admin consent;
8. Azure DevOps Basic access plus membership in the existing project's Readers group;
9. an application-user prerequisite for each of the three existing Power Platform environments with only the minimum role needed for `who-am-i` and approved metadata reads;
10. only `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` Environment variables;
11. API read-back of every created or existing object.

- [ ] **Step 2: Run trust tests to verify RED**

Run:

```powershell
Invoke-Pester infra/tests/pester/TenantTrust.Tests.ps1 -Output Detailed
```

Expected: FAIL because `Initialize-TenantTrust.ps1` does not exist.

- [ ] **Step 3: Implement the attended trust entry point**

Create `Initialize-TenantTrust.ps1` with `SupportsShouldProcess`. It:

1. imports the tenant configuration;
2. verifies interactive Azure tenant/admin context and authenticated GitHub repository-admin permission, then reads repository metadata and OIDC customization and requires the reviewed owner/repository names and IDs, `use_default: true`, `use_immutable_subject: true`, and exact `sub_claim_prefix`;
3. finds an app by stable configured object ID or exact display name `$configuration.NamingRoot-github-bootstrap`;
4. fails `Ambiguous` when multiple candidates exist;
5. creates the single-tenant app with `az ad app create --sign-in-audience AzureADMyOrg` only when Mode is `Create`;
6. creates the service principal with `az ad sp create --id $application.appId` when missing;
7. verifies `passwordCredentials` and `keyCredentials` are empty;
8. adds or validates Dynamics CRM `user_impersonation` and Microsoft Graph `Application.Read.All`, then requires the interactive administrator to grant consent;
9. creates or validates the exact federated credential using `az ad app federated-credential create`;
10. resolves the reviewer ID with `gh api users/urruegg`;
11. creates or updates the GitHub Environment through `PUT /repos/urruegg/caldova-hr-frontier/environments/$configuration.GitHub.EnvironmentName` with `prevent_self_review: false`, required reviewer, and protected-branch policy;
12. writes the three non-secret Environment variables with `gh variable set --env`;
13. creates or validates Azure DevOps Basic entitlement for the service-principal object ID and membership in the existing `Caldova HR Frontier` project Readers group, only when reviewed intent is `Create`;
14. reads back and compares all automated properties;
15. prints only object IDs, names, status, and the attended Power Platform application-user action.

The script never calls an app-credential creation command.

- [ ] **Step 4: Define the attended Power Platform access checkpoint**

Following Microsoft's OIDC/FIC tutorial, the tenant administrator adds the reviewed Entra application as an application user in each of the three existing Tenant 1 environments. Assign only the minimum existing security role that permits `who-am-i` and approved environment metadata reads; do not assign System Administrator, create a new security role, query Dataverse business data, or create an environment.

This is a live Power Platform access change. At execution time, stop and obtain explicit user approval before each environment update. Record each application-user object ID and role in the reviewed tenant manifest. If the minimum role cannot support the OIDC probe, stop and raise a design change; do not fall back to a client secret or a broad administrator role.

- [ ] **Step 5: Run trust tests to verify GREEN**

Run:

```powershell
Invoke-Pester infra/tests/pester/TenantTrust.Tests.ps1 -Output Detailed
```

Expected: all trust tests pass.

- [ ] **Step 6: Commit trust setup**

```powershell
git add -- infra/src/scripts/Initialize-TenantTrust.ps1 infra/tests/pester/TenantTrust.Tests.ps1
git commit -m "feat: add attended OIDC trust bootstrap" -- infra/src/scripts/Initialize-TenantTrust.ps1 infra/tests/pester/TenantTrust.Tests.ps1
```

### Task 5: Implement the Subscription Baseline Bicep

**Files:**
- Create: `infra/src/bicep/bicepconfig.json`
- Create: `infra/src/bicep/main.bicep`
- Create: `infra/src/bicep/modules/resource-group.bicep`
- Create: `infra/src/bicep/modules/log-analytics-workspace.bicep`
- Create: `infra/src/bicep/modules/activity-log-diagnostics.bicep`
- Create: `infra/src/bicep/modules/validation-role.bicep`
- Create: `infra/src/bicep/modules/subscription-policy-assignments.bicep`
- Create: `infra/src/scripts/New-TenantBicepParameters.ps1`
- Create: `infra/tests/pester/BicepComposition.Tests.ps1`

- [ ] **Step 1: Write failing Bicep composition tests**

Create `BicepComposition.Tests.ps1` to assert:

- `main.bicep` contains `targetScope = 'subscription'`;
- the entry point uses a closed user-defined `tenantConfiguration` type;
- module declarations omit explicit deployment names;
- the five approved modules are referenced;
- policy assignments default to an empty typed array;
- no resource type outside `Microsoft.Resources/resourceGroups`, `Microsoft.OperationalInsights/workspaces`, `Microsoft.Insights/diagnosticSettings`, `Microsoft.Authorization/roleDefinitions`, and `Microsoft.Authorization/roleAssignments` appears;
- no `Microsoft.ManagedIdentity`, Key Vault, storage, App Service, Functions, networking, or application runtime type appears;
- `az bicep build --file infra/src/bicep/main.bicep --stdout` exits zero.

- [ ] **Step 2: Run Bicep tests to verify RED**

Run:

```powershell
Invoke-Pester infra/tests/pester/BicepComposition.Tests.ps1 -Output Detailed
```

Expected: FAIL because the Bicep files do not exist.

- [ ] **Step 3: Implement typed subscription composition**

Create `main.bicep` with this interface:

```bicep
targetScope = 'subscription'

type tenantConfiguration = {
  tenantAlias: string
  location: string
  namingRoot: string
  platformResourceGroupName: string
  logAnalyticsWorkspaceName: string
  validationRoleName: string
  validationPrincipalId: string
  policyAssignments: policyAssignmentConfiguration[]
}

type policyAssignmentConfiguration = {
  name: string
  definitionId: string
  displayName: string
  parameters: object
}

@description('Reviewed non-secret tenant subscription baseline configuration.')
param tenant tenantConfiguration
```

Declare modules without explicit `name` fields. Create the platform resource group at subscription scope, scope the workspace module to that resource group, configure subscription Activity Log diagnostics to the workspace, declare a deterministic custom deployment-validation role and assignment at subscription scope, and pass `tenant.policyAssignments` to the empty policy module.

The validation role permits only resource reads plus `Microsoft.Resources/deployments/read`, `Microsoft.Resources/deployments/validate/action`, and `Microsoft.Resources/deployments/whatIf/action`. It has no write or delete wildcard.

- [ ] **Step 4: Implement focused modules**

- `resource-group.bicep`: subscription-scoped resource group with location and standard tags.
- `log-analytics-workspace.bicep`: workspace with `PerGB2018`, 30-day retention, public ingestion/query settings explicitly reviewed for the bootstrap baseline.
- `activity-log-diagnostics.bicep`: subscription Activity Log categories sent to the workspace, with no storage/Event Hub destination.
- `validation-role.bicep`: deterministic role GUID from subscription ID and role name, closed read/validate/what-if permission set, deterministic assignment GUID from role/principal/subscription.
- `subscription-policy-assignments.bicep`: typed loop over the supplied array; Tenant 1 passes `[]`, producing no policy resource.

Use current stable API versions discovered through the Azure Bicep schema tools during implementation. If a planned property produces BCP036, BCP037, or BCP081, stop and correct it against the resource schema; do not suppress diagnostics.

- [ ] **Step 5: Generate `.bicepparam` from the reviewed manifest**

`New-TenantBicepParameters.ps1` loads the tenant manifest, derives the three resource names, accepts the discovered service-principal object ID, and writes `infra/src/bicep/params/${tenantAlias}.bicepparam`. For a synthetic example suffix and principal, the shape is:

```bicep
using '../main.bicep'

param tenant = {
  tenantAlias: 'caldova25156897'
  location: 'switzerlandnorth'
  namingRoot: 'cal-hr-agentic-a7k29x'
  platformResourceGroupName: 'rg-cal-hr-agentic-a7k29x-platform'
  logAnalyticsWorkspaceName: 'log-cal-hr-agentic-a7k29x'
  validationRoleName: 'cal-hr-agentic-a7k29x-deployment-validation'
  validationPrincipalId: '11111111-1111-1111-1111-111111111111'
  policyAssignments: []
}
```

The `a7k29x` suffix and all-ones GUID above are synthetic examples only. The script emits the committed Tenant 1 suffix and discovered service-principal object ID, validates all values against the manifest, and refuses to overwrite a file whose suffix or principal ID differs unless `-Replace` is explicitly supplied in a reviewed change.

- [ ] **Step 6: Run Bicep tests to verify GREEN**

Run:

```powershell
az bicep format --file infra/src/bicep/main.bicep
Get-ChildItem infra/src/bicep/modules -Filter *.bicep | ForEach-Object { az bicep format --file $_.FullName }
Invoke-Pester infra/tests/pester/BicepComposition.Tests.ps1 -Output Detailed
az bicep build --file infra/src/bicep/main.bicep --stdout | Out-Null
```

Expected: all tests pass and Bicep build exits zero without diagnostics.

- [ ] **Step 7: Commit Bicep composition**

```powershell
git add -- infra/src/bicep infra/src/scripts/New-TenantBicepParameters.ps1 infra/tests/pester/BicepComposition.Tests.ps1
git commit -m "feat: model tenant subscription baseline" -- infra/src/bicep infra/src/scripts/New-TenantBicepParameters.ps1 infra/tests/pester/BicepComposition.Tests.ps1
```

### Task 6: Implement Temporary RBAC Cleanup and What-If Boundary Validation

**Files:**
- Create: `infra/src/config/schemas/bootstrap-result.schema.json`
- Create: `infra/src/scripts/Grant-TemporaryBootstrapRoles.ps1`
- Create: `infra/src/scripts/Get-TemporaryBootstrapRoleState.ps1`
- Create: `infra/src/scripts/Invoke-TenantBootstrap.ps1`
- Create: `infra/src/scripts/Test-WhatIfBoundary.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Remove-TemporaryRoleAssignments.ps1`
- Create: `infra/tests/fixtures/what-if/allowed.json`
- Create: `infra/tests/fixtures/what-if/unexpected-type.json`
- Create: `infra/tests/fixtures/what-if/wrong-scope.json`
- Create: `infra/tests/pester/TemporaryRoleCleanup.Tests.ps1`
- Create: `infra/tests/pester/WhatIfBoundary.Tests.ps1`
- Create: `infra/tests/pester/Idempotency.Tests.ps1`

- [ ] **Step 1: Write failing cleanup and boundary tests**

Tests must prove:

- grant script returns exact role-assignment IDs for only `Contributor` and `Role Based Access Control Administrator` at the configured subscription;
- role-state discovery requires exactly one assignment for each temporary role and writes their exact IDs for the workflow;
- cleanup rejects role IDs not produced by the current run;
- cleanup deletes Contributor first and RBAC Administrator last;
- cleanup executes from `finally` after a simulated bootstrap failure;
- cleanup polls until both exact IDs are absent and fails on bounded timeout;
- repeated cleanup treats already-absent exact IDs as success;
- `allowed.json` passes with only approved type/scope/location changes;
- `unexpected-type.json` and `wrong-scope.json` fail with named offending resources.

- [ ] **Step 2: Run cleanup and boundary tests to verify RED**

Run:

```powershell
Invoke-Pester infra/tests/pester/TemporaryRoleCleanup.Tests.ps1,infra/tests/pester/WhatIfBoundary.Tests.ps1,infra/tests/pester/Idempotency.Tests.ps1 -Output Detailed
```

Expected: FAIL because scripts and functions do not exist.

- [ ] **Step 3: Implement temporary grants and exact-ID cleanup**

`Grant-TemporaryBootstrapRoles.ps1` is attended, requires subscription-owner or RBAC-administrator context, verifies the target principal from the tenant manifest, creates only the two temporary assignments, and writes their IDs and creation timestamps to a local bootstrap result file excluded from Git until normalized.

`Get-TemporaryBootstrapRoleState.ps1` runs after OIDC login, lists role assignments for the exact principal and subscription, requires exactly one Contributor and one Role Based Access Control Administrator assignment, rejects foreign scopes or duplicates, and writes their exact IDs to `$env:RUNNER_TEMP`. This is how the workflow obtains cleanup IDs; no local temporary file is transferred to GitHub.

`Remove-TemporaryRoleAssignments` accepts exactly two assignment IDs and the expected principal/scope. It reads each assignment first, validates principal, role definition, and scope, asks for ShouldProcess confirmation, deletes Contributor first and RBAC Administrator last, and polls read-only until both are absent.

- [ ] **Step 4: Implement bootstrap orchestration with unconditional cleanup**

`Invoke-TenantBootstrap.ps1` accepts `-TenantAlias`, `-EvidencePath`, `-ParameterFile`, `-TemporaryRoleStatePath`, and `-WhatIfOnly`. It validates configuration, evidence, intent, OIDC context, Bicep, and role state; runs:

```powershell
az deployment sub what-if `
  --location switzerlandnorth `
  --name "whatif-$TenantAlias-$env:GITHUB_RUN_ID" `
  --template-file infra/src/bicep/main.bicep `
  --parameters $ParameterFile `
  --result-format FullResourcePayloads `
  --no-pretty-print
```

It writes machine-readable output to a temporary file, invokes `Test-WhatIfBoundary.ps1`, and enters cleanup in `finally`. It contains no deployment-create command.

- [ ] **Step 5: Implement exact boundary validation**

`Test-WhatIfBoundary.ps1` parses JSON and allows only the five approved resource types. It validates Tenant 1 subscription ID, the one derived platform resource group, `switzerlandnorth`, deterministic names, and empty policy assignments. It rejects deletes, unsupported resource types, foreign scopes, foreign resource groups, other locations, and ignored/error diagnostics.

- [ ] **Step 6: Run cleanup and boundary tests to verify GREEN**

Run:

```powershell
Invoke-Pester infra/tests/pester/TemporaryRoleCleanup.Tests.ps1,infra/tests/pester/WhatIfBoundary.Tests.ps1,infra/tests/pester/Idempotency.Tests.ps1 -Output Detailed
```

Expected: all tests pass.

- [ ] **Step 7: Commit bootstrap safety controls**

```powershell
git add -- infra/src/config/schemas/bootstrap-result.schema.json infra/src/scripts/Grant-TemporaryBootstrapRoles.ps1 infra/src/scripts/Get-TemporaryBootstrapRoleState.ps1 infra/src/scripts/Invoke-TenantBootstrap.ps1 infra/src/scripts/Test-WhatIfBoundary.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/fixtures/what-if infra/tests/pester/TemporaryRoleCleanup.Tests.ps1 infra/tests/pester/WhatIfBoundary.Tests.ps1 infra/tests/pester/Idempotency.Tests.ps1
git commit -m "feat: gate tenant what-if and role cleanup" -- infra/src/config/schemas/bootstrap-result.schema.json infra/src/scripts/Grant-TemporaryBootstrapRoles.ps1 infra/src/scripts/Get-TemporaryBootstrapRoleState.ps1 infra/src/scripts/Invoke-TenantBootstrap.ps1 infra/src/scripts/Test-WhatIfBoundary.ps1 infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/fixtures/what-if infra/tests/pester/TemporaryRoleCleanup.Tests.ps1 infra/tests/pester/WhatIfBoundary.Tests.ps1 infra/tests/pester/Idempotency.Tests.ps1
```

### Task 7: Add Tenant Discovery and Bootstrap Workflows

**Files:**
- Create: `.github/workflows/discover-tenant.yml`
- Create: `.github/workflows/bootstrap-tenant.yml`
- Create: `infra/tests/pester/WorkflowContract.Tests.ps1`
- Modify: `.github/workflows/README.md`

- [ ] **Step 1: Write failing workflow contract tests**

Assert both workflows:

- use `workflow_dispatch` with required `tenantAlias` choice containing only `caldova25156897` in this sprint;
- derive `environment: bootstrap-${{ inputs.tenantAlias }}`;
- use `permissions: { id-token: write, contents: read }` and no other write permission;
- pin checkout to `11bd71901bbe5b1630ceea73d27597364c9af683`;
- pin Azure login to `a457da9ea143d694b1b9c7c869ebb04ebe844ef5`;
- pass `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` from Environment variables;
- contain no client secret, PAT, deployment create, automatic commit, or push;
- use one-tenant concurrency `bootstrap-${{ inputs.tenantAlias }}` with `cancel-in-progress: false`.

Assert `discover-tenant.yml` calls discovery only, runs Power Platform `who-am-i` against all three manifest URLs with `microsoft/powerplatform-actions/who-am-i@0e44beb5424af932af47250a2568eba4c259e3d8`, and uploads a redacted artifact with `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02`. Assert `bootstrap-tenant.yml` requires boolean input `confirmRoleCleanup`, rejects a false value before authentication, discovers the two exact temporary role IDs after OIDC login, validates committed evidence, runs Bicep build and `what-if`, calls boundary validation, and always calls exact-ID cleanup.

- [ ] **Step 2: Run workflow tests to verify RED**

Run:

```powershell
Invoke-Pester infra/tests/pester/WorkflowContract.Tests.ps1 -Output Detailed
```

Expected: FAIL because the workflows do not exist.

- [ ] **Step 3: Create the discovery workflow**

Create a Windows workflow with checkout, Azure OIDC login, pinned Pester install, environment/config cross-check, and:

```powershell
./infra/src/scripts/Invoke-TenantDiscovery.ps1 `
  -TenantAlias '${{ inputs.tenantAlias }}' `
  -AuthenticationMode ExistingContext `
  -PowerPlatformProbePath "$env:RUNNER_TEMP\power-platform-probes.json" `
  -OutputPath "$env:RUNNER_TEMP\discovery.json"
```

Before invoking the script, run the pinned Power Platform `who-am-i` action once for DEV, TEST, and PROD, using each URL from the validated manifest plus the same Environment client/tenant IDs and no client secret. Write only URL, stage, success status, UTC time, and action revision to `power-platform-probes.json`; do not capture action tokens or unrestricted output. Validate the normalized discovery with Pester and upload only `$env:RUNNER_TEMP\discovery.json`. Do not write into the checkout or open a PR automatically.

- [ ] **Step 4: Create the bootstrap workflow**

Create a Windows workflow with the same exact tenant/environment binding and a required boolean `confirmRoleCleanup` dispatch input whose default is `false`. The first step fails unless it is explicitly `true`. After OIDC login, call `Get-TemporaryBootstrapRoleState.ps1` to capture exact assignment IDs. Before `Invoke-TenantBootstrap.ps1`, require the committed evidence path and parameter file. Use `if: always()` on the cleanup step and pass the two discovered exact IDs. Never use `continue-on-error` for validation, what-if, boundary, or cleanup.

- [ ] **Step 5: Run workflow tests to verify GREEN**

Run:

```powershell
Invoke-Pester infra/tests/pester/WorkflowContract.Tests.ps1 -Output Detailed
```

Expected: all tests pass.

- [ ] **Step 6: Update workflow catalogue and commit**

Document manual inputs, Environment variables, OIDC permissions, evidence review, no-deployment boundary, cleanup gate, and artifact handling in `.github/workflows/README.md`.

Commit:

```powershell
git add -- .github/workflows/discover-tenant.yml .github/workflows/bootstrap-tenant.yml .github/workflows/README.md infra/tests/pester/WorkflowContract.Tests.ps1
git commit -m "ci: add tenant discovery and what-if workflows" -- .github/workflows/discover-tenant.yml .github/workflows/bootstrap-tenant.yml .github/workflows/README.md infra/tests/pester/WorkflowContract.Tests.ps1
```

### Task 8: Extend Repository Validation for Infrastructure Contracts

**Files:**
- Modify: `.github/cli/verify-repository-setup.ps1`
- Modify: `.github/cli/README.md`
- Modify: `README.md`
- Modify: `docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md`

- [ ] **Step 1: Add failing required-path and prohibited-command checks**

Extend the repository validator tests to require every Phase 3 schema, script, module, fixture, test, workflow, Bicep file, document, and Tenant 1 manifest. Add exact scans that reject:

```regex
az\s+deployment\s+sub\s+create|New-AzSubscriptionDeployment|client[_-]?secret|AZURE_CLIENT_SECRET|--password
```

from executable bootstrap/workflow files. Exclude synthetic secret-detection fixtures only by exact path.

- [ ] **Step 2: Run the validator to verify RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: FAIL until the new required paths and checks are integrated consistently.

- [ ] **Step 3: Integrate focused infrastructure suites**

Extend the validator while preserving all Superpowers and issue-form byte/index checks. Require:

- Tenant 1 manifest schema and naming derivation;
- five-service discovery schema and prohibited-data scan;
- exact immutable OIDC subject, reviewed GitHub owner/repository IDs, OIDC prefix, and Environment name;
- Bicep resource-type allowlist and successful build;
- workflow permission/action pins and no-deployment scan;
- infrastructure documentation metadata and links;
- no rejected `.gitkeep` paths;
- no Tenant 2 or Tenant 3 manifest.

Update CLI documentation and root README with Tenant 1's documented bootstrap entry points, Proposed Baseline status, and no-live-deployment scope.

- [ ] **Step 4: Complete Phase 3 intake review status**

Set the Phase 3 review to `Approved` only after every imported path has a target commit, all five source placeholders are absent, and all reconciliation decisions are recorded.

- [ ] **Step 5: Run the full local validation suite**

Run:

```powershell
Invoke-Pester .github/cli/tests,infra/tests/pester -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
az bicep build --file infra/src/bicep/main.bicep --stdout | Out-Null
git diff --check main...HEAD
git diff --exit-code -- .github/skills
```

Expected: all tests pass; validator prints its sole success line; Bicep builds; both Git checks are empty.

- [ ] **Step 6: Commit repository integration**

```powershell
git add -- .github/cli/verify-repository-setup.ps1 .github/cli/README.md README.md docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md
git commit -m "test: validate tenant bootstrap contracts" -- .github/cli/verify-repository-setup.ps1 .github/cli/README.md README.md docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md
```

### Task 9: Perform Attended Tenant 1 Discovery and Trust Bootstrap

**Files:**
- Create after review: `infra/evidence/discovery/caldova25156897.json`
- Modify after review: `infra/src/config/tenants/caldova25156897.psd1`
- Create after review: `infra/src/bicep/params/caldova25156897.bicepparam`

- [ ] **Step 1: Run attended local discovery**

Run outside any agent-mediated secret prompt:

```powershell
./infra/src/scripts/Invoke-TenantDiscovery.ps1 `
  -TenantAlias caldova25156897 `
  -AuthenticationMode Interactive `
  -OutputPath "$env:TEMP\caldova25156897-discovery.json"
```

The user completes browser authentication directly. Expected: all five services return `Found` or `Missing`; no required service is `Unauthorized`, `Unavailable`, or `Ambiguous`.

- [ ] **Step 2: Review normalized evidence before copying it into the repository**

Run:

```powershell
Invoke-Pester infra/tests/pester/EvidenceSecurity.Tests.ps1 -Output Detailed
Get-Content "$env:TEMP\caldova25156897-discovery.json" -Raw | ConvertFrom-Json | Select-Object TenantAlias,TenantId,RunId,CollectionStartedUtc
```

Manually inspect every normalized field. Do not proceed if a secret, personal name, unapproved email address, unrestricted membership list, or raw token appears.

- [ ] **Step 3: Copy evidence and review `Existing/Create` decisions**

Copy the reviewed normalized file to `infra/evidence/discovery/caldova25156897.json`. Update the Tenant 1 manifest with stable IDs and explicit modes supported by the evidence. Keep the supplied Azure DevOps project and Power Platform URLs as `Existing` only when stable IDs match.

Open a pull request containing only the evidence and manifest decision update. Merge it after review before trust creation.

- [ ] **Step 4: Dry-run and execute attended trust setup**

Run:

```powershell
./infra/src/scripts/Initialize-TenantTrust.ps1 -TenantAlias caldova25156897 -WhatIf
./infra/src/scripts/Initialize-TenantTrust.ps1 -TenantAlias caldova25156897
```

Expected: exact app/SP/FIC/Environment plan first, then create-or-validate output with no credential. Read-back must match the exact immutable OIDC subject and GitHub-reported prefix.

- [ ] **Step 5: Generate reviewed Bicep parameters**

Run:

```powershell
$config = Import-PowerShellDataFile infra/src/config/tenants/caldova25156897.psd1
./infra/src/scripts/New-TenantBicepParameters.ps1 `
  -TenantAlias caldova25156897 `
  -ValidationPrincipalId $config.Components.EntraServicePrincipal.Id
az bicep build-params --file infra/src/bicep/params/caldova25156897.bicepparam --stdout | Out-Null
```

The object ID is copied from the reviewed manifest, not entered from memory. Expected: parameter build succeeds and policy assignments are empty.

- [ ] **Step 6: Commit reviewed evidence and trust identifiers**

Commit only after review:

```powershell
git add -- infra/evidence/discovery/caldova25156897.json infra/src/config/tenants/caldova25156897.psd1 infra/src/bicep/params/caldova25156897.bicepparam
git commit -m "chore: record Tenant 1 bootstrap evidence" -- infra/evidence/discovery/caldova25156897.json infra/src/config/tenants/caldova25156897.psd1 infra/src/bicep/params/caldova25156897.bicepparam
```

### Task 10: Run Tenant 1 OIDC Discovery and Subscription What-If

**Files:**
- Verify: committed Tenant 1 configuration and evidence
- Record outside Git: temporary role-assignment state and raw `what-if` output

- [ ] **Step 1: Merge implementation and evidence through pull request**

Run the full repository suite on the branch, push it, open a pull request, and merge only after required review. Do not activate the final ruleset yet.

- [ ] **Step 2: Run validator workflow on `main`**

Dispatch `Validate repository` on `main` and record the successful run URL. A failed or incomplete run blocks all remaining steps.

- [ ] **Step 3: Dispatch OIDC discovery for Tenant 1**

Dispatch `discover-tenant.yml` with `tenantAlias=caldova25156897`, approve `bootstrap-caldova25156897`, download the artifact, compare it with committed evidence, and create a reviewed evidence-update PR if the observed state changed.

- [ ] **Step 4: Grant temporary roles in an attended session**

Run:

```powershell
./infra/src/scripts/Grant-TemporaryBootstrapRoles.ps1 `
  -TenantAlias caldova25156897 `
  -OutputPath "$env:TEMP\caldova25156897-temporary-roles.json"
```

Expected: exactly two assignment IDs at Tenant 1 subscription scope. Keep this file outside Git.

- [ ] **Step 5: Approve cleanup deletion and dispatch bootstrap**

Review the two assignment IDs and obtain explicit user approval to delete those exact temporary role assignments. Immediately after approval, dispatch `bootstrap-tenant.yml` with `tenantAlias=caldova25156897` and `confirmRoleCleanup=true`, then approve the `bootstrap-caldova25156897` Environment gate. The workflow discovers and verifies the same exact IDs before any deletion.

If approval is withheld, do not dispatch the bootstrap workflow. An attended administrator must remove the assignments through a separately approved recovery action; they must not remain standing.

- [ ] **Step 6: Verify successful `what-if` and cleanup**

Expected workflow evidence:

- Bicep build succeeds;
- `what-if` exits zero;
- changes contain only the approved five resource types/scopes and no deletes;
- no Azure platform deployment occurs;
- exact Contributor assignment is absent;
- exact Role Based Access Control Administrator assignment is absent;
- steady-state custom validation role and assignment match the approved contract;
- workflow completes successfully.

Run independent read-back:

```powershell
$config = Import-PowerShellDataFile infra/src/config/tenants/caldova25156897.psd1
az role assignment list --assignee-object-id $config.Components.EntraServicePrincipal.Id --scope '/subscriptions/edb45a24-408d-47c4-bbc7-685b9b3fc017' --output json
```

Expected: neither temporary built-in role appears.

### Task 11: Activate and Verify Final GitHub Governance

**Files:**
- Create: `infra/src/config/github/main-ruleset.json`
- Create: `infra/src/config/schemas/github-ruleset.schema.json`
- Create: `infra/src/scripts/Enable-GitHubGovernance.ps1`
- Create: `infra/tests/pester/GitHubGovernance.Tests.ps1`
- Modify: `.github/agent-policy/BREAK_GLASS.md`

- [ ] **Step 1: Write failing GitHub governance tests**

Tests assert desired state includes:

- target `refs/heads/main`;
- active enforcement;
- branch deletion and force-push blocks;
- required pull request with one approval, stale-approval dismissal, CODEOWNERS review, and resolved conversations;
- required `Repository setup validation` status check, matching the explicit validator job name;
- repository-owner user `urruegg` as the administrator bypass actor with `bypass_mode: pull_request` only;
- no always-on bypass;
- exact Environment protection/read-back checks;
- no mutation unless validator run and Tenant 1 bootstrap result are supplied and successful.

- [ ] **Step 2: Run governance tests to verify RED**

Run:

```powershell
Invoke-Pester infra/tests/pester/GitHubGovernance.Tests.ps1 -Output Detailed
```

Expected: FAIL because desired state and script do not exist.

- [ ] **Step 3: Add reviewed ruleset desired state**

Create a closed JSON schema and `main-ruleset.json` containing the exact settings above. Represent the administrator bypass intent as:

```json
{
  "actorType": "User",
  "login": "urruegg",
  "bypassMode": "pull_request"
}
```

`Enable-GitHubGovernance.ps1` resolves the numeric actor ID with `gh api users/urruegg --jq .id`, verifies that `gh api repos/urruegg/caldova-hr-frontier/collaborators/urruegg/permission --jq .user.permissions.admin` is `true`, and emits the GitHub REST payload with `actor_type: User`, the resolved `actor_id`, and `bypass_mode: pull_request`. `OrganizationAdmin` is forbidden because GitHub documents it as inapplicable to personal repositories.

- [ ] **Step 4: Implement fail-closed governance activation**

`Enable-GitHubGovernance.ps1` accepts `-Repository`, `-ValidatorRunId`, `-BootstrapRunId`, and `-DesiredStatePath`. It:

1. verifies both run IDs belong to `main`, concluded `success`, and match the expected workflows;
2. verifies temporary Azure roles are absent through supplied normalized bootstrap evidence;
3. reads current rulesets and fails on ambiguity;
4. displays the exact proposed GitHub mutation under `-WhatIf`;
5. creates or updates the ruleset only under ShouldProcess;
6. reads back the ruleset and all three configured bootstrap Environments;
7. compares every reviewed field and fails on drift;
8. never enables direct-push bypass.

- [ ] **Step 5: Run governance tests to verify GREEN**

Run:

```powershell
Invoke-Pester infra/tests/pester/GitHubGovernance.Tests.ps1 -Output Detailed
```

Expected: all tests pass.

- [ ] **Step 6: Commit governance code through a pull request**

```powershell
git add -- infra/src/config/github infra/src/config/schemas/github-ruleset.schema.json infra/src/scripts/Enable-GitHubGovernance.ps1 infra/tests/pester/GitHubGovernance.Tests.ps1 .github/agent-policy/BREAK_GLASS.md
git commit -m "feat: codify final GitHub governance" -- infra/src/config/github infra/src/config/schemas/github-ruleset.schema.json infra/src/scripts/Enable-GitHubGovernance.ps1 infra/tests/pester/GitHubGovernance.Tests.ps1 .github/agent-policy/BREAK_GLASS.md
```

Merge and rerun the validator workflow on `main` before activation.

- [ ] **Step 7: Dry-run and activate the ruleset as the final GitHub mutation**

Run:

```powershell
$validatorRunId = gh run list --workflow validate-repository.yml --branch main --status success --limit 1 --json databaseId --jq '.[0].databaseId'
$bootstrapRunId = gh run list --workflow bootstrap-tenant.yml --branch main --status success --limit 1 --json databaseId --jq '.[0].databaseId'
./infra/src/scripts/Enable-GitHubGovernance.ps1 `
  -Repository 'urruegg/caldova-hr-frontier' `
  -ValidatorRunId $validatorRunId `
  -BootstrapRunId $bootstrapRunId `
  -DesiredStatePath 'infra/src/config/github/main-ruleset.json' `
  -WhatIf
```

Copy both run IDs from GitHub Actions, not from agent output. Review the exact plan, then rerun without `-WhatIf` only after explicit user approval.

- [ ] **Step 8: Verify final GitHub state through API read-back**

Run:

```powershell
gh api repos/urruegg/caldova-hr-frontier/rulesets
gh api repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897
```

Expected: active `main` protection, PR-only administrator bypass, required validator check, and Tenant 1 Environment settings match desired state. Tenant 2 and Tenant 3 Environments are created only when their tenant manifests and attended onboarding are approved; absence is valid in this sprint.

### Task 12: Complete Final Sprint Verification

**Files:**
- Verify: all files and external control-plane state introduced by all three plans

- [ ] **Step 1: Run local executable validation**

Run:

```powershell
Invoke-Pester .github/cli/tests,infra/tests/pester -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
az bicep build --file infra/src/bicep/main.bicep --stdout | Out-Null
git diff --check main...HEAD
git status --short
```

Expected: all tests pass; validator sole output is `Repository setup validation passed.`; Bicep builds; diff check and status are empty.

- [ ] **Step 2: Verify acceptance evidence**

Record links or command output proving:

- all three phase review documents are Approved;
- the metadata/header policy and docs-agent are active;
- the source inventory remains 45 files and 485126 bytes;
- Tenant 1 five-service discovery is complete and secret-free;
- Tenant 1 OIDC login succeeded without stored credential;
- Tenant 1 subscription `what-if` succeeded within the approved boundary;
- both temporary Azure roles are absent;
- validator workflow succeeded on `main` before ruleset activation;
- API read-back matches ruleset and Environment desired state;
- no Azure platform resource deployment, Power Platform solution deployment, Tenant 2 provisioning, or Tenant 3 provisioning occurred.

- [ ] **Step 3: Request final code and security review**

Use the repository review workflow with focus on authorization cleanup, OIDC subject binding, evidence allowlisting, Bicep scope, workflow permissions, and preservation of vendored Superpowers bytes. Resolve findings and rerun every affected check before claiming completion.