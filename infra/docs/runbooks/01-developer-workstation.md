# Developer Workstation Runbook

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Approved Windows 11 administrator workstation |
| **References** | [Infrastructure Operational Runbooks](README.md); [Operational Runbooks Design](../../../docs/specs/2026-09-26-operational-runbooks-design.md) |

This runbook assesses and, when explicitly approved, initializes one local Windows 11 administrator workstation for later attended infrastructure operations. It does not authenticate to cloud services, deploy infrastructure, create tenants, install repository-bundled skills, or mutate vendored content.

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

The durable Windows convention is `%LOCALAPPDATA%\CaldovaHR\wt\<repository>\<short-task-id>`. Task worktrees append a reviewed short task ID below the repository root, require no administrator rights, and are removed through `git worktree remove` after branch completion. In this example, `doc-arch` is the reviewed short task ID.

```powershell
$localAppData = [Environment]::GetFolderPath('LocalApplicationData')
if ([string]::IsNullOrWhiteSpace($localAppData)) {
    throw 'LocalApplicationData is unavailable.'
}
$worktreeRoot = Join-Path $localAppData 'CaldovaHR\wt'
$repositoryRoot = Join-Path $worktreeRoot 'caldova-hr-frontier'
New-Item -ItemType Directory -Path $repositoryRoot -Force | Out-Null
$probe = Join-Path $repositoryRoot ('.write-probe-{0}.tmp' -f [guid]::NewGuid().ToString('N'))
[IO.File]::WriteAllText($probe, 'permission-probe', [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $probe -Force
$taskRoot = Join-Path $repositoryRoot 'doc-arch'
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
| PowerShell 7 | `pwsh --version` | Exact reviewed WinGet ID only | Local attended admin | `pwsh --version` | Reassess after restart if required |
| Git | `git --version` | Exact reviewed WinGet ID only | Local attended admin | `git --version` | Generate a new manifest if path or version differs |
| VS Code | `code --version` | Exact reviewed WinGet ID only | Local attended admin | `code --version` | Reassess if PATH or extension host changes |
| GitHub CLI | `gh --version` | Exact reviewed WinGet ID only | Local attended admin | `gh --version` | Authentication remains attended and separate |
| Azure CLI | `az version` | Exact reviewed WinGet ID only | Local attended admin | `az version` | Reassess after extension or component change |
| Azure Developer CLI | `azd version` | Exact reviewed WinGet ID only | Local attended admin | `azd version` | Reassess after restart if required |
| PAC CLI | `pac help` | Exact reviewed WinGet ID only | Local attended admin | `pac help` | PAC profile operations happen later and attended |
| Copilot CLI | `copilot --help` | Exact reviewed WinGet ID only | Local attended admin | `copilot --help` | Entitlement and sign-in remain attended |
| Bicep | `az bicep version` | Azure CLI component only | Local attended admin | `az bicep version` | Reassess after Azure CLI changes |
| Pester 5.7.1 | `Get-Module Pester -ListAvailable` | `CurrentUser` exact reviewed version only | Current user scope | `Import-Module Pester -RequiredVersion 5.7.1 -Force` | New manifest required for any version drift |
| Azure DevOps CLI extension | `az extension show --name azure-devops` | Azure CLI extension only | Local attended admin | `az extension show --name azure-devops` | PAT mode is prohibited; see authentication readiness |
| VS Code extensions | `code --list-extensions --show-versions` | Recommended only when present in manifest | User scope | `code --list-extensions --show-versions` | Optional; never infer or add unapproved IDs |

Windows PowerShell 5.1 is an OS component and is never installed by this runbook. PowerShell 7, Git, VS Code, GitHub CLI, Azure CLI, Azure Developer CLI, PAC CLI, and officially verified Copilot CLI use exact reviewed WinGet IDs. Bicep is an Azure CLI component, and `az bicep version` is its read-back. Pester is exact version 5.7.1 in `CurrentUser`. `azure-devops` is the only required Azure CLI extension in this increment. VS Code extensions are recommendations and may be applied only when present in the execution manifest. GitHub Copilot entitlement, terms, and sign-in remain attended; installation does not prove entitlement or authentication.

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

Any restart, partial failure, identity change, PATH change, or tool drift requires full reassessment, a new manifest when state changed, and a new approval digest. Recovery never broadens scope, changes package IDs, weakens security, or claims a `Manual` item as verified. Sanitized evidence is preserved for escalation to the service owner and the responsible workstation or security administrator.
