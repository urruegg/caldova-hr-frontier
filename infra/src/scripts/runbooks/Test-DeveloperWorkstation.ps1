[CmdletBinding()]
param(
    [guid]$RunId,
    [string]$EvidenceRoot,
    [string]$CompatibilityPath,
    [string]$ExpectedSourceCommit,
    [string]$RepositoryIdentity,
    [string]$ExpectedMachineId,
    [string]$WorktreeRoot,
    [string]$TenantConfigurationPath,
    [string]$TenantStatePath,
    [string]$BackupManifestPath,
    [string]$RestoreRoot,
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
        '$schema', 'schemaVersion', 'compatibilityRecord', 'platform', 'interactiveAuthentication', 'tools',
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
        Assert-ExactPropertySet -InputObject $extension.versionPolicy -Context "Workstation policy Azure CLI extension $($extension.name) versionPolicy" -ExpectedProperties @('mode', 'value')
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

function Get-ToolAssessment {
    param(
        [Parameter(Mandatory)][object]$ToolPolicy,
        [Parameter(Mandatory)][scriptblock]$Resolver,
        [Parameter(Mandatory)][scriptblock]$IdentityProvider,
        [Parameter(Mandatory)][scriptblock]$Runner,
        [string]$ExpectedSha256
    )

    $identity = Resolve-ExecutableIdentity -CommandName ([string]$ToolPolicy.command) -Resolver $Resolver -IdentityProvider $IdentityProvider
    if ($ExpectedSha256 -and $identity.sha256 -cne $ExpectedSha256) {
        $identity = [pscustomobject]@{ status = 'Blocked'; diagnostic = 'Reviewed executable hash mismatch.' }
    }
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

function Get-PackageManagerAssessment {
    param(
        [Parameter(Mandatory)][scriptblock]$Resolver,
        [Parameter(Mandatory)][scriptblock]$IdentityProvider,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $identity = Resolve-ExecutableIdentity -CommandName 'winget.exe' -Resolver $Resolver -IdentityProvider $IdentityProvider
    if ($identity.status -ne 'Ready') {
        return [pscustomobject][ordered]@{
            status = [string]$identity.status
            path = $null
            sha256 = $null
            version = $null
            diagnostic = [string]$identity.diagnostic
        }
    }

    $native = Invoke-NativeCommand -Runner $Runner -FilePath $identity.path -ArgumentList @('--version')
    $observedVersion = Get-ObservedVersion -ToolId 'WinGet' -Result $native
    if ($native.exitCode -ne 0 -or [string]::IsNullOrWhiteSpace($observedVersion)) {
        return [pscustomobject][ordered]@{
            status = 'Blocked'
            path = $null
            sha256 = $null
            version = $null
            diagnostic = 'Reviewed WinGet version probe failed.'
        }
    }

    [pscustomobject][ordered]@{
        status = 'Ready'
        path = [string]$identity.path
        sha256 = [string]$identity.sha256
        version = [string]$observedVersion
        diagnostic = $null
    }
}

function Get-AzureCliExtensionAssessments {
    param(
        [Parameter(Mandatory)][object[]]$ExtensionPolicies,
        [Parameter(Mandatory)][object[]]$ToolAssessments,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $azureCli = $ToolAssessments | Where-Object { [string]$_.id -ceq 'AzureCli' } | Select-Object -First 1
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
                status = $(if ($native.exitCode -ne 0) { 'Blocked' } elseif ($null -eq $match) { 'Missing' }
                    elseif (-not (Test-VersionPolicy -ObservedVersion ([string]$match.version) -VersionPolicy $policy.versionPolicy)) { 'Blocked' } else { 'Ready' })
                version = $(if ($null -ne $match) { [string]$match.version } else { $null })
                diagnostic = $(if ($native.exitCode -ne 0) { 'Azure CLI extension list probe failed.' } elseif ($null -eq $match) { 'Reviewed Azure CLI extension is not installed.' }
                    elseif (-not (Test-VersionPolicy -ObservedVersion ([string]$match.version) -VersionPolicy $policy.versionPolicy)) { 'Reviewed extension version mismatch.' } else { $null })
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

    $code = $ToolAssessments | Where-Object { [string]$_.id -ceq 'VisualStudioCode' } | Select-Object -First 1
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

    $git = $ToolAssessments | Where-Object { [string]$_.id -ceq 'Git' } | Select-Object -First 1
    $state = [ordered]@{
        root = $RepositoryRootPath
        sourceCommit = $null
        clean = $false
        diagnostic = 'Git is not ready for repository read-back.'
    }
    if ($null -eq $git -or $git.status -ne 'Ready') {
        return [pscustomobject]$state
    }

    $rootResult = Invoke-NativeCommand -Runner $Runner -FilePath $git.executablePath -ArgumentList @('-C', $RepositoryRootPath, 'rev-parse', '--show-toplevel')
    if ($rootResult.exitCode -ne 0) {
        $state.diagnostic = 'git rev-parse --show-toplevel failed.'
        return [pscustomobject]$state
    }

    $expectedRoot = [IO.Path]::GetFullPath($RepositoryRootPath).TrimEnd('\')
    $reportedRoot = [IO.Path]::GetFullPath((($rootResult.stdout | Select-Object -First 1).Trim())).TrimEnd('\')
    if (-not $reportedRoot.Equals($expectedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $state.diagnostic = 'The reviewed repository root does not match the current Git working tree.'
        return [pscustomobject]$state
    }

    $headResult = Invoke-NativeCommand -Runner $Runner -FilePath $git.executablePath -ArgumentList @('-C', $RepositoryRootPath, 'rev-parse', 'HEAD')
    $statusResult = Invoke-NativeCommand -Runner $Runner -FilePath $git.executablePath -ArgumentList @('-C', $RepositoryRootPath, 'status', '--porcelain')
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
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
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
        $normalizedRelativePath = $fullPath.Substring($skillsRoot.TrimEnd('\').Length + 1).Replace('\', '/')
        if (-not $seenPaths.Add($normalizedRelativePath)) {
            return [pscustomobject]@{ status = 'Mismatch'; diagnostic = 'SUPERPOWERS_SHA256SUMS' }
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

. (Join-Path $scriptDirectory 'WorkstationTools.ps1')

function Resolve-WorkstationBoundPath {
    param([string]$Path)
    try {
        if ([string]::IsNullOrWhiteSpace($Path) -or
            [Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Path) -or
            $Path -match '(^|[\\/])\.([\\/] |$)|[\\/]\.[\\/]' -or $Path.EndsWith('\.')) { throw 'Path' }
        $provider = $null
        $drive = $null
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
        if ($provider.Name -cne 'FileSystem' -or $full -notmatch '^[A-Za-z]:\\' -or
            $full.Substring(2).Contains(':')) { throw 'Path' }
        [IO.Path]::GetFullPath($full).TrimEnd('\')
    } catch { throw 'Workstation.Context.Path' }
}

function Assert-WorkstationBoundPhysicalPath {
    param([string]$Path, [switch]$Directory, [switch]$File, [switch]$Optional)
    try {
        $cursor = $Path
        if (-not (Test-Path -LiteralPath $Path)) {
            if (-not $Optional) { throw 'Missing' }
        } else {
            $item = Get-Item -LiteralPath $Path -Force
            if (($Directory -and $item -isnot [IO.DirectoryInfo]) -or
                ($File -and $item -isnot [IO.FileInfo])) { throw 'Type' }
        }
        while ($cursor) {
            if (Test-Path -LiteralPath $cursor) {
                $item = Get-Item -LiteralPath $cursor -Force
                if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Alias' }
                if ($item.FullName.TrimEnd('\') -ine $cursor.TrimEnd('\')) { throw 'Alias' }
            }
            $parent = Split-Path -Parent $cursor
            if ($parent -eq $cursor) { break }
            $cursor = $parent
        }
    } catch { throw 'Workstation.Context.PhysicalPath' }
}

function Invoke-BoundWorkstationAssessment {
    function Test-RunbookPathWithin {
        param([string]$Path, [string]$Root)
        & (Get-WorkstationBootstrapModule) {
            param($candidate, $boundary)
            Test-RunbookPathWithin -Path $candidate -Root $boundary
        } $Path $Root
    }
    $required = @('RunId','EvidenceRoot','PolicyPath','CompatibilityPath','RepositoryRoot','ExpectedSourceCommit',
        'RepositoryIdentity','ExpectedMachineId','WorktreeRoot','TenantConfigurationPath','TenantStatePath','BackupManifestPath','RestoreRoot')
    foreach ($name in $required) {
        if (-not $PSBoundParameters.ContainsKey($name) -and -not $script:boundInputs.ContainsKey($name)) {
            throw 'Workstation.Context.Required'
        }
    }
    if ($RunId -eq [guid]::Empty -or $ExpectedSourceCommit -cnotmatch '^[0-9a-f]{40}$' -or
        $RepositoryIdentity -cnotmatch '^[0-9a-f]{64}$' -or [string]::IsNullOrWhiteSpace($ExpectedMachineId)) {
        throw 'Workstation.Context.Identity'
    }
    $paths = @{}
    foreach ($name in @('RepositoryRoot','WorktreeRoot','EvidenceRoot','PolicyPath','CompatibilityPath',
        'TenantConfigurationPath','TenantStatePath','BackupManifestPath','RestoreRoot')) {
        $paths[$name] = Resolve-WorkstationBoundPath (Get-Variable -Name $name -ValueOnly)
    }
    $repo = $paths.RepositoryRoot
    $target = $paths.WorktreeRoot
    $tenantRoot = Join-Path $repo 'infra\src\config\tenants'
    if ($paths.PolicyPath -ine (Join-Path $repo 'infra\src\config\runbooks\workstation-prerequisites.json') -or
        $paths.CompatibilityPath -ine (Join-Path $repo 'infra\src\config\runbooks\workstation-compatibility.json') -or
        $paths.TenantConfigurationPath -ine (Join-Path $tenantRoot 'tenant1.local.psd1') -or
        $paths.TenantStatePath -ine (Join-Path $tenantRoot 'tenant1.state.local.json')) {
        throw 'Workstation.Context.InputBoundary'
    }
    $sourceParent = Split-Path -Parent $repo
    $context = if ((Split-Path -Leaf $sourceParent) -ieq 'wt') { Split-Path -Parent $sourceParent } else { $sourceParent }
    $sibling = Join-Path $context 'wt'
    if ((Split-Path -Parent $target) -ine $sibling -or
        (Split-Path -Leaf $target) -cnotmatch '^[a-zA-Z0-9][a-zA-Z0-9-]{0,119}$' -or
        ($target -ine $repo -and (Test-RunbookPathWithin -Path $target -Root $repo))) {
        throw 'Workstation.Context.WorktreeBoundary'
    }
    foreach ($external in @($paths.EvidenceRoot, (Split-Path -Parent $paths.BackupManifestPath), $paths.RestoreRoot)) {
        if ((Test-RunbookPathWithin -Path $external -Root $repo) -or
            (Test-RunbookPathWithin -Path $external -Root $sibling) -or
            (Test-RunbookPathWithin -Path $repo -Root $external) -or
            (Test-RunbookPathWithin -Path $sibling -Root $external)) { throw 'Workstation.Context.ExternalBoundary' }
    }
    if ((Test-RunbookPathWithin -Path $paths.BackupManifestPath -Root $paths.EvidenceRoot) -or
        (Test-RunbookPathWithin -Path $paths.EvidenceRoot -Root (Split-Path -Parent $paths.BackupManifestPath))) {
        throw 'Workstation.Context.ExternalBoundary'
    }
    foreach ($other in @($paths.EvidenceRoot, (Split-Path -Parent $paths.BackupManifestPath))) {
        if ((Test-RunbookPathWithin -Path $paths.RestoreRoot -Root $other) -or
            (Test-RunbookPathWithin -Path $other -Root $paths.RestoreRoot)) { throw 'Workstation.Context.ExternalBoundary' }
    }
    # Inspect every bound coordinate before opening any contract or invoking a tool.
    Assert-WorkstationBoundPhysicalPath $repo -Directory
    Assert-WorkstationBoundPhysicalPath $target -Directory -Optional
    Assert-WorkstationBoundPhysicalPath $paths.EvidenceRoot -Directory -Optional
    Assert-WorkstationBoundPhysicalPath $paths.BackupManifestPath -File -Optional
    Assert-WorkstationBoundPhysicalPath $paths.RestoreRoot -Directory -Optional
    foreach ($name in @('PolicyPath','CompatibilityPath','TenantConfigurationPath','TenantStatePath')) {
        Assert-WorkstationBoundPhysicalPath $paths[$name] -File
    }
    foreach ($external in @($paths.EvidenceRoot, (Split-Path -Parent $paths.BackupManifestPath), $paths.RestoreRoot)) {
        $null = Resolve-RunbookReportPath -RunId $RunId -Path $external -RepositoryRoot $repo
    }
    $gitMarker = Join-Path $repo '.git'
    Assert-WorkstationBoundPhysicalPath $gitMarker
    $gitItem = Get-Item -LiteralPath $gitMarker -Force
    if ($gitItem -is [IO.DirectoryInfo]) {
        $common = $gitMarker
        $gitDirectory = $gitMarker
    } else {
        $gitText = [IO.File]::ReadAllText($gitMarker).Trim()
        if ($gitText -notmatch '^gitdir: ([^\r\n]+)$') { throw 'Workstation.Source.GitDirectory' }
        $gitDirectory = Resolve-WorkstationBoundPath $Matches[1]
        $adminParent = Split-Path -Parent $gitDirectory
        $common = Split-Path -Parent $adminParent
        if ((Split-Path -Leaf $adminParent) -cne 'worktrees' -or (Split-Path -Leaf $common) -cne '.git') {
            throw 'Workstation.Source.CommonDirectory'
        }
    }
    $primary = Split-Path -Parent $common
    if ((Split-Path -Parent $primary) -ine $context -or $primary -ieq $sibling -or
        (Join-Path (Split-Path -Parent $primary) 'wt') -ine $sibling) { throw 'Workstation.Source.CommonDirectory' }
    Assert-WorkstationBoundPhysicalPath $primary -Directory
    Assert-WorkstationBoundPhysicalPath $common -Directory
    Assert-WorkstationBoundPhysicalPath $gitDirectory -Directory
    if ($gitDirectory -ine $common) {
        $commonMarker = Join-Path $gitDirectory 'commondir'
        Assert-WorkstationBoundPhysicalPath $commonMarker -File
        $commonText = [IO.File]::ReadAllText($commonMarker).Trim()
        $resolvedCommon = [IO.Path]::GetFullPath((Join-Path $gitDirectory $commonText)).TrimEnd('\')
        if ($resolvedCommon -ine $common) { throw 'Workstation.Source.CommonDirectory' }
    }
    $interactive = if ($InteractiveHostProbe) { & $InteractiveHostProbe } else { Get-DefaultInteractiveHostState }
    if (-not $interactive.isInteractive) { throw 'Workstation.Host.InteractiveRequired' }
    $platform = if ($PlatformProbe) { & $PlatformProbe } else {
        $value = Get-DefaultPlatformState
        $value | Add-Member NoteProperty architecture $env:PROCESSOR_ARCHITECTURE
        $value | Add-Member NoteProperty machineId ('{0}\{1}' -f $env:COMPUTERNAME,$env:USERNAME)
        $value
    }
    if ($platform.productName -cne 'Windows 11' -or $platform.build -lt 22000 -or
        $platform.architecture -cnotin @('X64','AMD64') -or $platform.machineId -cne $ExpectedMachineId) {
        throw 'Workstation.Host.Mismatch'
    }
    $inputHashes = @{}
    foreach ($name in @('PolicyPath','CompatibilityPath')) {
        $inputHashes[$name] = (Get-FileHash -LiteralPath $paths[$name] -Algorithm SHA256).Hash
    }
    $policy = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText($paths.PolicyPath))
    Assert-WorkstationPolicy $policy
    $record = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText($paths.CompatibilityPath))
    Assert-WorkstationCompatibilityRecord $record
    $compatibility = ConvertTo-WorkstationCompatibilityModel $record
    Assert-WorkstationDeliveryPolicy $policy $compatibility (Join-Path $scriptDirectory '..\..\config\schemas\workstation-prerequisites.schema.json')
    $runner = if ($NativeCommandRunner) { $NativeCommandRunner } else { New-DefaultNativeCommandRunner }
    $resolver = if ($CommandResolver) { $CommandResolver } else { New-DefaultCommandResolver }
    $identityProvider = if ($FileIdentityProvider) { $FileIdentityProvider } else { New-DefaultFileIdentityProvider $compatibility }
    $gitPolicy = @($policy.tools | Where-Object id -CEQ Git)[0]
    $gitComponent = @($compatibility.components | Where-Object id -CEQ Git)[0]
    $git = Resolve-ExecutableIdentity $gitPolicy.command $resolver $identityProvider
    if ($git.status -cne 'Ready' -or $git.sha256 -cne $gitComponent.sha256 -or
        $git.path -ine (Join-Path $env:ProgramFiles 'Git\cmd\git.exe')) { throw 'Workstation.Tools.GitIdentity' }
    Assert-WorkstationX64Executable $git.path
    $gitTool = Get-ToolAssessment $gitPolicy $resolver $identityProvider $runner $gitComponent.sha256
    if ($gitTool.status -cne 'Ready') { throw 'Workstation.Tools.GitVersion' }
    function Invoke-BoundGit {
        param([string[]]$Arguments, [int[]]$AllowedExitCodes = @(0))
        $fresh = Resolve-ExecutableIdentity $gitPolicy.command $resolver $identityProvider
        if ($fresh.status -cne 'Ready' -or $fresh.path -ine $git.path -or $fresh.sha256 -cne $git.sha256) {
            throw 'Workstation.Tools.GitDrift'
        }
        $native = Invoke-NativeCommand $runner $git.path (@('--no-optional-locks','-c','core.quotepath=false','-c','core.fsmonitor=false','-C',$repo) + $Arguments)
        if ($native.exitCode -notin $AllowedExitCodes) { throw 'Workstation.Source.NativeRead' }
        $native
    }
    function Get-BoundSource {
        $top = ((Invoke-BoundGit @('rev-parse','--show-toplevel')).stdout -join "`n").Trim().Replace('/','\')
        $observedCommon = ((Invoke-BoundGit @('rev-parse','--path-format=absolute','--git-common-dir')).stdout -join "`n").Trim().Replace('/','\')
        $observedGit = ((Invoke-BoundGit @('rev-parse','--absolute-git-dir')).stdout -join "`n").Trim().Replace('/','\')
        if ($top -ine $repo -or $observedCommon -ine $common -or $observedGit -ine $gitDirectory) { throw 'Workstation.Source.RootMismatch' }
        $commit = ((Invoke-BoundGit @('rev-parse','--verify','HEAD')).stdout -join "`n").Trim()
        if ($commit -cne $ExpectedSourceCommit) { throw 'Workstation.Source.CommitMismatch' }
        $remoteLines = @((Invoke-BoundGit @('remote','-v')).stdout | Where-Object { $_ } | Sort-Object)
        if ($remoteLines.Count -lt 2 -or (Get-RunbookContentDigest -InputObject $remoteLines) -cne $RepositoryIdentity) {
            throw 'Workstation.Source.RemoteMismatch'
        }
        $sparse = Invoke-BoundGit @('config','--bool','--get','core.sparseCheckout') @(0,1)
        if ($sparse.exitCode -eq 0 -and ($sparse.stdout -join '') -cne 'false') { throw 'Workstation.Source.Sparse' }
        $files = [Collections.Generic.List[string]]::new()
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $entries = (Invoke-BoundGit @('ls-files','--stage','-z')).stdout -join "`n"
        foreach ($entry in @($entries -split [char]0 | Where-Object { $_ })) {
            if ($entry -notmatch '^(100644|100755) [0-9a-f]{40} 0\t([^\r\n]+)$') { throw 'Workstation.Source.TrackedEntry' }
            $relative = $Matches[2]
            if ($relative -match '(^|/)\.\.?(/|$)|[\\:\x00-\x1f]' -or $relative.StartsWith('/') -or
                $relative -match '(?i)(^|/)([^/]*\.local\.[^/]*|\.env[^/]*|[^/]*\.state\.local\.json)$|^\.github/plugins(/|$)' -or
                -not $seen.Add($relative)) { throw 'Workstation.Source.TrackedBoundary' }
            Assert-WorkstationBoundPhysicalPath (Join-Path $repo $relative.Replace('/','\')) -File
            $files.Add($relative)
        }
        if ($files.Count -eq 0) { throw 'Workstation.Source.Empty' }
        $dirty = (Invoke-BoundGit @('status','--porcelain=v1','--untracked-files=all','--ignore-submodules=none')).stdout -join ''
        if ($dirty) { throw 'Workstation.Source.NotClean' }
        foreach ($label in @('infra/src/config/tenants/tenant1.local.psd1','infra/src/config/tenants/tenant1.state.local.json')) {
            $null = Invoke-BoundGit @('check-ignore','--quiet','--no-index','--',$label)
        }
        [pscustomobject]@{ files = @($files); commit = $commit }
    }
    $index = Join-Path $gitDirectory 'index'
    Assert-WorkstationBoundPhysicalPath $index -File
    $indexHash = (Get-FileHash -LiteralPath $index -Algorithm SHA256).Hash
    $indexTime = [IO.File]::GetLastWriteTimeUtc($index)
    $source = Get-BoundSource
    $compatibilityProof = & (Join-Path $scriptDirectory 'Test-DeveloperWorkstationCompatibility.ps1') `
        -CompatibilityPath $paths.CompatibilityPath -PolicyPath $paths.PolicyPath `
        -CommandResolver $resolver -NativeCommandRunner $runner -NowUtc $NowUtc
    $tools = @(
        foreach ($component in $compatibility.components) {
            $observed = @($compatibilityProof.components | Where-Object id -CEQ $component.id)
            $ready = $compatibilityProof.status -ceq 'NoChange' -and
                $compatibilityProof.policyAccepted -and $observed.Count -eq 1 -and
                $observed[0].status -ceq 'Proven'
            if ($ready -and ($observed[0].version -cne $component.version -or
                $observed[0].sha256 -cne $component.sha256)) { throw 'Workstation.Tools.Compatibility' }
            [pscustomobject][ordered]@{
                id = $component.id
                status = $(if ($ready) { 'Ready' } else { 'Blocked' })
                version = $(if ($ready) { $observed[0].version } else { $null })
                executablePath = $(if ($ready) { $observed[0].canonicalPath } else { $null })
                executableSha256 = $(if ($ready) { $observed[0].sha256 } else { $null })
            }
        }
    )
    $longest = @($source.files | Sort-Object @{ Expression = { $_.Length }; Descending = $true }, @{ Expression = { $_ } })[0]
    $checkoutLength = $target.Length + 1 + $longest.Length
    $budget = [pscustomobject][ordered]@{
        worktreeRootLength = $target.Length
        longestTrackedRelativePath = $longest
        longestCheckoutPathLength = $checkoutLength
        maximumExclusive = 240
        classification = $(if ($checkoutLength -lt 240) { 'NoChange' } else { 'Blocked' })
    }
    $access = 'Blocked'
    $probe = $null
    $probeOwned = $false
    if ($checkoutLength -lt 240 -and [IO.Directory]::Exists($target)) {
        try {
            Assert-WorkstationBoundPhysicalPath $target -Directory
            $probe = Join-Path $target ('.access-probe-' + [guid]::NewGuid().ToString('N'))
            $null = New-Item -ItemType File -Path $probe -ErrorAction Stop
            $probeOwned = $true
            Set-Content -LiteralPath $probe -Value 'current-user-access' -Encoding ASCII -ErrorAction Stop
            Remove-Item -LiteralPath $probe -ErrorAction Stop
            $probeOwned = $false
            if (Test-Path -LiteralPath $probe) { throw 'Delete' }
            $access = 'NoChange'
        } catch { $access = 'Blocked' }
        finally {
            if ($probeOwned) {
                try { Remove-Item -LiteralPath $probe -ErrorAction Stop } catch { $access = 'Blocked' }
            }
        }
    }
    $privateLocks = [Collections.Generic.List[IO.FileStream]]::new()
    try {
        $privateBackup = Test-TenantPrivateBackup -IntentPath $paths.TenantConfigurationPath `
            -StatePath $paths.TenantStatePath -BackupManifestPath $paths.BackupManifestPath `
            -RestoreRoot $paths.RestoreRoot -NowUtc $NowUtc
        if ($privateBackup.classification -ceq 'NoChange' -and
            $privateBackup.bytesChecked -and $privateBackup.intentEqual -and $privateBackup.stateEqual) {
            try {
                $declarationBinding = $privateBackup.declarationMetadataDigest
                # Keep current bytes stable through shared schema/Git validation and
                # evidence projection. Invalid declarations never reach these opens.
                foreach ($path in @($paths.BackupManifestPath, $paths.TenantConfigurationPath, $paths.TenantStatePath,
                    (Join-Path $paths.RestoreRoot 'intent'), (Join-Path $paths.RestoreRoot 'state'))) {
                    $privateLocks.Add([IO.File]::Open($path, 'Open', 'Read', 'Read'))
                }
                $privateBackup = Test-TenantPrivateBackup -IntentPath $paths.TenantConfigurationPath `
                    -StatePath $paths.TenantStatePath -BackupManifestPath $paths.BackupManifestPath `
                    -RestoreRoot $paths.RestoreRoot -NowUtc $NowUtc
                if ($privateBackup.classification -cne 'NoChange' -or
                    $privateBackup.declarationMetadataDigest -cne $declarationBinding -or
                    -not ($privateBackup.bytesChecked -and $privateBackup.intentEqual -and $privateBackup.stateEqual)) {
                    throw 'Private input changed before binding.'
                }
                $boundaryRunner = {
                    param($file, $arguments)
                    & $runner $git.path (@('--no-optional-locks','-c','core.fsmonitor=false') + $arguments)
                }.GetNewClosure()
                $boundary = & (Get-WorkstationBootstrapModule) {
                    param($intent, $state, $sourceRoot, $gitRunner)
                    Test-TenantLifecyclePrivateBoundary -PublicTenantKey tenant1 `
                        -IntentPath $intent -StatePath $state -RepositoryRoot $sourceRoot -NativeCommandRunner $gitRunner
                } $paths.TenantConfigurationPath $paths.TenantStatePath $repo $boundaryRunner
                $predicates = [ordered]@{}
                foreach ($entry in @('intent','state')) {
                    $predicates[$entry] = [pscustomobject][ordered]@{
                        exists = [bool]$boundary.$entry.exists
                        ignored = [bool]$boundary.$entry.ignored
                        tracked = [bool]$boundary.$entry.tracked
                        schemaValid = [bool]$boundary.$entry.schemaValid
                    }
                }
                $privateBackup | Add-Member NoteProperty privateBoundary ([pscustomobject]$predicates)
            } catch {
                $privateBackup.classification = 'Blocked'
                $privateBackup.reason = 'PrivateBoundaryInvalid'
            }
        }
        $after = Get-BoundSource
        if ($after.commit -cne $source.commit -or
            (Get-RunbookContentDigest $after.files) -cne (Get-RunbookContentDigest $source.files) -or
            (Get-FileHash -LiteralPath $index -Algorithm SHA256).Hash -cne $indexHash -or
            [IO.File]::GetLastWriteTimeUtc($index) -ne $indexTime) { throw 'Workstation.Source.Drift' }
        foreach ($name in @('PolicyPath','CompatibilityPath')) {
            Assert-WorkstationBoundPhysicalPath $paths[$name] -File
            if ((Get-FileHash -LiteralPath $paths[$name] -Algorithm SHA256).Hash -cne $inputHashes[$name]) {
                throw 'Workstation.Policy.Drift'
            }
        }
        $freshGit = Get-ToolAssessment $gitPolicy $resolver $identityProvider $runner $git.sha256
        if ($freshGit.status -cne 'Ready' -or $freshGit.executablePath -ine $git.path -or
            $freshGit.executableSha256 -cne $git.sha256 -or $freshGit.version -cne $gitTool.version) {
            throw 'Workstation.Tools.Drift'
        }
        foreach ($tool in $tools | Where-Object status -CEQ Ready) {
            Assert-WorkstationPhysicalPath $tool.executablePath
            if ((Get-FileHash -LiteralPath $tool.executablePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne
                $tool.executableSha256) { throw 'Workstation.Tools.Drift' }
        }
        $components = [pscustomobject][ordered]@{
            worktreeAccess = [pscustomobject]@{ classification = $access }
            pathBudget = $budget
            repositorySource = [pscustomobject]@{ classification = 'NoChange'; sourceCommit = $ExpectedSourceCommit; remotesDigest = $RepositoryIdentity; machineMatched = $true }
            repositoryCleanliness = [pscustomobject]@{ classification = 'NoChange'; cleanBefore = $true; cleanAfter = $true; optionalIndexWrites = $false }
            toolIdentities = [pscustomobject]@{
                classification = $(if (@($tools | Where-Object status -CNE Ready).Count -eq 0) { 'NoChange' } else { 'Blocked' })
                inventory = @($tools | Select-Object id,status,version,executablePath,executableSha256)
                diagnostic = $compatibilityProof.diagnostic
            }
        }
        $projection = [pscustomobject][ordered]@{
            schemaVersion = '1.0'
            scopeStage = 'Task2AssessmentOnly'
            policyDigest = Get-RunbookContentDigest $policy
            compatibilityDigest = [string]$record.digest
            components = $components
            privateBackup = $privateBackup
            overallStatus = 'Blocked'
        }
        $result = [pscustomobject][ordered]@{
            schemaVersion = $projection.schemaVersion
            scopeStage = $projection.scopeStage
            runId = $RunId.ToString('D')
            assessedAtUtc = $NowUtc.ToUniversalTime().ToString('o')
            policyDigest = $projection.policyDigest
            compatibilityDigest = $projection.compatibilityDigest
            components = $components
            privateBackup = $projection.privateBackup
            overallStatus = $projection.overallStatus
            assessmentDigest = Get-RunbookContentDigest $projection
        }
        $safe = Resolve-RunbookReportPath -RunId $RunId -Path (Join-Path $paths.EvidenceRoot $RunId.ToString('D')) -RepositoryRoot $repo
        Assert-WorkstationBoundPhysicalPath $safe -Directory -Optional
        New-Item -ItemType Directory -Path $safe -Force | Out-Null
        Write-CanonicalJson -InputObject $result -Path (Join-Path $safe 'assessment.json') | Out-Null
        $result
    } finally {
        foreach ($handle in $privateLocks) { $handle.Dispose() }
    }
}

$script:boundInputs = $PSBoundParameters
$boundContext = @('RunId','EvidenceRoot','CompatibilityPath','ExpectedSourceCommit','RepositoryIdentity','ExpectedMachineId',
    'WorktreeRoot','TenantConfigurationPath','TenantStatePath','BackupManifestPath','RestoreRoot') |
    Where-Object { $PSBoundParameters.ContainsKey($_) }
if (@($boundContext).Count -gt 0) {
    try { Invoke-BoundWorkstationAssessment } catch {
        if ($_.Exception.Message -cmatch '^Workstation\.[A-Za-z.]+$') { throw $_.Exception.Message }
        throw ('Workstation.Assessment.Blocked.' + $_.Exception.GetType().Name + '.' + $_.InvocationInfo.ScriptLineNumber)
    }
    return
}
if ($null -eq $PlatformProbe) { throw 'Workstation.Context.Required' }

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

$policy = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText($PolicyPath))
Assert-WorkstationPolicy -Policy $policy
$compatibility = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText(
    (Join-Path $scriptDirectory '..\..\config\runbooks\workstation-compatibility.json')))
Assert-WorkstationCompatibilityRecord $compatibility
$compatibility = ConvertTo-WorkstationCompatibilityModel $compatibility
Assert-WorkstationDeliveryPolicy $policy $compatibility (Join-Path $scriptDirectory '..\..\config\schemas\workstation-prerequisites.schema.json')
$policyDigest = Get-RunbookContentDigest -InputObject $policy

$packageManagerIdentity = Get-PackageManagerAssessment -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider -Runner $NativeCommandRunner
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
    $safeToolVersions['WinGet'] = $packageManagerIdentity.version
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
        version = $(if ($packageManagerIdentity.status -eq 'Ready') { $packageManagerIdentity.version } else { $null })
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
