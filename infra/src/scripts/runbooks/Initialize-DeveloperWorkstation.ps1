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

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleManifestPath = Join-Path $scriptDirectory '..\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
Import-Module $moduleManifestPath -Force

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
        default {
            if ([string]::IsNullOrWhiteSpace($joined)) {
                return $null
            }
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

    [pscustomobject]@{
        exitCode = $(if ($result.PSObject.Properties.Name -contains 'exitCode') { [int]$result.exitCode } else { 1 })
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

function Get-CurrentProcessElevationState {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    [pscustomobject]@{
        isElevated = $isElevated
        reason = $(if ($isElevated) { 'AdministratorToken' } else { 'StandardUserToken' })
    }
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

function Assert-WorkstationStableId {
    param([Parameter(Mandatory)][string]$Expected, [Parameter(Mandatory)][string]$Actual)

    if ($Expected -cne $Actual) {
        throw 'Execution manifest workstation target does not match the current user and computer.'
    }
}

function Assert-AllowedPolicyActions {
    param([Parameter(Mandatory)][object]$Manifest, [Parameter(Mandatory)][object]$Policy)

    $allowed = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($tool in $Policy.tools) {
        $item = $null
        switch ([string]$tool.install.kind) {
            'WinGet' {
                $postcondition = switch ([string]$tool.id) {
                    'Git' { 'git.exe resolves and git --version exits 0' }
                    default { "$($tool.id) resolves uniquely with the reviewed executable identity and version policy" }
                }
                $item = [pscustomobject][ordered]@{
                    action = 'WinGetInstallExact'
                    targetId = [string]$tool.install.packageId
                    packageSource = [string]$tool.install.source
                    packageId = [string]$tool.install.packageId
                    scope = [string]$tool.install.scope
                    expectedPostcondition = $postcondition
                }
            }
            'PowerShellGallery' {
                $item = [pscustomobject][ordered]@{
                    action = 'InstallPesterExact'
                    targetId = [string]$tool.install.moduleName
                    packageSource = [string]$tool.install.repository
                    scope = [string]$tool.install.scope
                    requiredVersion = [string]$tool.install.requiredVersion
                    expectedPostcondition = 'Pester 5.7.1 resolves in CurrentUser scope'
                }
            }
            'AzureCliComponent' {
                $item = [pscustomobject][ordered]@{
                    action = 'InstallBicepComponent'
                    targetId = [string]$tool.id
                    expectedPostcondition = 'az bicep version exits 0'
                }
            }
        }
        if ($null -ne $item) {
            $allowed["$($item.action)|$($item.targetId)"] = $item
        }
    }

    foreach ($extension in $Policy.azureCliExtensions) {
        $item = [pscustomobject][ordered]@{
            action = 'InstallAzureCliExtensionExact'
            targetId = [string]$extension.name
            requiredVersion = $(if ($extension.versionPolicy.PSObject.Properties.Name -contains 'value') { [string]$extension.versionPolicy.value } else { $null })
            expectedPostcondition = "Azure CLI extension $($extension.name) resolves at the reviewed version"
        }
        $allowed["$($item.action)|$($item.targetId)"] = $item
    }

    foreach ($extension in $Policy.vsCodeExtensions) {
        $item = [pscustomobject][ordered]@{
            action = 'InstallVsCodeExtensionExact'
            targetId = [string]$extension.id
            expectedPostcondition = "VS Code reports extension $($extension.id)"
        }
        $allowed["$($item.action)|$($item.targetId)"] = $item
    }

    $selected = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    foreach ($operation in @($Manifest.allowedActions)) {
        $key = "$($operation.action)|$($operation.targetId)"
        if (-not $allowed.ContainsKey($key)) {
            throw 'Execution manifest contains an action absent from reviewed policy.'
        }
        if ((Get-RunbookContentDigest -InputObject $operation) -cne (Get-RunbookContentDigest -InputObject $allowed[$key])) {
            throw 'Execution manifest action arguments differ from reviewed policy.'
        }
        $selected[$key] = $allowed[$key]
    }

    $selected
}

function Show-RunbookChangeSummary {
    param([AllowEmptyCollection()][object[]]$Operations, [Parameter(Mandatory)][scriptblock]$Writer)

    if (@($Operations).Count -eq 0) { return }

    $displayRows = foreach ($operation in $Operations) {
        $propertyNames = @($operation.PSObject.Properties | ForEach-Object Name)
        [pscustomobject][ordered]@{
            action = [string]$operation.action
            targetId = [string]$operation.targetId
            packageSource = $(if ($propertyNames -contains 'packageSource') { [string]$operation.packageSource } else { $null })
            packageId = $(if ($propertyNames -contains 'packageId') { [string]$operation.packageId } else { $null })
            scope = $(if ($propertyNames -contains 'scope') { [string]$operation.scope } else { $null })
            requiredVersion = $(if ($propertyNames -contains 'requiredVersion') { [string]$operation.requiredVersion } else { $null })
            expectedPostcondition = $(if ($propertyNames -contains 'expectedPostcondition') { [string]$operation.expectedPostcondition } else { $null })
        }
    }

    & $Writer @($displayRows)
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

function Get-Policy {
    param([Parameter(Mandatory)][string]$PolicyFilePath)
    Get-Content -Raw -LiteralPath $PolicyFilePath | ConvertFrom-Json
}

function Get-Assessment {
    param(
        [string]$PolicyFilePath,
        [string]$RepositoryRootPath,
        [scriptblock]$Provider,
        [scriptblock]$Runner,
        [scriptblock]$Resolver,
        [scriptblock]$IdentityProvider,
        [scriptblock]$InteractiveProbe,
        [datetime]$UtcNow
    )

    if ($null -ne $Provider) {
        return & $Provider
    }

    $assessmentScriptPath = Join-Path $scriptDirectory 'Test-DeveloperWorkstation.ps1'
    & $assessmentScriptPath -PolicyPath $PolicyFilePath -RepositoryRoot $RepositoryRootPath `
        -NativeCommandRunner $Runner -CommandResolver $Resolver -FileIdentityProvider $IdentityProvider `
        -InteractiveHostProbe $InteractiveProbe -NowUtc $UtcNow
}

function New-Operation {
    param(
        [Parameter(Mandatory)][string]$Classification,
        [Parameter(Mandatory)][object]$Action,
        [bool]$RequiresElevation = $false
    )

    $propertyNames = @($Action.PSObject.Properties | ForEach-Object Name)
    [pscustomobject][ordered]@{
        classification = $Classification
        requiresElevation = $RequiresElevation
        action = [string]$Action.action
        targetId = [string]$Action.targetId
        packageSource = $(if ($propertyNames -contains 'packageSource') { [string]$Action.packageSource } else { $null })
        packageId = $(if ($propertyNames -contains 'packageId') { [string]$Action.packageId } else { $null })
        scope = $(if ($propertyNames -contains 'scope') { [string]$Action.scope } else { $null })
        requiredVersion = $(if ($propertyNames -contains 'requiredVersion') { [string]$Action.requiredVersion } else { $null })
        expectedPostcondition = $(if ($propertyNames -contains 'expectedPostcondition') { [string]$Action.expectedPostcondition } else { $null })
    }
}

function Get-ToolStatusClassification {
    param(
        [Parameter(Mandatory)][object]$CurrentState,
        [Parameter(Mandatory)][string]$InstallDisposition
    )

    if ([string]$CurrentState.status -eq 'Missing') {
        return 'Create'
    }
    if ([string]$CurrentState.status -eq 'Blocked' -and
        [string]$InstallDisposition -ceq 'Manual') {
        return 'Manual'
    }
    if ([string]$CurrentState.status -eq 'Blocked' -and
        -not [string]::IsNullOrWhiteSpace([string]$CurrentState.diagnostic) -and
        [string]$CurrentState.diagnostic -like 'Reviewed version policy failed*') {
        return 'Update'
    }
    return 'Blocked'
}

function Get-PlannedOperations {
    param(
        [Parameter(Mandatory)][object]$Policy,
        [Parameter(Mandatory)][object]$Assessment
    )

    $operations = [Collections.Generic.List[object]]::new()
    foreach ($tool in @($Policy.tools)) {
        $current = @($Assessment.tools | Where-Object { [string]$_.id -ceq [string]$tool.id }) | Select-Object -First 1
        if ($null -eq $current -or $current.status -eq 'Ready') {
            continue
        }

        $classification = Get-ToolStatusClassification -CurrentState $current -InstallDisposition ([string]$tool.installDisposition)

        switch ([string]$tool.install.kind) {
            'WinGet' {
                $postcondition = switch ([string]$tool.id) {
                    'Git' { 'git.exe resolves and git --version exits 0' }
                    default { "$($tool.id) resolves uniquely with the reviewed executable identity and version policy" }
                }
                [void]$operations.Add((New-Operation -Classification $classification -RequiresElevation ([string]$tool.install.scope -ceq 'machine') -Action ([pscustomobject][ordered]@{
                    action = 'WinGetInstallExact'
                    targetId = [string]$tool.install.packageId
                    packageSource = [string]$tool.install.source
                    packageId = [string]$tool.install.packageId
                    scope = [string]$tool.install.scope
                    expectedPostcondition = $postcondition
                })))
            }
            'PowerShellGallery' {
                [void]$operations.Add((New-Operation -Classification $classification -Action ([pscustomobject][ordered]@{
                    action = 'InstallPesterExact'
                    targetId = [string]$tool.install.moduleName
                    packageSource = [string]$tool.install.repository
                    scope = [string]$tool.install.scope
                    requiredVersion = [string]$tool.install.requiredVersion
                    expectedPostcondition = 'Pester 5.7.1 resolves in CurrentUser scope'
                })))
            }
            'AzureCliComponent' {
                [void]$operations.Add((New-Operation -Classification $classification -Action ([pscustomobject][ordered]@{
                    action = 'InstallBicepComponent'
                    targetId = [string]$tool.id
                    expectedPostcondition = 'az bicep version exits 0'
                })))
            }
            'None' {
                [void]$operations.Add((New-Operation -Classification $classification -Action ([pscustomobject][ordered]@{
                    action = 'ManualReview'
                    targetId = [string]$tool.id
                    expectedPostcondition = [string]$current.diagnostic
                })))
            }
        }
    }

    $azureCliExtensions = @()
    if ($Assessment.PSObject.Properties.Name -contains 'azureCliExtensions') {
        $azureCliExtensions = @($Assessment.azureCliExtensions)
    }
    foreach ($extension in $azureCliExtensions) {
        if ($extension.status -eq 'Missing') {
            [void]$operations.Add((New-Operation -Classification 'Create' -Action ([pscustomobject][ordered]@{
                action = 'InstallAzureCliExtensionExact'
                targetId = [string]$extension.name
                requiredVersion = $(if ($extension.PSObject.Properties.Name -contains 'version') { [string]$extension.version } else { $null })
                expectedPostcondition = "Azure CLI extension $($extension.name) resolves at the reviewed version"
            })))
        }
        elseif ($extension.status -ne 'Ready') {
            [void]$operations.Add((New-Operation -Classification 'Blocked' -Action ([pscustomobject][ordered]@{
                action = 'InstallAzureCliExtensionExact'
                targetId = [string]$extension.name
                requiredVersion = $(if ($extension.PSObject.Properties.Name -contains 'version') { [string]$extension.version } else { $null })
                expectedPostcondition = "Azure CLI extension $($extension.name) resolves at the reviewed version"
            })))
        }
    }
    $vsCodeExtensions = @()
    if ($Assessment.PSObject.Properties.Name -contains 'vsCodeExtensions') {
        $vsCodeExtensions = @($Assessment.vsCodeExtensions)
    }
    foreach ($extension in $vsCodeExtensions) {
        if ($extension.status -eq 'Missing') {
            [void]$operations.Add((New-Operation -Classification 'Create' -Action ([pscustomobject][ordered]@{
                action = 'InstallVsCodeExtensionExact'
                targetId = [string]$extension.id
                expectedPostcondition = "VS Code reports extension $($extension.id)"
            })))
        }
        elseif ($extension.status -ne 'Ready') {
            [void]$operations.Add((New-Operation -Classification 'Blocked' -Action ([pscustomobject][ordered]@{
                action = 'InstallVsCodeExtensionExact'
                targetId = [string]$extension.id
                expectedPostcondition = "VS Code reports extension $($extension.id)"
            })))
        }
    }

    @($operations)
}

function Get-CurrentAuthenticationContext {
    [pscustomobject]@{
        executionHost = 'InteractiveWindows11PowerShell'
        mode = 'NotRequired'
    }
}

function Get-FinalWorkstationContext {
    [pscustomobject]@{
        executionHost = 'InteractiveWindows11PowerShell'
        status = 'InteractiveWindows11PowerShell'
    }
}

function New-DefaultSummaryWriter {
    {
        param($rows)
        if (@($rows).Count -eq 0) { return }
        ($rows | Format-Table -AutoSize | Out-String).TrimEnd() | Out-Host
    }.GetNewClosure()
}

function Get-ToolPolicyForAction {
    param(
        [Parameter(Mandatory)][object]$Policy,
        [Parameter(Mandatory)][object]$Action
    )

    switch ([string]$Action.action) {
        'WinGetInstallExact' {
            @($Policy.tools | Where-Object {
                [string]$_.install.kind -eq 'WinGet' -and
                [string]$_.install.packageId -eq [string]$Action.targetId
            }) | Select-Object -First 1
        }
        'InstallPesterExact' {
            @($Policy.tools | Where-Object {
                [string]$_.install.kind -eq 'PowerShellGallery' -and
                [string]$_.install.moduleName -eq [string]$Action.targetId
            }) | Select-Object -First 1
        }
        'InstallBicepComponent' {
            @($Policy.tools | Where-Object {
                [string]$_.install.kind -eq 'AzureCliComponent' -and
                [string]$_.id -eq [string]$Action.targetId
            }) | Select-Object -First 1
        }
        'InstallAzureCliExtensionExact' { $null }
        'InstallVsCodeExtensionExact' { $null }
        default { $null }
    }
}

function Get-HostToolRuntimeState {
    param(
        [Parameter(Mandatory)][object]$Assessment,
        [Parameter(Mandatory)][string]$ActionName
    )

    switch ($ActionName) {
        'WinGetInstallExact' {
            $command = if (-not [string]::IsNullOrWhiteSpace([string]$Assessment.platform.packageManager.executablePath)) {
                Split-Path -Path ([string]$Assessment.platform.packageManager.executablePath) -Leaf
            }
            else {
                'winget.exe'
            }
            [pscustomobject][ordered]@{
                id = 'WinGet'
                command = $command
                versionArguments = @('--version')
                expectedPath = [string]$Assessment.platform.packageManager.executablePath
                expectedSha256 = [string]$Assessment.platform.packageManager.executableSha256
                expectedVersion = [string]$Assessment.platform.packageManager.version
            }
        }
        'InstallPesterExact' {
            $tool = @($Assessment.tools | Where-Object { [string]$_.id -ceq 'WindowsPowerShell' }) | Select-Object -First 1
            $command = if (-not [string]::IsNullOrWhiteSpace([string]$tool.executablePath)) {
                Split-Path -Path ([string]$tool.executablePath) -Leaf
            }
            else {
                'powershell.exe'
            }
            [pscustomobject][ordered]@{
                id = 'WindowsPowerShell'
                command = $command
                versionArguments = @('-NoLogo', '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
                expectedPath = [string]$tool.executablePath
                expectedSha256 = [string]$tool.executableSha256
                expectedVersion = [string]$tool.version
            }
        }
        'InstallBicepComponent' { Get-HostToolRuntimeState -Assessment $Assessment -ActionName 'InstallAzureCliExtensionExact' }
        'InstallAzureCliExtensionExact' {
            $tool = @($Assessment.tools | Where-Object { [string]$_.id -ceq 'AzureCli' }) | Select-Object -First 1
            $command = if (-not [string]::IsNullOrWhiteSpace([string]$tool.executablePath)) {
                Split-Path -Path ([string]$tool.executablePath) -Leaf
            }
            else {
                'az.cmd'
            }
            [pscustomobject][ordered]@{
                id = 'AzureCli'
                command = $command
                versionArguments = @('version', '--output', 'json')
                expectedPath = [string]$tool.executablePath
                expectedSha256 = [string]$tool.executableSha256
                expectedVersion = [string]$tool.version
            }
        }
        'InstallVsCodeExtensionExact' {
            $tool = @($Assessment.tools | Where-Object { [string]$_.id -ceq 'VisualStudioCode' }) | Select-Object -First 1
            $command = if (-not [string]::IsNullOrWhiteSpace([string]$tool.executablePath)) {
                Split-Path -Path ([string]$tool.executablePath) -Leaf
            }
            else {
                'code.cmd'
            }
            [pscustomobject][ordered]@{
                id = 'VisualStudioCode'
                command = $command
                versionArguments = @('--version')
                expectedPath = [string]$tool.executablePath
                expectedSha256 = [string]$tool.executableSha256
                expectedVersion = [string]$tool.version
            }
        }
        default { $null }
    }
}

function Assert-ExecutableStateUnchanged {
    param(
        [Parameter(Mandatory)][string]$ExpectedPath,
        [Parameter(Mandatory)][string]$ExpectedSha256,
        [Parameter(Mandatory)][string]$ExpectedVersion,
        [Parameter(Mandatory)][string[]]$VersionArguments,
        [Parameter(Mandatory)][string]$ToolId,
        [Parameter(Mandatory)][string]$CommandName,
        [Parameter(Mandatory)][scriptblock]$Resolver,
        [Parameter(Mandatory)][scriptblock]$IdentityProvider,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $identity = Resolve-ExecutableIdentity -CommandName $CommandName -Resolver $Resolver -IdentityProvider $IdentityProvider
    if ($identity.status -ne 'Ready' -or
        $identity.path -cne $ExpectedPath -or
        $identity.sha256 -cne $ExpectedSha256) {
        throw 'A reviewed executable identity changed before mutation.'
    }

    $versionResult = Invoke-NativeCommand -Runner $Runner -FilePath $identity.path -ArgumentList $VersionArguments
    $observedVersion = Get-ObservedVersion -ToolId $ToolId -Result $versionResult
    if ($versionResult.exitCode -ne 0 -or
        [string]::IsNullOrWhiteSpace($observedVersion) -or
        $observedVersion -cne $ExpectedVersion) {
        throw 'A reviewed executable state changed before mutation.'
    }

    $identity
}

function New-ReadBackFailure {
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string]$TargetId,
        [Parameter(Mandatory)][string]$ExpectedPostcondition,
        [Parameter(Mandatory)][string]$Diagnostic
    )

    [pscustomobject][ordered]@{
        status = 'Failed'
        errorCategory = 'ReadBack'
        readBack = [pscustomobject][ordered]@{
            service = $Service
            targetId = $TargetId
            status = 'Failed'
            expectedPostcondition = $ExpectedPostcondition
        }
        recoveryItems = @([pscustomobject][ordered]@{
            service = $Service
            targetId = $TargetId
            lastProvenState = 'Command returned without proving the reviewed postcondition.'
            safeDiagnostic = $Diagnostic
            owner = 'Workstation administrator'
            nextAction = 'Reassess the workstation and generate a new approved manifest.'
            requiresNewPlan = $true
            requiresNewApproval = $true
        })
    }
}

function Get-AzureCliExtensionReadBack {
    param(
        [Parameter(Mandatory)][string]$ExtensionName,
        [Parameter(Mandatory)][object[]]$ToolAssessments,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $azureCli = $ToolAssessments | Where-Object { [string]$_.id -ceq 'AzureCli' } | Select-Object -First 1
    if ($null -eq $azureCli -or $azureCli.status -ne 'Ready') {
        return [pscustomobject][ordered]@{
            name = $ExtensionName
            status = 'Blocked'
            version = $null
            diagnostic = 'Azure CLI is not ready for extension read-back.'
        }
    }

    $native = Invoke-NativeCommand -Runner $Runner -FilePath ([string]$azureCli.executablePath) -ArgumentList @('extension', 'list', '--output', 'json')
    $installed = @()
    if ($native.exitCode -eq 0) {
        try {
            $installed = @((($native.stdout -join "`n") | ConvertFrom-Json))
        }
        catch {
            $installed = @()
        }
    }

    $match = $installed | Where-Object { [string]$_.name -ceq $ExtensionName } | Select-Object -First 1
    [pscustomobject][ordered]@{
        name = $ExtensionName
        status = $(if ($native.exitCode -ne 0) { 'Blocked' } elseif ($null -eq $match) { 'Missing' } else { 'Ready' })
        version = $(if ($null -ne $match) { [string]$match.version } else { $null })
        diagnostic = $(if ($native.exitCode -ne 0) { 'Azure CLI extension list probe failed.' } elseif ($null -eq $match) { 'Reviewed Azure CLI extension is not installed.' } else { $null })
    }
}

function Get-VsCodeExtensionReadBack {
    param(
        [Parameter(Mandatory)][string]$ExtensionId,
        [Parameter(Mandatory)][object[]]$ToolAssessments,
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $code = $ToolAssessments | Where-Object { [string]$_.id -ceq 'VisualStudioCode' } | Select-Object -First 1
    if ($null -eq $code -or $code.status -ne 'Ready') {
        return [pscustomobject][ordered]@{
            id = $ExtensionId
            status = 'Blocked'
            diagnostic = 'Visual Studio Code is not ready for extension read-back.'
        }
    }

    $native = Invoke-NativeCommand -Runner $Runner -FilePath ([string]$code.executablePath) -ArgumentList @('--list-extensions')
    $installed = @($native.stdout | ForEach-Object { [string]$_ })
    $present = @($installed | Where-Object { $_ -ceq $ExtensionId }).Count -gt 0
    [pscustomobject][ordered]@{
        id = $ExtensionId
        status = $(if ($native.exitCode -ne 0) { 'Blocked' } elseif ($present) { 'Ready' } else { 'Missing' })
        diagnostic = $(if ($native.exitCode -ne 0) { 'VS Code extension list probe failed.' } elseif ($present) { $null } else { 'Reviewed VS Code extension is not installed.' })
    }
}

function Get-ExecutableOperations {
    param([AllowEmptyCollection()][object[]]$Operations)
    @($Operations | Where-Object { $_.classification -in @('Create', 'Update') })
}

function New-EvidenceRecord {
    param(
        [Parameter(Mandatory)][guid]$RunId,
        [Parameter(Mandatory)][datetime]$GeneratedAtUtc,
        [Parameter(Mandatory)][string]$SourceCommit,
        [Parameter(Mandatory)][string]$AssessmentDigest,
        [string]$PlanDigest,
        [string]$ManifestDigest,
        [Parameter(Mandatory)][string]$OperatorId,
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$Classification,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$ShouldProcessDecision,
        [string]$TargetId,
        [object]$ToolVersions,
        [object]$ReadBack,
        [object]$FinalContext,
        [object[]]$ManualItems,
        [object[]]$RecoveryItems,
        [string]$ErrorCategory
    )

    ConvertTo-RunbookEvidenceRecord -RunId $RunId -GeneratedAtUtc $GeneratedAtUtc `
        -SourceCommit $SourceCommit -AssessmentDigest $AssessmentDigest -PlanDigest $PlanDigest `
        -ManifestDigest $ManifestDigest -OperatorId $OperatorId -Operation $Operation `
        -Classification $Classification -Status $Status -ShouldProcessDecision $ShouldProcessDecision `
        -TargetId $TargetId -ToolVersions $ToolVersions -ReadBack $ReadBack -FinalContext $FinalContext `
        -ManualItems $ManualItems -RecoveryItems $RecoveryItems -ErrorCategory $ErrorCategory
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
if ($null -eq $SummaryWriter) { $SummaryWriter = New-DefaultSummaryWriter }

$interactiveState = $(if ($null -eq $InteractiveHostProbe) { Get-DefaultInteractiveHostState } else { & $InteractiveHostProbe })
if (-not [bool]$interactiveState.isInteractive) {
    throw 'This runbook requires an interactive Windows 11 PowerShell session.'
}

$policy = Get-Policy -PolicyFilePath $PolicyPath
$assessment = Get-Assessment -PolicyFilePath $PolicyPath -RepositoryRootPath $RepositoryRoot `
    -Provider $AssessmentProvider -Runner $NativeCommandRunner -Resolver $CommandResolver `
    -IdentityProvider $FileIdentityProvider -InteractiveProbe $InteractiveHostProbe -UtcNow $NowUtc
$runId = [guid]::NewGuid()
$reportDirectory = Resolve-RunbookReportPath -RunId $runId -Path $ReportPath -RepositoryRoot $RepositoryRoot
[IO.Directory]::CreateDirectory($reportDirectory) | Out-Null

$operations = Get-PlannedOperations -Policy $policy -Assessment $assessment
$executableOperations = Get-ExecutableOperations -Operations @($operations)
$planProjection = [pscustomobject][ordered]@{
    schemaVersion = '1.0'
    runId = $runId.ToString('D')
    generatedAtUtc = $NowUtc.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    sourceCommit = [string]$assessment.repository.sourceCommit
    assessmentDigest = [string]$assessment.assessmentDigest
    operations = @($operations)
}
$planDigest = Get-RunbookContentDigest -InputObject $planProjection
$manifest = New-RunbookExecutionManifest -RunId $runId -Kind Workstation `
    -SourceCommit ([string]$assessment.repository.sourceCommit) -AssessmentDigest ([string]$assessment.assessmentDigest) `
    -TargetStableId ([string]$assessment.platform.stableId) -AuthenticationContext (Get-CurrentAuthenticationContext) `
    -AllowedActions @($executableOperations | ForEach-Object {
        [pscustomobject][ordered]@{
            action = [string]$_.action
            targetId = [string]$_.targetId
            packageSource = [string]$_.packageSource
            packageId = [string]$_.packageId
            scope = [string]$_.scope
            requiredVersion = [string]$_.requiredVersion
            expectedPostcondition = [string]$_.expectedPostcondition
        }
    }) -ToolVersions ([ordered]@{}) -GeneratedAtUtc $NowUtc

$planResult = [pscustomobject][ordered]@{
    schemaVersion = '1.0'
    mode = 'Preview'
    runId = $runId.ToString('D')
    reportDirectory = $reportDirectory
    planDigest = $planDigest
    manifestDigest = [string]$manifest.digest
    assessmentDigest = [string]$assessment.assessmentDigest
    executionManifestPath = (Join-Path $reportDirectory 'workstation-execution-manifest.json')
    operations = @($operations)
}

Write-CanonicalJson -InputObject $planResult -Path (Join-Path $reportDirectory 'workstation-plan.json') | Out-Null
Write-CanonicalJson -InputObject $manifest -Path (Join-Path $reportDirectory 'workstation-execution-manifest.json') | Out-Null

if (-not $Apply) {
    Write-Output ("Execution manifest digest: {0}" -f $manifest.digest)
    Write-Output ("Review '{0}' and approve '{1}' before Apply." -f (Join-Path $reportDirectory 'workstation-execution-manifest.json'), $manifest.digest)
    return $planResult
}

if ([string]::IsNullOrWhiteSpace($ExecutionManifestPath)) { throw 'Apply requires -ExecutionManifestPath.' }
if ([string]::IsNullOrWhiteSpace($ApprovedDigest)) { throw 'Apply requires -ApprovedDigest.' }
$manifestContent = Get-Content -Raw -LiteralPath $ExecutionManifestPath | ConvertFrom-Json
Test-RunbookExecutionManifest -Manifest $manifestContent -ApprovedDigest $ApprovedDigest `
    -CurrentSourceCommit ([string]$assessment.repository.sourceCommit) `
    -CurrentAssessmentDigest ([string]$assessment.assessmentDigest) `
    -CurrentAuthenticationContext (Get-CurrentAuthenticationContext) `
    -AllowedActionNames @($policy.allowedActions) -NowUtc $NowUtc | Out-Null
Assert-WorkstationStableId -Expected ([string]$manifestContent.target.stableId) -Actual ([string]$assessment.platform.stableId)
$approvedActions = Assert-AllowedPolicyActions -Manifest $manifestContent -Policy $policy
Show-RunbookChangeSummary -Operations @($approvedActions.Values) -Writer $SummaryWriter
$currentOperations = Get-PlannedOperations -Policy $policy -Assessment $assessment
$currentOperationMap = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
foreach ($operation in @($currentOperations)) {
    $currentOperationMap["$($operation.action)|$($operation.targetId)"] = $operation
}
$elevationState = Get-CurrentProcessElevationState

if (-not [bool]$assessment.repository.clean) {
    throw 'The current source commit is dirty and must be reassessed before Apply.'
}

$records = [Collections.Generic.List[object]]::new()
$toolVersions = [ordered]@{}

foreach ($action in @($manifestContent.allowedActions)) {
    $key = "$($action.action)|$($action.targetId)"
    $policyAction = $approvedActions[$key]
    $plannedOperation = $currentOperationMap[$key]
    $decision = 'Declined'
    $readBack = $null
    $status = 'Refused'
    $errorCategory = $null
    $recoveryItems = @()
    $classification = $(if ($null -ne $plannedOperation) { [string]$plannedOperation.classification } else { 'Create' })
    $hostTool = Get-HostToolRuntimeState -Assessment $assessment -ActionName ([string]$action.action)

    switch ([string]$action.action) {
        'WinGetInstallExact' {
            $arguments = @(
                'install', '--exact', '--id', $policyAction.packageId,
                '--source', $policyAction.packageSource, '--scope', $policyAction.scope
            )
            if ($null -ne $plannedOperation -and $plannedOperation.requiresElevation -and -not $elevationState.isElevated) {
                $decision = 'Approved'
                $status = 'Manual'
                $errorCategory = 'Elevation'
                $recoveryItems = @([pscustomobject][ordered]@{
                    service = 'WorkstationTooling'
                    targetId = [string]$policyAction.targetId
                    lastProvenState = 'The current token is not elevated for the reviewed machine-scope operation.'
                    safeDiagnostic = [string]$elevationState.reason
                    owner = 'Workstation administrator'
                    nextAction = 'Restart the attended run in an already elevated PowerShell session and generate a new approved manifest.'
                    requiresNewPlan = $true
                    requiresNewApproval = $true
                })
            }
            elseif ($PSCmdlet.ShouldProcess($policyAction.targetId, "Install exact WinGet package $($policyAction.packageId)")) {
                $decision = 'Approved'
                Assert-ExecutableStateUnchanged -ExpectedPath ([string]$hostTool.expectedPath) `
                    -ExpectedSha256 ([string]$hostTool.expectedSha256) -ExpectedVersion ([string]$hostTool.expectedVersion) `
                    -VersionArguments @($hostTool.versionArguments) -ToolId ([string]$hostTool.id) `
                    -CommandName 'winget.exe' -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider `
                    -Runner $NativeCommandRunner | Out-Null
                $nativeResult = Invoke-NativeCommand -Runner $NativeCommandRunner `
                    -FilePath ([string]$assessment.platform.packageManager.executablePath) `
                    -ArgumentList $arguments
                Update-RunbookProcessPath | Out-Null

                $toolPolicy = Get-ToolPolicyForAction -Policy $policy -Action $policyAction
                $resolved = Resolve-ExecutableIdentity -CommandName ([string]$toolPolicy.command) -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider
                if ($resolved.status -ne 'Ready') {
                    $status = 'Failed'
                    $errorCategory = 'ReadBack'
                    $recoveryItems = @([pscustomobject][ordered]@{
                        service = 'WorkstationTooling'
                        targetId = [string]$policyAction.targetId
                        lastProvenState = 'Package manager returned success but executable did not resolve uniquely.'
                        safeDiagnostic = [string]$resolved.diagnostic
                        owner = 'Workstation administrator'
                        nextAction = 'Reassess the workstation and generate a new approved manifest.'
                        requiresNewPlan = $true
                        requiresNewApproval = $true
                    })
                    $readBack = [pscustomobject][ordered]@{
                        service = 'WorkstationTooling'
                        targetId = [string]$policyAction.targetId
                        status = 'Failed'
                        expectedPostcondition = [string]$policyAction.expectedPostcondition
                    }
                }
                else {
                    $nativeReadBack = Invoke-NativeCommand -Runner $NativeCommandRunner -FilePath $resolved.path -ArgumentList @($toolPolicy.versionArguments)
                    $observedVersion = Get-ObservedVersion -ToolId ([string]$toolPolicy.id) -Result $nativeReadBack
                    $verified = ($nativeResult.exitCode -eq 0 -and $nativeReadBack.exitCode -eq 0 -and
                        (Test-VersionPolicy -ObservedVersion $observedVersion -VersionPolicy $toolPolicy.versionPolicy))
                    $status = $(if ($verified) { 'Verified' } else { 'Failed' })
                    $readBack = [pscustomobject][ordered]@{
                        service = 'WorkstationTooling'
                        targetId = [string]$policyAction.targetId
                        status = $status
                        expectedPostcondition = [string]$policyAction.expectedPostcondition
                        version = $observedVersion
                        path = $resolved.path
                        exitCode = [int]$nativeReadBack.exitCode
                    }
                    if ($verified) {
                        $toolVersions[[string]$toolPolicy.id] = $observedVersion
                    }
                    else {
                        $errorCategory = 'ReadBack'
                        $recoveryItems = @([pscustomobject][ordered]@{
                            service = 'WorkstationTooling'
                            targetId = [string]$policyAction.targetId
                            lastProvenState = 'Command returned without proving the reviewed postcondition.'
                            safeDiagnostic = [string]$policyAction.expectedPostcondition
                            owner = 'Workstation administrator'
                            nextAction = 'Reassess the workstation and generate a new approved manifest.'
                            requiresNewPlan = $true
                            requiresNewApproval = $true
                        })
                    }
                }
            }
            else {
                $decision = $(if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' })
                $status = 'Refused'
            }
        }
        'InstallPesterExact' {
            $arguments = @(
                '-NoProfile', '-Command',
                "Install-Module '$($policyAction.targetId)' -RequiredVersion '$($policyAction.requiredVersion)' -Repository '$($policyAction.packageSource)' -Scope '$($policyAction.scope)'"
            )
            $tool = @($assessment.tools | Where-Object { [string]$_.id -ceq 'WindowsPowerShell' }) | Select-Object -First 1
            if ($PSCmdlet.ShouldProcess(
                "$($policyAction.targetId) $($policyAction.requiredVersion)",
                "Install exact module from $($policyAction.packageSource) in $($policyAction.scope) scope"
            )) {
                $decision = 'Approved'
                Assert-ExecutableStateUnchanged -ExpectedPath ([string]$hostTool.expectedPath) `
                    -ExpectedSha256 ([string]$hostTool.expectedSha256) -ExpectedVersion ([string]$hostTool.expectedVersion) `
                    -VersionArguments @($hostTool.versionArguments) -ToolId ([string]$hostTool.id) `
                    -CommandName 'powershell.exe' -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider `
                    -Runner $NativeCommandRunner | Out-Null
                $nativeResult = Invoke-NativeCommand -Runner $NativeCommandRunner -FilePath ([string]$tool.executablePath) -ArgumentList $arguments
                $toolPolicy = Get-ToolPolicyForAction -Policy $policy -Action $policyAction
                $readBackResult = Invoke-NativeCommand -Runner $NativeCommandRunner -FilePath ([string]$tool.executablePath) -ArgumentList @($toolPolicy.versionArguments)
                $observedVersion = Get-ObservedVersion -ToolId ([string]$toolPolicy.id) -Result $readBackResult
                $verified = ($nativeResult.exitCode -eq 0 -and $readBackResult.exitCode -eq 0 -and
                    (Test-VersionPolicy -ObservedVersion $observedVersion -VersionPolicy $toolPolicy.versionPolicy))
                $status = $(if ($verified) { 'Verified' } else { 'Failed' })
                $readBack = [pscustomobject][ordered]@{
                    service = 'WorkstationTooling'
                    targetId = [string]$policyAction.targetId
                    status = $status
                    expectedPostcondition = [string]$policyAction.expectedPostcondition
                    version = $observedVersion
                    path = [string]$tool.executablePath
                    exitCode = [int]$readBackResult.exitCode
                }
                if (-not $verified) {
                    $failure = New-ReadBackFailure -Service 'WorkstationTooling' -TargetId ([string]$policyAction.targetId) `
                        -ExpectedPostcondition ([string]$policyAction.expectedPostcondition) -Diagnostic ([string]$policyAction.expectedPostcondition)
                    $errorCategory = [string]$failure.errorCategory
                    $recoveryItems = @($failure.recoveryItems)
                    $readBack = $failure.readBack
                }
            }
            else {
                $decision = $(if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' })
            }
        }
        'InstallBicepComponent' {
            $tool = @($assessment.tools | Where-Object { [string]$_.id -ceq 'AzureCli' }) | Select-Object -First 1
            if ($PSCmdlet.ShouldProcess('Azure CLI Bicep component', 'Install')) {
                $decision = 'Approved'
                Assert-ExecutableStateUnchanged -ExpectedPath ([string]$hostTool.expectedPath) `
                    -ExpectedSha256 ([string]$hostTool.expectedSha256) -ExpectedVersion ([string]$hostTool.expectedVersion) `
                    -VersionArguments @($hostTool.versionArguments) -ToolId ([string]$hostTool.id) `
                    -CommandName 'az.cmd' -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider `
                    -Runner $NativeCommandRunner | Out-Null
                $nativeResult = Invoke-NativeCommand -Runner $NativeCommandRunner -FilePath ([string]$tool.executablePath) -ArgumentList @('bicep', 'install')
                $toolPolicy = Get-ToolPolicyForAction -Policy $policy -Action $policyAction
                $readBackResult = Invoke-NativeCommand -Runner $NativeCommandRunner -FilePath ([string]$tool.executablePath) -ArgumentList @($toolPolicy.versionArguments)
                $observedVersion = Get-ObservedVersion -ToolId ([string]$toolPolicy.id) -Result $readBackResult
                $verified = ($nativeResult.exitCode -eq 0 -and $readBackResult.exitCode -eq 0 -and
                    (Test-VersionPolicy -ObservedVersion $observedVersion -VersionPolicy $toolPolicy.versionPolicy))
                $status = $(if ($verified) { 'Verified' } else { 'Failed' })
                $readBack = [pscustomobject][ordered]@{
                    service = 'WorkstationTooling'
                    targetId = [string]$policyAction.targetId
                    status = $status
                    expectedPostcondition = [string]$policyAction.expectedPostcondition
                    version = $observedVersion
                    path = [string]$tool.executablePath
                    exitCode = [int]$readBackResult.exitCode
                }
                if (-not $verified) {
                    $failure = New-ReadBackFailure -Service 'WorkstationTooling' -TargetId ([string]$policyAction.targetId) `
                        -ExpectedPostcondition ([string]$policyAction.expectedPostcondition) -Diagnostic ([string]$policyAction.expectedPostcondition)
                    $errorCategory = [string]$failure.errorCategory
                    $recoveryItems = @($failure.recoveryItems)
                    $readBack = $failure.readBack
                }
            }
            else {
                $decision = $(if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' })
            }
        }
        'InstallAzureCliExtensionExact' {
            $tool = @($assessment.tools | Where-Object { [string]$_.id -ceq 'AzureCli' }) | Select-Object -First 1
            if ($PSCmdlet.ShouldProcess('azure-devops', 'Install exact Azure CLI extension')) {
                $decision = 'Approved'
                Assert-ExecutableStateUnchanged -ExpectedPath ([string]$hostTool.expectedPath) `
                    -ExpectedSha256 ([string]$hostTool.expectedSha256) -ExpectedVersion ([string]$hostTool.expectedVersion) `
                    -VersionArguments @($hostTool.versionArguments) -ToolId ([string]$hostTool.id) `
                    -CommandName 'az.cmd' -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider `
                    -Runner $NativeCommandRunner | Out-Null
                $nativeResult = Invoke-NativeCommand -Runner $NativeCommandRunner -FilePath ([string]$tool.executablePath) -ArgumentList @('extension', 'add', '--name', $policyAction.targetId)
                $extensionState = Get-AzureCliExtensionReadBack -ExtensionName ([string]$policyAction.targetId) `
                    -ToolAssessments @($assessment.tools) -Runner $NativeCommandRunner
                $verified = ($nativeResult.exitCode -eq 0 -and $extensionState.status -eq 'Ready')
                $status = $(if ($verified) { 'Verified' } else { 'Failed' })
                $readBack = [pscustomobject][ordered]@{
                    service = 'AzureCliExtension'
                    targetId = [string]$policyAction.targetId
                    status = $status
                    expectedPostcondition = [string]$policyAction.expectedPostcondition
                    version = [string]$extensionState.version
                }
                if (-not $verified) {
                    $failure = New-ReadBackFailure -Service 'AzureCliExtension' -TargetId ([string]$policyAction.targetId) `
                        -ExpectedPostcondition ([string]$policyAction.expectedPostcondition) -Diagnostic ([string]$policyAction.expectedPostcondition)
                    $errorCategory = [string]$failure.errorCategory
                    $recoveryItems = @($failure.recoveryItems)
                    $readBack = $failure.readBack
                }
            }
            else {
                $decision = $(if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' })
            }
        }
        'InstallVsCodeExtensionExact' {
            $tool = @($assessment.tools | Where-Object { [string]$_.id -ceq 'VisualStudioCode' }) | Select-Object -First 1
            if ($PSCmdlet.ShouldProcess($policyAction.targetId, 'Install reviewed VS Code extension')) {
                $decision = 'Approved'
                Assert-ExecutableStateUnchanged -ExpectedPath ([string]$hostTool.expectedPath) `
                    -ExpectedSha256 ([string]$hostTool.expectedSha256) -ExpectedVersion ([string]$hostTool.expectedVersion) `
                    -VersionArguments @($hostTool.versionArguments) -ToolId ([string]$hostTool.id) `
                    -CommandName 'code.cmd' -Resolver $CommandResolver -IdentityProvider $FileIdentityProvider `
                    -Runner $NativeCommandRunner | Out-Null
                $nativeResult = Invoke-NativeCommand -Runner $NativeCommandRunner -FilePath ([string]$tool.executablePath) -ArgumentList @('--install-extension', $policyAction.targetId)
                $extensionState = Get-VsCodeExtensionReadBack -ExtensionId ([string]$policyAction.targetId) `
                    -ToolAssessments @($assessment.tools) -Runner $NativeCommandRunner
                $verified = ($nativeResult.exitCode -eq 0 -and $extensionState.status -eq 'Ready')
                $status = $(if ($verified) { 'Verified' } else { 'Failed' })
                $readBack = [pscustomobject][ordered]@{
                    service = 'VsCodeExtension'
                    targetId = [string]$policyAction.targetId
                    status = $status
                    expectedPostcondition = [string]$policyAction.expectedPostcondition
                }
                if (-not $verified) {
                    $failure = New-ReadBackFailure -Service 'VsCodeExtension' -TargetId ([string]$policyAction.targetId) `
                        -ExpectedPostcondition ([string]$policyAction.expectedPostcondition) -Diagnostic ([string]$policyAction.expectedPostcondition)
                    $errorCategory = [string]$failure.errorCategory
                    $recoveryItems = @($failure.recoveryItems)
                    $readBack = $failure.readBack
                }
            }
            else {
                $decision = $(if ($WhatIfPreference) { 'WhatIf' } else { 'Declined' })
            }
        }
        default {
            throw "Execution manifest contains an unallowlisted action: $($action.action)"
        }
    }

    [void]$records.Add((New-EvidenceRecord -RunId $runId -GeneratedAtUtc $NowUtc `
        -SourceCommit ([string]$assessment.repository.sourceCommit) -AssessmentDigest ([string]$assessment.assessmentDigest) `
        -PlanDigest $planDigest -ManifestDigest ([string]$manifestContent.digest) -OperatorId ([string]$assessment.platform.stableId) `
        -Operation ([string]$action.action) -Classification $classification -Status $status `
        -ShouldProcessDecision $decision -TargetId ([string]$action.targetId) -ToolVersions $toolVersions `
        -ReadBack $readBack -FinalContext (Get-FinalWorkstationContext) -RecoveryItems $recoveryItems -ErrorCategory $errorCategory))

    if ($status -eq 'Failed') {
        break
    }
}

$applyResult = [pscustomobject][ordered]@{
    schemaVersion = '1.0'
    mode = 'Apply'
    runId = $runId.ToString('D')
    planDigest = $planDigest
    manifestDigest = [string]$manifestContent.digest
    assessmentDigest = [string]$assessment.assessmentDigest
    operations = @($records)
}

Write-CanonicalJson -InputObject $applyResult -Path (Join-Path $reportDirectory 'workstation-evidence.json') | Out-Null
$applyResult
