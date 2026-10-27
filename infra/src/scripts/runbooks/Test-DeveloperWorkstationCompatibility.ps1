[CmdletBinding()]
param(
    [string]$CompatibilityPath,
    [string]$PolicyPath,
    [string]$ReportPath,
    [Parameter(DontShow)] [scriptblock]$CommandResolver,
    [Parameter(DontShow)] [scriptblock]$NativeCommandRunner,
    [datetime]$NowUtc = [datetime]::UtcNow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$directory = $PSScriptRoot
. (Join-Path $directory 'WorkstationTools.ps1')
Import-Module (Join-Path $directory '..\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
if (-not $CompatibilityPath) { $CompatibilityPath = Join-Path $directory '..\..\config\runbooks\workstation-compatibility.json' }
if (-not $PolicyPath) { $PolicyPath = Join-Path $directory '..\..\config\runbooks\workstation-prerequisites.json' }
if ($null -eq $CommandResolver) { $CommandResolver = New-DefaultCommandResolver }
if ($null -eq $NativeCommandRunner) { $NativeCommandRunner = New-DefaultNativeCommandRunner }
$identityProvider = $null
$result = [ordered]@{
    schemaVersion = '1.0'; assessedAtUtc = $NowUtc.ToUniversalTime().ToString('o')
    status = 'Blocked'; policyAccepted = $false; diagnostic = $null
    components = @(); componentProof = $null
}
$owned = $null
$owner = [guid]::NewGuid().ToString('N')
$currentComponent = 'Contract'
$phase = 'RecordAndPolicyValidation'

try {
    $inputHashes = @((Get-FileHash -LiteralPath $CompatibilityPath).Hash, (Get-FileHash -LiteralPath $PolicyPath).Hash)
    $record = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText($CompatibilityPath))
    $policy = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText($PolicyPath))
    Assert-WorkstationCompatibilityRecord $record
    $record = ConvertTo-WorkstationCompatibilityModel $record
    Assert-WorkstationDeliveryPolicy $policy $record (Join-Path $directory '..\..\config\schemas\workstation-prerequisites.schema.json')
    $identityProvider = New-DefaultFileIdentityProvider -CompatibilityRecord $record
    if (-not [Environment]::Is64BitProcess -or [Environment]::OSVersion.Platform -ne 'Win32NT') {
        throw 'Windows X64 host required.'
    }
    $paths = @{
        PowerShell7 = Join-Path $env:ProgramFiles ('WindowsApps\Microsoft.PowerShell_' + ($record.components | Where-Object id -CEQ PowerShell7).version + '.0_x64__8wekyb3d8bbwe\pwsh.exe')
        WindowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Git = Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
        GitHubCli = Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe'
        AzureCli = Join-Path $env:ProgramFiles 'Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
        Bicep = Join-Path $env:USERPROFILE '.azure\bin\bicep.exe'
        PowerPlatformCli = Join-Path $env:USERPROFILE '.dotnet\tools\pac.exe'
    }
    $hosts = @{}
    $identities = @{}
    $dependencies = @{}
    $dependencyOwners = @{}
    $azureVersion = $null
    foreach ($component in $record.components) {
        $currentComponent = [string]$component.id
        $phase = 'InstalledSourceIdentity'
        $id = $currentComponent
        if ($id -eq 'Pester') {
            $hostModule = $hosts.WindowsPowerShell
            if ($hostModule.pester -cne $component.version -or $hostModule.moduleSha256 -cne $component.sha256 -or
                $hosts.PowerShell7.moduleSha256 -cne $component.sha256) { throw 'Exact module version/hash drift.' }
            $observed = $hostModule.pester
            $identity = [pscustomobject]@{ path = $hostModule.modulePath; sha256 = $hostModule.moduleSha256 }
            $dependencies[$hosts.PowerShell7.modulePath] = $component.sha256
            $dependencyOwners[$hosts.PowerShell7.modulePath] = $id
        } elseif ($id -eq 'azure-devops') {
            $metadata = Join-Path $env:USERPROFILE ('.azure\cliextensions\azure-devops\azure_devops-' + $component.version + '.dist-info\METADATA')
            if (-not (Test-Path -LiteralPath $metadata -PathType Leaf) -or
                (Get-FileHash -LiteralPath $metadata).Hash.ToLowerInvariant() -cne $component.sha256 -or
                $azureVersion.extensions.'azure-devops' -cne $component.version) { throw 'Installed extension source/version/hash unproven.' }
            $native = Invoke-NativeCommand $NativeCommandRunner $identities.AzureCli.path @('devops', '--help')
            $help = $native.stdout -join "`n"
            if ($native.exitCode -ne 0 -or $help -notmatch 'service-endpoint' -or $help -notmatch 'invoke') { throw 'Extension help capability unproven.' }
            $identity = [pscustomobject]@{ path = $metadata; sha256 = $component.sha256 }
            $observed = [string]$azureVersion.extensions.'azure-devops'
        } else {
            $tool = @($policy.tools | Where-Object id -CEQ $id)[0]
            $identity = Resolve-ExecutableIdentity $tool.command $CommandResolver $identityProvider
            if ($identity.status -ne 'Ready' -or $identity.path -ine $paths[$id] -or
                $identity.sha256 -cne $component.sha256) { throw 'Canonical executable/source/hash unproven.' }
            if ($id -ne 'AzureCli') { Assert-WorkstationX64Executable $identity.path }
            if ($id -in @('AzureCli', 'PowerPlatformCli')) {
                foreach ($payload in $component.payloads) {
                    if ($id -eq 'AzureCli') {
                        $payloadPath = [IO.Path]::GetFullPath((Join-Path (Split-Path $identity.path -Parent) '..\python.exe'))
                        Assert-WorkstationX64Executable $payloadPath
                    } else {
                        $packageVersion = $component.version -replace '\+.*$', ''
                        $packageRoot = Join-Path $env:USERPROFILE ('.dotnet\tools\.store\microsoft.powerapps.cli.tool\' +
                            $packageVersion + '\microsoft.powerapps.cli.tool\' + $packageVersion + '\tools\net8.0\any')
                        $payloadName = if ($payload.id -eq 'PacAssembly') { 'pac.dll' } else { 'SolutionPackagerLib.dll' }
                        $payloadPath = Join-Path $packageRoot $payloadName
                    }
                    if ((Get-FileHash -LiteralPath $payloadPath).Hash.ToLowerInvariant() -cne $payload.sha256) {
                        throw 'Principal payload source/hash changed before invocation.'
                    }
                    $dependencies[$payloadPath] = $payload.sha256
                    $dependencyOwners[$payloadPath] = $id
                }
            }
            $phase = 'ExactVersionParser'
            $native = Invoke-NativeCommand $NativeCommandRunner $identity.path @($tool.versionArguments)
            $observed = Get-ObservedVersion $id $native
            if ($native.exitCode -ne 0 -or $observed -cne $component.version) { throw 'Exact version/parser capability unproven.' }
            $phase = 'DeclaredLocalCapabilities'
            switch ($id) {
                { $_ -in @('PowerShell7', 'WindowsPowerShell') } {
                    $hostProbe = Get-WorkstationHostProbeCommand -PesterRecord (
                        @($record.components | Where-Object id -CEQ Pester)[0]) -HostId $id
                    $native = Invoke-NativeCommand $NativeCommandRunner $identity.path @('-NoLogo', '-NoProfile', '-Command', $hostProbe)
                    if ($native.exitCode -ne 0) { throw 'Host/module capability failed.' }
                    $hostState = ($native.stdout -join "`n") | ConvertFrom-Json
                    if (-not $hostState.windows -or $hostState.arch -cne 'X64' -or $hostState.build -lt 22000 -or
                        $hostState.ps -cne $component.version -or $hostState.pester -cne '5.7.1' -or
                        ($id -eq 'PowerShell7' -and -not $hostState.compat)) { throw 'Windows host compatibility unproven.' }
                    $hosts[$id] = $hostState
                }
                'Git' {
                    $help = Invoke-NativeCommand $NativeCommandRunner $identity.path @('worktree', '-h')
                    if ($help.exitCode -ne 0 -or ($help.stdout -join "`n") -notmatch 'worktree move') { throw 'Worktree help unproven.' }
                }
                'GitHubCli' {
                    $help = Invoke-NativeCommand $NativeCommandRunner $identity.path @('repo', 'view', '--help')
                    if ($help.exitCode -ne 0 -or ($help.stdout -join "`n") -notmatch '--json') { throw 'Repository JSON help unproven.' }
                }
                'AzureCli' {
                    $azureVersion = ($native.stdout -join "`n") | ConvertFrom-Json
                    if ($azureVersion.'azure-cli-core' -cne $component.version) { throw 'Azure CLI core version mismatch.' }
                }
                'Bicep' {
                    $help = Invoke-NativeCommand $NativeCommandRunner $identity.path @('build', '--help')
                    $text = $help.stdout -join "`n"
                    if ($help.exitCode -ne 0 -or $text -notmatch '--stdout' -or $text -notmatch '--no-restore' -or $text -notmatch '--outfile') {
                        throw 'Standalone Bicep build help unproven.'
                    }
                }
                'PowerPlatformCli' {
                    foreach ($verb in @('pack', 'unpack')) {
                        $help = Invoke-NativeCommand $NativeCommandRunner $identity.path @('solution', $verb, '--help')
                        if (-not (Test-WorkstationPacHelp $help $verb)) { throw 'PAC usage/diagnostic parser unproven.' }
                    }
                }
            }
        }
        $identities[$id] = $identity
        $result.components += [pscustomobject]@{
            id = $id; version = $observed; source = $component.source; architecture = 'X64'
            canonicalPath = $identity.path; sha256 = $identity.sha256
            status = $(if ($id -eq 'PowerPlatformCli') { 'PendingFunctionalProof' } else { 'Proven' })
        }
    }
    $currentComponent = 'DeclaredWebResourceRoundTrip'
    $phase = 'NativeComponentReferencePayloadPreservation'
    $ancestor = Get-Item -LiteralPath $env:TEMP
    while ($null -ne $ancestor) {
        if (Test-Path -LiteralPath (Join-Path $ancestor.FullName '.git')) { throw 'Probe workspace must be external to Git worktrees.' }
        if (($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Unreviewed workspace reparse point.' }
        $ancestor = $ancestor.Parent
    }
    $owned = Join-Path $env:TEMP ('wscomp-' + $owner.Substring(0, 8))
    if (Test-Path -LiteralPath $owned) { throw 'Probe workspace already exists.' }
    if ((Join-Path $owned 'seed\WebResources\syn_probe.html.data.xml').Length -ge 240) { throw 'Probe path budget exceeded.' }
    New-Item -ItemType Directory -Path $owned | Out-Null
    [IO.File]::WriteAllText((Join-Path $owned 'owner.txt'), $owner)
    $fixture = [IO.Path]::GetFullPath((Join-Path $directory '..\..\..\tests\fixtures\workstation'))
    $result.componentProof = Invoke-WorkstationComponentProof $identities.PowerPlatformCli.path $fixture $owned $NativeCommandRunner
    ($result.components | Where-Object id -CEQ PowerPlatformCli).status = 'Proven'
    foreach ($component in $record.components) {
        $currentComponent = [string]$component.id
        $phase = 'PostProbeIdentityDrift'
        if ((Get-FileHash -LiteralPath $identities[$component.id].path).Hash.ToLowerInvariant() -cne $component.sha256) {
            throw 'Executable/module/extension changed during assessment.'
        }
        foreach ($path in $dependencies.Keys) {
            $currentComponent = [string]$dependencyOwners[$path]
            $phase = 'PostProbePrincipalPayloadDrift'
            if ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $dependencies[$path]) {
                throw 'Principal source payload changed during assessment.'
            }
            foreach ($installation in @($record.components | Where-Object id -CEQ Pester)[0].installations) {
                $currentComponent = 'Pester'
                $phase = 'PostProbeModuleSourceDrift'
                $null = Assert-WorkstationPesterInstallation $installation
            }
        }
        $currentComponent = 'Contract'
        $phase = 'PostProbePolicyDrift'
    }
    if ((Get-FileHash -LiteralPath $CompatibilityPath).Hash -cne $inputHashes[0] -or
        (Get-FileHash -LiteralPath $PolicyPath).Hash -cne $inputHashes[1]) { throw 'Policy or record changed during assessment.' }
    $result.status = 'NoChange'
    $result.policyAccepted = $true
} catch {
    $result.diagnostic = 'Blocked:' + $currentComponent + ':' + $phase
    $failedId = if ($currentComponent -eq 'DeclaredWebResourceRoundTrip') { 'PowerPlatformCli' } else { $currentComponent }
    $failed = @($result.components | Where-Object id -CEQ $failedId)
    if ($failed.Count -eq 1) { $failed[0].status = 'Blocked' }
    elseif ($failedId -ne 'Contract') {
        $result.components += [pscustomobject]@{ id = $failedId; status = 'Blocked' }
    }
} finally {
    if ($null -ne $owned -and (Test-Path -LiteralPath $owned)) {
        $marker = Join-Path $owned 'owner.txt'
        $links = @(Get-ChildItem -LiteralPath $owned -Recurse -Force | Where-Object {
            ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
        })
        if ((Test-Path -LiteralPath $marker) -and [IO.File]::ReadAllText($marker) -ceq $owner -and $links.Count -eq 0) {
            Remove-Item -LiteralPath $owned -Recurse -Force
        } else {
            $result.status = 'Blocked'; $result.policyAccepted = $false; $result.diagnostic = 'Blocked:OwnedProbeCleanup'
        }
    }
}
if ($ReportPath) {
    $repo = [IO.Path]::GetFullPath((Join-Path $directory '..\..\..\..'))
    $safe = Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) -Path $ReportPath -RepositoryRoot $repo
    New-Item -ItemType Directory -Path $safe -Force | Out-Null
    Write-CanonicalJson -InputObject ([pscustomobject]$result) -Path (Join-Path $safe 'workstation-compatibility.json') | Out-Null
}
[pscustomobject]$result
if ($result.status -ne 'NoChange') { exit 1 }
