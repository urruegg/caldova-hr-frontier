# Tenant 1 Engineering Platform Configuration Review Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Tenant 1 GitHub, Azure DevOps, Azure, Entra, and Power Platform control planes |
| **References** | [Tenant 1 Engineering Platform Configuration Review Design](../specs/2026-09-28-tenant-1-engineering-platform-configuration-review-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a read-only, evidence-backed Tenant 1 configuration review with sanitized machine-readable results, redacted screenshots, prioritized gaps, and post-remediation validation tests.

**Architecture:** Collect raw configuration into private session storage through authenticated read-only commands and APIs, normalize observations into an allowlisted public evidence model, and evaluate every control against the approved one-GitHub-repository-to-one-Azure-DevOps-project North Star. Publish only sanitized JSON, redacted screenshots, and an English review; do not mutate any control plane or create synthetic runtime records.

**Tech Stack:** PowerShell 5.1, GitHub CLI 2.83.1, Azure CLI 2.81.0, Azure DevOps CLI extension 1.0.8, Azure DevOps REST API 7.1 and 7.2-preview.1, Microsoft Graph, Power Platform CLI 1.43.6, Pester 5.7.1, Git

**Spec:** `docs/specs/2026-09-28-tenant-1-engineering-platform-configuration-review-design.md`

## Global Constraints

- Work only against GitHub repository `urruegg/caldova-hr-frontier` and Azure DevOps project `Caldova HR Frontier` in Tenant 1.
- GitHub is the product-source and pull-request authority; Azure Boards is the delivery backlog; Azure Pipelines owns HR solution CI/CD.
- The review is read-only. Do not invoke a create, update, delete, queue, dispatch, approve, merge, push, deploy, role-assignment, or identity-mutation operation.
- Do not create a work item, branch, commit, pull request, pipeline run, artifact, deployment, identity, service connection, variable group, secure file, environment, or role assignment as audit evidence.
- Raw identity-bearing API and command output stays in private session storage and is never staged.
- Public evidence excludes tokens, secrets, certificates, credential metadata, personal names, email addresses, avatars, tenant/subscription/object/application/connection/environment identifiers, tenant-specific service URLs, and unrestricted membership lists.
- Each control outcome is exactly one of `PASS`, `GAP`, `NOT EVIDENCED`, or `NOT APPLICABLE`.
- Authorization failures, API errors, empty fallbacks, missing runtime events, and ambiguous duplicates never become `PASS`.
- Existing runtime records may be inspected; absent runtime records remain `NOT EVIDENCED`.
- Tenant 2 and Tenant 3 are assessed only for reproducibility implications; no live query targets them.
- Supply the tenant-bearing Azure DevOps organization URL at runtime through `ADO_ORGANIZATION_URL`; never write the value into a public artifact.
- Preserve unrelated working-tree changes, including `.github/cli/tests/ContributorSkills.Tests.ps1` and `.vscode/`.

---

## File and Evidence Structure

### Private Session Artifacts

Use this non-repository root for raw collection:

```powershell
$AuditRoot = Join-Path $env:LOCALAPPDATA 'Caldova\audit\tenant1-engineering-platform-review'
```

The structure is:

```text
tenant1-engineering-platform-review/
├─ raw/
│  ├─ preflight/
│  ├─ github/
│  ├─ azure-devops/
│  ├─ azure/
│  ├─ power-platform/
│  └─ screenshots/
├─ normalized/
│  ├─ observations.json
│  └─ findings.json
├─ sources/
│  └─ microsoft-guidance.json
└─ logs/
   └─ collection-log.jsonl
```

### Repository Artifacts

Create or modify only:

```text
docs/reviews/
├─ 2026-09-28-tenant-1-engineering-platform-configuration-review.md
├─ README.md
└─ evidence/
   └─ 2026-09-28-tenant-1-engineering-platform/
      ├─ evidence-manifest.json
      ├─ test-results.json
      ├─ 01-azure-boards-github-app-connection.png
      ├─ 02-azure-repo-settings.png
      ├─ 03-azure-repo-branch-policy-state.png
      ├─ 04-azure-repo-permission-state.png
      ├─ 05-azure-repos-migration-surface.png
      └─ 06-migration-dialog-mismatch.png
```

The report explains the assessment. `evidence-manifest.json` identifies sanitized evidence sources. `test-results.json` contains the complete control outcomes. Screenshots support only portal-visible observations.

---

### Task 1: Establish the Private Evidence Workspace and Verify Identity Context

**Files:**
- Create outside Git: `$AuditRoot\AuditHelpers.psm1`
- Create outside Git: `$AuditRoot\raw\preflight\*.json`
- Create outside Git: `$AuditRoot\logs\collection-log.jsonl`
- Verify: no repository file changes

**Interfaces:**
- Produces: `Invoke-EvidenceCommand -Name [string] -Command [scriptblock] -OutputDirectory [string]`
- Produces: `Invoke-AdoGet -Name [string] -Uri [uri] -OutputDirectory [string]`
- Produces: private preflight evidence proving the active GitHub, Azure, Azure DevOps, and Power Platform contexts
- Consumes: current interactive authenticated sessions only

- [ ] **Step 1: Confirm the working tree and create the private directory structure**

Run:

```powershell
git status --short

$AuditRoot = Join-Path $env:LOCALAPPDATA 'Caldova\audit\tenant1-engineering-platform-review'
$directories = @(
    'raw\preflight',
    'raw\github',
    'raw\azure-devops',
    'raw\azure',
    'raw\power-platform',
    'raw\screenshots',
    'normalized',
    'sources',
    'logs'
)

foreach ($directory in $directories) {
    New-Item -ItemType Directory -Path (Join-Path $AuditRoot $directory) -Force | Out-Null
}
```

Expected: the existing unrelated untracked paths remain unchanged, and no path under `$AuditRoot` appears in `git status`.

- [ ] **Step 2: Create the private collection helper**

Create `$AuditRoot\AuditHelpers.psm1`:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-CollectionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AuditRoot,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('Succeeded', 'Failed')]
        [string]$Status,

        [Parameter(Mandatory)]
        [int]$ExitCode,

        [string]$ErrorClass
    )

    $record = [ordered]@{
        observedUtc = [DateTime]::UtcNow.ToString('o')
        name = $Name
        status = $Status
        exitCode = $ExitCode
        errorClass = $ErrorClass
    }

    $record | ConvertTo-Json -Compress |
        Add-Content -LiteralPath (Join-Path $AuditRoot 'logs\collection-log.jsonl') -Encoding UTF8
}

function Invoke-EvidenceCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AuditRoot,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Command,

        [Parameter(Mandatory)]
        [string]$OutputDirectory,

        [ValidateSet('json', 'txt')]
        [string]$OutputExtension = 'json'
    )

    $outputPath = Join-Path $OutputDirectory "$Name.$OutputExtension"
    $errorPath = Join-Path $OutputDirectory "$Name.error.txt"
    Remove-Item -LiteralPath $outputPath, $errorPath -Force -ErrorAction SilentlyContinue

    try {
        & $Command 1> $outputPath 2> $errorPath
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        if ($exitCode -ne 0) {
            throw "Command exited with code $exitCode."
        }

        Write-CollectionLog -AuditRoot $AuditRoot -Name $Name -Status Succeeded -ExitCode 0
        return $outputPath
    }
    catch {
        $exitCode = if ($null -eq $LASTEXITCODE) { 1 } else { [int]$LASTEXITCODE }
        Write-CollectionLog -AuditRoot $AuditRoot -Name $Name -Status Failed -ExitCode $exitCode -ErrorClass $_.Exception.GetType().FullName
        throw
    }
}

function Invoke-AdoGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AuditRoot,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )

    $token = az account get-access-token `
        --resource 499b84ac-1321-427f-aa17-267ca6975798 `
        --query accessToken `
        --output tsv

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw 'Could not obtain an Azure DevOps Microsoft Entra access token.'
    }

    try {
        $response = Invoke-RestMethod -Method Get -Uri $Uri -Headers @{
            Authorization = "Bearer $token"
            Accept = 'application/json'
        }

        $outputPath = Join-Path $OutputDirectory "$Name.json"
        $response | ConvertTo-Json -Depth 100 |
            Set-Content -LiteralPath $outputPath -Encoding UTF8
        Write-CollectionLog -AuditRoot $AuditRoot -Name $Name -Status Succeeded -ExitCode 0
        return $outputPath
    }
    catch {
        Write-CollectionLog -AuditRoot $AuditRoot -Name $Name -Status Failed -ExitCode 1 -ErrorClass $_.Exception.GetType().FullName
        throw
    }
    finally {
        $token = $null
    }
}

Export-ModuleMember -Function Invoke-EvidenceCommand, Invoke-AdoGet
```

- [ ] **Step 3: Import the helper and verify CLI availability**

Run:

```powershell
$AuditRoot = Join-Path $env:LOCALAPPDATA 'Caldova\audit\tenant1-engineering-platform-review'
Import-Module (Join-Path $AuditRoot 'AuditHelpers.psm1') -Force

gh --version
az --version
az extension show --name azure-devops --query '{name:name,version:version}' --output json
pac help
```

Expected: GitHub CLI, Azure CLI, Azure DevOps extension, and Power Platform CLI all execute. Do not install or upgrade a tool unless its absence blocks collection.

- [ ] **Step 4: Capture identity and context preflight evidence**

Run:

```powershell
$preflight = Join-Path $AuditRoot 'raw\preflight'
$organization = $env:ADO_ORGANIZATION_URL
if ([string]::IsNullOrWhiteSpace($organization) -or $organization -notmatch '^https://dev\.azure\.com/[^/]+/?$') {
    throw 'ADO_ORGANIZATION_URL must contain the attended Tenant 1 Azure DevOps organization URL.'
}
$project = 'Caldova HR Frontier'

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'github-auth-status' -OutputDirectory $preflight -Command {
    gh auth status
} -OutputExtension txt

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'github-user' -OutputDirectory $preflight -Command {
    gh api user
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'azure-account' -OutputDirectory $preflight -Command {
    az account show --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'azure-devops-project' -OutputDirectory $preflight -Command {
    az devops project show --organization $organization --project $project --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'power-platform-auth' -OutputDirectory $preflight -Command {
    pac auth list
} -OutputExtension txt
```

Expected: all commands authenticate. If any identity is not clearly Tenant 1 or lacks read access, stop that collector and record `NOT EVIDENCED`; do not switch tenant or alter defaults without user confirmation.

- [ ] **Step 5: Prove that preflight made no repository change**

Run:

```powershell
git status --short
```

Expected: only the unrelated pre-existing paths remain outside the committed plan state.

---

### Task 2: Refresh the Microsoft Control Baseline

**Files:**
- Create outside Git: `$AuditRoot\sources\microsoft-guidance.json`
- Verify: all committed citations later originate from official Microsoft documentation

**Interfaces:**
- Consumes: approved design and current Microsoft Learn search/fetch tools
- Produces: a timestamped list of official source URLs and the exact control assertions used by Tasks 3-7

- [ ] **Step 1: Fetch the current official guidance**

Use Microsoft Learn search followed by full-page fetch for these official pages:

```text
https://learn.microsoft.com/azure/devops/boards/github/?view=azure-devops
https://learn.microsoft.com/azure/devops/boards/github/install-github-app?view=azure-devops
https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/github-connections/get-github-connections?view=azure-devops-rest-7.2
https://learn.microsoft.com/azure/devops/pipelines/process/approvals?view=azure-devops
https://learn.microsoft.com/en-us/rest/api/azure/devops/approvalsandchecks/check-configurations/list?view=azure-devops-rest-7.1
https://learn.microsoft.com/en-us/rest/api/azure/devops/distributedtask/environments/list?view=azure-devops-rest-7.1
https://learn.microsoft.com/en-us/rest/api/azure/devops/serviceendpoint/endpoints/get-service-endpoints?view=azure-devops-rest-7.1
https://learn.microsoft.com/azure/devops/pipelines/release/configure-workload-identity?view=azure-devops
https://learn.microsoft.com/azure/devops/integrate/get-started/authentication/authentication-guidance?view=azure-devops
https://learn.microsoft.com/power-platform/admin/manage-application-users
https://learn.microsoft.com/power-platform/alm/devops-build-tools
```

Expected: each source resolves to `learn.microsoft.com`; record redirects and API versions rather than relying on remembered behavior.

- [ ] **Step 2: Record the source assertions privately**

Create `$AuditRoot\sources\microsoft-guidance.json` with this shape:

```json
{
  "retrievedUtc": "2026-09-28T00:00:00Z",
  "sources": [
    {
      "control": "ADO-004",
      "title": "What is the Azure Boards-GitHub integration?",
      "url": "https://learn.microsoft.com/azure/devops/boards/github/?view=azure-devops",
      "assertion": "Use the Azure Boards GitHub App and connect one GitHub repository to only one Azure DevOps organization and project."
    }
  ]
}
```

Replace the example timestamp with the actual UTC collection time and add one source record for every distinct assertion used in the report. Do not add third-party or community sources.

- [ ] **Step 3: Validate the source record**

Run:

```powershell
$sources = Get-Content -LiteralPath (Join-Path $AuditRoot 'sources\microsoft-guidance.json') -Raw | ConvertFrom-Json
if ($sources.sources.Count -lt 8) { throw 'The control baseline has fewer than eight official sources.' }
if (@($sources.sources | Where-Object { $_.url -notmatch '^https://learn\.microsoft\.com/' }).Count -ne 0) {
    throw 'The control baseline contains a non-Microsoft Learn source.'
}
if (@($sources.sources | Where-Object { [string]::IsNullOrWhiteSpace($_.control) -or [string]::IsNullOrWhiteSpace($_.assertion) }).Count -ne 0) {
    throw 'A source record is missing its control or assertion.'
}
```

Expected: no output and exit code 0.

---

### Task 3: Collect GitHub Repository Governance Evidence

**Files:**
- Create outside Git: `$AuditRoot\raw\github\*.json`
- Verify: controls `GH-001` through `GH-014`

**Interfaces:**
- Consumes: `Invoke-EvidenceCommand`
- Produces: raw repository, ruleset, branch-protection, Actions, environment, security-analysis, installation, and workflow-run evidence

- [ ] **Step 1: Collect repository and merge-policy state**

Run:

```powershell
$githubRaw = Join-Path $AuditRoot 'raw\github'
$repository = 'urruegg/caldova-hr-frontier'

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'repository' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository"
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'rulesets' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository/rulesets"
}

try {
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'main-classic-protection' -OutputDirectory $githubRaw -Command {
        gh api "repos/$repository/branches/main/protection"
    }
}
catch {
    # Preserve the HTTP error as evidence; a ruleset can validly replace classic protection.
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'codeowners-errors' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository/codeowners/errors"
}
```

Expected: repository and ruleset reads succeed. A classic-protection `404` remains distinct and is evaluated together with ruleset evidence.

- [ ] **Step 2: Collect GitHub Actions and environment state**

Run:

```powershell
Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'actions-permissions' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository/actions/permissions"
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'workflow-permissions' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository/actions/permissions/workflow"
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'workflows' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository/actions/workflows"
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'main-validation-runs' -OutputDirectory $githubRaw -Command {
    gh run list --repo $repository --workflow validate-repository.yml --branch main --limit 20 `
        --json databaseId,displayTitle,event,headBranch,headSha,status,conclusion,createdAt,updatedAt,url
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'environments' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository/environments"
}
```

Expected: the workflow definition and its recent `main` results are readable. Do not dispatch a workflow.

- [ ] **Step 3: Collect security-analysis and GitHub App evidence**

Run:

```powershell
Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'security-and-analysis' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository" --jq '{security_and_analysis: .security_and_analysis, visibility: .visibility}'
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'dependabot-config' -OutputDirectory $githubRaw -Command {
    gh api "repos/$repository/contents/.github/dependabot.yml"
}

try {
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'user-installations' -OutputDirectory $githubRaw -Command {
        gh api user/installations
    }
}
catch {
    # The Azure Boards connection is still evidenced through Azure DevOps API and sanitized screenshots.
}
```

Expected: no secret alerts or secret values are requested. The installation list is raw private evidence only.

- [ ] **Step 4: Evaluate the GitHub control set privately**

Create private observations for:

```text
GH-001  Repository visibility, default branch, and source authority
GH-002  Merge methods and branch deletion behavior
GH-003  Active main ruleset or equivalent branch protection
GH-004  Pull request, approval, stale-review, CODEOWNERS, and conversation requirements
GH-005  Force-push and branch-deletion restrictions
GH-006  Required repository validation status check
GH-007  CODEOWNERS validity
GH-008  GitHub Actions default token permissions
GH-009  Immutable action pinning in tracked workflows
GH-010  Existing successful main validation record
GH-011  Dependabot and available security-analysis configuration
GH-012  Azure Boards GitHub App installation and repository scope
GH-013  Administrative access and ruleset bypass boundary
GH-014  GitHub environment and protection-rule configuration
```

Expected: every control has observed evidence or an explicit evidence limitation; do not assign final outcomes until Task 7 cross-checks Azure DevOps.

- [ ] **Step 5: Confirm collection was read-only**

Run:

```powershell
git status --short
gh run list --repo $repository --limit 1 --json databaseId,createdAt,event,status,conclusion
```

Expected: no repository change and no new audit-generated workflow run.

---

### Task 4: Collect Azure DevOps Project and Boards Evidence

**Files:**
- Create outside Git: `$AuditRoot\raw\azure-devops\project-*.json`
- Create outside Git: `$AuditRoot\raw\azure-devops\boards-*.json`
- Verify: controls `ADO-001` through `ADO-009`

**Interfaces:**
- Consumes: `Invoke-EvidenceCommand`, `Invoke-AdoGet`
- Produces: raw project, team, process, area, iteration, permissions, repository, GitHub connection, connected repository, and existing work-item link evidence

- [ ] **Step 1: Collect project, team, area, iteration, and repository state**

Run:

```powershell
$adoRaw = Join-Path $AuditRoot 'raw\azure-devops'
$organization = $env:ADO_ORGANIZATION_URL
if ([string]::IsNullOrWhiteSpace($organization) -or $organization -notmatch '^https://dev\.azure\.com/[^/]+/?$') {
    throw 'ADO_ORGANIZATION_URL must contain the attended Tenant 1 Azure DevOps organization URL.'
}
$project = 'Caldova HR Frontier'

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'project' -OutputDirectory $adoRaw -Command {
    az devops project show --organization $organization --project $project --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'teams' -OutputDirectory $adoRaw -Command {
    az devops team list --organization $organization --project $project --top 100 --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'areas' -OutputDirectory $adoRaw -Command {
    az boards area project list --organization $organization --project $project --depth 10 --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'iterations' -OutputDirectory $adoRaw -Command {
    az boards iteration project list --organization $organization --project $project --depth 10 --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'repositories' -OutputDirectory $adoRaw -Command {
    az repos list --organization $organization --project $project --output json
}
```

Expected: the project is readable, and the Azure Repo shown in screenshots can be matched to a live repository without assuming it is an approved product source.

- [ ] **Step 2: Collect project group and process evidence without expanding membership**

Run:

```powershell
Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'project-groups' -OutputDirectory $adoRaw -Command {
    az devops security group list --organization $organization --project $project --scope project --output json
}

$projectRecord = Get-Content -LiteralPath (Join-Path $adoRaw 'project.json') -Raw | ConvertFrom-Json
$processUri = "$organization/_apis/process/processes/$($projectRecord.capabilities.processTemplate.templateTypeId)?api-version=7.1"
Invoke-AdoGet -AuditRoot $AuditRoot -Name 'process' -Uri $processUri -OutputDirectory $adoRaw
```

Expected: group descriptors and process metadata are raw private evidence. Do not enumerate unrestricted user membership.

- [ ] **Step 3: Collect the Azure Boards GitHub connection and repository binding**

Run:

```powershell
$encodedProject = [uri]::EscapeDataString($project)
$connectionsUri = "$organization/$encodedProject/_apis/githubconnections?api-version=7.2-preview.1"
$connectionsPath = Invoke-AdoGet -AuditRoot $AuditRoot -Name 'github-connections' -Uri $connectionsUri -OutputDirectory $adoRaw
$connections = Get-Content -LiteralPath $connectionsPath -Raw | ConvertFrom-Json

foreach ($connection in @($connections.value)) {
    $repositoriesUri = "$organization/$encodedProject/_apis/githubconnections/$($connection.id)/repos?api-version=7.2-preview.1"
    Invoke-AdoGet -AuditRoot $AuditRoot -Name "github-connection-$($connection.id)-repositories" -Uri $repositoriesUri -OutputDirectory $adoRaw
}
```

Expected: the connection reports valid state, GitHub App authentication, and the exact `urruegg/caldova-hr-frontier` binding. Connection IDs and creator identity remain private.

- [ ] **Step 4: Query existing work items with external links**

Run:

```powershell
$wiql = @"
SELECT [System.Id], [System.State], [System.ChangedDate], [System.ExternalLinkCount]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.ExternalLinkCount] > 0
ORDER BY [System.ChangedDate] DESC
"@

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'work-items-with-external-links' -OutputDirectory $adoRaw -Command {
    az boards query --organization $organization --project $project --wiql $wiql --output json
}

$linkedItems = Get-Content -LiteralPath (Join-Path $adoRaw 'work-items-with-external-links.json') -Raw | ConvertFrom-Json
foreach ($item in @($linkedItems | Select-Object -First 20)) {
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "work-item-$($item.id)-relations" -OutputDirectory $adoRaw -Command {
        az boards work-item show --organization $organization --id $item.id --expand relations --output json
    }
}
```

Expected: existing links are inspected without editing a work item. Work-item titles and personal fields never enter public evidence.

- [ ] **Step 5: Evaluate the Boards control set privately**

Create private observations for:

```text
ADO-001  Private project and expected project identity
ADO-002  Named process and work-item hierarchy
ADO-003  Team, area, and iteration configuration
ADO-004  Valid GitHub App connection
ADO-005  Exact GitHub repository binding
ADO-006  One-repository-to-one-organization-and-project topology
ADO-007  Existing AB# and external-link evidence
ADO-008  Explicit approved role for every Azure Repo
ADO-009  Least-privilege project group model without broad inherited administration
```

Expected: empty link evidence becomes `NOT EVIDENCED`, not `PASS`; a duplicate product-source repository becomes a `GAP` unless its narrow role is documented and evidenced.

---

### Task 5: Collect Azure Pipelines Control-Plane Evidence

**Files:**
- Create outside Git: `$AuditRoot\raw\azure-devops\pipelines-*.json`
- Create outside Git: `$AuditRoot\raw\azure-devops\service-endpoints.json`
- Create outside Git: `$AuditRoot\raw\azure-devops\environments.json`
- Create outside Git: `$AuditRoot\raw\azure-devops\checks.json`
- Verify: controls `PIPE-001` through `PIPE-014`

**Interfaces:**
- Consumes: Azure DevOps project context and the private Azure DevOps REST helper
- Produces: raw pipeline definitions, existing runs, resource authorization, agent, service connection, environment, check, variable-group, and secure-file metadata

- [ ] **Step 1: Collect pipeline definitions and existing runs**

Run:

```powershell
Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'pipelines' -OutputDirectory $adoRaw -Command {
    az pipelines list --organization $organization --project $project --top 100 --query-order NameAsc --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'pipeline-runs' -OutputDirectory $adoRaw -Command {
    az pipelines runs list --organization $organization --project $project --top 100 --query-order FinishTimeDesc --output json
}

$pipelines = Get-Content -LiteralPath (Join-Path $adoRaw 'pipelines.json') -Raw | ConvertFrom-Json
foreach ($pipeline in @($pipelines)) {
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "pipeline-$($pipeline.id)" -OutputDirectory $adoRaw -Command {
        az pipelines show --organization $organization --project $project --id $pipeline.id --output json
    }
}
```

Expected: each definition identifies its repository type, repository, YAML path, and current configuration. Do not queue a pipeline.

- [ ] **Step 2: Collect service connection and variable-group metadata without values**

Run:

```powershell
Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'service-endpoints' -OutputDirectory $adoRaw -Command {
    az devops service-endpoint list `
        --organization $organization `
        --project $project `
        --query "[].{id:id,name:name,type:type,isReady:isReady,owner:owner,authorizationScheme:authorization.scheme,projectReferences:serviceEndpointProjectReferences}" `
        --output json
}

Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'variable-groups' -OutputDirectory $adoRaw -Command {
    az pipelines variable-group list `
        --organization $organization `
        --project $project `
        --top 100 `
        --query "[].{id:id,name:name,type:type,isShared:isShared}" `
        --output json
}

$secureFilesUri = "$organization/$encodedProject/_apis/distributedtask/securefiles?api-version=7.1"
Invoke-AdoGet -AuditRoot $AuditRoot -Name 'secure-files' -Uri $secureFilesUri -OutputDirectory $adoRaw
```

Expected: no variable value, secret, certificate body, or service-endpoint authorization parameter is requested.

- [ ] **Step 3: Collect environments, checks, and resource pipeline permissions**

Run:

```powershell
$environmentsUri = "$organization/$encodedProject/_apis/distributedtask/environments?api-version=7.1"
$checksUri = "$organization/$encodedProject/_apis/pipelines/checks/configurations?api-version=7.1-preview.1"

$environmentPath = Invoke-AdoGet -AuditRoot $AuditRoot -Name 'environments' -Uri $environmentsUri -OutputDirectory $adoRaw
Invoke-AdoGet -AuditRoot $AuditRoot -Name 'checks' -Uri $checksUri -OutputDirectory $adoRaw

$environments = Get-Content -LiteralPath $environmentPath -Raw | ConvertFrom-Json
foreach ($environment in @($environments.value)) {
    $permissionsUri = "$organization/$encodedProject/_apis/pipelines/pipelinepermissions/environment/$($environment.id)?api-version=7.1-preview.1"
    Invoke-AdoGet -AuditRoot $AuditRoot -Name "environment-$($environment.id)-pipeline-permissions" -Uri $permissionsUri -OutputDirectory $adoRaw
}
```

Expected: environment and check metadata is readable. A `403` is `NOT EVIDENCED`; an authenticated empty list is a potential `GAP`.

- [ ] **Step 4: Collect agent-pool readiness**

Run:

```powershell
Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'agent-pools' -OutputDirectory $adoRaw -Command {
    az pipelines pool list --organization $organization --output json
}

$pools = Get-Content -LiteralPath (Join-Path $adoRaw 'agent-pools.json') -Raw | ConvertFrom-Json
foreach ($pool in @($pools)) {
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "agent-pool-$($pool.id)-agents" -OutputDirectory $adoRaw -Command {
        az pipelines agent list `
            --organization $organization `
            --pool-id $pool.id `
            --include-capabilities false `
            --include-assigned-request false `
            --include-last-completed-request false `
            --output json
    }
}
```

Expected: pool and online/readiness metadata is captured without agent capability details. Parallel-job entitlement that cannot be read through supported APIs is `NOT EVIDENCED` and supported by a sanitized portal screenshot only if needed.

- [ ] **Step 5: Evaluate the Pipelines control set privately**

Create private observations for:

```text
PIPE-001  HR solution pipeline definitions exist
PIPE-002  Pipeline source is the approved GitHub repository
PIPE-003  CI and pull-request triggers are correctly scoped
PIPE-004  Existing CI validates and builds the HR solution
PIPE-005  One immutable artifact is promoted
PIPE-006  One managed artifact is built from unmanaged DEV source and promoted unchanged to TEST and PROD
PIPE-007  Azure DevOps deployment environments exist
PIPE-008  TEST and PROD approvals/checks are owned outside YAML
PIPE-009  Service connections are ready, scoped, and non-personal
PIPE-010  Workload identity is used where the supported task and connection type permit it
PIPE-011  Variable groups and secure files avoid public or inline secrets
PIPE-012  Agent pool and parallel-job readiness
PIPE-013  Build-service and resource authorization follow least privilege
PIPE-014  Required-template enforcement uses a tenant-private governed template
```

Expected: do not require workload identity for a Power Platform connection type that current official tooling does not support. Record the compatibility limitation and the safest supported authentication scheme.

---

### Task 6: Collect Entra, Azure, and Power Platform Prerequisite Evidence

**Files:**
- Create outside Git: `$AuditRoot\raw\azure\*.json`
- Create outside Git: `$AuditRoot\raw\power-platform\*.json`
- Verify: controls `TEN-001` through `TEN-007`

**Interfaces:**
- Consumes: service connection metadata from Task 5 and current Tenant 1 sessions
- Produces: raw application, service-principal, federated-credential, role-assignment, environment, application-user, solution, and publisher observations

- [ ] **Step 1: Derive only the identity references needed for validation**

Read the private service-endpoint evidence and retrieve full details one endpoint at a time:

```powershell
$azureRaw = Join-Path $AuditRoot 'raw\azure'
$powerPlatformRaw = Join-Path $AuditRoot 'raw\power-platform'
$endpointList = Get-Content -LiteralPath (Join-Path $adoRaw 'service-endpoints.json') -Raw | ConvertFrom-Json

foreach ($endpoint in @($endpointList)) {
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "service-endpoint-$($endpoint.id)-detail" -OutputDirectory $adoRaw -Command {
        az devops service-endpoint show `
            --organization $organization `
            --project $project `
            --id $endpoint.id `
            --output json
    }
}
```

Expected: detailed endpoint payloads remain private. Do not publish endpoint IDs, application IDs, subscription IDs, URLs, or authorization parameters.

- [ ] **Step 2: Inspect referenced Entra applications and service principals**

Build the distinct application ID list from the private endpoint details, then inspect each identity:

```powershell
$endpointDetails = Get-ChildItem -LiteralPath $adoRaw -Filter 'service-endpoint-*-detail.json' |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json }
$applicationIds = @(
    $endpointDetails |
        ForEach-Object { $_.authorization.parameters.serviceprincipalid } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
)

foreach ($applicationId in $applicationIds) {
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "entra-application-$applicationId" -OutputDirectory $azureRaw -Command {
        az ad app show --id $applicationId --output json
    }

    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "entra-service-principal-$applicationId" -OutputDirectory $azureRaw -Command {
        az ad sp show --id $applicationId --output json
    }

    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "entra-federated-credentials-$applicationId" -OutputDirectory $azureRaw -Command {
        az ad app federated-credential list --id $applicationId --output json
    }
}
```

Expected: application and federation metadata is read-only. If no application ID exists because no service connection exists, record the dependent tenant controls as `GAP` or `NOT APPLICABLE` according to the expected architecture.

- [ ] **Step 3: Inspect Azure role assignment scope**

For each service principal object ID found in Step 2, run:

```powershell
$servicePrincipalRecords = Get-ChildItem -LiteralPath $azureRaw -Filter 'entra-service-principal-*.json' |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json }

foreach ($servicePrincipal in $servicePrincipalRecords) {
    $servicePrincipalObjectId = $servicePrincipal.id
    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "azure-role-assignments-$servicePrincipalObjectId" -OutputDirectory $azureRaw -Command {
        az role assignment list `
            --assignee-object-id $servicePrincipalObjectId `
            --all `
            --include-inherited `
            --output json
    }
}
```

Expected: role and scope are captured privately. Flag standing Owner, User Access Administrator, or subscription-wide Contributor unless explicitly required and approved.

- [ ] **Step 4: Enumerate Power Platform environments and validate environment access**

Run:

```powershell
Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name 'power-platform-environments' -OutputDirectory $powerPlatformRaw -Command {
    pac admin list
} -OutputExtension txt
```

Review the private environment inventory, identify exactly one DEV, TEST, and PROD environment, and create `$AuditRoot\raw\power-platform\stage-map.json`. The private JSON is an array of exactly three objects. Each object has `stage`, `url`, and `environmentId`; copy the actual values from the raw environment inventory and never copy those values to Git. Then run:

```powershell
$stageMap = Get-Content -LiteralPath (Join-Path $powerPlatformRaw 'stage-map.json') -Raw | ConvertFrom-Json
$expectedStages = @('DEV', 'PROD', 'TEST')
$actualStages = @($stageMap.stage | Sort-Object -Unique)
$stageDifference = @(Compare-Object -ReferenceObject $expectedStages -DifferenceObject $actualStages)
if ($stageMap.Count -ne 3 -or $stageDifference.Count -ne 0) {
    throw 'Power Platform stage map must contain exactly DEV, TEST, and PROD.'
}

foreach ($environment in $stageMap) {
    $stage = $environment.stage
    $environmentUrl = $environment.url

    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "environment-$stage-who" -OutputDirectory $powerPlatformRaw -Command {
        pac env who --environment $environmentUrl
    } -OutputExtension txt

    Invoke-EvidenceCommand -AuditRoot $AuditRoot -Name "environment-$stage-solutions" -OutputDirectory $powerPlatformRaw -Command {
        pac solution list --environment $environmentUrl
    } -OutputExtension txt
}
```

Expected: exactly one DEV, one TEST, and one PROD role can be identified. Environment URLs and IDs remain private.

- [ ] **Step 5: Validate application-user and publisher prerequisites**

Obtain an interactive user token for each Dataverse environment without storing it:

```powershell
$applicationId = @($applicationIds | Select-Object -First 1)
if ($applicationIds.Count -ne 1) {
    throw 'Application-user validation requires one unambiguous deployment application ID.'
}

foreach ($environment in $stageMap) {
    $stage = $environment.stage
    $environmentUrl = $environment.url.TrimEnd('/')
    $token = az account get-access-token --resource $environmentUrl --query accessToken --output tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw "Cannot obtain a Dataverse token for stage $stage."
    }

    try {
        $headers = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
        $systemUsersUri = "$environmentUrl/api/data/v9.2/systemusers?`$select=applicationid,isdisabled&`$filter=applicationid eq $applicationId"
        $publishersUri = "$environmentUrl/api/data/v9.2/publishers?`$select=uniquename,customizationprefix"

        Invoke-RestMethod -Method Get -Uri $systemUsersUri -Headers $headers |
            ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath (Join-Path $powerPlatformRaw "environment-$stage-application-user.json") -Encoding UTF8

        Invoke-RestMethod -Method Get -Uri $publishersUri -Headers $headers |
            ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath (Join-Path $powerPlatformRaw "environment-$stage-publishers.json") -Encoding UTF8
    }
    finally {
        $token = $null
    }
}
```

Expected: application-user existence and disabled state are readable where access permits. Do not publish application IDs or unrelated publisher records.

- [ ] **Step 6: Evaluate the Tenant prerequisite control set privately**

Create private observations for:

```text
TEN-001  Dedicated non-personal Entra application and service principal
TEN-002  Federated credential matches each workload-identity service connection where supported
TEN-003  Azure role assignments use least privilege and minimum scope
TEN-004  DEV, TEST, and PROD Power Platform environments exist with distinct lifecycle roles
TEN-005  Deployment application user exists and is enabled in each required environment
TEN-006  Approved HR solution publisher and solution prerequisites exist
TEN-007  Tenant-specific identifiers and endpoints remain outside the public repository
```

Expected: inability to query an application user is `NOT EVIDENCED`, not proof of absence.

---

### Task 7: Normalize Observations and Assign Control Outcomes

**Files:**
- Create outside Git: `$AuditRoot\normalized\observations.json`
- Create outside Git: `$AuditRoot\normalized\findings.json`
- Create: `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/evidence-manifest.json`
- Create: `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/test-results.json`

**Interfaces:**
- Consumes: all private raw evidence and official-source assertions
- Produces: complete sanitized public evidence and result records consumed by Tasks 8 and 9

- [ ] **Step 1: Create the complete private observation set**

Create `$AuditRoot\normalized\observations.json` with one record for every control ID listed in Tasks 3-6 plus:

```text
TRACE-001  Existing GitHub commit or pull request links to an Azure Boards work item
TRACE-002  Existing Azure Pipeline run automatically links work items and source
TRACE-003  Existing run proves immutable artifact and gated deployment evidence
TRACE-004  Tenant 1 setup is declarative and parameterized
TRACE-005  Tenant 2 and Tenant 3 can use the runbook without inheriting Tenant 1 identifiers
GOV-001    ADR-0001 and ADR-0002 are reconciled with the approved 1:1 North Star
```

Use this exact record shape:

```json
{
  "id": "GH-001",
  "domain": "GitHub",
  "expected": "GitHub is the public product-source authority and main is the default branch.",
  "observed": "Sanitized factual observation.",
  "outcome": "PASS",
  "observedUtc": "2026-09-28T00:00:00Z",
  "evidence": [
    {
      "source": "GitHub REST API",
      "privatePath": "raw/github/repository.json",
      "publicReference": "evidence-manifest.json#github-repository"
    }
  ],
  "confidence": 10,
  "priority": null,
  "impact": null,
  "dependencies": [],
  "owner": "Repository owner",
  "correctiveAction": null,
  "postRemediationTest": null
}
```

Replace example values with actual observations and timestamps. `confidence` is an integer from 1 through 10.

- [ ] **Step 2: Apply outcome rules**

For every observation:

```text
PASS             direct read-back or an existing successful runtime record proves expected state
GAP              successful read-back proves required state absent or incorrect
NOT EVIDENCED    access, API coverage, ambiguity, or absent runtime transaction prevents proof
NOT APPLICABLE   control does not apply and the observed field explains why
```

For every `GAP`, set priority, impact, dependencies, owner, corrective action, and post-remediation test. For every `NOT EVIDENCED`, state the exact missing permission, unsupported API, ambiguity, or absent transaction in `observed`.

- [ ] **Step 3: Derive the prioritized finding set**

Create `$AuditRoot\normalized\findings.json` sorted by:

```text
BLOCKER -> HIGH -> MEDIUM -> LOW
then dependency order
then control ID
```

Each finding references one or more control IDs and contains one accountable owner recommendation. Do not merge unrelated controls into a vague finding.

- [ ] **Step 4: Create the sanitized evidence manifest**

Create `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/evidence-manifest.json`:

```json
{
  "schemaVersion": "1.0",
  "reviewId": "tenant-1-engineering-platform-2026-09-28",
  "generatedUtc": "2026-09-28T00:00:00Z",
  "scope": {
    "githubRepository": "urruegg/caldova-hr-frontier",
    "azureDevOpsProject": "Caldova HR Frontier",
    "tenantAlias": "Tenant 1"
  },
  "evidence": [
    {
      "id": "github-repository",
      "domain": "GitHub",
      "sourceType": "api-readback",
      "collector": "GitHub CLI",
      "operation": "GitHub REST repository read",
      "collectionResult": "Succeeded",
      "observedUtc": "2026-09-28T00:00:00Z",
      "summary": "Repository visibility, default branch, and merge settings were read through the GitHub REST API.",
      "sensitiveRawStoredOutsideGit": true
    }
  ],
  "screenshots": []
}
```

Add one allowlisted evidence record for each source actually used. Do not copy raw payloads or identifiers.

- [ ] **Step 5: Create the sanitized test results**

Create `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/test-results.json`:

```json
{
  "schemaVersion": "1.0",
  "reviewId": "tenant-1-engineering-platform-2026-09-28",
  "generatedUtc": "2026-09-28T00:00:00Z",
  "summary": {
    "total": 0,
    "pass": 0,
    "gap": 0,
    "notEvidenced": 0,
    "notApplicable": 0
  },
  "controls": []
}
```

Populate `controls` from the private observations after removing `privatePath` and sensitive values. Recalculate every summary count from `controls`; do not type summary counts manually.

- [ ] **Step 6: Validate JSON shape, result completeness, and sanitization**

Run:

```powershell
$publicEvidenceRoot = 'docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform'
$manifestPath = Join-Path $publicEvidenceRoot 'evidence-manifest.json'
$resultsPath = Join-Path $publicEvidenceRoot 'test-results.json'

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$results = Get-Content -LiteralPath $resultsPath -Raw | ConvertFrom-Json
$allowedOutcomes = @('PASS', 'GAP', 'NOT EVIDENCED', 'NOT APPLICABLE')

if ($manifest.evidence.Count -eq 0) { throw 'Evidence manifest is empty.' }
if ($results.controls.Count -eq 0) { throw 'Test results contain no controls.' }
if (@($results.controls | Where-Object { $_.outcome -notin $allowedOutcomes }).Count -ne 0) {
    throw 'Test results contain an invalid outcome.'
}
if (@($results.controls.id | Sort-Object -Unique).Count -ne $results.controls.Count) {
    throw 'Test results contain duplicate control IDs.'
}

$expectedTotal = $results.controls.Count
$expectedPass = @($results.controls | Where-Object outcome -eq 'PASS').Count
$expectedGap = @($results.controls | Where-Object outcome -eq 'GAP').Count
$expectedNotEvidenced = @($results.controls | Where-Object outcome -eq 'NOT EVIDENCED').Count
$expectedNotApplicable = @($results.controls | Where-Object outcome -eq 'NOT APPLICABLE').Count

if ($results.summary.total -ne $expectedTotal -or
    $results.summary.pass -ne $expectedPass -or
    $results.summary.gap -ne $expectedGap -or
    $results.summary.notEvidenced -ne $expectedNotEvidenced -or
    $results.summary.notApplicable -ne $expectedNotApplicable) {
    throw 'Test result summary does not match control records.'
}

$publicText = (Get-Content -LiteralPath $manifestPath, $resultsPath -Raw) -join "`n"
$forbiddenPatterns = [ordered]@{
    Email = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    Guid = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
    TenantUrl = '(?i)https://dev\.azure\.com/caldova[0-9]+'
    BearerToken = '(?i)\bBearer\s+[A-Za-z0-9._-]+'
    SecretField = '(?i)"(clientSecret|accessToken|refreshToken|certificate)"\s*:'
}

foreach ($entry in $forbiddenPatterns.GetEnumerator()) {
    if ($publicText -match $entry.Value) {
        throw "Public evidence contains forbidden pattern $($entry.Key)."
    }
}
```

Expected: exit code 0.

- [ ] **Step 7: Commit the sanitized JSON evidence**

Run:

```powershell
git add -- docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform\evidence-manifest.json `
    docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform\test-results.json
git diff --cached --check
git commit -m "docs: record Tenant 1 platform evidence" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: only the two sanitized JSON files are committed.

---

### Task 8: Sanitize and Add Screenshot Evidence

**Files:**
- Read only: six supplied attachment images
- Create outside Git: `$AuditRoot\raw\screenshots\*.png`
- Create: six sanitized PNG files under `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/`
- Modify: `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/evidence-manifest.json`

**Interfaces:**
- Consumes: supplied screenshots and the approved redaction policy
- Produces: opaque-redacted screenshot evidence and manifest captions

- [ ] **Step 1: Copy the supplied screenshots to private session storage**

Set six process-scoped environment variables, `CALDOVA_AUDIT_ATTACHMENT_1` through `CALDOVA_AUDIT_ATTACHMENT_6`, from the read-only attachment paths supplied to the active agent session. Do not print or persist those source paths. Then run:

```powershell
$screenshotNames = @(
    '01-azure-boards-github-app-connection.png',
    '02-azure-repo-settings.png',
    '03-azure-repo-branch-policy-state.png',
    '04-azure-repo-permission-state.png',
    '05-azure-repos-migration-surface.png',
    '06-migration-dialog-mismatch.png'
)

for ($index = 1; $index -le $screenshotNames.Count; $index++) {
    $sourcePath = [Environment]::GetEnvironmentVariable("CALDOVA_AUDIT_ATTACHMENT_$index", 'Process')
    if ([string]::IsNullOrWhiteSpace($sourcePath) -or -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing supplied screenshot path at position $index."
    }
    Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $AuditRoot "raw\screenshots\$($screenshotNames[$index - 1])") -Force
}
```

Expected: attachment snapshots remain unchanged.

- [ ] **Step 2: Apply opaque redaction and browser-chrome cropping**

Create `$AuditRoot\Sanitize-Screenshots.ps1`:

```powershell
param(
    [Parameter(Mandatory)]
    [string]$AuditRoot,

    [Parameter(Mandatory)]
    [string]$DestinationRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$jobs = @(
    @{
        Name = '01-azure-boards-github-app-connection.png'
        Width = 1699
        Height = 735
        Redactions = @(
            [Drawing.Rectangle]::new(48, 26, 116, 38),
            [Drawing.Rectangle]::new(324, 174, 132, 70),
            [Drawing.Rectangle]::new(1255, 174, 225, 68),
            [Drawing.Rectangle]::new(1638, 7, 61, 66)
        )
    },
    @{
        Name = '02-azure-repo-settings.png'
        Width = 1217
        Height = 768
        Redactions = @(
            [Drawing.Rectangle]::new(32, 0, 98, 38),
            [Drawing.Rectangle]::new(1162, 0, 56, 42)
        )
    },
    @{
        Name = '03-azure-repo-branch-policy-state.png'
        Width = 1220
        Height = 768
        Redactions = @(
            [Drawing.Rectangle]::new(32, 0, 98, 38),
            [Drawing.Rectangle]::new(1162, 0, 56, 42)
        )
    },
    @{
        Name = '04-azure-repo-permission-state.png'
        Width = 1220
        Height = 768
        Redactions = @(
            [Drawing.Rectangle]::new(32, 0, 98, 38),
            [Drawing.Rectangle]::new(1162, 0, 56, 42),
            [Drawing.Rectangle]::new(486, 525, 298, 47)
        )
    },
    @{
        Name = '05-azure-repos-migration-surface.png'
        Width = 1219
        Height = 768
        Redactions = @(
            [Drawing.Rectangle]::new(32, 0, 98, 38),
            [Drawing.Rectangle]::new(1162, 0, 56, 42)
        )
    },
    @{
        Name = '06-migration-dialog-mismatch.png'
        Width = 1186
        Height = 768
        Redactions = @(
            [Drawing.Rectangle]::new(0, 0, 1190, 35),
            [Drawing.Rectangle]::new(20, 34, 112, 38),
            [Drawing.Rectangle]::new(1145, 34, 45, 42)
        )
    }
)

New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
$brush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 32, 32, 32))

try {
    foreach ($job in $jobs) {
        $sourcePath = Join-Path $AuditRoot "raw\screenshots\$($job.Name)"
        $destinationPath = Join-Path $DestinationRoot $job.Name
        $source = [Drawing.Image]::FromFile($sourcePath)

        try {
            if ($source.Width -ne $job.Width -or $source.Height -ne $job.Height) {
                throw "Unexpected dimensions for $($job.Name): $($source.Width)x$($source.Height)."
            }

            $bitmap = [Drawing.Bitmap]::new($source)
            try {
                $graphics = [Drawing.Graphics]::FromImage($bitmap)
                try {
                    foreach ($rectangle in $job.Redactions) {
                        $graphics.FillRectangle($brush, $rectangle)
                    }
                }
                finally {
                    $graphics.Dispose()
                }

                $bitmap.Save($destinationPath, [Drawing.Imaging.ImageFormat]::Png)
            }
            finally {
                $bitmap.Dispose()
            }
        }
        finally {
            $source.Dispose()
        }
    }
}
finally {
    $brush.Dispose()
}
```

Run:

```powershell
$destinationRoot = 'docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $AuditRoot 'Sanitize-Screenshots.ps1') `
    -AuditRoot $AuditRoot `
    -DestinationRoot $destinationRoot
```

Expected: six new PNG files with original dimensions and opaque redaction. Keep repository/project names and control states. Do not blur because blur can preserve recoverable text.

- [ ] **Step 3: Inspect every sanitized screenshot**

Open all six generated PNG files and confirm:

```text
no browser URL containing a tenant identifier
no organization identifier
no personal or administrator display name
no email address
no account avatar
no token or populated credential field
repository name, project name, setting label, and control state remain legible
```

If a screenshot cannot satisfy both privacy and legibility, omit it and explain the omission in the manifest.

- [ ] **Step 4: Add screenshot captions to the evidence manifest**

Add records with:

```json
{
  "id": "screenshot-01-github-connection",
  "file": "01-azure-boards-github-app-connection.png",
  "observedUtc": "2026-09-28T00:00:00Z",
  "caption": "Azure Boards shows a GitHub App connection scoped to the approved GitHub repository.",
  "supportsControls": ["GH-012", "ADO-004", "ADO-005"],
  "redactions": [
    "tenant-bearing organization breadcrumb",
    "administrator display identity",
    "account avatar"
  ]
}
```

Use the actual observation time and accurate captions for all retained images.

- [ ] **Step 5: Re-run the public evidence sanitizer and commit screenshots**

Run the Task 7 Step 6 validation, then:

```powershell
git add -- docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform
git diff --cached --check
git commit -m "docs: add redacted Tenant 1 screenshots" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: only sanitized screenshots and the sanitized manifest update are committed.

---

### Task 9: Write the Configuration Review and Gap Register

**Files:**
- Create: `docs/reviews/2026-09-28-tenant-1-engineering-platform-configuration-review.md`
- Modify: `docs/reviews/README.md`
- Read: sanitized evidence and test results

**Interfaces:**
- Consumes: `evidence-manifest.json`, `test-results.json`, sanitized screenshots, private findings, and official Microsoft sources
- Produces: the decision-ready English review

- [ ] **Step 1: Write the review with repository metadata**

Use:

```markdown
# Tenant 1 Engineering Platform Configuration Review

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Tenant 1 GitHub, Azure DevOps, Azure, Entra, and Power Platform control planes |
| **References** | [Review Design](../specs/2026-09-28-tenant-1-engineering-platform-configuration-review-design.md), [Evidence Manifest](./evidence/2026-09-28-tenant-1-engineering-platform/evidence-manifest.json), [Test Results](./evidence/2026-09-28-tenant-1-engineering-platform/test-results.json) |
```

The body must contain these sections in order:

```text
Status and Review Boundary
Executive Summary
Current-State Topology
Evidence Coverage and Limitations
Control Results
Confirmed Gaps
Not-Evidenced Controls
Dependency-Ordered Remediation Waves
Post-Remediation Validation Tests
Tenant 2 and Tenant 3 Reproducibility
Sanitized Screenshot Evidence
Microsoft Guidance
Conclusion
```

- [ ] **Step 2: Build the control-results table from JSON**

Include every control once with:

```text
ID | Domain | Outcome | Observed state | Evidence | Confidence
```

The Markdown counts must match `test-results.json`. Do not copy private IDs, URLs, identities, work-item titles, or raw output.

- [ ] **Step 3: Build the confirmed gap register**

For every `GAP`, include:

```text
Priority | Control(s) | Gap | Delivery impact | Dependency | Recommended owner | Corrective action | Validation test
```

Order by priority and dependency. Keep security vulnerabilities distinct from delivery-governance gaps; this document is not a vulnerability assessment.

- [ ] **Step 4: Build remediation waves**

Use dependency order:

```text
Wave 0: approve the target operating model and reconcile ADR-0001/ADR-0002
Wave 1: remove source-of-truth ambiguity and establish Boards structure/linkage
Wave 2: establish pipeline identities, service connections, and environment boundaries
Wave 3: implement HR solution CI and immutable artifact production
Wave 4: build/export from unmanaged DEV and promote the unchanged managed artifact to TEST and PROD
Wave 5: execute synthetic cross-system traceability and deployment proof
Wave 6: extract reusable Tenant 2/3 conformance automation and runbooks
```

Omit a wave only when every associated control is already `PASS`.

- [ ] **Step 5: Embed sanitized screenshots**

Use relative links and captions, for example:

```markdown
![Azure Boards GitHub App connection with tenant and administrator identity redacted](./evidence/2026-09-28-tenant-1-engineering-platform/01-azure-boards-github-app-connection.png)

*The portal shows a GitHub App connection scoped to the approved repository. API read-back determines validity and authentication type.*
```

Every image must support a named control or finding.

- [ ] **Step 6: Update the reviews catalogue**

Update `docs/reviews/README.md` metadata to version `1.1`, date `2026-09-28`, and reference the new review. Add a catalogue row for the Tenant 1 engineering platform review and its evidence package.

- [ ] **Step 7: Self-review the report**

Check:

```text
every control appears once
summary counts match JSON
every PASS has direct evidence
every GAP has all remediation fields
every NOT EVIDENCED states what is missing
known, inferred, and unvalidated statements are labeled
no Proposed Baseline statement is presented as deployed fact
ADR reconciliation is recorded without silently approving the old ADRs
the conclusion distinguishes configured, evidenced, and runtime-proven
```

---

### Task 10: Validate, Review, and Commit the Evidence Package

**Files:**
- Verify: all Task 7-9 repository artifacts
- Commit: report, catalogue, sanitized evidence, and sanitized screenshots only

**Interfaces:**
- Consumes: completed public evidence package
- Produces: a committed, reviewable Tenant 1 baseline and an explicit verification record

- [ ] **Step 1: Scan the complete public package for sensitive patterns**

Run:

```powershell
$reviewPaths = @(
    'docs\reviews\2026-09-28-tenant-1-engineering-platform-configuration-review.md',
    'docs\reviews\README.md',
    'docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform\evidence-manifest.json',
    'docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform\test-results.json'
)

$reviewText = (Get-Content -LiteralPath $reviewPaths -Raw) -join "`n"
$forbiddenPatterns = [ordered]@{
    Email = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
    Guid = '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
    TenantUrl = '(?i)https://dev\.azure\.com/caldova[0-9]+'
    BearerToken = '(?i)\bBearer\s+[A-Za-z0-9._-]+'
    SecretField = '(?i)"(clientSecret|accessToken|refreshToken|certificate)"\s*:'
}

foreach ($entry in $forbiddenPatterns.GetEnumerator()) {
    if ($reviewText -match $entry.Value) {
        throw "Public review contains forbidden pattern $($entry.Key)."
    }
}
```

Expected: exit code 0.

- [ ] **Step 2: Run documentation validation**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester .github\cli\tests\DocumentationMetadata.Tests.ps1,.github\cli\tests\DocumentationLinks.Tests.ps1 -Output Detailed -CI
```

Expected: all documentation tests pass.

- [ ] **Step 3: Run the tracked repository baseline**

Run:

```powershell
$trackedTests = @(git ls-files '.github/cli/tests/*.Tests.ps1')
Invoke-Pester $trackedTests -Output Detailed -CI
```

Expected: all tracked repository tests pass. Also run `.github\cli\verify-repository-setup.ps1`; if it still discovers the unrelated untracked contributor-skill test and fails, record that pre-existing limitation without editing or deleting the test.

- [ ] **Step 4: Run scoped Git checks**

Run:

```powershell
git diff --check -- docs\reviews
git status --short
git --no-pager diff -- docs\reviews
```

Expected: no whitespace errors; unrelated working-tree changes remain untouched.

- [ ] **Step 5: Request documentation and technical review**

Request:

```text
docs-agent review: metadata, placement, references, English, catalogue, and screenshot captions
cloud-solution-architect review: Microsoft guidance interpretation, control expectations, and overclaims
```

Resolve only findings that are supported by the collected evidence. Do not weaken a `GAP` or promote `NOT EVIDENCED` to `PASS` to make the report appear complete.

- [ ] **Step 6: Re-run affected checks after review**

Repeat the sensitive-pattern scan, documentation tests, tracked Pester suite, and `git diff --check` after every report or evidence change.

- [ ] **Step 7: Commit the final review**

Run:

```powershell
git add -- docs\reviews\2026-09-28-tenant-1-engineering-platform-configuration-review.md `
    docs\reviews\README.md `
    docs\reviews\evidence\2026-09-28-tenant-1-engineering-platform
git diff --cached --check
git diff --cached --name-status
git commit -m "docs: publish Tenant 1 platform review" `
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Expected: the final commit contains only public sanitized review artifacts.

- [ ] **Step 8: Verify the committed result**

Run:

```powershell
git --no-pager show --stat --oneline HEAD
git status --short
```

Expected: the review commit is present, no audit raw data is tracked, and only unrelated pre-existing working-tree changes remain.

## Completion Criteria

- Every in-scope control has exactly one timestamped outcome.
- All `PASS` results have direct read-back or existing runtime evidence.
- All `GAP` results have priority, impact, dependency, owner, corrective action, and post-remediation test.
- All `NOT EVIDENCED` results state the exact missing evidence.
- The public package contains no excluded identity, tenant, endpoint, or credential material.
- Sanitized screenshots are legible, relevant, and opaque-redacted.
- The report provides dependency-ordered remediation waves and Tenant 2/3 implications.
- No live configuration mutation or synthetic runtime transaction occurred.
- Documentation tests, tracked repository tests, sensitive-pattern scans, and scoped Git checks pass.
- The final report distinguishes configuration, configuration evidence, and proven runtime behavior.
