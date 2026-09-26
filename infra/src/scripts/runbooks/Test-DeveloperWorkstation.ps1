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

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $scriptDirectory '..\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $moduleManifestPath -Force

function Get-ObjectPropertyNames {
    param([Parameter(Mandatory)][object]$InputObject)

    @($InputObject.PSObject.Properties | ForEach-Object Name)
}

function Assert-ExactPropertySet {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string[]]$ExpectedProperties,
        [Parameter(Mandatory)][string]$Context
    )

    $actual = @(Get-ObjectPropertyNames -InputObject $InputObject)
    if ($actual.Count -ne $ExpectedProperties.Count) {
        throw "$Context contains an unrecognized property."
    }
    for ($index = 0; $index -lt $ExpectedProperties.Count; $index++) {
        if ($actual[$index] -cne $ExpectedProperties[$index]) {
            throw "$Context contains an unrecognized property."
        }
    }
}

function Assert-Condition {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-WorkstationPolicy {
    param([Parameter(Mandatory)][object]$Policy)

    Assert-ExactPropertySet -InputObject $Policy -Context 'Workstation policy root' -ExpectedProperties @(
        '$schema', 'schemaVersion', 'platform', 'interactiveAuthentication', 'tools',
        'azureCliExtensions', 'vsCodeExtensions', 'repositoryAssets', 'allowedActions'
    )
    Assert-Condition ([string]$Policy.schemaVersion -ceq '1.0') 'Workstation policy schemaVersion must be exactly 1.0.'

    Assert-ExactPropertySet -InputObject $Policy.platform -Context 'Workstation policy platform' -ExpectedProperties @(
        'productName', 'minimumBuild'
    )
    Assert-Condition ([string]$Policy.platform.productName -ceq 'Windows 11') 'Workstation policy platform productName must be Windows 11.'
    Assert-Condition ([int]$Policy.platform.minimumBuild -ge 22000) 'Workstation policy platform minimumBuild is not supported.'

    Assert-ExactPropertySet -InputObject $Policy.interactiveAuthentication -Context 'Workstation policy interactive authentication' -ExpectedProperties @(
        'executionHost', 'allowUnattendedExecution', 'allowOidcWorkloadIdentity',
        'allowCredentialParameters', 'methods'
    )
    Assert-Condition ([string]$Policy.interactiveAuthentication.executionHost -ceq 'InteractiveWindows11PowerShell') 'Workstation policy executionHost is not supported.'
    Assert-Condition (-not [bool]$Policy.interactiveAuthentication.allowUnattendedExecution) 'Workstation policy must refuse unattended execution.'
    Assert-Condition (-not [bool]$Policy.interactiveAuthentication.allowOidcWorkloadIdentity) 'Workstation policy must refuse OIDC workload identity.'
    Assert-Condition (-not [bool]$Policy.interactiveAuthentication.allowCredentialParameters) 'Workstation policy must refuse credential parameters.'

    foreach ($method in @($Policy.interactiveAuthentication.methods)) {
        Assert-ExactPropertySet -InputObject $method -Context 'Workstation policy interactive authentication method' -ExpectedProperties @(
            'service', 'mode', 'loginCommand', 'readBackCommand', 'cleanupCommands'
        )
    }

    $expectedToolOrder = @(
        'PowerShell7', 'WindowsPowerShell', 'Git', 'VisualStudioCode', 'GitHubCli',
        'AzureCli', 'AzureDeveloperCli', 'PowerPlatformCli', 'Bicep', 'Pester',
        'GitHubCopilotCli'
    )
    Assert-Condition (@($Policy.tools).Count -eq $expectedToolOrder.Count) 'Workstation policy tools allowlist is not complete.'
    for ($toolIndex = 0; $toolIndex -lt $expectedToolOrder.Count; $toolIndex++) {
        $tool = $Policy.tools[$toolIndex]
        Assert-ExactPropertySet -InputObject $tool -Context "Workstation policy tool $toolIndex" -ExpectedProperties @(
            'id', 'command', 'versionArguments', 'versionPolicy', 'installDisposition', 'install', 'reference'
        )
        Assert-Condition ([string]$tool.id -ceq $expectedToolOrder[$toolIndex]) "Workstation policy tool order is not reviewed at index $toolIndex."

        if ((Get-ObjectPropertyNames -InputObject $tool.versionPolicy) -ceq @('mode')) {
            $null = $null
        }
        Assert-ExactPropertySet -InputObject $tool.versionPolicy -Context "Workstation policy tool $($tool.id) versionPolicy" -ExpectedProperties $(
            if ([string]$tool.versionPolicy.mode -ceq 'Exact') { @('mode', 'value') } else { @('mode') }
        )

        $installExpected = switch ([string]$tool.install.kind) {
            'None' { @('kind') }
            'WinGet' { @('kind', 'source', 'packageId', 'scope') }
            'AzureCliComponent' { @('kind', 'arguments') }
            'PowerShellGallery' { @('kind', 'repository', 'moduleName', 'requiredVersion', 'scope') }
            default { throw "Workstation policy tool $($tool.id) install kind is not supported." }
        }
        Assert-ExactPropertySet -InputObject $tool.install -Context "Workstation policy tool $($tool.id) install" -ExpectedProperties $installExpected
    }

    $expectedAzureCliExtensions = @('azure-devops')
    Assert-Condition (@($Policy.azureCliExtensions).Count -eq $expectedAzureCliExtensions.Count) 'Workstation policy Azure CLI extensions allowlist is not complete.'
    for ($extensionIndex = 0; $extensionIndex -lt $expectedAzureCliExtensions.Count; $extensionIndex++) {
        $extension = $Policy.azureCliExtensions[$extensionIndex]
        Assert-ExactPropertySet -InputObject $extension -Context "Workstation policy Azure CLI extension $extensionIndex" -ExpectedProperties @(
            'name', 'versionPolicy', 'installDisposition', 'reference'
        )
        Assert-Condition ([string]$extension.name -ceq $expectedAzureCliExtensions[$extensionIndex]) 'Workstation policy Azure CLI extension order is not reviewed.'
        Assert-ExactPropertySet -InputObject $extension.versionPolicy -Context "Workstation policy Azure CLI extension $($extension.name) versionPolicy" -ExpectedProperties @('mode')
    }

    $expectedVsCodeExtensions = @(
        'ms-vscode.PowerShell', 'ms-azuretools.vscode-bicep', 'ms-azuretools.azure-dev',
        'microsoft-IsvExpTools.powerplatform-vscode', 'GitHub.copilot'
    )
    Assert-Condition (@($Policy.vsCodeExtensions).Count -eq $expectedVsCodeExtensions.Count) 'Workstation policy VS Code extensions allowlist is not complete.'
    for ($extensionIndex = 0; $extensionIndex -lt $expectedVsCodeExtensions.Count; $extensionIndex++) {
        $extension = $Policy.vsCodeExtensions[$extensionIndex]
        Assert-ExactPropertySet -InputObject $extension -Context "Workstation policy VS Code extension $extensionIndex" -ExpectedProperties @(
            'id', 'installDisposition'
        )
        Assert-Condition ([string]$extension.id -ceq $expectedVsCodeExtensions[$extensionIndex]) 'Workstation policy VS Code extension order is not reviewed.'
    }

    $expectedAssets = @(
        @{ kind = 'Skills'; path = '.github/skills'; expected = 'Present'; installDisposition = 'VerifyOnly' }
        @{ kind = 'Agents'; path = '.github/agents'; expected = 'Present'; installDisposition = 'VerifyOnly' }
        @{ kind = 'Plugins'; path = '.github/plugins'; expected = 'Absent'; installDisposition = 'VerifyOnly' }
    )
    Assert-Condition (@($Policy.repositoryAssets).Count -eq $expectedAssets.Count) 'Workstation policy repository assets allowlist is not complete.'
    for ($assetIndex = 0; $assetIndex -lt $expectedAssets.Count; $assetIndex++) {
        $asset = $Policy.repositoryAssets[$assetIndex]
        Assert-ExactPropertySet -InputObject $asset -Context "Workstation policy repository asset $assetIndex" -ExpectedProperties @(
            'kind', 'path', 'expected', 'installDisposition'
        )
        foreach ($name in @('kind', 'path', 'expected', 'installDisposition')) {
            Assert-Condition ([string]$asset.$name -ceq [string]$expectedAssets[$assetIndex].$name) 'Workstation policy repository asset order is not reviewed.'
        }
    }

    $allowedActions = @($Policy.allowedActions)
    Assert-Condition (($allowedActions -join '|') -ceq 'WinGetInstallExact|InstallPesterExact|InstallBicepComponent|InstallAzureCliExtensionExact|InstallVsCodeExtensionExact') 'Workstation policy allowedActions allowlist is not supported.'
}

function Get-DefaultInteractiveHostState {
    $reasons = [Collections.Generic.List[string]]::new()

    if (-not [Environment]::UserInteractive) {
        [void]$reasons.Add('Environment.UserInteractive is false')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:CI)) {
        [void]$reasons.Add('CI environment variable is set')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_ACTIONS)) {
        [void]$reasons.Add('GITHUB_ACTIONS environment variable is set')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ACTIONS_ID_TOKEN_REQUEST_URL)) {
        [void]$reasons.Add('ACTIONS_ID_TOKEN_REQUEST_URL environment variable is set')
    }
    $senderInfo = Get-Variable -Name PSSenderInfo -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $senderInfo) {
        [void]$reasons.Add('PowerShell remoting is active')
    }
    if ($null -ne $Host.Runspace -and $null -ne $Host.Runspace.ConnectionInfo) {
        [void]$reasons.Add('PowerShell remoting is active')
    }

    [pscustomobject]@{
        isInteractive = ($reasons.Count -eq 0)
        reason = $(if ($reasons.Count -eq 0) { 'InteractiveWindows11PowerShell' } else { $reasons -join '; ' })
    }
}

function Get-DefaultPlatformState {
    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
    $productName = [string]$operatingSystem.Caption
    if ($productName -match 'Windows 11') {
        $productName = 'Windows 11'
    }
    [pscustomobject]@{
        productName = $productName
        build = [int]$operatingSystem.BuildNumber
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    $result = & $Runner $FilePath $ArgumentList
    if ($null -eq $result) {
        return [pscustomobject]@{ exitCode = 1; stdout = @(); stderr = @('runner returned no result') }
    }

    $exitCode = 1
    if ($result.PSObject.Properties.Name -contains 'exitCode') {
        $exitCode = [int]$result.exitCode
    }

    [pscustomobject]@{
        exitCode = $exitCode
        stdout = @($result.stdout | ForEach-Object { [string]$_ })
        stderr = @($result.stderr | ForEach-Object { [string]$_ })
    }
}

function New-DefaultNativeCommandRunner {
    {
        param([string]$FilePath, [string[]]$ArgumentList)

        $output = @(& $FilePath @ArgumentList 2>&1 | ForEach-Object { $_.ToString() })
        [pscustomobject]@{
            exitCode = $(if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 })
            stdout = $output
            stderr = @()
        }
    }.GetNewClosure()
}

function New-DefaultCommandResolver {
    {
        param($name)
        @(Get-Command $name -All -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object Source)
    }.GetNewClosure()
}

function New-DefaultFileIdentityProvider {
    {
        param($path)
        [pscustomobject]@{
            path = [IO.Path]::GetFullPath($path)
            sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        }
    }.GetNewClosure()
}

function New-ManualItem {
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string]$TargetId,
        [Parameter(Mandatory)][string]$Condition,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Diagnostic,
        [Parameter(Mandatory)][string]$Recovery
    )

    [pscustomobject][ordered]@{
        service = $Service
        targetId = $TargetId
        condition = $Condition
        owner = $Owner
        diagnostic = $Diagnostic
        recovery = $Recovery
    }
}

function Resolve-ExecutableIdentity {
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [Parameter(Mandatory)][scriptblock]$Resolver,
        [Parameter(Mandatory)][scriptblock]$IdentityProvider
    )

    $candidates = @(& $Resolver $CommandName)
    if ($candidates.Count -eq 0) {
        return [pscustomobject][ordered]@{
            status = 'Missing'
            path = $null
            sha256 = $null
            diagnostic = "No executable resolves for $CommandName."
        }
    }

    $unique = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($candidate in $candidates) {
        try {
            $identity = & $IdentityProvider $candidate
            $canonicalPath = [IO.Path]::GetFullPath([string]$identity.path)
            $hash = [string]$identity.sha256
            $key = '{0}|{1}' -f $canonicalPath, $hash
            if (-not $unique.ContainsKey($key)) {
                $unique[$key] = [pscustomobject][ordered]@{
                    path = $canonicalPath
                    sha256 = $hash
                }
            }
        }
        catch {
            return [pscustomobject][ordered]@{
                status = 'Blocked'
                path = $null
                sha256 = $null
                diagnostic = "Executable identity could not be verified for ${CommandName}: $($_.Exception.Message)"
            }
        }
    }

    if ($unique.Count -gt 1) {
        return [pscustomobject][ordered]@{
            status = 'Blocked'
            path = $null
            sha256 = $null
            diagnostic = "Executable resolution for $CommandName is ambiguous."
        }
    }

    $resolved = $unique.Values | Select-Object -First 1
    [pscustomobject][ordered]@{
        status = 'Ready'
        path = [string]$resolved.path
        sha256 = [string]$resolved.sha256
        diagnostic = $null
    }
}

function Get-ObservedVersion {
    param(
        [Parameter(Mandatory)][string]$ToolId,
        [Parameter(Mandatory)][pscustomobject]$Result
    )

    $joined = ($Result.stdout -join "`n").Trim()
    switch ($ToolId) {
        'AzureCli' {
            try {
                $parsed = $joined | ConvertFrom-Json
                return [string]$parsed.'azure-cli'
            }
            catch {
                return $joined
            }
        }
        'PowerShell7' {
            $first = $Result.stdout | Select-Object -First 1
            if ($null -eq $first) { return $null }
            return ([string]$first).Trim()
        }
        'WindowsPowerShell' {
            $first = $Result.stdout | Select-Object -First 1
            if ($null -eq $first) { return $null }
            return ([string]$first).Trim()
        }
        'Pester' {
            $first = $Result.stdout | Select-Object -First 1
            if ($null -eq $first) { return $null }
            return ([string]$first).Trim()
        }
        'Bicep' {
            $match = [regex]::Match($joined, '(?i)version\s+([0-9]+(?:\.[0-9]+)+)')
            if ($match.Success) { return $match.Groups[1].Value }
            return $joined
        }
        default {
            $match = [regex]::Match($joined, '([0-9]+(?:\.[0-9]+)+)')
            if ($match.Success) { return $match.Groups[1].Value }
            return $joined
        }
    }
}

function Test-VersionPolicy {
    param(
        [AllowNull()][string]$ObservedVersion,
        [Parameter(Mandatory)][object]$VersionPolicy
    )

    if ([string]::IsNullOrWhiteSpace($ObservedVersion)) {
        return $false
    }

    switch ([string]$VersionPolicy.mode) {
        'Present' { return $true }
        'Exact' {
            if ([string]$VersionPolicy.value -ceq $ObservedVersion) {
                return $true
            }
            return $ObservedVersion.StartsWith(([string]$VersionPolicy.value + '.'), [StringComparison]::Ordinal)
        }
        default { return $false }
    }
}

function Get-ToolAssessment {
    param(
        [Parameter(Mandatory)][object]$ToolPolicy,
        [Parameter(Mandatory)][scriptblock]$Resolver,
        [Parameter(Mandatory)][scriptblock]$IdentityProvider,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $identity = Resolve-ExecutableIdentity -CommandName ([string]$ToolPolicy.command) -Resolver $Resolver -IdentityProvider $IdentityProvider
    if ($identity.status -ne 'Ready') {
        return [pscustomobject][ordered]@{
            id = [string]$ToolPolicy.id
            status = [string]$identity.status
            version = $null
            executablePath = $null
            executableSha256 = $null
            diagnostic = [string]$identity.diagnostic
            installDisposition = [string]$ToolPolicy.installDisposition
            reference = [string]$ToolPolicy.reference
        }
    }

    $native = Invoke-NativeCommand -Runner $Runner -FilePath $identity.path -ArgumentList @($ToolPolicy.versionArguments)
    $observedVersion = Get-ObservedVersion -ToolId ([string]$ToolPolicy.id) -Result $native
    $status = 'Ready'
    $diagnostic = $null
    if ($native.exitCode -ne 0) {
        $status = 'Blocked'
        $diagnostic = "Reviewed version probe failed for $($ToolPolicy.id)."
    }
    elseif (-not (Test-VersionPolicy -ObservedVersion $observedVersion -VersionPolicy $ToolPolicy.versionPolicy)) {
        $status = 'Blocked'
        $diagnostic = "Reviewed version policy failed for $($ToolPolicy.id)."
    }

    [pscustomobject][ordered]@{
        id = [string]$ToolPolicy.id
        status = $status
        version = $(if ($status -eq 'Ready') { $observedVersion } else { $null })
        executablePath = $(if ($status -eq 'Ready') { $identity.path } else { $null })
        executableSha256 = $(if ($status -eq 'Ready') { $identity.sha256 } else { $null })
        diagnostic = $diagnostic
        installDisposition = [string]$ToolPolicy.installDisposition
        reference = [string]$ToolPolicy.reference
    }
}

function Get-AzureCliExtensionAssessments {
    param(
        [Parameter(Mandatory)][object[]]$ExtensionPolicies,
        [Parameter(Mandatory)][object[]]$ToolAssessments,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $azureCli = $ToolAssessments | Where-Object id -eq 'AzureCli' | Select-Object -First 1
    if ($null -eq $azureCli -or $azureCli.status -ne 'Ready') {
        return @(
            foreach ($policy in $ExtensionPolicies) {
                [pscustomobject][ordered]@{
                    name = [string]$policy.name
                    status = 'Blocked'
                    version = $null
                    diagnostic = 'Azure CLI is not ready for extension read-back.'
                    installDisposition = [string]$policy.installDisposition
                    reference = [string]$policy.reference
                }
            }
        )
    }

    $native = Invoke-NativeCommand -Runner $Runner -FilePath $azureCli.executablePath -ArgumentList @('extension', 'list', '--output', 'json')
    $installed = @()
    if ($native.exitCode -eq 0) {
        try {
            $installed = @((($native.stdout -join "`n") | ConvertFrom-Json))
        }
        catch {
            $installed = @()
        }
    }

    @(
        foreach ($policy in $ExtensionPolicies) {
            $match = $installed | Where-Object { [string]$_.name -ceq [string]$policy.name } | Select-Object -First 1
            [pscustomobject][ordered]@{
                name = [string]$policy.name
                status = $(if ($native.exitCode -ne 0) { 'Blocked' } elseif ($null -eq $match) { 'Missing' } else { 'Ready' })
                version = $(if ($null -ne $match) { [string]$match.version } else { $null })
                diagnostic = $(if ($native.exitCode -ne 0) { 'Azure CLI extension list probe failed.' } elseif ($null -eq $match) { 'Reviewed Azure CLI extension is not installed.' } else { $null })
                installDisposition = [string]$policy.installDisposition
                reference = [string]$policy.reference
            }
        }
    )
}

function Get-VsCodeExtensionAssessments {
    param(
        [Parameter(Mandatory)][object[]]$ExtensionPolicies,
        [Parameter(Mandatory)][object[]]$ToolAssessments,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $code = $ToolAssessments | Where-Object id -eq 'VisualStudioCode' | Select-Object -First 1
    if ($null -eq $code -or $code.status -ne 'Ready') {
        return @(
            foreach ($policy in $ExtensionPolicies) {
                [pscustomobject][ordered]@{
                    id = [string]$policy.id
                    status = 'Blocked'
                    diagnostic = 'Visual Studio Code is not ready for extension read-back.'
                    installDisposition = [string]$policy.installDisposition
                }
            }
        )
    }

    $native = Invoke-NativeCommand -Runner $Runner -FilePath $code.executablePath -ArgumentList @('--list-extensions')
    $installed = @($native.stdout | ForEach-Object { [string]$_ })
    @(
        foreach ($policy in $ExtensionPolicies) {
            $present = @($installed | Where-Object { $_ -ceq [string]$policy.id }).Count -gt 0
            [pscustomobject][ordered]@{
                id = [string]$policy.id
                status = $(if ($native.exitCode -ne 0) { 'Blocked' } elseif ($present) { 'Ready' } else { 'Missing' })
                diagnostic = $(if ($native.exitCode -ne 0) { 'VS Code extension list probe failed.' } elseif ($present) { $null } else { 'Reviewed VS Code extension is not installed.' })
                installDisposition = [string]$policy.installDisposition
            }
        }
    )
}

function Get-RepositoryState {
    param(
        [Parameter(Mandatory)][string]$RepositoryRootPath,
        [Parameter(Mandatory)][object[]]$ToolAssessments,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $git = $ToolAssessments | Where-Object id -eq 'Git' | Select-Object -First 1
    $state = [ordered]@{
        root = $RepositoryRootPath
        sourceCommit = $null
        clean = $false
        diagnostic = 'Git is not ready for repository read-back.'
    }
    if ($null -eq $git -or $git.status -ne 'Ready') {
        return [pscustomobject]$state
    }

    $rootResult = Invoke-NativeCommand -Runner $Runner -FilePath $git.executablePath -ArgumentList @('rev-parse', '--show-toplevel')
    if ($rootResult.exitCode -ne 0) {
        $state.diagnostic = 'git rev-parse --show-toplevel failed.'
        return [pscustomobject]$state
    }

    $reportedRoot = [IO.Path]::GetFullPath((($rootResult.stdout | Select-Object -First 1).Trim()))
    if ($reportedRoot -cne $RepositoryRootPath) {
        $state.diagnostic = 'The reviewed repository root does not match the current Git working tree.'
        return [pscustomobject]$state
    }

    $headResult = Invoke-NativeCommand -Runner $Runner -FilePath $git.executablePath -ArgumentList @('rev-parse', 'HEAD')
    $statusResult = Invoke-NativeCommand -Runner $Runner -FilePath $git.executablePath -ArgumentList @('status', '--porcelain')
    if ($headResult.exitCode -ne 0 -or $statusResult.exitCode -ne 0) {
        $state.diagnostic = 'Git repository read-back failed.'
        return [pscustomobject]$state
    }

    $state.sourceCommit = (($headResult.stdout | Select-Object -First 1).Trim()).ToLowerInvariant()
    $state.clean = (@($statusResult.stdout).Count -eq 0)
    $state.diagnostic = $null
    [pscustomobject]$state
}

function Test-SkillsIntegrity {
    param([Parameter(Mandatory)][string]$RepositoryRootPath)

    $skillsRoot = Join-Path $RepositoryRootPath '.github\skills'
    $versionPath = Join-Path $skillsRoot 'SUPERPOWERS_VERSION'
    $manifestPath = Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'
    if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        return [pscustomobject]@{ status = 'Mismatch'; diagnostic = 'SUPERPOWERS_VERSION' }
    }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return [pscustomobject]@{ status = 'Mismatch'; diagnostic = 'SUPERPOWERS_SHA256SUMS' }
    }

    $lines = Get-Content -LiteralPath $manifestPath
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $match = [regex]::Match($line, '^(?<hash>[0-9a-f]{64})\s{2}(?<path>.+)$')
        if (-not $match.Success) {
            return [pscustomobject]@{ status = 'Mismatch'; diagnostic = 'SUPERPOWERS_SHA256SUMS' }
        }
        $relativePath = $match.Groups['path'].Value
        if ($relativePath.Contains('..') -or $relativePath.StartsWith('\', [StringComparison]::Ordinal)) {
            return [pscustomobject]@{ status = 'Mismatch'; diagnostic = $relativePath }
        }
        $fullPath = [IO.Path]::GetFullPath((Join-Path $skillsRoot $relativePath))
        if (-not $fullPath.StartsWith($skillsRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ status = 'Mismatch'; diagnostic = $relativePath }
        }
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            return [pscustomobject]@{ status = 'Mismatch'; diagnostic = $relativePath }
        }
        $actualHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -cne $match.Groups['hash'].Value) {
            return [pscustomobject]@{ status = 'Mismatch'; diagnostic = $relativePath }
        }
    }

    [pscustomobject]@{ status = 'Verified'; diagnostic = $null }
}

function Get-RepositoryAssetAssessments {
    param(
        [Parameter(Mandatory)][object[]]$AssetPolicies,
        [Parameter(Mandatory)][string]$RepositoryRootPath
    )

    $results = [Collections.Generic.List[object]]::new()
    foreach ($policy in $AssetPolicies) {
        $fullPath = Join-Path $RepositoryRootPath ([string]$policy.path).Replace('/', '\')
        $status = 'Missing'
        $diagnostic = $null
        if ([string]$policy.path -ceq '.github/skills') {
            if (Test-Path -LiteralPath $fullPath -PathType Container) {
                $integrity = Test-SkillsIntegrity -RepositoryRootPath $RepositoryRootPath
                $status = [string]$integrity.status
                $diagnostic = [string]$integrity.diagnostic
            }
        }
        elseif ([string]$policy.path -ceq '.github/agents') {
            $requiredAgentFiles = @(
                '.github\agents\docs-agent.agent.md',
                '.github\agents\cloud-solution-architect.agent.md',
                '.github\agents\ux-designer.agent.md'
            )
            if ((Test-Path -LiteralPath $fullPath -PathType Container) -and
                @($requiredAgentFiles | Where-Object {
                    Test-Path -LiteralPath (Join-Path $RepositoryRootPath $_) -PathType Leaf
                }).Count -eq $requiredAgentFiles.Count) {
                $status = 'Present'
            }
        }
        elseif ([string]$policy.path -ceq '.github/plugins') {
            $status = $(if (Test-Path -LiteralPath $fullPath) { 'UnexpectedPresent' } else { 'Absent' })
        }

        if ([string]$policy.path -ceq '.github/plugins' -and $status -eq 'Absent') {
            $diagnostic = $null
        }
        elseif ($status -eq 'Missing') {
            $diagnostic = [string]$policy.path
        }

        [void]$results.Add([pscustomobject][ordered]@{
            kind = [string]$policy.kind
            path = [string]$policy.path
            expected = [string]$policy.expected
            installDisposition = [string]$policy.installDisposition
            status = $status
            diagnostic = $diagnostic
        })
    }

    @($results)
}

if ([string]::IsNullOrWhiteSpace($PolicyPath)) {
    $PolicyPath = [IO.Path]::GetFullPath((Join-Path $scriptDirectory '..\..\config\runbooks\workstation-prerequisites.json'))
}
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $scriptDirectory '..\..\..\..'))
}
if ($null -eq $NativeCommandRunner) { $NativeCommandRunner = New-DefaultNativeCommandRunner }
if ($null -eq $CommandResolver) { $CommandResolver = New-DefaultCommandResolver }
if ($null -eq $FileIdentityProvider) { $FileIdentityProvider = New-DefaultFileIdentityProvider }
if ($null -eq $InteractiveHostProbe) {
    $interactiveState = Get-DefaultInteractiveHostState
}
else {
    $interactiveState = & $InteractiveHostProbe
}
if (-not [bool]$interactiveState.isInteractive) {
    throw 'This runbook requires an interactive Windows 11 PowerShell session.'
}

$platformState = $(if ($null -eq $PlatformProbe) { Get-DefaultPlatformState } else { & $PlatformProbe })
$productName = [string]$platformState.productName
$build = [int]$platformState.build
if ($productName -cne 'Windows 11' -or $build -lt 22000) {
    throw 'This runbook requires Windows 11 build 22000 or later.'
}

$policy = Get-Content -Raw -LiteralPath $PolicyPath | ConvertFrom-Json
Assert-WorkstationPolicy -Policy $policy
$policyDigest = Get-RunbookContentDigest -InputObject $policy

$packageManagerIdentity = Resolve-ExecutableIdentity -CommandName 'winget.exe' -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider
$toolAssessments = @(
    foreach ($tool in @($policy.tools)) {
        Get-ToolAssessment -ToolPolicy $tool -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner
    }
)
$azureCliExtensions = Get-AzureCliExtensionAssessments -ExtensionPolicies @($policy.azureCliExtensions) -ToolAssessments $toolAssessments -Runner $NativeCommandRunner
$vsCodeExtensions = Get-VsCodeExtensionAssessments -ExtensionPolicies @($policy.vsCodeExtensions) -ToolAssessments $toolAssessments -Runner $NativeCommandRunner
$repository = Get-RepositoryState -RepositoryRootPath ([IO.Path]::GetFullPath($RepositoryRoot)) -ToolAssessments $toolAssessments -Runner $NativeCommandRunner
$repositoryAssets = Get-RepositoryAssetAssessments -AssetPolicies @($policy.repositoryAssets) -RepositoryRootPath ([IO.Path]::GetFullPath($RepositoryRoot))

$manualItems = [Collections.Generic.List[object]]::new()
foreach ($tool in $toolAssessments) {
    if ($tool.status -eq 'Ready') { continue }
    [void]$manualItems.Add((New-ManualItem -Service 'WorkstationTooling' -TargetId $tool.id `
        -Condition $tool.status -Owner 'Workstation administrator' `
        -Diagnostic $(if ([string]::IsNullOrWhiteSpace($tool.diagnostic)) { "Reviewed tool $($tool.id) is not ready." } else { $tool.diagnostic }) `
        -Recovery "Reassess after the reviewed $($tool.id) prerequisite is restored."))
}
foreach ($extension in $azureCliExtensions) {
    if ($extension.status -eq 'Ready') { continue }
    [void]$manualItems.Add((New-ManualItem -Service 'AzureCliExtension' -TargetId $extension.name `
        -Condition $extension.status -Owner 'Workstation administrator' `
        -Diagnostic $extension.diagnostic -Recovery "Reassess after the reviewed Azure CLI extension $($extension.name) is restored." ))
}
foreach ($extension in $vsCodeExtensions) {
    if ($extension.status -eq 'Ready') { continue }
    [void]$manualItems.Add((New-ManualItem -Service 'VsCodeExtension' -TargetId $extension.id `
        -Condition $extension.status -Owner 'Workstation administrator' `
        -Diagnostic $extension.diagnostic -Recovery "Reassess after the reviewed VS Code extension $($extension.id) is restored." ))
}
foreach ($asset in $repositoryAssets) {
    $isExpected = (
        ($asset.path -ceq '.github/skills' -and $asset.status -eq 'Verified') -or
        ($asset.path -ceq '.github/agents' -and $asset.status -eq 'Present') -or
        ($asset.path -ceq '.github/plugins' -and $asset.status -eq 'Absent')
    )
    if ($isExpected) { continue }
    [void]$manualItems.Add((New-ManualItem -Service 'RepositoryAsset' -TargetId $asset.path `
        -Condition $asset.status -Owner 'Repository administrator' `
        -Diagnostic $(if ([string]::IsNullOrWhiteSpace($asset.diagnostic)) { "Repository asset $($asset.path) is not in the reviewed state." } else { $asset.diagnostic }) `
        -Recovery 'Restore the reviewed repository asset state, then reassess.' ))
}
if ($packageManagerIdentity.status -ne 'Ready') {
    [void]$manualItems.Add((New-ManualItem -Service 'PackageManager' -TargetId 'winget.exe' `
        -Condition $packageManagerIdentity.status -Owner 'Workstation administrator' `
        -Diagnostic $packageManagerIdentity.diagnostic `
        -Recovery 'Restore a unique reviewed WinGet executable before reassessment.' ))
}
if ([string]::IsNullOrWhiteSpace([string]$repository.sourceCommit)) {
    [void]$manualItems.Add((New-ManualItem -Service 'Repository' -TargetId 'GitWorkingTree' `
        -Condition 'Blocked' -Owner 'Repository administrator' `
        -Diagnostic $(if ([string]::IsNullOrWhiteSpace([string]$repository.diagnostic)) { 'Git repository read-back did not produce a reviewed source commit.' } else { [string]$repository.diagnostic }) `
        -Recovery 'Restore a reviewed Git working tree and reassess.' ))
}

$overallStatus = $(if ($manualItems.Count -eq 0) { 'Ready' } else { 'Blocked' })
$safeToolVersions = [ordered]@{}
if ($packageManagerIdentity.status -eq 'Ready') {
    $safeToolVersions['WinGet'] = $packageManagerIdentity.sha256
}
foreach ($tool in $toolAssessments | Where-Object { $_.status -eq 'Ready' -and -not [string]::IsNullOrWhiteSpace($_.version) }) {
    $safeToolVersions[$tool.id] = $tool.version
}
foreach ($extension in $azureCliExtensions | Where-Object { $_.status -eq 'Ready' -and -not [string]::IsNullOrWhiteSpace($_.version) }) {
    $safeToolVersions["AzureCliExtension:$($extension.name)"] = $extension.version
}

$platform = [pscustomobject][ordered]@{
    productName = $productName
    build = $build
    stableId = ('{0}\{1}' -f $env:COMPUTERNAME, $env:USERNAME)
    packageManager = [pscustomobject][ordered]@{
        executablePath = $(if ($packageManagerIdentity.status -eq 'Ready') { $packageManagerIdentity.path } else { $null })
        executableSha256 = $(if ($packageManagerIdentity.status -eq 'Ready') { $packageManagerIdentity.sha256 } else { $null })
    }
}

$stateProjection = [pscustomobject][ordered]@{
    schemaVersion = '1.0'
    policyDigest = $policyDigest
    platform = $platform
    repository = $repository
    tools = @($toolAssessments)
    azureCliExtensions = @($azureCliExtensions)
    vsCodeExtensions = @($vsCodeExtensions)
    repositoryAssets = @($repositoryAssets)
    manualItems = @($manualItems)
    overallStatus = $overallStatus
}
$assessmentDigest = Get-RunbookContentDigest -InputObject $stateProjection
$runId = [guid]::NewGuid()
$assessment = [pscustomobject][ordered]@{
    schemaVersion = '1.0'
    policyDigest = $policyDigest
    runId = $runId.ToString('D')
    assessedAtUtc = $NowUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    platform = $platform
    repository = $repository
    tools = @($toolAssessments)
    azureCliExtensions = @($azureCliExtensions)
    vsCodeExtensions = @($vsCodeExtensions)
    repositoryAssets = @($repositoryAssets)
    manualItems = @($manualItems)
    overallStatus = $overallStatus
    assessmentDigest = $assessmentDigest
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $safeDirectory = Resolve-RunbookReportPath -RunId $runId -Path $ReportPath -RepositoryRoot $RepositoryRoot
    [IO.Directory]::CreateDirectory($safeDirectory) | Out-Null
    Write-CanonicalJson -InputObject $assessment -Path (Join-Path $safeDirectory 'workstation-assessment.json') | Out-Null
    $evidence = ConvertTo-RunbookEvidenceRecord -RunId $runId -GeneratedAtUtc $NowUtc `
        -SourceCommit $(if ([string]::IsNullOrWhiteSpace([string]$assessment.repository.sourceCommit)) { ('0' * 40) } else { [string]$assessment.repository.sourceCommit }) `
        -AssessmentDigest $assessment.assessmentDigest -OperatorId $assessment.platform.stableId `
        -ShouldProcessDecision NotApplicable -Operation 'AssessWorkstation' `
        -Classification $(if ($assessment.overallStatus -eq 'Ready') { 'NoChange' } else { 'Blocked' }) `
        -Status $(if ($assessment.overallStatus -eq 'Ready') { 'Verified' } else { 'Failed' }) `
        -TargetId $assessment.platform.stableId -ToolVersions $safeToolVersions `
        -FinalContext ([pscustomobject]@{ status = 'InteractiveWindows11PowerShell' }) `
        -ManualItems $assessment.manualItems
    Write-CanonicalJson -InputObject $evidence -Path (Join-Path $safeDirectory 'workstation-evidence.json') | Out-Null
}

$assessment
