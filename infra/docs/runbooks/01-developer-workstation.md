# Developer Workstation Runbook

| Field | Value |
|---|---|
| **Version** | 1.7 |
| **Date** | 2026-10-26 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Approved Windows 11 administrator workstation |
| **References** | [Infrastructure Operational Runbooks](README.md); [Approved Tenant 1 Runbook End-to-End Design](../../../docs/specs/2026-10-02-tenant-1-runbook-end-to-end-design.md); [Approved Child Summary Envelope Design](../../../docs/specs/2026-10-03-tenant-lifecycle-child-summary-envelope-design.md); [Draft Child Summary Envelope Implementation Plan](../../../docs/plans/2026-10-03-tenant-lifecycle-child-summary-envelope-implementation.md); [Tenant Lifecycle Core Implementation Plan](../../../docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md); [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md) |

This runbook assesses and, when explicitly approved, initializes one local Windows 11 administrator workstation for later attended infrastructure operations. It does not authenticate to cloud services, deploy infrastructure, create tenants, install repository-bundled skills, or mutate vendored content.

## Read-only tool compatibility gate

Run [`Test-DeveloperWorkstationCompatibility.ps1`](../../src/scripts/runbooks/Test-DeveloperWorkstationCompatibility.ps1)
before accepting the prerequisite policy. The closed
[technical compatibility record](../../src/config/runbooks/workstation-compatibility.json)
pins all nine delivery-critical components, including full Windows and vendor
build suffixes. Its automated technical review is not a human approval, child
acceptance result, or live organization/import capability.

```powershell
powershell.exe -NoProfile -File infra/src/scripts/runbooks/Test-DeveloperWorkstationCompatibility.ps1 `
  -ReportPath (Join-Path $env:TEMP 'caldova-workstation-compatibility')
```

The gate checks unique canonical physical identities, exact source/hash/version,
Windows X64 host constraints, installed extension metadata, and local command
capabilities without authentication or installation. Both WindowsApps PowerShell
aliases must identify the same physical host. The reviewed standalone Bicep
location is resolved explicitly; assessment does not invoke `az bicep version`
or implicitly install an absent component.

PAC must also preserve the synthetic fixture's two declared HTML/JavaScript Web
Resources, their manifest and payload references, and payload bytes through
pack/unpack in a unique owned external workspace. The fixture follows
[Microsoft's Web Resource model](https://learn.microsoft.com/en-us/power-apps/developer/model-driven-apps/web-resources)
and [published resource metadata](https://github.com/microsoft/coe-starter-kit/blob/main/CenterofExcellenceCoreComponents/SolutionPackage/src/WebResources/accessChecker_openDialog.js.data.xml).
Exit zero and help alone are not packaging proof. Empty source, missing payload,
component loss, changed identities, or unproven capabilities return `Blocked`
and process exit 1 without policy mutation. `NoChange` means only that this local
compatibility gate passed.

The legacy Code App and its historical `BackgroundImageUri` case remain excluded
only for this sprint under the [declared component boundary](../../../docs/specs/2026-10-02-cloud-service-foundation-runbook-design.md#33-current-sprint-component-boundary).
Unexpected out-of-scope Code App input is refused, never stripped. Fixture
success neither fixes that historical issue nor proves complete HR delivery
source or Dataverse parity. Installer execution and live acceptance remain
separate, explicitly approved operations.

## Lifecycle-core integration boundary

The lifecycle core recognizes `Workstation` as a stage identifier but does not invoke [`Test-DeveloperWorkstation.ps1`](../../src/scripts/runbooks/Test-DeveloperWorkstation.ps1) or [`Initialize-DeveloperWorkstation.ps1`](../../src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1). The workstation procedure remains independently runnable under its own manifest and evidence contract. A later reviewed plan must supply and test the production subsystem invoker before the umbrella may sequence it.

Plan 1's synthetic `Workstation` stage is not workstation assessment, installation, authentication, Apply, or read-back evidence. It authorizes none of those operations and does not change the gates in this runbook.

The workstation child owns its assessment, execution manifest, approval, WhatIf/Apply, `ShouldProcess`, local read-back, terminal summary, and immutable `<run>/stage-results/Workstation.json` result. Existing `ExecutionManifestPath`, `ApprovedDigest`, and `Apply` parameters remain child interfaces on `Initialize-DeveloperWorkstation.ps1`; they are not umbrella parameters. The exact future sequence is child `Plan` -> child `approvals.json` -> child `WhatIf` -> child `Apply` -> child read-back -> canonical stage result -> umbrella `Verify`.

Umbrella `Assess` or `Plan` may later dispatch only the matching non-mutating workstation child mode through a reviewed invoker. Umbrella `Verify` never invokes the workstation child, never installs software, and never interprets workstation actions; it accepts only an exact canonical stage result with literal `Passed` status. Plan 1 was implemented with local synthetic tests only; no live cloud, provider, or tenant operation was performed.

### Approved child summary envelope and residual gate

The shared child summary envelope reserves exactly `schemaVersion`, `runId`, `stage`, `sourceCommit`, `publicTenantKey`, `intentDigest`, `stateDigest`, `phaseManifestDigest`, `status`, `classification`, and `completedAtUtc`, and retains the five standard fields `startedAtUtc`, `counts`, `prerequisites`, `actions`, and `nonClaims`.

Provider-specific extras are root-only and opaque, are absent from projections and errors, and cannot enter the closed shared nested structures.

The manifest embedded `digest`, exact-file `phaseManifestDigest`, and exact-file `phaseSummaryDigest` are three distinct checks.

The child writes the summary before the stage result, and the summary has no self-digest.

Umbrella `Verify` and `Assess`/`Plan` prerequisite dispatch enforce the same envelope and embedded manifest digest.

Legacy evidence fails closed and requires a new run; there is no compatibility, inference, or repair path.

Umbrella authority remains exactly `Assess`, `Plan`, and `Verify`; `stage-results` remains authoritative and the second `Verify` pass remains required.

Plan 1 and the child summary envelope implementation remain synthetic, `Draft`, and blocked until reviewed merge and then-current green `main`.

No live, provider, or tenant operation was performed, and no merge-readiness claim is made.

## Authoritative installation and authentication references

- <https://learn.microsoft.com/en-us/windows/package-manager/winget/>
- <https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess>
- <https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows>
- <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows>
- <https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install>
- <https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd>
- <https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction>
- <https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth>
- <https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively>
- <https://learn.microsoft.com/en-us/azure/devops/cli/>
- <https://docs.github.com/en/get-started/getting-started-with-git/set-up-git>
- <https://docs.github.com/en/github-cli/github-cli/quickstart>
- <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github>
- <https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli>

## Local refresh and read-only assessment

Refresh the current shell without changing persistent PATH configuration:

```powershell
# Refresh PATH in the current shell without changing persistent configuration.
$env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'
```

## External worktree prerequisite

The durable Windows convention keeps the primary checkout and its worktree container beside each other:

```text
Source\
    <repository-context>\
        caldova-hr-frontier\
        wt\
            <sprint-branch>\
```

`<repository-context>` identifies the GitHub or Azure DevOps repository context. Each worktree uses a reviewed, unique, short sprint or branch directory name directly below `wt`; do not create `.worktrees` or `worktrees` inside the primary checkout. In this example, `doc-arch` is the reviewed task directory name.

The following resolves the primary checkout's shared Git directory, so it uses the same sibling `wt` root from the primary checkout or a linked worktree. It requires no administrator rights.

```powershell
$gitCommonDirectory = git rev-parse --path-format=absolute --git-common-dir
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to resolve the primary checkout Git directory.'
}
$primaryCheckoutRoot = Split-Path -Parent $gitCommonDirectory
$repositoryContextRoot = Split-Path -Parent $primaryCheckoutRoot
$worktreeRoot = Join-Path $repositoryContextRoot 'wt'
New-Item -ItemType Directory -Path $worktreeRoot -Force -ErrorAction Stop | Out-Null
$probe = Join-Path $worktreeRoot ('.write-probe-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
[IO.File]::WriteAllText($probe, 'permission-probe', [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
$taskRoot = Join-Path $worktreeRoot 'doc-arch'
$longestRelative = @(
    git -c core.quotepath=false ls-files |
        Sort-Object Length -Descending
)[0]
$longestCheckoutPath = Join-Path $taskRoot $longestRelative
if ($longestCheckoutPath.Length -ge 240) {
    throw "Worktree path budget exceeded: $($longestCheckoutPath.Length)"
}
```

Never loosen directory ACLs or enable `core.longpaths` automatically. A failed current-user write/delete probe or path-budget check is a blocking workstation prerequisite.

Use `git worktree move <current-path> <new-path>` to relocate existing worktrees without losing their registration or local changes. After branch completion, remove a worktree through `git worktree remove <path>` without forcing removal of uncommitted work. Remove an old container only after confirming it is empty. This sibling convention replaces older Local AppData worktree examples; evidence and tenant-private configuration roots remain unchanged.

Run assessment without installation, configuration, or authentication mutation:

```powershell
# Assessment: no install, configuration, or authentication mutation.
powershell.exe -NoProfile -File infra/src/scripts/runbooks/Test-DeveloperWorkstation.ps1 `
    -ReportPath (Join-Path $env:LOCALAPPDATA 'CaldovaHrFrontier\runbook-evidence\assessment')
```

The assessment script refuses non-interactive, remoted, CI, GitHub Actions, or workload contexts before probing tools. It proves repository integrity, reviewed policy presence, Windows 11 suitability, allowed tool identity, expected repository assets, and the absence of `.github/plugins`.

## Preview, digest approval, and Apply

Generate the reviewed plan and execution manifest first:

```powershell
# Preview and generate the execution manifest.
powershell.exe -NoProfile -File infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1 `
    -ReportPath (Join-Path $env:LOCALAPPDATA 'CaldovaHrFrontier\runbook-evidence\preview')
```

Review the exact manifest digest before any real mutation:

```powershell
$manifestPath = "$env:LOCALAPPDATA\CaldovaHrFrontier\runbook-evidence\preview\workstation-execution-manifest.json"
$approvedDigest = (Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json).digest
if ($approvedDigest -cnotmatch '^[0-9a-f]{64}$') { throw 'The reviewed manifest does not contain a valid digest.' }
```

Use `-WhatIf` to prove the reviewed Apply path without mutating:

```powershell
# Review the manifest and record its exact digest before Apply.
powershell.exe -NoProfile -File infra/src/scripts/runbooks/Initialize-DeveloperWorkstation.ps1 `
    -Apply `
    -ExecutionManifestPath "$env:LOCALAPPDATA\CaldovaHrFrontier\runbook-evidence\preview\workstation-execution-manifest.json" `
    -ApprovedDigest $approvedDigest `
    -WhatIf
```

The service owner compares and records that displayed digest before the workstation administrator removes `-WhatIf` for an attended Apply. Apply prompts at each target unless `-Confirm:$false` is explicitly reviewed for that run. Every mutation remains behind `ShouldProcess`, and every postcondition is read back before the run can claim success.

## Tool-specific operational contract

| Tool or component | Assessment command | Mutation scope | Elevation expectation | Read-back | Recovery notes |
|---|---|---|---|---|---|
| Windows PowerShell 5.1 | `$PSVersionTable.PSVersion` | None; OS component only | Existing local admin shell | `$PSVersionTable.PSVersion` | Reassess only; never install through this runbook |
| PowerShell 7 | `pwsh --version` | Manual; currently reviewed Microsoft Store host only | Local attended admin | `pwsh --version` and the compatibility gate | Reassess after restart if required |
| Git | `git --version` | Exact reviewed WinGet ID only | Local attended admin | `git --version` | Generate a new manifest if path or version differs |
| VS Code | `code --version` | Exact reviewed WinGet ID only | Local attended admin | `code --version` | Reassess if PATH or extension host changes |
| GitHub CLI | `gh --version` | Exact reviewed WinGet ID only | Local attended admin | `gh --version` | Authentication remains attended and separate |
| Azure CLI | `az version` | Exact reviewed WinGet ID only | Local attended admin | `az version` | Reassess after extension or component change |
| Azure Developer CLI | `azd version` | Exact reviewed WinGet ID only | Local attended admin | `azd version` | Reassess after restart if required |
| PAC CLI | `pac help` | Manual; currently reviewed .NET tool only | Local attended admin | `pac help` and the component round-trip gate | PAC profile operations happen later and attended |
| Copilot CLI | `copilot --help` | Exact reviewed WinGet ID only | Local attended admin | `copilot --help` | Entitlement and sign-in remain attended |
| Bicep | Standalone `bicep --version` | Azure CLI component at the exact reviewed version | Local attended admin | Standalone `bicep --version` and build help | Reassess after component changes |
| Pester 5.7.1 | `Get-Module Pester -ListAvailable` | `CurrentUser` exact reviewed version only | Current user scope | `Import-Module Pester -RequiredVersion 5.7.1 -Force` | New manifest required for any version drift |
| Azure DevOps CLI extension | `az extension show --name azure-devops` | Azure CLI extension only | Local attended admin | `az extension show --name azure-devops` | PAT mode is prohibited; see authentication readiness |
| VS Code extensions | `code --list-extensions --show-versions` | Recommended only when present in manifest | User scope | `code --list-extensions --show-versions` | Optional; never infer or add unapproved IDs |

Windows PowerShell 5.1 is an OS component and is never installed by this runbook. The currently reviewed PowerShell 7 Microsoft Store host and PAC .NET tool remain manual prerequisites; the compatibility record does not approve untested WinGet/MSI substitutes for them. Git, VS Code, GitHub CLI, Azure CLI, Azure Developer CLI, and officially verified Copilot CLI retain their reviewed WinGet IDs. Bicep remains an Azure CLI component, but assessment and read-back use its explicit standalone executable without auto-installation. Pester is exact version 5.7.1 in `CurrentUser`. `azure-devops` is the only required Azure CLI extension in this increment. VS Code extensions are recommendations and may be applied only when present in the execution manifest. GitHub Copilot entitlement, terms, and sign-in remain attended; installation does not prove entitlement or authentication.

## Attended authentication readiness

These are operator commands for later service runbooks. They are not called by either workstation script.

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

Current Microsoft Learn documents both delegated Microsoft Entra authentication and PAT-based sign-in for the Azure DevOps CLI extension. This repository prohibits PAT mode. Service approval for Azure DevOps mutation remains blocked until a sandbox check confirms that the installed `azure-devops` extension still reuses Azure CLI delegated user context for the required read-back on the approved workstation. If that delegated check ever fails, Azure DevOps authentication stays `Blocked` and no PAT alternative is allowed.

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

Later GitHub mutations use reviewed local `gh api --method POST|PUT|PATCH|DELETE` calls with exact repository identifiers and digest-approved bodies. They never use `workflow_dispatch`, a runner, an Actions secret, an OIDC token, or a workflow permission.

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

Before approving PAC use on a workstation, run `pac auth create help` locally and compare its supported syntax with Microsoft Learn. This runbook documents the `pac auth create --deviceCode` form because the supported reference allows it. If the installed PAC version supports selection or deletion only by index, capture the exact index from `pac auth list`, cross-check its profile name and environment, and pass only that index. Never call `pac auth clear`, because it could delete unrelated operator profiles.

## Hard boundaries for attended sign-in

- The operator completes device-code entry, browser interaction, MFA, Conditional Access, terms, and consent personally. A script never opens a credential prompt that it reads or controls.
- Cancellation, timeout, wrong account, wrong tenant, wrong subscription, wrong organization, wrong project, wrong environment, MFA denial, Conditional Access denial, or incomplete read-back stops the run before mutation.
- Console and evidence may record only the non-secret account identifiers needed for comparison. They never record tokens, device codes, cookies, authorization headers, credential-store contents, or raw authentication responses.
- Commands never include a password, token, PAT, client secret, or certificate secret. Scripts expose no parameter or pipeline input for such material.
- Sign-out happens after final read-back and also on refusal or failure where supported. Cleanup failure is reported as `Manual` and escalated; it is not reported as a successful close.

## Recovery

Any restart, partial failure, identity change, PATH change, or tool drift requires full reassessment, a new manifest, and a new approval digest. A process restart invalidates the lifecycle approval even when source and private files are byte-identical; the prior action evidence is preserved but is not resumed as an approved run. Recovery never broadens scope, changes package IDs, weakens security, or claims a `Manual` item as verified. Sanitized evidence is preserved for escalation to the service owner and the responsible workstation or security administrator.
