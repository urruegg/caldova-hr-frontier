# Power Platform Solution Foundation Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR Solution Architecture |
| **References** | [Power Platform Solution Foundation Design](../specs/2026-09-24-power-platform-solution-foundation-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build reusable, tested PowerShell tooling that connects to a tenant's Power Platform environment, exports its unmanaged solution, and unpacks it into `hr/src/solutions/`, then use it to commit the first real (currently empty) solution source for Tenant 1.

**Architecture:** A small PowerShell module (`Caldova.HrFrontier.Solutions`), mirroring the exact structure and testing pattern already used by `infra/src/scripts/modules/Caldova.HrFrontier.Bootstrap/` — `Public/` functions each accept an injectable `-NativeCommandRunner` scriptblock (default: actually invoke `pac.exe`), so Pester can supply canned responses and assert exact argument construction without touching a live tenant. Two thin entry-point scripts expose the module as a CLI. The module reads (never writes) `infra/src/config/tenants/<alias>.psd1` for environment URLs.

**Tech Stack:** PowerShell 5.1+, Pester 5.7.1, Microsoft PowerPlatform CLI (`pac`, confirmed installed at `C:\Users\urruegg\.dotnet\tools\pac.exe`, version 1.43.6).

**Spec:** [`docs/specs/2026-09-24-power-platform-solution-foundation-design.md`](../specs/2026-09-24-power-platform-solution-foundation-design.md)

## Global Constraints

- **No file under `infra/` is created, modified, or deleted.** The module only reads `infra/src/config/tenants/<alias>.psd1`.
- **`pac solution export` is DEV-only.** `Export-HrSolutionPackage` hardcodes `Stage = 'Dev'` internally and does not expose a `-Stage` parameter — managed solutions for TEST/PROD are pipeline-produced, never hand-exported (`docs/solution-design.md` §7).
- **Interactive auth only.** No service-principal/CI credential path this sprint.
- **Every `pac` invocation is explicit about its target `--environment`** — never relies on "currently selected org" ambient state. Verified empirically: `pac org who --environment <url>`, `pac solution export --environment <url>`, and `pac auth create --environment <url>` all accept this directly.
- **Confirmed ground truth values** (from live, read-only `pac` investigation): Tenant alias `caldova25156897`; DEV URL `https://hrfrontierdev.crm17.dynamics.com/`; solution unique name `caldovahrfrontier`; publisher prefix `calhr`; unpacked solution manifest lives at `<folder>/Other/Solution.xml` with the version at `.ImportExportXml.SolutionManifest.Version`.
- **PAC auth profile names have a 30-character limit.** Computed as `hr-<TenantAlias>-<stage>` (lowercase stage); the function must throw rather than silently truncate if this exceeds 30 characters.
- Every markdown file created or rewritten carries the repository's required six-field documentation metadata table (`Version`/`Date`/`Author`/`Status`/`Scope`/`References`) immediately after its H1 — enforced by `.github/cli/modules/DocumentationMetadata.psm1`.

---

### Task 1: Module scaffold and `Get-HrTenantPowerPlatformUrl`

**Files:**
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psd1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psm1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Get-HrTenantPowerPlatformUrl.ps1`
- Create: `hr/tests/pester/SolutionLifecycle.Tests.ps1`

**Interfaces:**
- Produces: `Get-HrTenantPowerPlatformUrl -TenantAlias <string> -Stage <'Dev'|'Test'|'Prod'> [-TenantConfigurationPath <string>]` → returns `[string]` (the resolved URL). Later tasks (2, 3) call this function by this exact name and signature.

- [ ] **Step 1: Write the failing test**

Create `hr/tests/pester/SolutionLifecycle.Tests.ps1` with this content:

```powershell
Set-StrictMode -Version Latest

Describe 'Get-HrTenantPowerPlatformUrl' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        $script:RealTenantManifestPath = Join-Path $PSScriptRoot '..\..\..\infra\src\config\tenants\caldova25156897.psd1'
        Import-Module $script:ModuleManifestPath -Force

        function script:New-FixtureManifest {
            param([string]$Content)

            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.psd1')
            [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
            $path
        }
    }

    It 'resolves the Dev, Test, and Prod URLs from the real Tenant 1 manifest' {
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath) |
            Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Test' -TenantConfigurationPath $script:RealTenantManifestPath) |
            Should -Be 'https://hrfrontiertest.crm17.dynamics.com/'
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Prod' -TenantConfigurationPath $script:RealTenantManifestPath) |
            Should -Be 'https://hrfrontier.crm17.dynamics.com/'
    }

    It 'resolves the default manifest path from TenantAlias when no path is given' {
        (Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Dev') |
            Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
    }

    It 'throws a clear error when the tenant manifest does not exist' {
        { Get-HrTenantPowerPlatformUrl -TenantAlias 'doesnotexist' -Stage 'Dev' } |
            Should -Throw '*Tenant manifest not found*'
    }

    It 'throws when the manifest has no PowerPlatform section' {
        $path = New-FixtureManifest -Content "@{ TenantAlias = 'fixturetenant' }"

        { Get-HrTenantPowerPlatformUrl -TenantAlias 'fixturetenant' -Stage 'Dev' -TenantConfigurationPath $path } |
            Should -Throw '*does not define PowerPlatform.DevUrl*'
    }

    It 'rejects an invalid TenantAlias' {
        { Get-HrTenantPowerPlatformUrl -TenantAlias 'Not-Valid!' -Stage 'Dev' } | Should -Throw
    }

    It 'rejects an invalid Stage' {
        { Get-HrTenantPowerPlatformUrl -TenantAlias 'caldova25156897' -Stage 'Staging' } | Should -Throw
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: FAIL — the module manifest file does not exist yet, so `Import-Module` throws.

- [ ] **Step 3: Create the module manifest**

Create `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psd1`:

```powershell
@{
    RootModule = 'Caldova.HrFrontier.Solutions.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'e17e045c-0ec6-4427-84c4-6b244b2687ae'
    Author = 'GitHub Copilot'
    CompanyName = 'Caldova'
    Copyright = '(c) Caldova'
    Description = 'Power Platform solution lifecycle helpers for the Caldova HR Frontier HR domain.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-HrTenantPowerPlatformUrl'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
```

- [ ] **Step 4: Create the module loader**

Create `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psm1`:

```powershell
$privateScriptsPath = Join-Path $PSScriptRoot 'Private'
if (Test-Path -LiteralPath $privateScriptsPath) {
    Get-ChildItem -LiteralPath $privateScriptsPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
        . $_.FullName
    }
}

$publicScriptsPath = Join-Path $PSScriptRoot 'Public'
Get-ChildItem -LiteralPath $publicScriptsPath -Filter '*.ps1' | Sort-Object Name | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function @(
    'Get-HrTenantPowerPlatformUrl'
)
```

- [ ] **Step 5: Implement `Get-HrTenantPowerPlatformUrl`**

Create `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Get-HrTenantPowerPlatformUrl.ps1`:

```powershell
function Get-HrTenantPowerPlatformUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]+$')]
        [string]$TenantAlias,

        [Parameter(Mandatory)]
        [ValidateSet('Dev', 'Test', 'Prod')]
        [string]$Stage,

        [string]$TenantConfigurationPath
    )

    $resolvedPath = if ([string]::IsNullOrWhiteSpace($TenantConfigurationPath)) {
        [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\..\..\..\infra\src\config\tenants\$TenantAlias.psd1"))
    }
    else {
        [System.IO.Path]::GetFullPath($TenantConfigurationPath)
    }

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "Tenant manifest not found for '$TenantAlias': $resolvedPath. This function reads infra/src/config/tenants/ read-only and never creates a manifest."
    }

    $configuration = Import-PowerShellDataFile -LiteralPath $resolvedPath
    $urlPropertyName = "$($Stage)Url"
    $powerPlatform = $configuration.PowerPlatform
    if ($null -eq $powerPlatform -or -not $powerPlatform.Contains($urlPropertyName)) {
        throw "Tenant manifest for '$TenantAlias' does not define PowerPlatform.$urlPropertyName."
    }

    [string]$powerPlatform[$urlPropertyName]
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: PASS — all 6 tests green.

- [ ] **Step 7: Commit**

```bash
git add hr/src/scripts/modules/Caldova.HrFrontier.Solutions/ hr/tests/pester/SolutionLifecycle.Tests.ps1
git commit -m "feat: scaffold Caldova.HrFrontier.Solutions module with tenant URL resolution"
```

---

### Task 2: `Connect-HrPowerPlatformEnvironment`

**Files:**
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Private/Invoke-HrNativeCommand.ps1`
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Connect-HrPowerPlatformEnvironment.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psd1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psm1`
- Modify: `hr/tests/pester/SolutionLifecycle.Tests.ps1`

**Interfaces:**
- Consumes: `Get-HrTenantPowerPlatformUrl` from Task 1 (exact signature above).
- Produces: `Connect-HrPowerPlatformEnvironment -TenantAlias <string> -Stage <'Dev'|'Test'|'Prod'> [-TenantConfigurationPath <string>] [-NativeCommandRunner <scriptblock>]` → returns `[pscustomobject]@{ TenantAlias; Stage; EnvironmentUrl; ProfileName }`. Task 3 calls this with `-Stage 'Dev'` internally. The injected `-NativeCommandRunner` scriptblock, when supplied, is called as `& $NativeCommandRunner -FilePath <string> -ArgumentList <string[]>` and must return an object with `.ExitCode`, `.StdOut`, `.StdErr` — this exact shape is reused by Tasks 3 and 4.

- [ ] **Step 1: Write the failing tests**

Append to `hr/tests/pester/SolutionLifecycle.Tests.ps1` (after the closing `}` of the `Get-HrTenantPowerPlatformUrl` `Describe` block):

```powershell
Describe 'Connect-HrPowerPlatformEnvironment' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        $script:RealTenantManifestPath = Join-Path $PSScriptRoot '..\..\..\infra\src\config\tenants\caldova25156897.psd1'
        Import-Module $script:ModuleManifestPath -Force

        function script:New-FakeNativeRunner {
            param(
                [Parameter(Mandatory)]
                [hashtable]$Responses,

                [Parameter(Mandatory)]
                [System.Collections.Generic.List[object]]$Calls
            )

            {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $Calls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = @($ArgumentList) }) | Out-Null
                $joined = $ArgumentList -join ' '
                foreach ($key in $Responses.Keys) {
                    if ($joined -like $key) {
                        return $Responses[$key]
                    }
                }

                [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = "Unmapped fake call: $joined" }
            }.GetNewClosure()
        }

        $script:ExistingProfileAuthList = @'
Index Active Kind      Name                    User                                  Cloud  Type Environment Environment Url
[1]          UNIVERSAL hr-caldova25156897-dev admin@caldova25156897.onmicrosoft.com Public User
'@

        $script:EmptyAuthList = @'
Index Active Kind      Name         User                                  Cloud  Type Environment Environment Url
[1]          UNIVERSAL otherprofile admin@other.onmicrosoft.com           Public User
'@
    }

    It 'selects an existing profile rather than creating a new one' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-FakeNativeRunner -Calls $calls -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 0; StdOut = $script:ExistingProfileAuthList; StdErr = '' }
            'auth select --name hr-caldova25156897-dev' = [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            "org who --environment https://hrfrontierdev.crm17.dynamics.com/" = [pscustomobject]@{ ExitCode = 0; StdOut = 'Connected'; StdErr = '' }
        }

        $result = Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner

        $result.EnvironmentUrl | Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        $result.ProfileName | Should -Be 'hr-caldova25156897-dev'
        @($calls | Where-Object { $_.ArgumentList -join ' ' -like 'auth create*' }).Count | Should -Be 0
        @($calls | Where-Object { $_.ArgumentList -join ' ' -eq 'auth select --name hr-caldova25156897-dev' }).Count | Should -Be 1
    }

    It 'creates a new profile when none matches' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-FakeNativeRunner -Calls $calls -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 0; StdOut = $script:EmptyAuthList; StdErr = '' }
            'auth create --name hr-caldova25156897-dev --environment https://hrfrontierdev.crm17.dynamics.com/' = [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            "org who --environment https://hrfrontierdev.crm17.dynamics.com/" = [pscustomobject]@{ ExitCode = 0; StdOut = 'Connected'; StdErr = '' }
        }

        $result = Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner

        $result.ProfileName | Should -Be 'hr-caldova25156897-dev'
        @($calls | Where-Object { $_.ArgumentList -join ' ' -eq 'auth create --name hr-caldova25156897-dev --environment https://hrfrontierdev.crm17.dynamics.com/' }).Count | Should -Be 1
    }

    It 'throws when the computed profile name would exceed 30 characters' {
        $runner = New-FakeNativeRunner -Calls ([System.Collections.Generic.List[object]]::new()) -Responses @{}

        { Connect-HrPowerPlatformEnvironment -TenantAlias 'aterriblylongtenantaliasname' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*exceeds the 30-character limit*'
    }

    It 'propagates failure when pac auth list fails' {
        $runner = New-FakeNativeRunner -Calls ([System.Collections.Generic.List[object]]::new()) -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'boom' }
        }

        { Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*pac auth list failed*'
    }

    It 'propagates failure when pac org who fails' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-FakeNativeRunner -Calls $calls -Responses @{
            'auth list' = [pscustomobject]@{ ExitCode = 0; StdOut = $script:ExistingProfileAuthList; StdErr = '' }
            'auth select --name hr-caldova25156897-dev' = [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
            "org who --environment https://hrfrontierdev.crm17.dynamics.com/" = [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'not connected' }
        }

        { Connect-HrPowerPlatformEnvironment -TenantAlias 'caldova25156897' -Stage 'Dev' -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*pac org who failed*'
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: FAIL — `Connect-HrPowerPlatformEnvironment` is not recognized.

- [ ] **Step 3: Implement the private native-command helper**

Create `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Private/Invoke-HrNativeCommand.ps1`:

```powershell
function Invoke-HrNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [scriptblock]$NativeCommandRunner
    )

    if ($NativeCommandRunner) {
        $result = & $NativeCommandRunner -FilePath $FilePath -ArgumentList $ArgumentList
        return [pscustomobject]@{
            ExitCode = [int]$result.ExitCode
            StdOut = [string]$result.StdOut
            StdErr = [string]$result.StdErr
        }
    }

    $resolvedCommand = Get-Command $FilePath -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $resolvedCommand) {
        throw "Cannot resolve executable on PATH: $FilePath"
    }

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        & $resolvedCommand.Source @ArgumentList 1> $stdoutPath 2> $stderrPath
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            StdOut = [System.IO.File]::ReadAllText($stdoutPath)
            StdErr = [System.IO.File]::ReadAllText($stderrPath)
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}
```

- [ ] **Step 4: Implement `Connect-HrPowerPlatformEnvironment`**

Create `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Connect-HrPowerPlatformEnvironment.ps1`:

```powershell
function Connect-HrPowerPlatformEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]+$')]
        [string]$TenantAlias,

        [Parameter(Mandatory)]
        [ValidateSet('Dev', 'Test', 'Prod')]
        [string]$Stage,

        [string]$TenantConfigurationPath,

        [scriptblock]$NativeCommandRunner
    )

    $environmentUrl = Get-HrTenantPowerPlatformUrl -TenantAlias $TenantAlias -Stage $Stage -TenantConfigurationPath $TenantConfigurationPath
    $profileName = "hr-$TenantAlias-$($Stage.ToLowerInvariant())"
    if ($profileName.Length -gt 30) {
        throw "Computed PAC auth profile name '$profileName' exceeds the 30-character limit. Shorten TenantAlias or contact the platform owner before proceeding."
    }

    $listResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('auth', 'list') -NativeCommandRunner $NativeCommandRunner
    if ($listResult.ExitCode -ne 0) {
        throw "pac auth list failed: $($listResult.StdErr)"
    }

    $existingProfileFound = $false
    foreach ($line in ($listResult.StdOut -split "`r?`n")) {
        $match = [regex]::Match($line, '^\[(?<idx>\d+)\]\s*(?<active>\*)?\s*(?<kind>\S+)\s+(?<name>\S+)')
        if ($match.Success -and $match.Groups['name'].Value -ceq $profileName) {
            $existingProfileFound = $true
            break
        }
    }

    if ($existingProfileFound) {
        $selectResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('auth', 'select', '--name', $profileName) -NativeCommandRunner $NativeCommandRunner
        if ($selectResult.ExitCode -ne 0) {
            throw "pac auth select failed for profile '$profileName': $($selectResult.StdErr)"
        }
    }
    else {
        $createResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('auth', 'create', '--name', $profileName, '--environment', $environmentUrl) -NativeCommandRunner $NativeCommandRunner
        if ($createResult.ExitCode -ne 0) {
            throw "pac auth create failed for profile '$profileName': $($createResult.StdErr)"
        }
    }

    $whoResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('org', 'who', '--environment', $environmentUrl) -NativeCommandRunner $NativeCommandRunner
    if ($whoResult.ExitCode -ne 0) {
        throw "pac org who failed to verify connectivity for '$environmentUrl': $($whoResult.StdErr)"
    }

    [pscustomobject]@{
        TenantAlias = $TenantAlias
        Stage = $Stage
        EnvironmentUrl = $environmentUrl
        ProfileName = $profileName
    }
}
```

- [ ] **Step 5: Register the new function in the module manifest and loader**

In `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psd1`, change:

```powershell
    FunctionsToExport = @(
        'Get-HrTenantPowerPlatformUrl'
    )
```

to:

```powershell
    FunctionsToExport = @(
        'Get-HrTenantPowerPlatformUrl',
        'Connect-HrPowerPlatformEnvironment'
    )
```

In `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psm1`, change:

```powershell
Export-ModuleMember -Function @(
    'Get-HrTenantPowerPlatformUrl'
)
```

to:

```powershell
Export-ModuleMember -Function @(
    'Get-HrTenantPowerPlatformUrl',
    'Connect-HrPowerPlatformEnvironment'
)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: PASS — 11 tests total (6 from Task 1, 5 new), 0 failed.

- [ ] **Step 7: Commit**

```bash
git add hr/src/scripts/modules/Caldova.HrFrontier.Solutions/ hr/tests/pester/SolutionLifecycle.Tests.ps1
git commit -m "feat: add Connect-HrPowerPlatformEnvironment with injectable native command runner"
```

---

### Task 3: `Export-HrSolutionPackage`

**Files:**
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Export-HrSolutionPackage.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psd1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psm1`
- Modify: `hr/tests/pester/SolutionLifecycle.Tests.ps1`

**Interfaces:**
- Consumes: `Connect-HrPowerPlatformEnvironment` from Task 2 (exact signature above); `Invoke-HrNativeCommand` (private, Task 2).
- Produces: `Export-HrSolutionPackage -TenantAlias <string> -SolutionUniqueName <string> -DestinationPath <string> [-TenantConfigurationPath <string>] [-NativeCommandRunner <scriptblock>]` → returns `[pscustomobject]@{ TenantAlias; SolutionUniqueName; Path; EnvironmentUrl }`. Task 5's `Sync-HrSolutionSource.ps1` calls this and reads `.Path` and `.EnvironmentUrl` from the result.

- [ ] **Step 1: Write the failing tests**

Append to `hr/tests/pester/SolutionLifecycle.Tests.ps1`:

```powershell
Describe 'Export-HrSolutionPackage' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        $script:RealTenantManifestPath = Join-Path $PSScriptRoot '..\..\..\infra\src\config\tenants\caldova25156897.psd1'
        Import-Module $script:ModuleManifestPath -Force

        function script:New-ExportFakeRunner {
            param([System.Collections.Generic.List[object]]$Calls)

            {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $Calls.Add([pscustomobject]@{ FilePath = $FilePath; ArgumentList = @($ArgumentList) }) | Out-Null
                $joined = $ArgumentList -join ' '
                if ($joined -eq 'auth list') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = "Index Active Kind Name User Cloud Type`n[1] * UNIVERSAL hr-caldova25156897-dev admin@x Public User"; StdErr = '' }
                }
                if ($joined -eq 'auth select --name hr-caldova25156897-dev') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
                }
                if ($joined -eq 'org who --environment https://hrfrontierdev.crm17.dynamics.com/') {
                    return [pscustomobject]@{ ExitCode = 0; StdOut = 'Connected'; StdErr = '' }
                }
                if ($FilePath -eq 'pac' -and $ArgumentList[0] -eq 'solution' -and $ArgumentList[1] -eq 'export') {
                    $pathIndex = [array]::IndexOf($ArgumentList, '--path') + 1
                    [System.IO.File]::WriteAllText($ArgumentList[$pathIndex], 'fake zip content')
                    return [pscustomobject]@{ ExitCode = 0; StdOut = 'Solution export succeeded.'; StdErr = '' }
                }

                [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = "Unmapped fake call: $joined" }
            }.GetNewClosure()
        }
    }

    It 'exports with the Dev environment explicitly, never relying on ambient org state' {
        $destination = Join-Path $TestDrive 'caldovahrfrontier.zip'
        $calls = [System.Collections.Generic.List[object]]::new()
        $runner = New-ExportFakeRunner -Calls $calls

        $result = Export-HrSolutionPackage -TenantAlias 'caldova25156897' -SolutionUniqueName 'caldovahrfrontier' -DestinationPath $destination -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner

        $result.EnvironmentUrl | Should -Be 'https://hrfrontierdev.crm17.dynamics.com/'
        $result.SolutionUniqueName | Should -Be 'caldovahrfrontier'
        Test-Path -LiteralPath $result.Path | Should -BeTrue

        $exportCall = $calls | Where-Object { $_.ArgumentList[0] -eq 'solution' -and $_.ArgumentList[1] -eq 'export' }
        $exportCall.ArgumentList -join ' ' | Should -Be "solution export --name caldovahrfrontier --path $destination --managed false --overwrite true --environment https://hrfrontierdev.crm17.dynamics.com/"
    }

    It 'does not expose a Stage parameter — export is always Dev-only' {
        (Get-Command Export-HrSolutionPackage).Parameters.Keys | Should -Not -Contain 'Stage'
    }

    It 'throws when pac solution export fails' {
        $destination = Join-Path $TestDrive 'failed.zip'
        $runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            $joined = $ArgumentList -join ' '
            if ($joined -eq 'auth list') { return [pscustomobject]@{ ExitCode = 0; StdOut = "Index`n[1] * UNIVERSAL hr-caldova25156897-dev admin@x Public User"; StdErr = '' } }
            if ($joined -eq 'auth select --name hr-caldova25156897-dev') { return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }
            if ($joined -eq 'org who --environment https://hrfrontierdev.crm17.dynamics.com/') { return [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' } }
            [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'export failed' }
        }

        { Export-HrSolutionPackage -TenantAlias 'caldova25156897' -SolutionUniqueName 'caldovahrfrontier' -DestinationPath $destination -TenantConfigurationPath $script:RealTenantManifestPath -NativeCommandRunner $runner } |
            Should -Throw '*pac solution export failed*'
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: FAIL — `Export-HrSolutionPackage` is not recognized.

- [ ] **Step 3: Implement `Export-HrSolutionPackage`**

Create `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Export-HrSolutionPackage.ps1`:

```powershell
function Export-HrSolutionPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]+$')]
        [string]$TenantAlias,

        [Parameter(Mandatory)]
        [string]$SolutionUniqueName,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [string]$TenantConfigurationPath,

        [scriptblock]$NativeCommandRunner
    )

    $connection = Connect-HrPowerPlatformEnvironment -TenantAlias $TenantAlias -Stage 'Dev' -TenantConfigurationPath $TenantConfigurationPath -NativeCommandRunner $NativeCommandRunner

    $resolvedDestinationPath = [System.IO.Path]::GetFullPath($DestinationPath)
    $destinationDirectory = Split-Path -Parent $resolvedDestinationPath
    if (-not [string]::IsNullOrWhiteSpace($destinationDirectory) -and -not (Test-Path -LiteralPath $destinationDirectory)) {
        [void](New-Item -ItemType Directory -Path $destinationDirectory -Force)
    }

    $exportResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @(
        'solution', 'export',
        '--name', $SolutionUniqueName,
        '--path', $resolvedDestinationPath,
        '--managed', 'false',
        '--overwrite', 'true',
        '--environment', $connection.EnvironmentUrl
    ) -NativeCommandRunner $NativeCommandRunner

    if ($exportResult.ExitCode -ne 0) {
        throw "pac solution export failed for '$SolutionUniqueName': $($exportResult.StdErr)"
    }

    if (-not (Test-Path -LiteralPath $resolvedDestinationPath -PathType Leaf)) {
        throw "pac solution export reported success but no file was written to $resolvedDestinationPath."
    }

    [pscustomobject]@{
        TenantAlias = $TenantAlias
        SolutionUniqueName = $SolutionUniqueName
        Path = $resolvedDestinationPath
        EnvironmentUrl = $connection.EnvironmentUrl
    }
}
```

- [ ] **Step 4: Register the new function**

In `Caldova.HrFrontier.Solutions.psd1`, change `FunctionsToExport` to:

```powershell
    FunctionsToExport = @(
        'Get-HrTenantPowerPlatformUrl',
        'Connect-HrPowerPlatformEnvironment',
        'Export-HrSolutionPackage'
    )
```

In `Caldova.HrFrontier.Solutions.psm1`, change `Export-ModuleMember` to:

```powershell
Export-ModuleMember -Function @(
    'Get-HrTenantPowerPlatformUrl',
    'Connect-HrPowerPlatformEnvironment',
    'Export-HrSolutionPackage'
)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: PASS — 14 tests total, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add hr/src/scripts/modules/Caldova.HrFrontier.Solutions/ hr/tests/pester/SolutionLifecycle.Tests.ps1
git commit -m "feat: add Export-HrSolutionPackage (Dev-only, explicit environment)"
```

---

### Task 4: `Expand-HrSolutionPackage`

**Files:**
- Create: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Expand-HrSolutionPackage.ps1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psd1`
- Modify: `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Caldova.HrFrontier.Solutions.psm1`
- Modify: `hr/tests/pester/SolutionLifecycle.Tests.ps1`

**Interfaces:**
- Consumes: `Invoke-HrNativeCommand` (private, Task 2).
- Produces: `Expand-HrSolutionPackage -ZipPath <string> -SolutionUniqueName <string> -SolutionsRoot <string> [-NativeCommandRunner <scriptblock>]` → returns `[pscustomobject]@{ SolutionUniqueName; Folder }`. Task 5's `Sync-HrSolutionSource.ps1` calls this and reads `.Folder`.

- [ ] **Step 1: Write the failing tests**

Append to `hr/tests/pester/SolutionLifecycle.Tests.ps1`:

```powershell
Describe 'Expand-HrSolutionPackage' {
    BeforeAll {
        $script:ModuleManifestPath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
        Import-Module $script:ModuleManifestPath -Force
    }

    It 'constructs the exact expected pac solution unpack arguments and reports the target folder' {
        $zipPath = Join-Path $TestDrive 'caldovahrfrontier.zip'
        [System.IO.File]::WriteAllText($zipPath, 'fake zip content')
        $solutionsRoot = Join-Path $TestDrive 'solutions'
        $expectedFolder = Join-Path $solutionsRoot 'caldovahrfrontier'
        $calls = [System.Collections.Generic.List[object]]::new()

        $runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            $calls.Add(@($ArgumentList)) | Out-Null
            [void](New-Item -ItemType Directory -Path $expectedFolder -Force)
            [System.IO.File]::WriteAllText((Join-Path $expectedFolder 'solution.xml'), '<x/>')
            [pscustomobject]@{ ExitCode = 0; StdOut = 'Unpacked Solution.'; StdErr = '' }
        }.GetNewClosure()

        $result = Expand-HrSolutionPackage -ZipPath $zipPath -SolutionUniqueName 'caldovahrfrontier' -SolutionsRoot $solutionsRoot -NativeCommandRunner $runner

        $result.Folder | Should -Be $expectedFolder
        ($calls[0] -join ' ') | Should -Be "solution unpack --zipfile $zipPath --folder $expectedFolder --packagetype Unmanaged --allowWrite true --allowDelete true --clobber true"
    }

    It 'throws when the zip file does not exist' {
        { Expand-HrSolutionPackage -ZipPath (Join-Path $TestDrive 'missing.zip') -SolutionUniqueName 'x' -SolutionsRoot $TestDrive } |
            Should -Throw '*Solution zip not found*'
    }

    It 'throws when pac solution unpack fails' {
        $zipPath = Join-Path $TestDrive 'caldovahrfrontier2.zip'
        [System.IO.File]::WriteAllText($zipPath, 'fake zip content')
        $runner = { param([string]$FilePath, [string[]]$ArgumentList) [pscustomobject]@{ ExitCode = 1; StdOut = ''; StdErr = 'unpack failed' } }

        { Expand-HrSolutionPackage -ZipPath $zipPath -SolutionUniqueName 'caldovahrfrontier' -SolutionsRoot (Join-Path $TestDrive 'solutions2') -NativeCommandRunner $runner } |
            Should -Throw '*pac solution unpack failed*'
    }

    It 'throws when unpack reports success but the target folder is empty' {
        $zipPath = Join-Path $TestDrive 'caldovahrfrontier3.zip'
        [System.IO.File]::WriteAllText($zipPath, 'fake zip content')
        $solutionsRoot = Join-Path $TestDrive 'solutions3'
        $expectedFolder = Join-Path $solutionsRoot 'caldovahrfrontier'
        $runner = {
            param([string]$FilePath, [string[]]$ArgumentList)
            [void](New-Item -ItemType Directory -Path $expectedFolder -Force)
            [pscustomobject]@{ ExitCode = 0; StdOut = ''; StdErr = '' }
        }.GetNewClosure()

        { Expand-HrSolutionPackage -ZipPath $zipPath -SolutionUniqueName 'caldovahrfrontier' -SolutionsRoot $solutionsRoot -NativeCommandRunner $runner } |
            Should -Throw '*is empty*'
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: FAIL — `Expand-HrSolutionPackage` is not recognized.

- [ ] **Step 3: Implement `Expand-HrSolutionPackage`**

Create `hr/src/scripts/modules/Caldova.HrFrontier.Solutions/Public/Expand-HrSolutionPackage.ps1`:

```powershell
function Expand-HrSolutionPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ZipPath,

        [Parameter(Mandatory)]
        [string]$SolutionUniqueName,

        [Parameter(Mandatory)]
        [string]$SolutionsRoot,

        [scriptblock]$NativeCommandRunner
    )

    $resolvedZipPath = [System.IO.Path]::GetFullPath($ZipPath)
    if (-not (Test-Path -LiteralPath $resolvedZipPath -PathType Leaf)) {
        throw "Solution zip not found: $resolvedZipPath"
    }

    $resolvedSolutionsRoot = [System.IO.Path]::GetFullPath($SolutionsRoot)
    $targetFolder = Join-Path $resolvedSolutionsRoot $SolutionUniqueName

    $unpackResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @(
        'solution', 'unpack',
        '--zipfile', $resolvedZipPath,
        '--folder', $targetFolder,
        '--packagetype', 'Unmanaged',
        '--allowWrite', 'true',
        '--allowDelete', 'true',
        '--clobber', 'true'
    ) -NativeCommandRunner $NativeCommandRunner

    if ($unpackResult.ExitCode -ne 0) {
        throw "pac solution unpack failed for '$SolutionUniqueName': $($unpackResult.StdErr)"
    }

    if (-not (Test-Path -LiteralPath $targetFolder -PathType Container) -or (@(Get-ChildItem -LiteralPath $targetFolder -Force)).Count -eq 0) {
        throw "pac solution unpack reported success but $targetFolder is empty."
    }

    [pscustomobject]@{
        SolutionUniqueName = $SolutionUniqueName
        Folder = $targetFolder
    }
}
```

- [ ] **Step 4: Register the new function**

In `Caldova.HrFrontier.Solutions.psd1`, change `FunctionsToExport` to:

```powershell
    FunctionsToExport = @(
        'Get-HrTenantPowerPlatformUrl',
        'Connect-HrPowerPlatformEnvironment',
        'Export-HrSolutionPackage',
        'Expand-HrSolutionPackage'
    )
```

In `Caldova.HrFrontier.Solutions.psm1`, change `Export-ModuleMember` to:

```powershell
Export-ModuleMember -Function @(
    'Get-HrTenantPowerPlatformUrl',
    'Connect-HrPowerPlatformEnvironment',
    'Export-HrSolutionPackage',
    'Expand-HrSolutionPackage'
)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `Import-Module Pester -RequiredVersion 5.7.1 -Force; Invoke-Pester -Path hr/tests/pester/SolutionLifecycle.Tests.ps1 -Output Detailed`
Expected: PASS — 18 tests total, 0 failed.

- [ ] **Step 6: Commit**

```bash
git add hr/src/scripts/modules/Caldova.HrFrontier.Solutions/ hr/tests/pester/SolutionLifecycle.Tests.ps1
git commit -m "feat: add Expand-HrSolutionPackage"
```

---

### Task 5: Entry-point scripts and script README

**Files:**
- Create: `hr/src/scripts/Connect-PowerPlatformEnvironment.ps1`
- Create: `hr/src/scripts/Sync-HrSolutionSource.ps1`
- Create: `hr/src/scripts/README.md`

**Interfaces:**
- Consumes: `Connect-HrPowerPlatformEnvironment`, `Export-HrSolutionPackage`, `Expand-HrSolutionPackage` from the module (Tasks 2-4).
- Produces: two runnable CLI scripts used manually in Task 8 and by future tenant onboarding.

This task has no new automated test — both scripts are thin parameter-parsing wrappers around already-tested module functions, and their end-to-end behavior against a real tenant is verified live in Task 8. Verification here is a syntax/structure check only.

- [ ] **Step 1: Create the Connect entry point**

Create `hr/src/scripts/Connect-PowerPlatformEnvironment.ps1`:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [ValidateSet('Dev', 'Test', 'Prod')]
    [string]$Stage = 'Dev'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
}

Import-Module (Get-ModuleManifestPath) -Force

Connect-HrPowerPlatformEnvironment -TenantAlias $TenantAlias -Stage $Stage
```

- [ ] **Step 2: Create the Sync entry point**

Create `hr/src/scripts/Sync-HrSolutionSource.ps1`:

```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [Parameter(Mandatory)]
    [string]$SolutionUniqueName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
}

function Get-SolutionsRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\solutions'))
}

Import-Module (Get-ModuleManifestPath) -Force

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-solution-sync-{0}" -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $temporaryDirectory -Force)
$temporaryZipPath = Join-Path $temporaryDirectory "$SolutionUniqueName.zip"

try {
    Write-Output "Connecting to Tenant '$TenantAlias' DEV and exporting solution '$SolutionUniqueName'..."
    $exportResult = Export-HrSolutionPackage -TenantAlias $TenantAlias -SolutionUniqueName $SolutionUniqueName -DestinationPath $temporaryZipPath

    Write-Output "Unpacking into hr/src/solutions/$SolutionUniqueName..."
    $solutionsRoot = Get-SolutionsRoot
    $unpackResult = Expand-HrSolutionPackage -ZipPath $exportResult.Path -SolutionUniqueName $SolutionUniqueName -SolutionsRoot $solutionsRoot

    $solutionXmlPath = Join-Path $unpackResult.Folder 'Other\Solution.xml'
    $solutionVersion = 'unknown'
    if (Test-Path -LiteralPath $solutionXmlPath -PathType Leaf) {
        $solutionXml = [xml](Get-Content -LiteralPath $solutionXmlPath -Raw)
        $solutionVersion = $solutionXml.ImportExportXml.SolutionManifest.Version
    }

    Write-Output ("Synced '{0}' version {1} from {2} into {3}" -f $SolutionUniqueName, $solutionVersion, $exportResult.EnvironmentUrl, $unpackResult.Folder)

    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gitCommand) {
        Write-Output '--- git status for the synced folder ---'
        & $gitCommand.Source status --porcelain -- $unpackResult.Folder
    }
}
finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 3: Verify both scripts parse without error**

Run:

```powershell
$errors = $null
[System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw hr/src/scripts/Connect-PowerPlatformEnvironment.ps1), [ref]$errors)
"Connect script parse errors: $($errors.Count)"
$errors2 = $null
[System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw hr/src/scripts/Sync-HrSolutionSource.ps1), [ref]$errors2)
"Sync script parse errors: $($errors2.Count)"
```

Expected: `Connect script parse errors: 0` and `Sync script parse errors: 0`.

- [ ] **Step 4: Write the script README**

Create `hr/src/scripts/README.md`:

````markdown
# `hr/src/scripts/` — Power Platform solution lifecycle tooling

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Architecture |
| **References** | [Power Platform Solution Foundation Design](../../../docs/specs/2026-09-24-power-platform-solution-foundation-design.md) |

**Purpose.** Connects to a tenant's Power Platform environment and pulls its Dataverse solution into source control. Built once, parameterized by tenant alias throughout, so the same scripts work unchanged for Tenant 2 and Tenant 3 after handover — no code here names Tenant 1 or `caldovahrfrontier` directly.

## What is here

| Path | Purpose |
|---|---|
| `Connect-PowerPlatformEnvironment.ps1` | Verifies (and if needed, creates) an authenticated PAC CLI profile for a tenant/stage. Useful standalone to check connectivity before running anything else. |
| `Sync-HrSolutionSource.ps1` | The main entry point: exports a named solution's unmanaged package from a tenant's **DEV environment only**, unpacks it into `hr/src/solutions/<SolutionUniqueName>/`, and cleans up the temporary zip. This is what makes the committed source an exact, reviewable mirror of what is in Dataverse. |
| `modules/Caldova.HrFrontier.Solutions/` | The module both scripts are built on — read `Public/` for the individual functions if you are calling this from another script. |

## Usage

```powershell
# Verify connectivity to Tenant 1's DEV environment
.\Connect-PowerPlatformEnvironment.ps1 -TenantAlias caldova25156897 -Stage Dev

# Pull the current state of the solution into source control
.\Sync-HrSolutionSource.ps1 -TenantAlias caldova25156897 -SolutionUniqueName caldovahrfrontier
```

The first run for a tenant prompts an interactive Microsoft Entra ID sign-in (a PAC auth profile named `hr-<TenantAlias>-<stage>` is created and reused on subsequent runs). No service-principal or CI credential path exists yet — that is deliberately deferred until a tenant's infrastructure bootstrap provisions a usable credential for it.

## Why export is DEV-only

`Export-HrSolutionPackage` does not accept a `-Stage` parameter. Managed solutions for TEST and PROD are produced by a deployment pipeline from the committed DEV source — never hand-exported from those environments — per [`docs/solution-design.md`](../../../docs/solution-design.md). Hand-exporting from TEST or PROD would create a second, undocumented path for solution content to enter source control, silently diverging from the pipeline-managed one.

## What this does not do (yet)

- **No push path.** These scripts only pull (export + unpack). Pushing local changes back into Dataverse (`pac solution pack` + `pac solution import`) is separate future work, once there is local content to round-trip.
- **No table, security role, connection reference, environment variable, or Copilot Studio agent creation.** Those are authored in the Power Platform maker portal (or via `pac` commands run directly by whoever is building); this tooling only pulls the result into source control afterward.
````

- [ ] **Step 5: Verify documentation metadata passes**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild`
Expected: `Repository setup validation passed.`

- [ ] **Step 6: Commit**

```bash
git add hr/src/scripts/Connect-PowerPlatformEnvironment.ps1 hr/src/scripts/Sync-HrSolutionSource.ps1 hr/src/scripts/README.md
git commit -m "feat: add Power Platform solution lifecycle entry-point scripts"
```

---

### Task 6: Wire `hr/tests/pester` into required CI

**Files:**
- Modify: `.github/workflows/validate-repository.yml`

**Interfaces:** none — this task only changes which test paths CI runs.

- [ ] **Step 1: Add the new test path**

In `.github/workflows/validate-repository.yml`, find:

```yaml
      - name: Run core contract tests
        shell: powershell
        run: |
          $paths = @(
            '.github/cli/tests/WorkflowContract.Tests.ps1'
            '.github/cli/tests/RepositorySafety.Tests.ps1'
            'infra/tests/pester'
          )
          Invoke-Pester -Path $paths -Output Detailed -CI
```

Change the `$paths` array to:

```yaml
      - name: Run core contract tests
        shell: powershell
        run: |
          $paths = @(
            '.github/cli/tests/WorkflowContract.Tests.ps1'
            '.github/cli/tests/RepositorySafety.Tests.ps1'
            'infra/tests/pester'
            'hr/tests/pester'
          )
          Invoke-Pester -Path $paths -Output Detailed -CI
```

- [ ] **Step 2: Verify locally with the exact CI command**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$paths = @(
  '.github/cli/tests/WorkflowContract.Tests.ps1'
  '.github/cli/tests/RepositorySafety.Tests.ps1'
  'infra/tests/pester'
  'hr/tests/pester'
)
Invoke-Pester -Path $paths -Output Detailed -CI
```

Expected: all tests pass, including the 18 in `hr/tests/pester/SolutionLifecycle.Tests.ps1`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/validate-repository.yml
git commit -m "ci: run hr/tests/pester as part of required repository validation"
```

---

### Task 7: Update domain documentation to reflect the foundation

**Files:**
- Modify: `hr/src/solutions/README.md`
- Modify: `hr/README.md`

**Interfaces:** none — documentation only.

- [ ] **Step 1: Rewrite `hr/src/solutions/README.md`**

Replace its entire content with:

```markdown
# HR Solution Sources

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR |
| **References** | [Power Platform Solution Foundation Design](../../../docs/specs/2026-09-24-power-platform-solution-foundation-design.md), [HR Employee Journey](../../docs/20-hr-employee-journey.md) |

This folder contains unpacked, reviewable Power Platform solution source owned by the HR domain.

Do not commit exported solution ZIP files, environment-specific connection values, secrets, personal data, or generated build output. The Infrastructure solution is imported before the HR solution in each Power Platform ALM stage.

## Current state

One foundation solution exists, synced from Tenant 1's DEV environment:

| Solution | Tenant | Publisher prefix | Contains |
|---|---|---|---|
| [`caldovahrfrontier`](caldovahrfrontier/) | Tenant 1 (Caldova) | `calhr` | Nothing yet — the solution is empty. This is the tracked foundation, ready to receive Dataverse tables and Copilot Studio agent artefacts as they are built. |

Synced using [`hr/src/scripts/Sync-HrSolutionSource.ps1`](../scripts/README.md), which exports the unmanaged solution and unpacks it here. Re-run that script after any change in the Power Platform maker portal to keep this folder an exact, reviewable mirror of what is actually in Dataverse.

`docs/solution-design.md` §7 documents an eventual two-solution split (`GFHRPlatformCore` / `GFHRMasterDataAgent`, Tenant 3 naming) once there is enough content to justify separating shared plumbing from a per-use-case agent. That split has not happened yet — there is currently one foundation solution, for one tenant.
```

- [ ] **Step 2: Update the Solutions table in `hr/README.md`**

Find this section (the exact current content):

```markdown
## Solutions

Power Platform solution source lives in `src/solutions/`, exported unmanaged from DEV and committed. Managed solutions for TEST and PROD are produced by the pipeline, never hand-exported.

| Solution | Contains |
|---|---|
| `GFHRPlatformCore` | Dataverse tables, security roles, connection references, environment variable definitions, shared agent skills |
| `GFHRMasterDataAgent` | The UC-0001 workflow, the agent it calls, the Workday Access Layer workflow, the control plane app registration |

Core imports first. The agent solution depends on it. Publisher prefix is tenant-specific and decided once per tenant before the first table — `calhr` for the Caldova practice tenants (Tenant 1 & 2), `gfhr` for the real customer tenant (Tenant 3) — because it cannot be changed afterwards without rebuilding every component that references it. This domain's solution names below (`GFHRPlatformCore`, `GFHRMasterDataAgent`) are the Tenant 3 build.
```

Replace it with:

```markdown
## Solutions

Power Platform solution source lives in `src/solutions/`, exported unmanaged from DEV and committed via [`hr/src/scripts/Sync-HrSolutionSource.ps1`](src/scripts/README.md). Managed solutions for TEST and PROD are produced by the pipeline, never hand-exported.

**Current state (Tenant 1):** one foundation solution, [`caldovahrfrontier`](src/solutions/caldovahrfrontier/), publisher prefix `calhr`. It is empty — no Dataverse tables or Copilot Studio agent artefacts exist in it yet.

**Documented target (Tenant 3 / GF), not yet built anywhere:**

| Solution | Contains |
|---|---|
| `GFHRPlatformCore` | Dataverse tables, security roles, connection references, environment variable definitions, shared agent skills |
| `GFHRMasterDataAgent` | The UC-0001 workflow, the agent it calls, the Workday Access Layer workflow, the control plane app registration |

Core would import first, with the agent solution depending on it — once there is enough content to justify splitting into two solutions. Until then, the single foundation solution above is where all of it goes. Publisher prefix is tenant-specific and decided once per tenant before the first table — `calhr` for the Caldova practice tenants (Tenant 1 & 2), `gfhr` for the real customer tenant (Tenant 3) — because it cannot be changed afterwards without rebuilding every component that references it.
```

- [ ] **Step 3: Verify documentation metadata and links**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild`
Expected: `Repository setup validation passed.`

- [ ] **Step 4: Commit**

```bash
git add hr/src/solutions/README.md hr/README.md
git commit -m "docs: reflect the current single-solution foundation state for Tenant 1"
```

---

### Task 8: Live sync — commit the real Tenant 1 solution source

**Files:**
- Create: `hr/src/solutions/caldovahrfrontier/` (generated by the script, then committed)

**Interfaces:** none — this is the first real invocation of the tooling built in Tasks 1-5, against the live Tenant 1 DEV environment already investigated during design.

- [ ] **Step 1: Run the sync script against the real tenant**

Run:

```powershell
.\hr\src\scripts\Sync-HrSolutionSource.ps1 -TenantAlias caldova25156897 -SolutionUniqueName caldovahrfrontier
```

Expected: the script prints `Synced 'caldovahrfrontier' version 0.0.0.1 from https://hrfrontierdev.crm17.dynamics.com/ into <path>\hr\src\solutions\caldovahrfrontier`, and a `hr/src/solutions/caldovahrfrontier/` folder now exists containing (at minimum) `Other/Solution.xml` and `Other/Customizations.xml`.

- [ ] **Step 2: Verify the synced content matches the confirmed ground truth**

Run:

```powershell
$solutionXml = [xml](Get-Content -Raw hr/src/solutions/caldovahrfrontier/Other/Solution.xml)
$manifest = $solutionXml.ImportExportXml.SolutionManifest
"UniqueName: $($manifest.UniqueName)"
"Version: $($manifest.Version)"
"Publisher prefix: $($manifest.Publisher.CustomizationPrefix)"
"RootComponents count: $($manifest.RootComponents.ChildNodes.Count)"
```

Expected: `UniqueName: caldovahrfrontier`, `Version: 0.0.0.1`, `Publisher prefix: calhr`, `RootComponents count: 0` — matching the ground truth recorded in the design spec exactly.

- [ ] **Step 3: Confirm no secrets or environment-specific zip made it into the tracked folder**

Run:

```powershell
Get-ChildItem hr/src/solutions/caldovahrfrontier -Recurse -Filter *.zip
Select-String -Path (Get-ChildItem hr/src/solutions/caldovahrfrontier -Recurse -File) -Pattern 'client[_-]?secret|password' -ErrorAction SilentlyContinue
```

Expected: no output from either command.

- [ ] **Step 4: Commit the synced solution source**

```bash
git add hr/src/solutions/caldovahrfrontier/
git commit -m "feat: commit the Tenant 1 caldovahrfrontier solution foundation

Synced from https://hrfrontierdev.crm17.dynamics.com/ via
hr/src/scripts/Sync-HrSolutionSource.ps1. Version 0.0.0.1, publisher
prefix calhr, no Dataverse tables or Copilot Studio agent artefacts yet
— this is the empty foundation the next sprint builds on."
```

- [ ] **Step 5: Run the full validation suite one final time**

Run:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$paths = @(
  '.github/cli/tests/WorkflowContract.Tests.ps1'
  '.github/cli/tests/RepositorySafety.Tests.ps1'
  'infra/tests/pester'
  'hr/tests/pester'
)
Invoke-Pester -Path $paths -Output Detailed -CI
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild
git diff --check origin/main...HEAD
```

Expected: all Pester tests pass, both validators pass, and the whitespace check is clean.
