# Runbook Foundation and Windows 11 Workstation Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure runbook contracts and Windows 11 developer workstation readiness |
| **References** | [Operational Runbooks Design](../../specs/2026-09-26-operational-runbooks-design.md), [Documentation Policy](../../README.md), [Infrastructure Domain](../../../infra/README.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the shared, digest-bound runbook contracts and an independently shippable Windows 11 workstation assessment and initialization runbook that later cloud-foundation and customer-handover plans can consume.

**Architecture:** A closed, reviewed JSON policy defines every workstation prerequisite and permitted installation/configuration operation. Every operational runbook is launched interactively from a Windows 11 developer workstation in PowerShell; thin entry points consume focused public helpers from the existing `Caldova.HrFrontier.Bootstrap` module for safe external output, deterministic JSON and digests, execution-manifest validation, and allowlist-based evidence. Assessment remains read-only, while initialization requires `-Apply`, a matching approved digest, fresh state, and `ShouldProcess` before each allowlisted mutation; later tenant operations reuse attended device-code contexts rather than GitHub Actions, OIDC workloads, secrets, or unattended identities.

**Tech Stack:** Windows 11, Windows PowerShell 5.1, PowerShell 7, Pester 5.7.1, JSON Schema draft 2020-12, Git, WinGet, Visual Studio Code, GitHub CLI, Azure CLI and Bicep, Azure Developer CLI, Power Platform CLI, GitHub Copilot, and the existing `Caldova.HrFrontier.Bootstrap` PowerShell module.

**Spec:** `docs/specs/2026-09-26-operational-runbooks-design.md`

## Global Constraints

- This increment covers only shared runbook contracts and Windows 11 developer workstation readiness; cloud service foundation and customer handover implementation are excluded.
- Every runbook and script is invoked interactively by a named operator from a Windows 11 developer workstation using Windows PowerShell 5.1 or PowerShell 7 as explicitly documented. A runbook must refuse a CI runner, background service, scheduled task, remoting session, or other non-interactive execution host.
- GitHub Actions, reusable workflows, workflow dispatch, hosted/self-hosted runners, and OIDC workload identities must never prepare or mutate a tenant. Do not add or modify a file under `.github/workflows/`.
- Device-code or supported browser/device login is the preferred attended authentication model: Azure CLI uses `az login --tenant <tenantId> --use-device-code`; GitHub CLI uses its supported web/device flow; Azure DevOps CLI reuses the verified Azure CLI delegated user context; PAC uses a named device-code authentication profile only where current Microsoft Learn and `pac auth create help` confirm support.
- Authentication is a manual attended boundary. Scripts may invoke documented interactive login commands only in later authentication-specific runbooks; workstation assessment and initialization never sign in. Every authenticated operation must read back and compare the exact account, tenant, subscription, GitHub host/user, Azure DevOps organization/project, Power Platform profile, and environment required by reviewed intent before continuing.
- Scripts must not define password, token, credential, client-secret, certificate-secret, or personal-access-token parameters; accept such values on stdin; read them from repository files; print them; add them to command lines; serialize them; or persist them. Tokens remain solely in supported CLI credential stores and process memory.
- Sign-out and cleanup are attended and explicit: GitHub CLI host logout, Azure CLI logout plus account-cache clear where appropriate, and deletion of the exact PAC authentication profile created for the run. Cleanup is read back and never silently broadens to unrelated profiles.
- GitHub configuration is performed only by local PowerShell calling documented GitHub REST endpoints through `gh api` or an equivalent local authenticated `gh` command. No GitHub workflow is an operational control plane.
- Default execution is assessment/planning only. The sole permitted output is a canonical plan, execution manifest, or redacted evidence record in an approved external report directory.
- Mutation requires explicit `-Apply`, a fresh schema-valid execution manifest, approval matching its lowercase SHA-256 digest, source-commit and assessment-digest matches, a displayed change summary, and `ShouldProcess`; `-WhatIf` always wins.
- Never install or upgrade a package, alter persistent `PATH`, authenticate, accept terms, purchase or assign a license, weaken execution policy, disable security tooling, or change organization policy during assessment, refusal, declined-confirmation, or `-WhatIf` paths.
- Installation and configuration are limited to exact identifiers in `infra/src/config/runbooks/workstation-prerequisites.json`; unknown keys, tools, package sources, package IDs, extensions, and actions fail closed.
- Package and extension identifiers must be verified against current official Microsoft Learn, GitHub Docs, WinGet, PowerShell Gallery, Visual Studio Marketplace, Azure CLI, or product-owned package metadata before the policy is committed.
- Windows PowerShell must be exactly 5.1, Pester must be exactly 5.7.1, and the supported workstation platform is Windows 11. Other version checks use the explicit policy mode `Present` unless the reviewed policy states an exact version.
- Reports default below `%LOCALAPPDATA%\CaldovaHrFrontier\runbook-evidence\<runId>\` and must resolve outside every Git working tree and outside any supplied staging root.
- JSON is UTF-8 without a byte-order mark, uses ordinally sorted object keys, retains array order, uses a stable depth of 30, and ends with one LF. Digests are lowercase SHA-256 over those exact UTF-8 bytes.
- Evidence is constructed from an allowlist. Tokens, authorization headers, cookies, secrets, private keys, connection strings, raw service responses, SharePoint content, HR data, and unreviewed command output are never serialized.
- Interactive sign-in, device-code entry, MFA, Conditional Access, license/terms acceptance, elevation, restart, and organization-managed policy remain attended boundaries. A required boundary is reported as `Manual` or `Blocked`, never bypassed; MFA or Conditional Access denial is a terminal refusal for that run.
- Repository-bundled Superpowers skills and custom agents are verified in place, not machine-installed. The absent `.github/plugins/` catalogue is verified as absent; no plugin is inferred or installed. Never edit vendored content under `.github/skills/`.
- Tests use synthetic fixtures, temporary external directories, and injected native-command runners. They do not authenticate, contact a tenant, install software, or contain real tenant/customer/HR data.
- Existing exported module functions and existing bootstrap behavior remain backward compatible.
- ADR-0001, ADR-0002, and ADR-0003 remain Proposed Baseline. This increment does not promote them or implement cloud mutation, tenant creation, production deployment, customer export, repository publication, source-history rewriting, or personal-data handling.
- Each checkbox is one 2–5 minute action. Stop after each command, compare the stated result, and do not combine red, green, or commit gates.

## File Map

| File | Responsibility |
|---|---|
| `infra/src/config/runbooks/workstation-prerequisites.json` | Reviewed workstation tool, extension, repository-asset, and allowlisted action policy. |
| `infra/src/config/schemas/workstation-prerequisites.schema.json` | Closed draft 2020-12 schema for the prerequisite policy. |
| `.vscode/extensions.json` | Repository recommendations copied exactly from the approved VS Code extension subset in the policy. |
| `infra/tests/fixtures/runbooks/native-command-results.json` | Synthetic outputs and exit codes for fixture-backed command execution. |
| `infra/tests/fixtures/runbooks/workstation-prerequisites.invalid.json` | Closed-schema negative fixture containing one unrecognized property. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/ConvertTo-CanonicalJsonValue.ps1` | Recursive ordinal key normalization used before serialization and hashing. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-RunbookPathWithin.ps1` | Canonical path containment check with reparse-point refusal. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Update-RunbookProcessPath.ps1` | In-process machine/user `PATH` merge and ordinal-insensitive de-duplication; no persistent write. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-RunbookReportPath.ps1` | Safe external report path resolution. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-CanonicalJson.ps1` | Atomic canonical BOM-free JSON writer. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-RunbookContentDigest.ps1` | SHA-256 generation over canonical JSON bytes. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-RunbookExecutionManifest.ps1` | Deterministic execution-manifest creation and digest binding. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-RunbookExecutionManifest.ps1` | Closed, fresh, approved manifest validation. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-RunbookEvidenceRecord.ps1` | Allowlist-based evidence projection and redaction refusal. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1` | Public function export contract. |
| `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1` | Runtime export list. |
| `infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1` | Read-only Windows 11 and prerequisite assessment with structured output. |
| `infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1` | Non-mutating plan by default and tightly gated allowlisted Apply orchestration. |
| `infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1` | Policy/schema/identifier and editor recommendation contracts. |
| `infra/tests/pester/RunbookContracts.Tests.ps1` | Shared path, JSON, digest, manifest, evidence, and process-`PATH` contracts. |
| `infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1` | Fixture-backed assessment and no-auth/no-mutation tests. |
| `infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1` | Red/green mutation-gate, read-back, and recovery tests. |
| `infra/tests/pester/RunbookStaticSafety.Tests.ps1` | AST/static proof of `ShouldProcess` and prohibited-operation boundaries. |
| `infra/tests/pester/RunbookDocumentation.Tests.ps1` | Runbook metadata, required-section, official-reference, and relative-link contracts. |
| `infra/docs/runbooks/README.md` | Shared runbook state machine, terminology, ownership, evidence, and escalation contract. |
| `infra/docs/runbooks/01-developer-workstation.md` | Service-owner/admin procedure for preview, approval, apply, read-back, and recovery. |
| `infra/README.md` | Infrastructure documentation map and current runbook ownership boundary. |

No validation-workflow edit is permitted. The existing `.github/workflows/validate-repository.yml` may continue to validate repository source, but it is not a runbook, must not authenticate, and must never prepare a tenant. No source-inventory evidence file is changed because the new files are repository implementation artifacts, not an imported architecture-source snapshot.

---

### Task 1: Establish the Reviewed Workstation Prerequisite Policy

**Files:**
- Create: `infra/src/config/runbooks/workstation-prerequisites.json`
- Create: `infra/src/config/schemas/workstation-prerequisites.schema.json`
- Create: `.vscode/extensions.json`
- Create: `infra/tests/fixtures/runbooks/native-command-results.json`
- Create: `infra/tests/fixtures/runbooks/workstation-prerequisites.invalid.json`
- Create: `infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1`

**Interfaces:**
- Consumes: Windows 11 platform contract and official-reference policy from `docs/specs/2026-09-26-operational-runbooks-design.md`.
- Produces: policy schema version `1.0`; tool keys `PowerShell7`, `WindowsPowerShell`, `Git`, `VisualStudioCode`, `GitHubCli`, `AzureCli`, `AzureDeveloperCli`, `PowerPlatformCli`, `Bicep`, `Pester`, and `GitHubCopilotCli`; Azure CLI extension `azure-devops`; VS Code extension IDs `ms-vscode.PowerShell`, `ms-azuretools.vscode-bicep`, `ms-azuretools.azure-dev`, `microsoft-IsvExpTools.powerplatform-vscode`, and `GitHub.copilot`; repository assets with `VerifyOnly` disposition.

- [ ] **Step 1: Verify every package-manager identifier without changing the workstation**

Run from an unelevated PowerShell 7 prompt:

```powershell
$wingetIds = @(
    'Microsoft.PowerShell',
    'Git.Git',
    'Microsoft.VisualStudioCode',
    'GitHub.cli',
    'Microsoft.AzureCLI',
    'Microsoft.Azd',
    'Microsoft.PowerAppsCLI',
    'GitHub.Copilot'
)
foreach ($id in $wingetIds) {
    winget show --exact --id $id --source winget
    if ($LASTEXITCODE -ne 0) { throw "Unverified WinGet identifier: $id" }
}
Find-Module Pester -Repository PSGallery -AllVersions |
    Where-Object Version -eq ([version]'5.7.1') |
    Select-Object -First 1 -ExpandProperty Name
az extension show --name azure-devops --output json
az devops project show --help | Out-Null
pac auth create help
pac auth select help
pac auth delete help
$vsCodeIds = @(
    'ms-vscode.PowerShell',
    'ms-azuretools.vscode-bicep',
    'ms-azuretools.azure-dev',
    'microsoft-IsvExpTools.powerplatform-vscode',
    'GitHub.copilot'
)
foreach ($id in $vsCodeIds) {
    $response = Invoke-WebRequest -UseBasicParsing `
        -Uri "https://marketplace.visualstudio.com/items?itemName=$id"
    if ($response.StatusCode -ne 200 -or $response.Content -notmatch [regex]::Escape($id)) {
        throw "Unverified Visual Studio Marketplace identifier: $id"
    }
}
```

Expected: every `winget show` exits `0` and displays the exact `Id`; `Find-Module` prints `Pester`; `az extension show` either exits `0` with `"name": "azure-devops"` or exits nonzero to show that the extension is not installed; installed Azure DevOps/PAC commands display current help; every official Marketplace request returns HTTP 200 and its exact extension ID. A missing installed Azure CLI extension does not invalidate its identifier when the Microsoft Learn reference confirms it. Record PAC device-code, profile selection, and exact-profile deletion syntax only when both installed help and Microsoft Learn agree.

Open and review these product-owned pages; record their direct URLs in the policy's `reference` fields:

```text
https://learn.microsoft.com/en-us/windows/package-manager/winget/
https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows
https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows
https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd
https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction
https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install
https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview
https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli
https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-extension-for-visual-studio-code
https://www.powershellgallery.com/packages/Pester/5.7.1
```

Expected: each page identifies the product or install mechanism used by the reviewed entry. If `GitHub.Copilot` is not confirmed by both GitHub Docs and `winget show`, set its policy `installDisposition` to `Manual` and omit an install action; do not substitute another package ID.

- [ ] **Step 2: Write the failing policy tests**

Create `infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1` with focused assertions:

```powershell
Set-StrictMode -Version Latest

Describe 'Workstation prerequisite policy' {
    BeforeAll {
        $script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:PolicyPath = Join-Path $script:Repo 'infra\src\config\runbooks\workstation-prerequisites.json'
        $script:SchemaPath = Join-Path $script:Repo 'infra\src\config\schemas\workstation-prerequisites.schema.json'
        $script:InvalidPath = Join-Path $script:Repo 'infra\tests\fixtures\runbooks\workstation-prerequisites.invalid.json'
        $script:Pwsh = (Get-Command pwsh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    }

    It 'validates the reviewed policy and rejects an unknown property with the closed schema' {
        & $script:Pwsh -NoProfile -Command {
            param($policy, $schema)
            if (-not (Test-Json -Json (Get-Content -Raw $policy) -SchemaFile $schema)) { exit 1 }
        } -args $script:PolicyPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0

        & $script:Pwsh -NoProfile -Command {
            param($fixture, $schema)
            if (Test-Json -Json (Get-Content -Raw $fixture) -SchemaFile $schema -ErrorAction SilentlyContinue) { exit 1 }
        } -args $script:InvalidPath, $script:SchemaPath
        $LASTEXITCODE | Should -Be 0
    }

    It 'contains the exact reviewed tool and extension allowlists' {
        $policy = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        @($policy.tools.id) | Should -Be @(
            'PowerShell7', 'WindowsPowerShell', 'Git', 'VisualStudioCode',
            'GitHubCli', 'AzureCli', 'AzureDeveloperCli', 'PowerPlatformCli',
            'Bicep', 'Pester', 'GitHubCopilotCli'
        )
        @($policy.azureCliExtensions.name) | Should -Be @('azure-devops')
        @($policy.vsCodeExtensions.id) | Should -Be @(
            'ms-vscode.PowerShell', 'ms-azuretools.vscode-bicep',
            'ms-azuretools.azure-dev', 'microsoft-IsvExpTools.powerplatform-vscode',
            'GitHub.copilot'
        )
    }

    It 'treats repository skills agents and plugins as verification-only assets' {
        $policy = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        @($policy.repositoryAssets.installDisposition | Select-Object -Unique) |
            Should -Be @('VerifyOnly')
        ($policy.repositoryAssets | Where-Object path -eq '.github/skills').expected |
            Should -Be 'Present'
        ($policy.repositoryAssets | Where-Object path -eq '.github/agents').expected |
            Should -Be 'Present'
        ($policy.repositoryAssets | Where-Object path -eq '.github/plugins').expected |
            Should -Be 'Absent'
    }

    It 'permits only attended delegated authentication and no workload identity' {
        $policy = Get-Content -Raw $script:PolicyPath | ConvertFrom-Json
        $policy.interactiveAuthentication.executionHost | Should -Be 'InteractiveWindows11PowerShell'
        $policy.interactiveAuthentication.allowUnattendedExecution | Should -BeFalse
        $policy.interactiveAuthentication.allowOidcWorkloadIdentity | Should -BeFalse
        $policy.interactiveAuthentication.allowCredentialParameters | Should -BeFalse
        @($policy.interactiveAuthentication.methods.service) |
            Should -Be @('Azure', 'GitHub', 'AzureDevOps', 'PowerPlatform')
        ($policy | ConvertTo-Json -Depth 20) |
            Should -Not -Match '(?i)(client.?secret|personal.?access.?token|federated.?credential)'
    }
}
```

- [ ] **Step 3: Run the policy tests to verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `workstation-prerequisites.json`, its schema, fixtures, and `.vscode/extensions.json` do not exist.

- [ ] **Step 4: Write the closed schema and reviewed policy**

The schema must set `additionalProperties: false` at the root and every nested object. Use these exact required root properties:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "schemaVersion",
    "platform",
    "interactiveAuthentication",
    "tools",
    "azureCliExtensions",
    "vsCodeExtensions",
    "repositoryAssets",
    "allowedActions"
  ]
}
```

Define `tools` as a non-empty array with `uniqueItems: true`; each entry requires `id`, `command`, `versionArguments`, `versionPolicy`, `installDisposition`, `install`, and `reference`. Restrict `versionPolicy.mode` to `Present` or `Exact`; require `versionPolicy.value` only for `Exact`. Restrict `install.kind` to `None`, `WinGet`, `PowerShellGallery`, or `AzureCliComponent`. A WinGet entry requires exact `source`, `packageId`, and `scope`; a gallery entry requires `repository`, `moduleName`, `requiredVersion`, and `scope`; a Bicep entry permits only `az bicep install`.

Create the policy with this reviewed action surface:

```json
{
  "$schema": "../schemas/workstation-prerequisites.schema.json",
  "schemaVersion": "1.0",
  "platform": {
    "productName": "Windows 11",
    "minimumBuild": 22000
  },
  "interactiveAuthentication": {
    "executionHost": "InteractiveWindows11PowerShell",
    "allowUnattendedExecution": false,
    "allowOidcWorkloadIdentity": false,
    "allowCredentialParameters": false,
    "methods": [
      {
        "service": "Azure",
        "mode": "DeviceCode",
        "loginCommand": "az login --tenant <tenantId> --use-device-code",
        "readBackCommand": "az account show --output json",
        "cleanupCommands": ["az logout", "az account clear"]
      },
      {
        "service": "GitHub",
        "mode": "WebDevice",
        "loginCommand": "gh auth login --hostname github.com --git-protocol https --web --clipboard",
        "readBackCommand": "gh auth status --hostname github.com",
        "cleanupCommands": ["gh auth logout --hostname github.com"]
      },
      {
        "service": "AzureDevOps",
        "mode": "AzureCliDelegatedContext",
        "loginCommand": "None",
        "readBackCommand": "az devops project show --organization <organizationUrl> --project <projectName> --output json",
        "cleanupCommands": ["az logout", "az account clear"]
      },
      {
        "service": "PowerPlatform",
        "mode": "PacNamedDeviceCodeProfile",
        "loginCommand": "pac auth create --name <hr-TenantAlias-stage> --environment <environmentUrl> --deviceCode",
        "readBackCommand": "pac auth list",
        "cleanupCommands": ["pac auth delete --index <exactCreatedProfileIndex>"]
      }
    ]
  },
  "tools": [
    {
      "id": "PowerShell7",
      "command": "pwsh.exe",
      "versionArguments": ["--NoLogo", "--NoProfile", "--Command", "$PSVersionTable.PSVersion.ToString()"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "Microsoft.PowerShell", "scope": "machine" },
      "reference": "https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows"
    },
    {
      "id": "WindowsPowerShell",
      "command": "powershell.exe",
      "versionArguments": ["-NoLogo", "-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"],
      "versionPolicy": { "mode": "Exact", "value": "5.1" },
      "installDisposition": "Manual",
      "install": { "kind": "None" },
      "reference": "https://learn.microsoft.com/en-us/powershell/scripting/what-is-windows-powershell"
    },
    {
      "id": "Git",
      "command": "git.exe",
      "versionArguments": ["--version"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "Git.Git", "scope": "machine" },
      "reference": "https://docs.github.com/en/get-started/getting-started-with-git/set-up-git"
    },
    {
      "id": "VisualStudioCode",
      "command": "code.cmd",
      "versionArguments": ["--version"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "Microsoft.VisualStudioCode", "scope": "machine" },
      "reference": "https://code.visualstudio.com/docs/setup/windows"
    },
    {
      "id": "GitHubCli",
      "command": "gh.exe",
      "versionArguments": ["--version"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "GitHub.cli", "scope": "machine" },
      "reference": "https://docs.github.com/en/github-cli/github-cli/quickstart"
    },
    {
      "id": "AzureCli",
      "command": "az.cmd",
      "versionArguments": ["version", "--output", "json"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "Microsoft.AzureCLI", "scope": "machine" },
      "reference": "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows"
    },
    {
      "id": "AzureDeveloperCli",
      "command": "azd.exe",
      "versionArguments": ["version"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "Microsoft.Azd", "scope": "machine" },
      "reference": "https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd"
    },
    {
      "id": "PowerPlatformCli",
      "command": "pac.exe",
      "versionArguments": ["help"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "Microsoft.PowerAppsCLI", "scope": "machine" },
      "reference": "https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction"
    },
    {
      "id": "Bicep",
      "command": "az.cmd",
      "versionArguments": ["bicep", "version"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "AzureCliComponent", "arguments": ["bicep", "install"] },
      "reference": "https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install"
    },
    {
      "id": "Pester",
      "command": "powershell.exe",
      "versionArguments": ["-NoProfile", "-Command", "(Get-Module -ListAvailable Pester | Where-Object Version -eq ([version]'5.7.1') | Select-Object -First 1).Version.ToString()"],
      "versionPolicy": { "mode": "Exact", "value": "5.7.1" },
      "installDisposition": "Automated",
      "install": { "kind": "PowerShellGallery", "repository": "PSGallery", "moduleName": "Pester", "requiredVersion": "5.7.1", "scope": "CurrentUser" },
      "reference": "https://www.powershellgallery.com/packages/Pester/5.7.1"
    },
    {
      "id": "GitHubCopilotCli",
      "command": "copilot.exe",
      "versionArguments": ["--version"],
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "install": { "kind": "WinGet", "source": "winget", "packageId": "GitHub.Copilot", "scope": "user" },
      "reference": "https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli"
    }
  ],
  "azureCliExtensions": [
    {
      "name": "azure-devops",
      "versionPolicy": { "mode": "Present" },
      "installDisposition": "Automated",
      "reference": "https://learn.microsoft.com/en-us/azure/devops/cli/"
    }
  ],
  "vsCodeExtensions": [
    { "id": "ms-vscode.PowerShell", "installDisposition": "Recommended" },
    { "id": "ms-azuretools.vscode-bicep", "installDisposition": "Recommended" },
    { "id": "ms-azuretools.azure-dev", "installDisposition": "Recommended" },
    { "id": "microsoft-IsvExpTools.powerplatform-vscode", "installDisposition": "Recommended" },
    { "id": "GitHub.copilot", "installDisposition": "Recommended" }
  ],
  "repositoryAssets": [
    { "kind": "Skills", "path": ".github/skills", "expected": "Present", "installDisposition": "VerifyOnly" },
    { "kind": "Agents", "path": ".github/agents", "expected": "Present", "installDisposition": "VerifyOnly" },
    { "kind": "Plugins", "path": ".github/plugins", "expected": "Absent", "installDisposition": "VerifyOnly" }
  ],
  "allowedActions": [
    "WinGetInstallExact",
    "InstallPesterExact",
    "InstallBicepComponent",
    "InstallAzureCliExtensionExact",
    "InstallVsCodeExtensionExact"
  ]
}
```

Angle-bracket terms in `interactiveAuthentication` are typed runtime fields, not literal arguments. The schema must constrain them to the exact command templates above and must prohibit additional authentication methods. Before committing the PAC template, run `pac auth create help` and compare it with [Power Platform CLI auth reference](https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth); if current official syntax differs, capture the officially documented device-code/profile syntax in both the reviewed policy and tests in the same change. If device-code profile creation is not officially supported by the installed PAC version, set the method mode to `ManualUnsupported`, set `loginCommand` to `None`, and require the Power Platform administrator to complete attended authentication outside automation.

If Step 1 proves `GitHub.Copilot` is not officially installable through WinGet, use this exact replacement for that one entry:

```json
"installDisposition": "Manual",
"install": { "kind": "None" }
```

The schema must require `install.kind` to be `None` when `installDisposition` is `Manual`, so an unverified identifier cannot remain executable.

- [ ] **Step 5: Add fixtures and editor recommendations**

Create `.vscode/extensions.json`:

```json
{
  "recommendations": [
    "ms-vscode.PowerShell",
    "ms-azuretools.vscode-bicep",
    "ms-azuretools.azure-dev",
    "microsoft-IsvExpTools.powerplatform-vscode",
    "GitHub.copilot"
  ],
  "unwantedRecommendations": []
}
```

Create the native-command fixture with synthetic values:

```json
{
  "schemaVersion": "1.0",
  "results": {
    "pwsh.exe|--NoLogo --NoProfile --Command $PSVersionTable.PSVersion.ToString()": { "exitCode": 0, "stdout": ["7.5.3"], "stderr": [] },
    "powershell.exe|-NoLogo -NoProfile -Command $PSVersionTable.PSVersion.ToString()": { "exitCode": 0, "stdout": ["5.1.26100.6584"], "stderr": [] },
    "git.exe|--version": { "exitCode": 0, "stdout": ["git version 2.51.0.windows.1"], "stderr": [] },
    "az.cmd|bicep version": { "exitCode": 0, "stdout": ["Bicep CLI version 0.38.33"], "stderr": [] },
    "az.cmd|extension list --output json": { "exitCode": 0, "stdout": ["[{\"name\":\"azure-devops\",\"version\":\"1.0.2\"}]"], "stderr": [] },
    "code.cmd|--list-extensions": { "exitCode": 0, "stdout": ["ms-vscode.powershell", "ms-azuretools.vscode-bicep", "github.copilot"], "stderr": [] }
  }
}
```

Create the invalid fixture by copying a minimal valid policy shape and adding `"unexpected": true` at its root. It must fail only because the root is closed.

- [ ] **Step 6: Run the policy tests to verify the green state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS, including schema rejection of the unknown root property and exact ordering of all reviewed identifiers.

- [ ] **Step 7: Commit the reviewed policy**

```powershell
git add -- .vscode/extensions.json infra/src/config/runbooks/workstation-prerequisites.json infra/src/config/schemas/workstation-prerequisites.schema.json infra/tests/fixtures/runbooks infra/tests/pester/WorkstationPrerequisitePolicy.Tests.ps1
git commit -m "feat(infra): define workstation prerequisite policy"
```

Expected: one commit containing policy, schema, fixtures, recommendations, and tests; no vendored skill file is staged.

---

### Task 2: Add Canonical Output, Digest, and Safe-Path Helpers

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/ConvertTo-CanonicalJsonValue.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Private/Test-RunbookPathWithin.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Update-RunbookProcessPath.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Resolve-RunbookReportPath.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Write-CanonicalJson.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Get-RunbookContentDigest.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Create: `infra/tests/pester/RunbookContracts.Tests.ps1`

**Interfaces:**
- Consumes: a repository root, optional candidate report path and staging root, JSON-compatible input, and process environment values.
- Produces:
  - `Resolve-RunbookReportPath -RunId <guid> [-Path <string>] -RepositoryRoot <string> [-StagingRoot <string>]` → absolute external directory path.
  - `Write-CanonicalJson -InputObject <object> -Path <string> [-Depth 30] [-Replace]` → absolute file path.
  - `Get-RunbookContentDigest -InputObject <object> [-Depth 30]` → lowercase 64-character SHA-256 string.
  - `Update-RunbookProcessPath` → refreshed process-only `PATH` string; it never writes machine/user environment state.

- [ ] **Step 1: Write failing helper tests**

Add these representative cases to `RunbookContracts.Tests.ps1`:

```powershell
Set-StrictMode -Version Latest

Describe 'Shared runbook output contracts' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
    }

    It 'refuses report paths in a Git working tree or staging root' {
        $repo = Join-Path $TestDrive 'repo'
        $stage = Join-Path $TestDrive 'stage'
        New-Item -ItemType Directory -Path (Join-Path $repo '.git'), $stage -Force | Out-Null
        { Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) -Path (Join-Path $repo 'report') -RepositoryRoot $repo } |
            Should -Throw '*outside every Git working tree*'
        { Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) -Path (Join-Path $stage 'report') -RepositoryRoot $repo -StagingRoot $stage } |
            Should -Throw '*outside the staging root*'
    }

    It 'writes stable BOM-free JSON and hashes the exact canonical bytes' {
        $value = [ordered]@{ z = 2; a = [ordered]@{ y = 1; b = 0 } }
        $path = Join-Path $TestDrive 'canonical.json'
        Write-CanonicalJson -InputObject $value -Path $path | Should -Be $path
        $bytes = [IO.File]::ReadAllBytes($path)
        $bytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
        [Text.Encoding]::UTF8.GetString($bytes) | Should -Be "{`"a`":{`"b`":0,`"y`":1},`"z`":2}`n"
        (Get-RunbookContentDigest -InputObject $value) |
            Should -Be ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-', '').ToLowerInvariant())
    }

    It 'exports every new public contract from both module declarations' {
        $expected = @(
            'Resolve-RunbookReportPath',
            'Write-CanonicalJson',
            'Get-RunbookContentDigest',
            'Update-RunbookProcessPath'
        )
        $manifest = Test-ModuleManifest $script:ModulePath
        foreach ($name in $expected) {
            $manifest.ExportedFunctions.Keys | Should -Contain $name
            Get-Command $name -Module Caldova.HrFrontier.Bootstrap | Should -Not -BeNullOrEmpty
        }
    }
}
```

- [ ] **Step 2: Run the focused tests to verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookContracts.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Resolve-RunbookReportPath`, `Write-CanonicalJson`, and `Get-RunbookContentDigest` are not exported.

- [ ] **Step 3: Implement canonical normalization and atomic writing**

Implement `ConvertTo-CanonicalJsonValue.ps1` so dictionaries and object properties are copied into `[ordered]` dictionaries sorted with `[StringComparer]::Ordinal`, arrays retain input order, scalar values remain scalar, and depth exhaustion throws. Implement the writer around these exact byte semantics:

```powershell
function Write-CanonicalJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object]$InputObject,
        [Parameter(Mandatory)] [string]$Path,
        [ValidateRange(2, 100)] [int]$Depth = 30,
        [switch]$Replace
    )
    process {
        $fullPath = [IO.Path]::GetFullPath($Path)
        if ((Test-Path -LiteralPath $fullPath) -and -not $Replace) {
            throw 'Canonical JSON output already exists; use -Replace only for a reviewed replacement.'
        }
        $canonical = ConvertTo-CanonicalJsonValue -Value $InputObject -RemainingDepth $Depth
        $json = ($canonical | ConvertTo-Json -Depth $Depth -Compress) + "`n"
        $directory = Split-Path -Parent $fullPath
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $temporary = Join-Path $directory (([guid]::NewGuid().ToString('N')) + '.tmp')
        try {
            [IO.File]::WriteAllText($temporary, $json, [Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath $temporary -Destination $fullPath -Force:$Replace
        }
        finally {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        }
        $fullPath
    }
}
```

`Get-RunbookContentDigest` must normalize and serialize independently in memory, append the same LF, hash UTF-8 bytes with `SHA256.Create()`, dispose the hash object in `finally`, and return lowercase hexadecimal.

- [ ] **Step 4: Implement safe report-path and process-`PATH` behavior**

`Resolve-RunbookReportPath` must:

1. default to `$env:LOCALAPPDATA\CaldovaHrFrontier\runbook-evidence\<runId>`;
2. canonicalize existing ancestors;
3. reject any reparse point from the candidate up to its existing ancestor;
4. reject the repository root and descendants;
5. walk parent directories and reject any directory containing `.git`;
6. reject the staging root and descendants;
7. create no directory while validating; and
8. return the canonical absolute path only.

Implement `Update-RunbookProcessPath.ps1` without calling `SetEnvironmentVariable`:

```powershell
function Update-RunbookProcessPath {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $segments = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
        [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $unique = foreach ($segment in $segments) {
        $trimmed = $segment.Trim().TrimEnd('\')
        if ($seen.Add($trimmed)) { $trimmed }
    }
    $env:Path = $unique -join ';'
    $env:Path
}
```

Add an `InModuleScope` test proving the function changes only `$env:Path` and leaves machine/user values unchanged.

- [ ] **Step 5: Export the four public functions from both module files**

Append, without removing or renaming any existing export:

```powershell
'Resolve-RunbookReportPath',
'Write-CanonicalJson',
'Get-RunbookContentDigest',
'Update-RunbookProcessPath'
```

Use the exact same names and casing in `FunctionsToExport` in the `.psd1` and `Export-ModuleMember` in the `.psm1`.

- [ ] **Step 6: Run helper and existing module tests**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookContracts.Tests.ps1,infra/tests/pester/TenantConfiguration.Tests.ps1,infra/tests/pester/EvidenceSecurity.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS. The original eight exports remain available, canonical bytes match exactly, and unsafe report paths are refused.

- [ ] **Step 7: Commit the output contracts**

```powershell
git add -- infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/RunbookContracts.Tests.ps1
git commit -m "feat(infra): add canonical runbook output helpers"
```

Expected: one independently reviewable helper commit.

---

### Task 3: Add Execution-Manifest and Redacted-Evidence Contracts

**Files:**
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/New-RunbookExecutionManifest.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/Test-RunbookExecutionManifest.ps1`
- Create: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Public/ConvertTo-RunbookEvidenceRecord.ps1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psd1`
- Modify: `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/Caldova.HrFrontier.Bootstrap.psm1`
- Modify: `infra/tests/pester/RunbookContracts.Tests.ps1`

**Interfaces:**
- Consumes:
  - `Get-RunbookContentDigest -InputObject <object>`.
  - `New-RunbookExecutionManifest -RunId <guid> -Kind <Workstation|CloudFoundation|CustomerExport> -TargetStableId <string> -SourceCommit <40-hex> -AssessmentDigest <64-hex> -AuthenticationContext <object> -AllowedActions <object[]> -ToolVersions <object> -GeneratedAtUtc <datetime>`.
  - `Test-RunbookExecutionManifest -Manifest <object> -ApprovedDigest <64-hex> -CurrentSourceCommit <40-hex> -CurrentAssessmentDigest <64-hex> -CurrentAuthenticationContext <object> -AllowedActionNames <string[]> [-NowUtc <datetime>] [-MaximumAge <timespan>]`.
- Produces:
  - manifest schema `1.0`, one kind-specific stable target, exact action records, canonical `digest`, and approval-independent content;
  - `$true` only for a closed, fresh manifest matching approval, source commit, assessment, and its own recomputed digest;
  - `ConvertTo-RunbookEvidenceRecord -RunId <guid> -GeneratedAtUtc <datetime> -SourceCommit <40-hex> -AssessmentDigest <64-hex> [-PlanDigest <64-hex>] [-ManifestDigest <64-hex>] -OperatorId <display-safe string> -Operation <string> -Classification <NoChange|Create|Update|Manual|Blocked|Refused> -Status <Planned|Applied|Verified|Failed|Refused> -ShouldProcessDecision <NotApplicable|Approved|Declined|WhatIf> [-TargetId <string>] [-ToolVersions <object>] [-ReadBack <object>] [-FinalContext <object>] [-ManualItems <object[]>] [-RecoveryItems <object[]>] [-ErrorCategory <string>]` → safe versioned evidence envelope.

- [ ] **Step 1: Add failing manifest and evidence tests**

Append:

```powershell
Describe 'Execution manifest integrity' {
    It 'binds approval to normalized actions source and assessment' {
        $manifest = New-RunbookExecutionManifest `
            -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
            -Kind Workstation `
            -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
            -SourceCommit ('a' * 40) `
            -AssessmentDigest ('b' * 64) `
            -AuthenticationContext ([pscustomobject]@{
                executionHost = 'InteractiveWindows11PowerShell'
                mode = 'NotRequired'
            }) `
            -AllowedActions @([pscustomobject]@{
                action = 'WinGetInstallExact'
                targetId = 'Git.Git'
                packageSource = 'winget'
                packageId = 'Git.Git'
                scope = 'machine'
                expectedPostcondition = 'git.exe resolves and git --version exits 0'
            }) `
            -ToolVersions ([ordered]@{ PowerShell7 = '7.5.3' }) `
            -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')

        $manifest.digest | Should -Match '^[0-9a-f]{64}$'
        Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $manifest.digest `
            -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
            -CurrentAuthenticationContext ([pscustomobject]@{
                executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
            }) `
            -AllowedActionNames @('WinGetInstallExact') `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') | Should -BeTrue

        { Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest ('c' * 64) `
            -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
            -CurrentAuthenticationContext ([pscustomobject]@{
                executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
            }) `
            -AllowedActionNames @('WinGetInstallExact') } |
            Should -Throw '*approved digest*'
    }

    It 'refuses stale manifests and unrecognized action properties' {
        $manifest = New-RunbookExecutionManifest -RunId ([guid]::NewGuid()) -Kind Workstation `
            -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
            -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
            -AuthenticationContext ([pscustomobject]@{
                executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
            }) `
            -AllowedActions @([pscustomobject]@{ action = 'InstallPesterExact'; targetId = 'Pester' }) `
            -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T04:00:00Z')
        $manifest.allowedActions[0] | Add-Member NoteProperty arguments '--force'
        { Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $manifest.digest `
            -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
            -CurrentAuthenticationContext ([pscustomobject]@{
                executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
            }) `
            -AllowedActionNames @('InstallPesterExact') `
            -NowUtc ([datetime]'2026-09-26T05:00:00Z') } | Should -Throw
    }

    It 'never copies arbitrary input into evidence' {
        $record = ConvertTo-RunbookEvidenceRecord -RunId ([guid]::NewGuid()) `
            -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z') -SourceCommit ('a' * 40) `
            -AssessmentDigest ('b' * 64) -PlanDigest ('c' * 64) -ManifestDigest ('d' * 64) `
            -OperatorId 'synthetic-operator' -ShouldProcessDecision NotApplicable `
            -Operation 'AssessTool' -Classification Refused -Status Refused `
            -TargetId 'AzureCli' -ErrorCategory 'ContextMismatch' `
            -ReadBack ([pscustomobject]@{
                status = 'Failed'; resourceId = '/subscriptions/synthetic/resourceGroups/rg'
                provisioningState = 'Failed'; bodyDigest = ('e' * 64)
            }) `
            -ManualItems @([pscustomobject]@{
                service = 'Azure'; targetId = 'synthetic-target'; condition = 'PermissionDenied'
                owner = 'Cloud service owner'; diagnostic = 'RoleNotActive'
                recovery = 'Activate the approved role and generate a new plan.'
            }) `
            -RecoveryItems @([pscustomobject]@{
                service = 'Azure'; targetId = 'synthetic-target'; lastProvenState = 'NotCreated'
                safeDiagnostic = 'RoleNotActive'; owner = 'Cloud service owner'
                nextAction = 'Activate the approved role and reassess.'
                requiresNewPlan = $true; requiresNewApproval = $true
            })
        ($record | ConvertTo-Json -Depth 20) | Should -Not -Match '(?i)token|authorization|cookie|secret'
        { ConvertTo-RunbookEvidenceRecord -RunId ([guid]::NewGuid()) `
            -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z') -SourceCommit ('a' * 40) `
            -AssessmentDigest ('b' * 64) -OperatorId 'synthetic-operator' `
            -ShouldProcessDecision NotApplicable -Operation 'AssessTool' `
            -Classification NoChange -Status Verified -TargetId 'Git' `
            -ReadBack ([pscustomobject]@{ access_token = 'synthetic-prohibited-value' }) } |
            Should -Throw '*prohibited evidence field*'
    }
}
```

- [ ] **Step 2: Run the tests to verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookContracts.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because all three functions are undefined.

- [ ] **Step 3: Implement deterministic manifest creation**

Build this closed shape, sort actions ordinally by `action` then `targetId`, format UTC as `yyyy-MM-ddTHH:mm:ssZ`, compute the digest over the object before adding `digest`, and return a new object:

```powershell
$unsigned = [ordered]@{
    schemaVersion = '1.0'
    runId = $RunId.ToString('D')
    kind = [string]$Kind
    generatedAtUtc = $GeneratedAtUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    sourceCommit = $SourceCommit.ToLowerInvariant()
    assessmentDigest = $AssessmentDigest.ToLowerInvariant()
    authentication = $AuthenticationContext
    target = [ordered]@{
        type = [string]$Kind
        stableId = $TargetStableId
    }
    toolVersions = $ToolVersions
    allowedActions = @($AllowedActions | Sort-Object action, targetId)
}
$digest = Get-RunbookContentDigest -InputObject $unsigned
$signed = [ordered]@{}
foreach ($entry in $unsigned.GetEnumerator()) { $signed[$entry.Key] = $entry.Value }
$signed.digest = $digest
[pscustomobject]$signed
```

Restrict `Kind` with `ValidateSet('Workstation', 'CloudFoundation', 'CustomerExport')`. Allow only action properties `action`, `targetId`, `service`, `method`, `uri`, `bodyDigest`, `packageSource`, `packageId`, `scope`, `requiredVersion`, `sourceRelativePath`, `destinationRelativePath`, `replacementRuleId`, and `expectedPostcondition`. Reject duplicate `action`/`targetId` pairs. The closed authentication object permits `executionHost`, `mode`, `accountId`, `tenantId`, `subscriptionId`, `githubHost`, `githubLogin`, `azureDevOpsOrganizationUrl`, `azureDevOpsActingUserId`, `azureDevOpsProjectId`, `powerPlatformProfileName`, and `powerPlatformEnvironmentId`; it rejects every property matching `(?i)(token|password|secret|credential|certificate)`. `executionHost` is always `InteractiveWindows11PowerShell`; workstation initialization uses `mode: NotRequired`, while later cloud plans may use only reviewed attended modes. Each entry point supplies its reviewed action-name allowlist to validation and separately reads back its kind-specific target before mutation.

- [ ] **Step 4: Implement fail-closed manifest validation**

Validate exact root/action/target property sets before values. Recompute the digest after removing only `digest`; compare with ordinal string equality. Require `MaximumAge` to default to 30 minutes and reject future timestamps beyond two minutes. Throw distinct sanitized messages for:

```text
Execution manifest schema is not supported.
Execution manifest contains an unrecognized property.
Execution manifest digest does not match its content.
Approved digest does not match the execution manifest.
Execution manifest source commit is stale.
Execution manifest assessment is stale.
Execution manifest authentication context does not match read-back.
Execution manifest has expired.
Execution manifest contains an unallowlisted action.
```

Return `$true` only after every check passes.

- [ ] **Step 5: Implement allowlist evidence projection**

Construct a new ordered object; never serialize an input object wholesale. `ReadBack` accepts either one record or a flat array of records. Permit only scalar record properties `service`, `targetId`, `status`, `expectedPostcondition`, `version`, `path`, `exitCode`, `restartRequired`, `resourceId`, `objectId`, `appId`, `projectId`, `repositoryId`, `rulesetId`, `deploymentId`, `deploymentName`, `projectName`, `processId`, `displayName`, `organizationUrl`, `visibility`, `provisioningState`, `bodyDigest`, `symmetricAuthCount`, `asymmetricAuthCount`, and `state`; permit `resourceIds` only as a flat array of display-safe strings. The two authentication-count fields prove that Entra client-secret and certificate collections are empty without exposing their contents. Permit only display-safe `FinalContext` properties `executionHost`, `principalId`, `accountId`, `tenantId`, `subscriptionId`, `githubHost`, `githubLogin`, `githubRepositoryId`, `azureDevOpsOrganizationUrl`, `azureDevOpsActingUserId`, `azureDevOpsProjectId`, `powerPlatformProfileName`, `powerPlatformEnvironmentId`, and `status`. `stages` is the only allowed `FinalContext` array; each entry has exactly `stage`, `powerPlatformProfileName`, `powerPlatformEnvironmentId`, `powerPlatformEnvironmentUrl`, `sharePointSiteId`, and `sharePointWebUrl`. Each `ManualItems` entry is reconstructed into the exact closed scalar fields `service`, `targetId`, `condition`, `owner`, `diagnostic`, and `recovery`; unknown or missing fields are rejected. `diagnostic` is a sanitized category, never provider output. Each `RecoveryItems` entry is reconstructed into exactly `service`, `targetId`, `lastProvenState`, `safeDiagnostic`, `owner`, `nextAction`, `requiresNewPlan`, and `requiresNewApproval`; the last two fields are Boolean and both must be true before a retryable write. Reject property names matching:

```powershell
'(?i)(token|authorization|cookie|secret|password|credential|private.?key|connection.?string|raw|content|payload)'
```

Use this exact root contract:

```powershell
[ordered]@{
    schemaVersion = '1.0'
    runId = $RunId.ToString('D')
    generatedAtUtc = $GeneratedAtUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    sourceCommit = $SourceCommit.ToLowerInvariant()
    assessmentDigest = $AssessmentDigest.ToLowerInvariant()
    planDigest = $PlanDigest
    manifestDigest = $ManifestDigest
    operatorId = $OperatorId
    operation = $Operation
    classification = [string]$Classification
    status = [string]$Status
    shouldProcessDecision = [string]$ShouldProcessDecision
    targetId = $TargetId
    toolVersions = $safeToolVersions
    readBack = $safeReadBack
    finalContext = $safeFinalContext
    manualItems = @($safeManualItems)
    recoveryItems = @($safeRecoveryItems)
    errorCategory = $ErrorCategory
}
```

- [ ] **Step 6: Export the new public functions and run regression tests**

Add these exact names to both export lists:

```powershell
'New-RunbookExecutionManifest',
'Test-RunbookExecutionManifest',
'ConvertTo-RunbookEvidenceRecord'
```

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookContracts.Tests.ps1,infra/tests/pester/EvidenceSecurity.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS; both manifest tampering and prohibited evidence fields are refused.

- [ ] **Step 7: Commit the shared approval and evidence contracts**

```powershell
git add -- infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap infra/tests/pester/RunbookContracts.Tests.ps1
git commit -m "feat(infra): add runbook manifest and evidence contracts"
```

Expected: one commit that later cloud and handover plans can consume without importing workstation entry points.

---

### Task 4: Implement Read-Only Workstation Assessment

**Files:**
- Create: `infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1`
- Create: `infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1`

**Interfaces:**
- Consumes:
  - reviewed prerequisite policy path;
  - `Resolve-RunbookReportPath`, `Write-CanonicalJson`, `Get-RunbookContentDigest`, and `ConvertTo-RunbookEvidenceRecord`;
  - fixture runner signature `param([string]$FilePath, [string[]]$ArgumentList)`, returning `{ exitCode, stdout[], stderr[] }`.
- Produces:
  - `Test-DeveloperWorkstation.ps1 [-PolicyPath <string>] [-RepositoryRoot <string>] [-ReportPath <string>] [-NativeCommandRunner <scriptblock>] [-CommandResolver <scriptblock>] [-FileIdentityProvider <scriptblock>] [-InteractiveHostProbe <scriptblock>] [-NowUtc <datetime>]`;
  - one structured object with `schemaVersion`, `runId`, `assessedAtUtc`, `platform`, `repository`, `tools`, `azureCliExtensions`, `vsCodeExtensions`, `repositoryAssets`, closed `manualItems` records `{ service, targetId, condition, owner, diagnostic, recovery }`, `overallStatus`, and `assessmentDigest`;
  - optional `workstation-assessment.json` and `workstation-evidence.json` only below a safe external report path.

- [ ] **Step 1: Write fixture-backed failing assessment tests**

Create a fixture runner that never invokes a native process:

```powershell
function New-FixtureRunner {
    param([string]$FixturePath)
    $fixture = Get-Content -Raw $FixturePath | ConvertFrom-Json
    return {
        param([string]$FilePath, [string[]]$ArgumentList)
        $key = '{0}|{1}' -f $FilePath, ($ArgumentList -join ' ')
        $property = $fixture.results.PSObject.Properties[$key]
        if ($null -eq $property) {
            return [pscustomobject]@{ exitCode = 127; stdout = @(); stderr = @('fixture command not found') }
        }
        $property.Value
    }.GetNewClosure()
}

Describe 'Developer workstation assessment' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Test-DeveloperWorkstation.ps1'
        $script:FixturePath = Join-Path $PSScriptRoot '..\fixtures\runbooks\native-command-results.json'
    }

    It 'returns structured results without invoking an install or authentication command' {
        $calls = [Collections.Generic.List[string]]::new()
        $fixtureRunner = New-FixtureRunner $script:FixturePath
        $runner = {
            param($file, $arguments)
            [void]$calls.Add(('{0} {1}' -f $file, ($arguments -join ' ')))
            & $fixtureRunner $file $arguments
        }.GetNewClosure()

        $result = & $script:ScriptPath -RepositoryRoot ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))) `
            -NativeCommandRunner $runner -NowUtc ([datetime]'2026-09-26T05:00:00Z')

        $result.schemaVersion | Should -Be '1.0'
        $result.assessmentDigest | Should -Match '^[0-9a-f]{64}$'
        $calls -join "`n" | Should -Not -Match '(?i)\b(install|upgrade|login|auth|config|set)\b'
    }

    It 'produces the same state digest when only run identity and time change' {
        $runner = New-FixtureRunner $script:FixturePath
        $first = & $script:ScriptPath -NativeCommandRunner $runner `
            -NowUtc ([datetime]'2026-09-26T05:00:00Z')
        $second = & $script:ScriptPath -NativeCommandRunner $runner `
            -NowUtc ([datetime]'2026-09-26T05:20:00Z')
        $first.runId | Should -Not -Be $second.runId
        $first.assessedAtUtc | Should -Not -Be $second.assessedAtUtc
        $first.assessmentDigest | Should -BeExactly $second.assessmentDigest
    }

    It 'refuses a non-Windows-11 platform before probing tools' {
        $calls = [Collections.Generic.List[string]]::new()
        { & $script:ScriptPath -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) } `
            -PlatformProbe { [pscustomobject]@{ productName = 'Windows 10'; build = 19045 } } } |
            Should -Throw '*Windows 11*'
        $calls.Count | Should -Be 0
    }

    It 'refuses CI OIDC remoting and every non-interactive execution host' {
        $calls = [Collections.Generic.List[string]]::new()
        { & $script:ScriptPath -InteractiveHostProbe {
                [pscustomobject]@{ isInteractive = $false; reason = 'CI runner' }
            } -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) } } |
            Should -Throw '*interactive Windows 11 PowerShell session*'
        $calls.Count | Should -Be 0
    }

    It 'blocks an ambiguous executable resolution before invoking either path' {
        $calls = [Collections.Generic.List[string]]::new()
        $result = & $script:ScriptPath `
            -CommandResolver { param($name) if ($name -eq 'git.exe') { @('C:\Approved\git.exe', 'C:\Shadow\git.exe') } else { @("C:\Approved\$name") } } `
            -FileIdentityProvider { param($path) [pscustomobject]@{ path = $path; sha256 = ('a' * 64) } } `
            -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) }
        ($result.tools | Where-Object id -eq 'Git').status | Should -Be 'Blocked'
        $calls | Should -Not -Contain 'C:\Approved\git.exe'
        $calls | Should -Not -Contain 'C:\Shadow\git.exe'
    }
}
```

Expose `-PlatformProbe` and `-InteractiveHostProbe` as `[Parameter(DontShow)] [scriptblock]` test seams. The platform probe defaults to a read-only CIM query of `Win32_OperatingSystem`. The host probe returns false when `[Environment]::UserInteractive` is false, `$env:CI` is set, `$env:GITHUB_ACTIONS` is set, `$env:ACTIONS_ID_TOKEN_REQUEST_URL` is set, the process session is non-interactive, or the PowerShell runspace indicates remoting. Refuse before policy parsing, Git inspection, report-directory creation, or native-command execution.

- [ ] **Step 2: Run the assessment tests to verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Test-DeveloperWorkstation.ps1` does not exist.

- [ ] **Step 3: Implement the platform, repository, and native-tool assessment**

Use this entry-point skeleton:

```powershell
[CmdletBinding()]
param(
    [string]$PolicyPath,
    [string]$RepositoryRoot,
    [string]$ReportPath,
    [Parameter(DontShow)] [scriptblock]$NativeCommandRunner,
    [Parameter(DontShow)] [scriptblock]$CommandResolver,
    [Parameter(DontShow)] [scriptblock]$FileIdentityProvider,
    [Parameter(DontShow)] [scriptblock]$PlatformProbe,
    [Parameter(DontShow)] [scriptblock]$InteractiveHostProbe,
    [datetime]$NowUtc = [datetime]::UtcNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

Default `PolicyPath` to `infra/src/config/runbooks/workstation-prerequisites.json` and `RepositoryRoot` to the Git root relative to the script. Prove the interactive local-host gate first. Parse the policy in Windows PowerShell 5.1 and enforce the schema's closed contract with explicit ordinal property-set checks at the root and every nested object. The draft 2020-12 schema remains the machine-readable policy contract and Task 1 proves it with PowerShell 7, but assessment must not depend on PowerShell 7 already being installed. Reject an OS product name other than `Windows 11` or a build below `22000` before any native command.

The resolver defaults to `param($name) { @(Get-Command $name -All -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object Source) }`. The identity provider defaults to `param($path) { [pscustomobject]@{ path = [IO.Path]::GetFullPath($path); sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() } }`. Resolve WinGet and each policy tool before invoking it. Collapse duplicate command results only when their canonical path and file hash are identical. Zero results is `Missing`; more than one non-equivalent result is `Blocked`. Record exactly one `executablePath` and `executableSha256` for a ready tool and for the WinGet package manager. Invoke only that absolute path with the policy's `versionArguments`. Probe Azure CLI extensions through the approved absolute Azure CLI path with `az extension list --output json`; do not run extension add/update. Probe VS Code extensions through the approved absolute VS Code path with `code --list-extensions`; compare case-insensitively. Verify:

```text
.github/skills/SUPERPOWERS_VERSION is a regular file
.github/skills/SUPERPOWERS_SHA256SUMS is a regular file
.github/agents/docs-agent.agent.md is a regular file
.github/agents/cloud-solution-architect.agent.md is a regular file
.github/agents/ux-designer.agent.md is a regular file
.github/plugins does not exist
```

Read `.github/skills/SUPERPOWERS_SHA256SUMS`, reject unsafe or duplicate relative paths, calculate SHA-256 for each listed vendored file, and report only aggregate `Verified` or exact relative-path `Mismatch` statuses. Do not rewrite vendored skill content or copy its content into evidence. Run `git rev-parse --show-toplevel`, `git rev-parse HEAD`, and `git status --porcelain` only; never run a Git write command.

- [ ] **Step 4: Add deterministic assessment output and external evidence writing**

Build a separate canonical state projection containing `schemaVersion`, `policyDigest`, `platform`, `repository`, `tools`, `azureCliExtensions`, `vsCodeExtensions`, `repositoryAssets`, `manualItems`, and `overallStatus`. Compute `policyDigest` from the validated policy. Calculate `assessmentDigest` over only that state projection; exclude `runId`, `assessedAtUtc`, report paths, and every other per-run or output-location field. Return the full assessment, including its per-run identity/time and state digest, to the success output stream. If `ReportPath` is supplied, resolve it before creating it, then write:

```powershell
$safeDirectory = Resolve-RunbookReportPath -RunId $runId -Path $ReportPath -RepositoryRoot $RepositoryRoot
[IO.Directory]::CreateDirectory($safeDirectory) | Out-Null
Write-CanonicalJson -InputObject $assessment -Path (Join-Path $safeDirectory 'workstation-assessment.json')
$evidence = ConvertTo-RunbookEvidenceRecord -RunId $runId -GeneratedAtUtc $NowUtc `
    -SourceCommit $assessment.repository.sourceCommit -AssessmentDigest $assessment.assessmentDigest `
    -OperatorId $assessment.platform.stableId -ShouldProcessDecision NotApplicable `
    -Operation 'AssessWorkstation' `
    -Classification $(if ($assessment.overallStatus -eq 'Ready') { 'NoChange' } else { 'Blocked' }) `
    -Status $(if ($assessment.overallStatus -eq 'Ready') { 'Verified' } else { 'Failed' }) `
    -TargetId $assessment.platform.stableId -ToolVersions $safeVersions `
    -FinalContext ([pscustomobject]@{ status = 'InteractiveWindows11PowerShell' }) `
    -ManualItems $assessment.manualItems
Write-CanonicalJson -InputObject $evidence -Path (Join-Path $safeDirectory 'workstation-evidence.json')
```

Creation of the approved external report directory is the only write. Authentication state is reported as `UnknownUntilAttendedSignIn`; assessment must not call `gh auth`, `az login`, `azd auth`, `pac auth`, or `copilot login`.

- [ ] **Step 5: Run assessment tests and an external dry run**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1 -Output Detailed -CI"
$report = Join-Path $env:TEMP ('caldova-workstation-assessment-' + [guid]::NewGuid().ToString('N'))
try {
    $result = powershell.exe -NoProfile -File infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1 -ReportPath $report
    Test-Path (Join-Path $report 'workstation-assessment.json')
}
finally {
    if (Test-Path $report) { Remove-Item $report -Recurse -Force }
}
```

Expected: Pester PASS. On a Windows 11 development machine the dry run writes only two JSON files below the temporary report path and returns structured output; missing tools produce `Blocked`, not installation or authentication.

- [ ] **Step 6: Commit the assessment entry point**

```powershell
git add -- infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1 infra/tests/pester/DeveloperWorkstationAssessment.Tests.ps1
git commit -m "feat(infra): add workstation readiness assessment"
```

Expected: one assessment-only commit with no mutator.

---

### Task 5: Implement Gated Workstation Initialization and Read-Back

**Files:**
- Create: `infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1`
- Create: `infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1`
- Create: `infra/tests/pester/RunbookStaticSafety.Tests.ps1`

**Interfaces:**
- Consumes:
  - prerequisite policy `1.0`;
  - fresh assessment and its digest;
  - `New-RunbookExecutionManifest` and `Test-RunbookExecutionManifest`;
  - `Resolve-RunbookReportPath`, `Write-CanonicalJson`, and `ConvertTo-RunbookEvidenceRecord`;
  - injected runner `param([string]$FilePath, [string[]]$ArgumentList)`.
- Produces:
  - `Initialize-DeveloperWorkstation.ps1 [-Apply] [-ExecutionManifestPath <string>] [-ApprovedDigest <64-hex>] [-PolicyPath <string>] [-RepositoryRoot <string>] [-ReportPath <string>] [-NativeCommandRunner <scriptblock>] [-CommandResolver <scriptblock>] [-FileIdentityProvider <scriptblock>] [-SummaryWriter <scriptblock>] [-InteractiveHostProbe <scriptblock>] [-Confirm] [-WhatIf]`;
  - default plan and execution manifest with no machine/auth mutation;
  - Apply operations only for exact policy actions, followed by process-only `PATH` refresh, independent read-back, redacted evidence, and explicit restart/manual/recovery status.

- [ ] **Step 1: Write failing default, WhatIf, refusal, and Apply tests**

Use one call-recording fixture runner and assert exact calls:

```powershell
Describe 'Developer workstation initialization gates' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Initialize-DeveloperWorkstation.ps1'
    }

    It 'does not call a mutator by default' {
        $mutations = [Collections.Generic.List[string]]::new()
        & $script:ScriptPath -RepositoryRoot $TestDrive -ReportPath (Join-Path $env:TEMP ([guid]::NewGuid())) `
            -AssessmentProvider { New-SyntheticAssessment } `
            -NativeCommandRunner { param($f, $a) if (($a -join ' ') -match 'install|add') { [void]$mutations.Add("$f $a") } }
        $mutations.Count | Should -Be 0
    }

    It 'does not call a mutator under WhatIf even when Apply is present' {
        $mutations = [Collections.Generic.List[string]]::new()
        & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -WhatIf -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment } `
            -NativeCommandRunner { param($f, $a) if (($a -join ' ') -match 'install|add') { [void]$mutations.Add("$f $a") } }
        $mutations.Count | Should -Be 0
    }

    It 'refuses a digest mismatch before calling a mutator' {
        $mutations = [Collections.Generic.List[string]]::new()
        { & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest ('f' * 64) -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment } `
            -NativeCommandRunner { param($f, $a) [void]$mutations.Add("$f $a") } } |
            Should -Throw '*Approved digest*'
        $mutations.Count | Should -Be 0
    }

    It 'refuses non-interactive and GitHub Actions execution before calling a mutator' {
        $mutations = [Collections.Generic.List[string]]::new()
        { & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $false; reason = 'GitHub Actions' } } `
            -AssessmentProvider { New-SyntheticAssessment } `
            -NativeCommandRunner { param($f, $a) [void]$mutations.Add("$f $a") } } |
            Should -Throw '*interactive Windows 11 PowerShell session*'
        $mutations.Count | Should -Be 0
    }

    It 'uses exact allowlisted arguments and reads back after an approved action' {
        $calls = [Collections.Generic.List[string]]::new()
        $summaries = [Collections.Generic.List[object]]::new()
        $result = & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
            -NativeCommandRunner {
                param($f, $a)
                [void]$calls.Add(('{0}|{1}' -f $f, ($a -join ' ')))
                [pscustomobject]@{ exitCode = 0; stdout = @('synthetic'); stderr = @() }
            } `
            -CommandResolver { param($name) @("C:\Approved\$name") } `
            -FileIdentityProvider { param($path) [pscustomobject]@{
                path = $path
                sha256 = $(if ($path -like '*winget.exe') { '1' * 64 } else { '2' * 64 })
            } } `
            -SummaryWriter { param($operations) foreach ($operation in $operations) { $summaries.Add($operation) } }
        $calls[0] | Should -Be 'C:\Approved\winget.exe|install --exact --id Git.Git --source winget --scope machine'
        $calls[-1] | Should -Be 'C:\Approved\git.exe|--version'
        $summaries.Count | Should -Be 1
        $summaries[0].targetId | Should -BeExactly 'Git.Git'
        $result.operations[0].readBack.status | Should -Be 'Verified'
    }

    It 'refuses a changed executable identity before mutation' {
        $calls = [Collections.Generic.List[string]]::new()
        { & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
            -CommandResolver { param($name) @("C:\Approved\$name") } `
            -FileIdentityProvider { param($path) [pscustomobject]@{ path = $path; sha256 = ('f' * 64) } } `
            -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) } } |
            Should -Throw '*executable identity changed*'
        $calls.Count | Should -Be 0
    }

    It 'keeps executable policy actions isolated from summary-writer mutation' {
        $calls = [Collections.Generic.List[string]]::new()
        & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
            -CommandResolver { param($name) @("C:\Approved\$name") } `
            -FileIdentityProvider { param($path) [pscustomobject]@{
                path = $path
                sha256 = $(if ($path -like '*winget.exe') { '1' * 64 } else { '2' * 64 })
            } } `
            -SummaryWriter { param($rows) $rows[0].packageId = 'Synthetic.Mutated' } `
            -NativeCommandRunner {
                param($f, $a)
                [void]$calls.Add(('{0}|{1}' -f $f, ($a -join ' ')))
                [pscustomobject]@{ exitCode = 0; stdout = @('synthetic'); stderr = @() }
            } | Out-Null
        $calls[0] | Should -Match '--id Git\.Git'
        $calls[0] | Should -Not -Match 'Synthetic\.Mutated'
    }
}
```

Define `New-SyntheticAssessment` and create the valid manifest in `BeforeAll` by calling the shared helper. Use only synthetic stable IDs and temporary paths.

Use this exact test setup:

```powershell
function New-SyntheticAssessment {
    param([ValidateSet('', 'Git')][string]$MissingTool = '')
    [pscustomobject]@{
        schemaVersion = '1.0'
        platform = [pscustomobject]@{
            productName = 'Windows 11'
            build = 26100
            stableId = '{0}\{1}' -f $env:COMPUTERNAME, $env:USERNAME
            packageManager = [pscustomobject]@{
                executablePath = 'C:\Approved\winget.exe'
                executableSha256 = ('1' * 64)
            }
        }
        repository = [pscustomobject]@{ sourceCommit = ('a' * 40); clean = $true }
        tools = @(
            [pscustomobject]@{
                id = 'Git'
                status = $(if ($MissingTool -eq 'Git') { 'Missing' } else { 'Ready' })
                version = $(if ($MissingTool -eq 'Git') { $null } else { '2.51.0.windows.1' })
                executablePath = $(if ($MissingTool -eq 'Git') { $null } else { 'C:\Approved\git.exe' })
                executableSha256 = $(if ($MissingTool -eq 'Git') { $null } else { ('2' * 64) })
            }
        )
        assessmentDigest = ('b' * 64)
        overallStatus = $(if ($MissingTool) { 'Blocked' } else { 'Ready' })
    }
}

$script:ValidManifest = Join-Path $TestDrive 'workstation-execution-manifest.json'
$manifest = New-RunbookExecutionManifest -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
    -Kind Workstation -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
    -TargetStableId ('{0}\{1}' -f $env:COMPUTERNAME, $env:USERNAME) `
    -AuthenticationContext ([pscustomobject]@{
        executionHost = 'InteractiveWindows11PowerShell'
        mode = 'NotRequired'
    }) `
    -AllowedActions @([pscustomobject]@{
        action = 'WinGetInstallExact'
        targetId = 'Git.Git'
        packageSource = 'winget'
        packageId = 'Git.Git'
        scope = 'machine'
        expectedPostcondition = 'git.exe resolves and git --version exits 0'
    }) -ToolVersions @{} -GeneratedAtUtc ([datetime]::UtcNow)
$script:ApprovedDigest = $manifest.digest
Write-CanonicalJson -InputObject $manifest -Path $script:ValidManifest | Out-Null
```

- [ ] **Step 2: Run initialization tests to verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because `Initialize-DeveloperWorkstation.ps1` does not exist.

- [ ] **Step 3: Implement non-mutating planning and manifest output**

Start with:

```powershell
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$Apply,
    [string]$ExecutionManifestPath,
    [ValidatePattern('^[0-9a-f]{64}$')] [string]$ApprovedDigest,
    [string]$PolicyPath,
    [string]$RepositoryRoot,
    [string]$ReportPath,
    [Parameter(DontShow)] [scriptblock]$AssessmentProvider,
    [Parameter(DontShow)] [scriptblock]$NativeCommandRunner,
    [Parameter(DontShow)] [scriptblock]$CommandResolver,
    [Parameter(DontShow)] [scriptblock]$FileIdentityProvider,
    [Parameter(DontShow)] [scriptblock]$SummaryWriter,
    [Parameter(DontShow)] [scriptblock]$InteractiveHostProbe,
    [datetime]$NowUtc = [datetime]::UtcNow
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

Use the same default `CommandResolver` and `FileIdentityProvider` implementations and invocation contracts as `Test-DeveloperWorkstation.ps1`. Apply the same local interactive-host refusal used by assessment before reading an execution manifest or invoking a provider. Always run a fresh assessment first. Compare observed results to reviewed policy and create exact `NoChange`, `Create`, `Manual`, or `Blocked` operations. Without `-Apply`, create the safe external report directory, write `workstation-plan.json` and `workstation-execution-manifest.json`, print the digest and exact approval instruction, and return. Do not infer approval from generating the file.

The default call must not require elevation. Classify machine-scope WinGet operations as `Manual` with `requiresElevation: true` when the current process is not elevated; do not self-elevate. Classify sign-in, terms, license, restart, and organization-policy requirements as `Manual` or `Blocked`.

- [ ] **Step 4: Implement the eight Apply gates before the first mutator**

In this exact order:

```powershell
if (-not $Apply) { return $planResult }
if ([string]::IsNullOrWhiteSpace($ExecutionManifestPath)) { throw 'Apply requires -ExecutionManifestPath.' }
if ([string]::IsNullOrWhiteSpace($ApprovedDigest)) { throw 'Apply requires -ApprovedDigest.' }
$manifest = Get-Content -Raw -LiteralPath $ExecutionManifestPath | ConvertFrom-Json
Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $ApprovedDigest `
    -CurrentSourceCommit $assessment.repository.sourceCommit `
    -CurrentAssessmentDigest $assessment.assessmentDigest `
    -CurrentAuthenticationContext ([pscustomobject]@{
        executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
    }) `
    -AllowedActionNames @($policy.allowedActions) -NowUtc $NowUtc | Out-Null
Assert-WorkstationStableId -Expected $manifest.target.stableId -Actual $assessment.platform.stableId
$approvedActions = Assert-AllowedPolicyActions -Manifest $manifest -Policy $policy
Show-RunbookChangeSummary -Operations @($approvedActions.Values) -Writer $SummaryWriter
```

Define those three script-local functions before orchestration with these exact signatures:

```powershell
function Assert-WorkstationStableId {
    param([Parameter(Mandatory)][string]$Expected, [Parameter(Mandatory)][string]$Actual)
    if ($Expected -cne $Actual) { throw 'Execution manifest workstation target does not match the current user and computer.' }
}
function Assert-AllowedPolicyActions {
    param([Parameter(Mandatory)][object]$Manifest, [Parameter(Mandatory)][object]$Policy)
    $allowed = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($tool in $Policy.tools) {
        switch ([string]$tool.install.kind) {
            'WinGet' {
                $item = [pscustomobject][ordered]@{
                    action = 'WinGetInstallExact'; targetId = [string]$tool.install.packageId
                    packageSource = [string]$tool.install.source; packageId = [string]$tool.install.packageId
                    scope = [string]$tool.install.scope
                    expectedPostcondition = "$($tool.id) resolves uniquely with the reviewed executable identity and version policy"
                }
            }
            'PowerShellGallery' {
                $item = [pscustomobject][ordered]@{
                    action = 'InstallPesterExact'; targetId = [string]$tool.install.moduleName
                    packageSource = [string]$tool.install.repository; scope = [string]$tool.install.scope
                    requiredVersion = [string]$tool.install.requiredVersion
                    expectedPostcondition = 'Pester 5.7.1 resolves in CurrentUser scope'
                }
            }
            'AzureCliComponent' {
                $item = [pscustomobject][ordered]@{
                    action = 'InstallBicepComponent'; targetId = [string]$tool.id
                    expectedPostcondition = 'az bicep version exits 0'
                }
            }
        }
        if ($null -ne $item) { $allowed["$($item.action)|$($item.targetId)"] = $item; $item = $null }
    }
    foreach ($extension in $Policy.azureCliExtensions) {
        $item = [pscustomobject][ordered]@{
            action = 'InstallAzureCliExtensionExact'; targetId = [string]$extension.name
            requiredVersion = [string]$extension.version
            expectedPostcondition = "Azure CLI extension $($extension.name) resolves at the reviewed version"
        }
        $allowed["$($item.action)|$($item.targetId)"] = $item
    }
    foreach ($extension in $Policy.vsCodeExtensions) {
        $item = [pscustomobject][ordered]@{
            action = 'InstallVsCodeExtensionExact'; targetId = [string]$extension.id
            expectedPostcondition = "VS Code reports extension $($extension.id)"
        }
        $allowed["$($item.action)|$($item.targetId)"] = $item
    }
    $selected = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    foreach ($operation in $Manifest.allowedActions) {
        $key = "$($operation.action)|$($operation.targetId)"
        if (-not $allowed.ContainsKey($key)) {
            throw 'Execution manifest contains an action absent from reviewed policy.'
        }
        if ((Get-RunbookContentDigest $operation) -cne (Get-RunbookContentDigest $allowed[$key])) {
            throw 'Execution manifest action arguments differ from reviewed policy.'
        }
        $selected[$key] = $allowed[$key]
    }
    return $selected
}
function Show-RunbookChangeSummary {
    param([Parameter(Mandatory)][object[]]$Operations, [Parameter(Mandatory)][scriptblock]$Writer)
    $displayRows = foreach ($operation in $Operations) {
        [pscustomobject][ordered]@{
            action = [string]$operation.action
            targetId = [string]$operation.targetId
            packageSource = [string]$operation.packageSource
            packageId = [string]$operation.packageId
            scope = [string]$operation.scope
            requiredVersion = [string]$operation.requiredVersion
            expectedPostcondition = [string]$operation.expectedPostcondition
        }
    }
    & $Writer @($displayRows)
}
```

Default `SummaryWriter` to a scriptblock that formats the detached display rows and sends the resulting table to `Out-Host`. The writer receives new scalar-only projection objects, never the executable objects retained in `$approvedActions`; mutation of a display row cannot change a command argument.

Add this negative test, which preserves the action key and valid approval while tampering with each executable field:

```powershell
It 'refuses every manifest argument that differs from reviewed policy' -ForEach @(
    @{ field = 'packageId'; value = 'Synthetic.Other' }
    @{ field = 'packageSource'; value = 'unreviewed' }
    @{ field = 'scope'; value = 'user' }
    @{ field = 'requiredVersion'; value = '99.0.0' }
    @{ field = 'expectedPostcondition'; value = 'skip verification' }
) {
    $copy = $manifest | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $copy.allowedActions[0] | Add-Member -NotePropertyName $field -NotePropertyValue $value -Force
    $unsigned = [ordered]@{}
    foreach ($property in $copy.PSObject.Properties | Where-Object Name -ne 'digest') {
        $unsigned[$property.Name] = $property.Value
    }
    $copy.digest = Get-RunbookContentDigest -InputObject $unsigned
    $path = Join-Path $TestDrive "tampered-$field.json"
    Write-CanonicalJson -InputObject $copy -Path $path | Out-Null
    $calls = [Collections.Generic.List[string]]::new()

    { & $script:ScriptPath -Apply -ExecutionManifestPath $path -ApprovedDigest $copy.digest `
        -Confirm:$false -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
        -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) } } |
        Should -Throw '*arguments differ from reviewed policy*'
    $calls.Count | Should -Be 0
}

```

Then re-run the affected precondition checks immediately before the first write. Refuse a dirty or changed source commit, stale assessment, target-user/computer mismatch, changed or ambiguous executable identity, missing elevation, package-policy mismatch, unsupported package source, or operation not present exactly in both policy and manifest. `-Force` is not a parameter.

- [ ] **Step 5: Implement exact mutation commands, `ShouldProcess`, PATH refresh, and read-back**

Map each action with a `switch` over the closed action name. Resolve `$policyAction = $approvedActions["$($action.action)|$($action.targetId)"]`, revalidate every executable's canonical absolute path and SHA-256 identity against the fresh assessment immediately before use, and build arguments only from `$policyAction`, never from manifest fields:

```powershell
'WinGetInstallExact' {
    $arguments = @(
        'install', '--exact', '--id', $policyAction.packageId,
        '--source', $policyAction.packageSource, '--scope', $policyAction.scope
    )
    if ($PSCmdlet.ShouldProcess($policyAction.targetId, "Install exact WinGet package $($policyAction.packageId)")) {
        $nativeResult = & $NativeCommandRunner $assessment.platform.packageManager.executablePath $arguments
    }
}
'InstallPesterExact' {
    $arguments = @(
        '-NoProfile', '-Command',
        "Install-Module '$($policyAction.targetId)' -RequiredVersion '$($policyAction.requiredVersion)' -Repository '$($policyAction.packageSource)' -Scope '$($policyAction.scope)'"
    )
    if ($PSCmdlet.ShouldProcess(
        "$($policyAction.targetId) $($policyAction.requiredVersion)",
        "Install exact module from $($policyAction.packageSource) in $($policyAction.scope) scope"
    )) {
        $nativeResult = & $NativeCommandRunner (($assessment.tools | Where-Object id -eq 'WindowsPowerShell').executablePath) $arguments
    }
}
'InstallBicepComponent' {
    if ($PSCmdlet.ShouldProcess('Azure CLI Bicep component', 'Install')) {
        $nativeResult = & $NativeCommandRunner (($assessment.tools | Where-Object id -eq 'AzureCli').executablePath) @('bicep', 'install')
    }
}
'InstallAzureCliExtensionExact' {
    if ($PSCmdlet.ShouldProcess('azure-devops', 'Install exact Azure CLI extension')) {
        $nativeResult = & $NativeCommandRunner (($assessment.tools | Where-Object id -eq 'AzureCli').executablePath) @('extension', 'add', '--name', $policyAction.targetId)
    }
}
'InstallVsCodeExtensionExact' {
    if ($PSCmdlet.ShouldProcess($policyAction.targetId, 'Install reviewed VS Code extension')) {
        $nativeResult = & $NativeCommandRunner (($assessment.tools | Where-Object id -eq 'VisualStudioCode').executablePath) @('--install-extension', $policyAction.targetId)
    }
}
default { throw "Execution manifest contains an unallowlisted action: $($action.action)" }
```

Do not use `Invoke-Expression`, `Start-Process -Verb RunAs`, `SetEnvironmentVariable`, `Set-ExecutionPolicy`, `Set-MpPreference`, registry writes, profile edits, shell restarts, or authentication commands.

Do not pass WinGet agreement-acceptance or non-interactive flags. The operator remains present for any package/source agreement prompt; if the package manager cannot complete without a separate terms, license, or source-consent action, record `Manual`, stop dependent actions, and require reassessment and a new approved digest. After a successful install, call `Update-RunbookProcessPath` inside module scope, resolve the expected executable again, refuse ambiguity, record its canonical absolute path and SHA-256 identity, run only its reviewed version arguments through that path, and mark the operation `Verified` only when the postcondition passes. Every planned, declined, WhatIf, applied, verified, failed, or refused operation calls `ConvertTo-RunbookEvidenceRecord` with the source commit, assessment/plan/manifest digests, display-safe operator ID, actual `ShouldProcess` decision, and final workstation context. A restart requirement stops later dependent actions and emits `Manual`. A failed command or read-back emits `Failed`, stops dependent actions, and writes a recovery item naming exact observed state and reassessment; it never retries with broader scope or permissions.

- [ ] **Step 6: Add AST/static safety tests**

Create `RunbookStaticSafety.Tests.ps1`:

```powershell
Describe 'Runbook static safety' {
    BeforeAll {
        $script:RunbookRoot = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks'
        $script:Initializer = Join-Path $script:RunbookRoot 'Initialize-DeveloperWorkstation.ps1'
        $script:Assessment = Join-Path $script:RunbookRoot 'Test-DeveloperWorkstation.ps1'
    }

    It 'declares SupportsShouldProcess and an explicit Apply switch' {
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($script:Initializer, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
        $ast.ParamBlock.Attributes.Extent.Text | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
        @($ast.ParamBlock.Parameters.Name.VariablePath.UserPath) | Should -Contain 'Apply'
        $ast.Extent.Text | Should -Match '\$PSCmdlet\.ShouldProcess\('
    }

    It 'contains no security weakening persistence self-elevation or authentication command' {
        $content = (Get-Content -Raw $script:Initializer), (Get-Content -Raw $script:Assessment) -join "`n"
        $content | Should -Not -Match '(?i)\b(Set-ExecutionPolicy|Set-MpPreference|Invoke-Expression)\b'
        $content | Should -Not -Match '(?i)Start-Process.+-Verb\s+RunAs'
        $content | Should -Not -Match '(?i)SetEnvironmentVariable'
        $content | Should -Not -Match '(?i)\b(az\s+login|gh\s+auth\s+login|azd\s+auth\s+login|pac\s+auth\s+create|copilot\s+login)\b'
        $content | Should -Not -Match '(?i)(Read-Host|\[Console\]::ReadLine|\$input\b)'
    }

    It 'accepts no credential material and contains no OIDC or workflow execution path' {
        $tokens = $null; $errors = $null
        $asts = @(
            [Management.Automation.Language.Parser]::ParseFile($script:Initializer, [ref]$tokens, [ref]$errors)
            [Management.Automation.Language.Parser]::ParseFile($script:Assessment, [ref]$tokens, [ref]$errors)
        )
        $parameterNames = @($asts.ParamBlock.Parameters.Name.VariablePath.UserPath)
        $parameterNames -join '|' |
            Should -Not -Match '(?i)(password|token|secret|credential|certificate|pat)'
        (($asts.Extent.Text) -join "`n") |
            Should -Not -Match '(?i)(ACTIONS_ID_TOKEN_REQUEST_TOKEN|id-token:\s*write|workflow_dispatch|federated.?credential)'
    }

    It 'keeps every native mutator behind ShouldProcess' {
        $content = Get-Content -Raw $script:Initializer
        foreach ($verb in @('WinGetInstallExact', 'Install-Module', "'extension', 'add'", "'bicep', 'install'", '--install-extension')) {
            $content | Should -Match ([regex]::Escape($verb))
        }
        $content | Should -Not -Match '(?i)\b(upgrade|uninstall|remove)\b'
    }

    It 'builds the module installation from the matched policy action' {
        $content = Get-Content -Raw $script:Initializer
        $branch = [regex]::Match(
            $content,
            "(?s)'InstallPesterExact'\s*\{(?<body>.*?)\}\s*'InstallBicepComponent'"
        )
        $branch.Success | Should -BeTrue
        foreach ($field in @('targetId', 'requiredVersion', 'packageSource', 'scope')) {
            $branch.Groups['body'].Value | Should -Match ([regex]::Escape("`$policyAction.$field"))
        }
        $branch.Groups['body'].Value |
            Should -Not -Match '(?i)(Install-Module\s+Pester|5\.7\.1|PSGallery|CurrentUser)'
    }
}
```

- [ ] **Step 7: Run all initialization and static safety tests**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1,infra/tests/pester/RunbookStaticSafety.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS. The call recorder remains empty for default, `-WhatIf`, declined confirmation, stale assessment, digest mismatch, source mismatch, target mismatch, unknown action, and missing elevation cases; approved Apply uses only exact arguments and performs read-back.

- [ ] **Step 8: Commit initialization as a separate review gate**

```powershell
git add -- infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1 infra/tests/pester/DeveloperWorkstationInitialization.Tests.ps1 infra/tests/pester/RunbookStaticSafety.Tests.ps1
git commit -m "feat(infra): add gated workstation initialization"
```

Expected: one commit whose mutation boundary can be reviewed independently from policy and assessment.

---

### Task 6: Publish the Runbook Index and Workstation Procedure

**Files:**
- Create: `infra/docs/runbooks/README.md`
- Create: `infra/docs/runbooks/01-developer-workstation.md`
- Create: `infra/tests/pester/RunbookDocumentation.Tests.ps1`
- Modify: `infra/README.md`

**Interfaces:**
- Consumes: delivered script signatures, policy identifiers, execution state machine, evidence location, and status semantics from Tasks 1–5.
- Produces: service-owner/admin-facing operational contracts linked from the Infrastructure documentation map; no script, tenant, authentication, package, or cloud change.

- [ ] **Step 1: Add failing documentation contract cases**

Create `infra/tests/pester/RunbookDocumentation.Tests.ps1`. Import `.github/cli/modules/DocumentationMetadata.psm1` and add focused cases:

```powershell
It 'includes metadata-compliant infrastructure runbooks in the documentation set' {
    foreach ($relative in @(
        'infra/docs/runbooks/README.md',
        'infra/docs/runbooks/01-developer-workstation.md'
    )) {
        $path = Join-Path $script:repositoryRoot $relative
        $path | Should -Exist
        @(Test-DocumentationMetadataContent -Content (Get-Content -Raw $path)).Count | Should -Be 0
    }
}

It 'documents local attended authentication and rejects workload execution' {
    $index = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\docs\runbooks\README.md')
    $workstation = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\docs\runbooks\01-developer-workstation.md')
    $content = $index + "`n" + $workstation
    $content | Should -Match ([regex]::Escape('az login --tenant $tenantId --use-device-code'))
    $content | Should -Match ([regex]::Escape('gh auth login --hostname github.com --git-protocol https --web'))
    $content | Should -Match ([regex]::Escape('az devops project show'))
    $content | Should -Match ([regex]::Escape('pac auth create --deviceCode'))
    $content | Should -Match 'MFA'
    $content | Should -Match 'Conditional Access'
    $content | Should -Match 'GitHub Actions.+prohibited'
    $content | Should -Match 'OIDC workload identit.+prohibited'
    $content | Should -Match 'token.+never'
}
```

In the same test file, require `infra/README.md` to link to both runbook documents. Parse each relative Markdown destination from the two runbooks, remove any `#fragment`, resolve it from the containing directory, and assert that the local target exists; skip `https://` destinations. Do not add the vendored `.github/skills/*/SKILL.md` files to metadata eligibility.

- [ ] **Step 2: Run documentation tests to verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookDocumentation.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because the two runbook Markdown files and Infrastructure map links do not exist.

- [ ] **Step 3: Write the shared runbook index**

Use the standard six-field table immediately after the H1:

```markdown
# Infrastructure Operational Runbooks

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure operations |
| **References** | [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md), [Infrastructure Domain](../../README.md) |
```

Write concise sections for:

1. audience and ownership: service owner approves intent/digest and accepts residual risk; workstation administrator performs attended local operations; operator may assess; security/tenant administrators own separate later cloud approvals;
2. ordered state machine: prerequisites → assessment → preview/plan → digest approval → Apply plus `ShouldProcess` → read-back → redacted evidence → recovery/close;
3. exact meanings of reviewed intent, execution manifest, evidence summary, `NoChange`, `Create`, `Update`, `Manual`, `Blocked`, and `Refused`;
4. external evidence path and prohibited evidence;
5. approval expiry of 30 minutes and invalidation conditions;
6. elevation, interactive sign-in, MFA, Conditional Access, license/terms, restart, and unsupported API boundaries;
7. local-only tenant operation: all later GitHub, Azure, Azure DevOps, Power Platform, and SharePoint operations start from this workstation in an attended PowerShell session; GitHub Actions and OIDC workload identities are prohibited tenant-preparation paths;
8. authentication lifecycle: attended device/web login, immediate context read-back, operation, final context read-back, explicit sign-out/profile deletion, and cleanup verification;
9. escalation: stop, preserve sanitized evidence, notify the service owner and responsible workstation/security administrator, then reassess;
10. a table linking `01-developer-workstation.md` as independently runnable and later runbooks only as out-of-scope future interfaces.

State explicitly: repository-bundled Superpowers skills and custom agents are integrity/presence checked, never machine-installed; `.github/plugins` is expected to be absent in this baseline; vendored skill content must never be edited by a workstation procedure.

- [ ] **Step 4: Write the Windows 11 administrator runbook**

Use the same six-field header and direct references to:

```text
https://learn.microsoft.com/en-us/windows/package-manager/winget/
https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess
https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows
https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows
https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install
https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd
https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction
https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth
https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively
https://learn.microsoft.com/en-us/azure/devops/cli/
https://docs.github.com/en/get-started/getting-started-with-git/set-up-git
https://docs.github.com/en/github-cli/github-cli/quickstart
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github
https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli
```

Include copy/paste-ready sections:

```powershell
# Refresh PATH in the current shell without changing persistent configuration.
$env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'

# Assessment: no install, configuration, or authentication mutation.
powershell.exe -NoProfile -File infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1 `
    -ReportPath (Join-Path $env:LOCALAPPDATA 'CaldovaHrFrontier\runbook-evidence\assessment')

# Preview and generate the execution manifest.
powershell.exe -NoProfile -File infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1 `
    -ReportPath (Join-Path $env:LOCALAPPDATA 'CaldovaHrFrontier\runbook-evidence\preview')

# Review the manifest and record its exact digest before Apply.
powershell.exe -NoProfile -File infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1 `
    -Apply `
    -ExecutionManifestPath "$env:LOCALAPPDATA\CaldovaHrFrontier\runbook-evidence\preview\workstation-execution-manifest.json" `
    -ApprovedDigest $approvedDigest `
    -WhatIf
```

Between the preview command and the Apply/`-WhatIf` command, run:

```powershell
$manifestPath = "$env:LOCALAPPDATA\CaldovaHrFrontier\runbook-evidence\preview\workstation-execution-manifest.json"
$approvedDigest = (Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json).digest
if ($approvedDigest -cnotmatch '^[0-9a-f]{64}$') { throw 'The reviewed manifest does not contain a valid digest.' }
```

Explain that the service owner compares and records this displayed digest before actual Apply removes `-WhatIf`; Apply prompts at each target unless `-Confirm:$false` is separately authorized.

For every tool, state assessment command, install scope, elevation expectation, read-back command, restart possibility, and recovery. Distinguish:

- Windows PowerShell 5.1 is an OS component and is never installed by this runbook.
- PowerShell 7, Git, VS Code, GitHub CLI, Azure CLI, Azure Developer CLI, PAC CLI, and officially verified Copilot CLI use exact reviewed WinGet IDs.
- Bicep is an Azure CLI component; `az bicep version` is its read-back.
- Pester is exact version 5.7.1 in `CurrentUser`.
- `azure-devops` is the only required Azure CLI extension in this increment.
- VS Code extensions are recommendations and may be applied only when present in the execution manifest.
- GitHub Copilot entitlement, terms, and sign-in remain attended; installation does not prove entitlement or authentication.
- All `gh`, `az`, `azd`, `pac`, and Copilot interactive authentication occurs only after initialization, in the later procedure that needs it.

Add an **Attended authentication readiness** section that states these are operator commands for later service runbooks, not commands called by either workstation script. Use non-secret variables loaded from reviewed intent and these exact patterns:

```powershell
# Azure and Azure DevOps: device-code delegated user context.
az login --tenant $tenantId --use-device-code
if ($LASTEXITCODE -ne 0) { throw 'Azure device-code authentication failed or was denied.' }
az account set --subscription $subscriptionId
$azureContext = az account show --output json | ConvertFrom-Json
if ($azureContext.tenantId -cne $tenantId) { throw 'Azure tenant context mismatch.' }
if ($azureContext.id -cne $subscriptionId) { throw 'Azure subscription context mismatch.' }
if ($azureContext.user.type -cne 'user') { throw 'Azure delegated user context is required.' }
$signedInUser = az ad signed-in-user show --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $signedInUser.id -cne $expectedEntraUserObjectId) {
    throw 'Azure signed-in user context mismatch.'
}

# Azure DevOps reuses that Azure CLI delegated context; never supply a PAT.
$project = az devops project show `
    --organization $organizationUrl `
    --project $projectName `
    --output json | ConvertFrom-Json
if ($project.id -cne $projectId) { throw 'Azure DevOps project context mismatch.' }

# Cleanup after the final Azure/Azure DevOps read-back.
az logout
az account clear
if ($LASTEXITCODE -ne 0) { throw 'Azure CLI context cleanup failed.' }
```

The Azure DevOps section must explain that the linked Microsoft Learn page also documents PAT-based login, but this repository prohibits that mode. Before approving the procedure, verify through current Microsoft Learn and a synthetic/sandbox check that the installed Azure DevOps CLI extension uses the Azure CLI delegated login for the shown read operation. If delegated context is not supported, mark Azure DevOps authentication `Blocked`; do not request or accept a PAT.

```powershell
# GitHub: supported browser/device flow from the local workstation.
gh auth login --hostname github.com --git-protocol https --web --clipboard
if ($LASTEXITCODE -ne 0) { throw 'GitHub web/device authentication failed or was denied.' }
$githubLogin = gh api user --jq .login
if ($LASTEXITCODE -ne 0 -or $githubLogin -cne $expectedGitHubLogin) {
    throw 'GitHub account context mismatch.'
}
gh auth status --hostname github.com

# Later GitHub configuration uses local gh API calls only.
gh api "repos/$owner/$repository" --method GET | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'GitHub repository context read-back failed.' }

# Cleanup after the final GitHub read-back.
gh auth logout --hostname github.com
gh auth status --hostname github.com
if ($LASTEXITCODE -eq 0) { throw 'GitHub CLI still reports an authenticated context.' }
```

State that later mutations use reviewed local `gh api --method POST|PUT|PATCH|DELETE` calls with exact repository IDs and digest-approved bodies. They never use `workflow_dispatch`, a runner, an Actions secret, an OIDC token, or a workflow permission.

Before publishing the PAC command, execute `pac auth create help` and compare it to Microsoft Learn. When the installed supported syntax is `--deviceCode`, document:

```powershell
# Power Platform: one deterministic profile for each reviewed stage.
$runProfileName = "hr-$tenantAlias-$stage"
if ($runProfileName.Length -gt 30) { throw 'PAC profile name exceeds 30 characters.' }
pac auth create --name $runProfileName --environment $environmentUrl --deviceCode
if ($LASTEXITCODE -ne 0) { throw 'PAC device-code authentication failed or was denied.' }
pac auth list
if ($LASTEXITCODE -ne 0) { throw 'PAC authentication-profile read-back failed.' }

# Select and validate the exact newly created profile before any operation.
pac auth select --name $runProfileName
pac org who --environment $environmentUrl
if ($LASTEXITCODE -ne 0) { throw 'PAC environment context read-back failed.' }

# Delete only the exact profile created for this run, then prove it is absent.
pac auth delete --name $runProfileName
$profilesAfterCleanup = pac auth list | Out-String
if ($profilesAfterCleanup -match [regex]::Escape($runProfileName)) {
    throw 'PAC authentication-profile cleanup failed.'
}
```

If the installed PAC version supports selection/deletion only by index, capture the exact index returned by `pac auth list`, cross-check its profile name and environment before selection and deletion, and pass that exact index. Never call `pac auth clear`, because it could delete unrelated operator profiles.

State explicitly:

- The operator completes device-code entry, browser interaction, MFA, Conditional Access, terms, and consent personally. A script never opens a credential prompt that it reads or controls.
- Cancellation, timeout, wrong account, wrong tenant/subscription/organization/project/environment, MFA denial, Conditional Access denial, or incomplete read-back stops the run before mutation.
- Console and evidence may record only non-secret account identifiers needed for comparison. They never record tokens, device codes, cookies, authorization headers, credential-store contents, or raw authentication responses.
- Commands never include a password, token, PAT, client secret, or certificate secret. Scripts expose no parameter or pipeline input for such material.
- Sign-out happens after final read-back and also on refusal/failure where supported. Cleanup failure is reported as `Manual` and escalated; it is not reported as a successful close.

Recovery must require full reassessment after restart or partial failure, a new manifest when state changed, and a new approval digest. It must prohibit broadening scope, changing package IDs, weakening security, or claiming a `Manual` item as verified.

- [ ] **Step 5: Update the Infrastructure documentation map**

Add:

```markdown
| [Operational Runbooks](docs/runbooks/README.md) | Defines the shared preview, approval, evidence, manual-step, read-back, and recovery contract. |
| [Developer Workstation](docs/runbooks/01-developer-workstation.md) | Assesses and explicitly initializes an approved Windows 11 administrator workstation. |
```

Update `Current Boundary` narrowly: this domain now contains workstation assessment/initialization tooling and shared runbook contracts, but no cloud-foundation Apply, customer export/publication, production deployment, or tenant creation.

- [ ] **Step 6: Run metadata and link tests to verify the green state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester infra/tests/pester/RunbookDocumentation.Tests.ps1,.github/cli/tests/DocumentationMetadata.Tests.ps1,.github/cli/tests/DocumentationLinks.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS with valid six-field headers, UTF-8-readable English text, and resolvable relative links.

- [ ] **Step 7: Commit runbook documentation**

```powershell
git add -- infra/docs/runbooks/README.md infra/docs/runbooks/01-developer-workstation.md infra/README.md infra/tests/pester/RunbookDocumentation.Tests.ps1
git commit -m "docs(infra): publish workstation runbook"
```

Expected: one documentation commit with no generated evidence and no vendored skill changes.

---

### Task 7: Close Repository Safety and Acceptance Gates

**Files:**
- Modify only if the red test proves necessary: `.github/cli/verify-repository-safety.ps1`
- Modify only if the red test proves necessary: `.github/cli/tests/RepositorySafety.Tests.ps1`
- Verify unchanged: `.github/workflows/validate-repository.yml`
- Verify unchanged: `.github/cli/tests/WorkflowContract.Tests.ps1`

**Interfaces:**
- Consumes: every artifact and test from Tasks 1–6.
- Produces: a green pinned Windows PowerShell 5.1 acceptance run, repository safety result, Bicep build, metadata/link result, clean whitespace check, and proof that the existing workflow already discovers the new tests.

- [ ] **Step 1: Run the safety validator before changing it**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
```

Expected: PASS with `Repository safety validation passed.` because exact workstation install operations are gated implementation, not a subscription deployment or credential pattern. If it fails on a genuine unsafe pattern, correct the runbook implementation rather than weakening the validator.

- [ ] **Step 2: Write a failing safety fixture for workstation security weakening**

Add this case to `RepositorySafety.Tests.ps1`:

```powershell
It 'rejects workstation security-policy weakening' -TestCases @(
    @{ Content = 'Set-ExecutionPolicy Unrestricted -Force' }
    @{ Content = 'Set-MpPreference -DisableRealtimeMonitoring $true' }
    @{ Content = 'Start-Process powershell.exe -Verb RunAs' }
) {
    param([string]$Content)
    $fixtureRoot = New-SafetyFixture -Content $Content
    $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object ToString)
    $LASTEXITCODE | Should -Be 1
    $output -join "`n" | Should -Match 'Prohibited bootstrap command or credential pattern found'
}
```

- [ ] **Step 3: Run the focused safety test to verify the red state**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester .github/cli/tests/RepositorySafety.Tests.ps1 -Output Detailed -CI"
```

Expected: FAIL because the repository safety pattern does not yet reject the three workstation security-weakening forms.

- [ ] **Step 4: Extend the safety pattern without blocking reviewed installers**

Extend only `$prohibitedPattern`:

```powershell
$prohibitedPattern = 'az\s+deployment\s+sub\s+create|New-AzSubscriptionDeployment|client[_-]?secret|AZURE_CLIENT_SECRET|--password|Set-ExecutionPolicy\s+(?:Unrestricted|Bypass)|Set-MpPreference\s+-DisableRealtimeMonitoring|Start-Process[^\r\n]+-Verb\s+RunAs'
```

Do not add `winget install`, `Install-Module`, `az bicep install`, `az extension add`, or `code --install-extension` to the global prohibited list; their exact allowlist and `ShouldProcess` boundaries are owned by `RunbookStaticSafety.Tests.ps1` and initialization behavior tests.

- [ ] **Step 5: Run safety and workflow contract tests**

Run:

```powershell
powershell.exe -NoProfile -Command "Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester .github/cli/tests/RepositorySafety.Tests.ps1,.github/cli/tests/WorkflowContract.Tests.ps1 -Output Detailed -CI"
```

Expected: PASS. `WorkflowContract.Tests.ps1` proves the unchanged validation workflow still invokes the full `infra/tests/pester` directory, safety validator, Bicep build, and whitespace check. Do not edit `.github/workflows/validate-repository.yml`.

- [ ] **Step 6: Refresh PATH and run the complete pinned Pester 5.7.1 suite under Windows PowerShell 5.1**

Run:

```powershell
$env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'
$windowsPowerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
& $windowsPowerShell -NoProfile -Command @'
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
if ((Get-Module Pester).Version -ne [version]'5.7.1') { throw 'Pester 5.7.1 is required.' }
Invoke-Pester -Path @(
    '.github/cli/tests/WorkflowContract.Tests.ps1'
    '.github/cli/tests/RepositorySafety.Tests.ps1'
    'infra/tests/pester'
    'hr/tests/pester'
) -Output Detailed -CI
'@
if ($LASTEXITCODE -ne 0) { throw "Pinned Windows PowerShell Pester acceptance failed: $LASTEXITCODE" }
```

Expected: PASS with Pester version exactly `5.7.1`; no live authentication, package installation, or tenant call occurs.

- [ ] **Step 7: Run repository safety, Bicep, documentation, and whitespace acceptance**

Run:

```powershell
& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
if ($LASTEXITCODE -ne 0) { throw 'Repository safety validation failed.' }

az bicep build --file infra/src/bicep/main.bicep --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed.' }

& $windowsPowerShell -NoProfile -Command @'
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester -Path @(
    '.github/cli/tests/DocumentationMetadata.Tests.ps1'
    '.github/cli/tests/DocumentationLinks.Tests.ps1'
    'infra/tests/pester/RunbookDocumentation.Tests.ps1'
) -Output Detailed -CI
'@
if ($LASTEXITCODE -ne 0) { throw 'Documentation metadata/link validation failed.' }

git diff --check
if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed.' }
```

Expected: safety prints `Repository safety validation passed.`; Bicep exits `0`; documentation tests PASS; `git diff --check` emits no output and exits `0`.

- [ ] **Step 8: Review scope and staged artifacts**

Run:

```powershell
git status --short
git diff --name-only HEAD
git diff -- .github/skills
git diff -- .github/workflows
```

Expected: only files named in this plan are changed; both final diff commands emit no output; no evidence/report file, cloud/handover script, tenant file, source inventory, secret, generated Bicep output, or vendored skill content is present.

- [ ] **Step 9: Commit the safety gate**

```powershell
git add -- .github/cli/verify-repository-safety.ps1 .github/cli/tests/RepositorySafety.Tests.ps1
git commit -m "test(repo): reject workstation security weakening"
```

Expected: one focused safety-validator commit. The validation workflow remains unchanged.

## Plan Self-Review

- **Spec coverage:** Tasks 2–3 provide shared external-output, canonical JSON, digest, manifest, interactive-authentication context, validation, and evidence interfaces for later plans. Tasks 4–5 provide interactive-host refusal, assessment, explicit Apply, `ShouldProcess`, read-back, PATH refresh, refusal, manual boundaries, and recovery. Task 6 provides both required runbooks, service-owner/admin language, official authentication references, device/web login, context read-back, cleanup, metadata, and catalogue links. Task 7 provides every required acceptance command.
- **Revised execution boundary:** Every operational command is local and attended on Windows 11. No GitHub Actions workflow is added or modified; no workflow, runner, OIDC workload identity, PAT, password, token, client secret, or certificate secret can prepare a tenant. GitHub configuration is reserved for reviewed local PowerShell/`gh api` calls.
- **Scope:** No cloud-foundation script, customer-export script, tenant mutation, publication, production deployment, unattended authentication, license operation, personal data, or source-history operation is included.
- **Identifier provenance:** Task 1 requires live read-only verification against official/package-manager sources before reviewed identifiers become executable. Tests consume synthetic fixtures and never depend on package-manager availability.
- **Signature consistency:** `assessmentDigest`, `sourceCommit`, `authentication`, `allowedActions`, `digest`, runner parameters, interactive-host probes, helper names, and script parameters use the same spelling and types in every consuming task. Both module export declarations are updated together.
- **Completeness scan:** Every implementation branch, test expectation, command, file path, status, identifier, and scope decision is explicit; runtime approval is read from the generated manifest and then compared and recorded by the service owner.
- **Documentation policy:** All planned repository-owned Markdown is English, has the exact six-field header, uses relative repository references, and remains Proposed Baseline pending review. Git history is the only change log.

## Execution Handoff

After all three coordinated plans are approved, execute this plan first because it establishes the shared contracts consumed by the cloud-foundation and customer-handover plans.

1. **Subagent-Driven (recommended):** use `superpowers:subagent-driven-development`, dispatch a fresh implementation subagent for each task, and complete requirements and quality review before the next task.
2. **Inline Execution:** use `superpowers:executing-plans`, implement in batches, and stop at the documented review checkpoints.
