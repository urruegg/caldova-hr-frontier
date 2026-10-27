function Get-WorkstationBootstrapModule {
    $path = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'))
    $loaded = @(Get-Module -Name Caldova.HrFrontier.Bootstrap | Where-Object {
        $_.Path -ieq [IO.Path]::ChangeExtension($path, '.psm1')
    })
    if ($loaded.Count -eq 1) { return $loaded[0] }
    Import-Module -Name $path -PassThru -ErrorAction Stop
}

function ConvertFrom-WorkstationStrictJson {
    param([string]$Text)
    & (Get-WorkstationBootstrapModule) {
        param([string]$raw)
        if ([string]::IsNullOrWhiteSpace($raw) -or $raw.TrimStart()[0] -ne '{') {
            throw [IO.InvalidDataException]::new('Expected a JSON object.')
        }
        Assert-TenantLifecycleJsonHasUniqueProperties -Text $raw -RejectCaseAliases
        $value = ConvertFrom-TenantLifecycleJson -InputObject $raw
        if ($null -eq $value -or $value -is [array] -or $value -is [string] -or $value.GetType().IsPrimitive) {
            throw [IO.InvalidDataException]::new('Expected a JSON object.')
        }
        $value
    } $Text
}

function Assert-WorkstationArray {
    param([AllowNull()][object]$Value, [int]$MinimumCount = 0, [switch]$Strings)
    & (Get-WorkstationBootstrapModule) {
        param([object]$raw, [int]$minimum, [bool]$stringsOnly)
        if ($stringsOnly) { Assert-TenantLifecycleStringArray -Value $raw -MinimumCount $minimum }
        else { Assert-TenantLifecycleArray -Value $raw -MinimumCount $minimum }
    } $Value $MinimumCount ([bool]$Strings)
}

function Invoke-NativeCommand {
    param([scriptblock]$Runner, [string]$FilePath, [string[]]$ArgumentList)
    $result = & $Runner $FilePath $ArgumentList
    if ($null -eq $result -or $result.PSObject.Properties.Name -notcontains 'exitCode') {
        return [pscustomobject]@{ exitCode = 1; stdout = @(); stderr = @('runner returned no exit contract') }
    }
    [pscustomobject]@{
        exitCode = [int]$result.exitCode
        stdout = @($result.stdout | ForEach-Object { [string]$_ })
        stderr = @($result.stderr | ForEach-Object { [string]$_ })
    }
}

function New-DefaultNativeCommandRunner {
    {
        param([string]$FilePath, [string[]]$ArgumentList)
        $arguments = @($ArgumentList)
        if ((Split-Path -Leaf $FilePath) -in @('powershell.exe', 'pwsh.exe')) {
            for ($index = 0; $index -lt $arguments.Count; $index++) {
                if ($arguments[$index] -in @('-Command', '--Command') -and $index -eq $arguments.Count - 2) {
                    $arguments[$index] = '-EncodedCommand'
                    $arguments[$index + 1] = [Convert]::ToBase64String(
                        [Text.Encoding]::Unicode.GetBytes($arguments[$index + 1]))
                }
            }
        }
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& $FilePath @arguments 2>&1 | ForEach-Object { $_.ToString() })
            $exitCode = [int]$LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        [pscustomobject]@{ exitCode = $exitCode; stdout = $output; stderr = @() }
    }
}

function New-DefaultCommandResolver {
    {
        param($name)
        $paths = @(Get-Command $name -All -CommandType Application -ErrorAction SilentlyContinue |
            ForEach-Object Source)
        if ($name -ceq 'bicep.exe') {
            $known = Join-Path $env:USERPROFILE '.azure\bin\bicep.exe'
            if (Test-Path -LiteralPath $known -PathType Leaf) { $paths += $known }
        }
        @($paths | Sort-Object -Unique)
    }
}

function Read-WorkstationReparseMetadata {
    param([string]$Path, [scriptblock]$Runner)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return [pscustomobject]@{ tag = [uint32]0; fields = @() }
    }
    if ($null -eq $Runner) { $Runner = New-DefaultNativeCommandRunner }
    $native = & $Runner (Join-Path ([Environment]::SystemDirectory) 'fsutil.exe') @(
        'reparsepoint', 'query', $item.FullName)
    if ($native.exitCode -ne 0) { throw 'Reparse metadata cannot be proven.' }
    $tags = @($native.stdout | ForEach-Object {
        if ($_ -match '(?i)^Reparse Tag Value\s*:\s*0x([0-9a-f]{8})\s*$') { [Convert]::ToUInt32($Matches[1], 16) }
    })
    if ($tags.Count -ne 1) { throw 'Unknown reparse metadata format.' }
    $fields = @()
    if ($tags[0] -eq [Convert]::ToUInt32('8000001b', 16)) {
        $bytes = [Collections.Generic.List[byte]]::new()
        foreach ($line in $native.stdout) {
            if ($line -match '^\s*[0-9a-fA-F]{4,8}:\s+((?:[0-9a-fA-F]{2}\s+){1,16})') {
                foreach ($byte in ($Matches[1].Trim() -split '\s+')) { $bytes.Add([Convert]::ToByte($byte, 16)) }
            }
        }
        if ($bytes.Count -lt 6 -or [BitConverter]::ToUInt32($bytes.ToArray(), 0) -ne 3) {
            throw 'Unsupported AppExecutionAlias metadata.'
        }
        $fields = @(([Text.Encoding]::Unicode.GetString($bytes.ToArray(), 4, $bytes.Count - 4)).Split([char]0) |
            Where-Object { $_ })
    }
    [pscustomobject]@{ tag = $tags[0]; fields = $fields }
}

function Assert-WorkstationPhysicalPath {
    param([string]$Path, [scriptblock]$MetadataReader, [scriptblock]$Runner)
    if ($null -eq $MetadataReader) { $MetadataReader = ${function:Read-WorkstationReparseMetadata} }
    if ($null -eq $Runner) { $Runner = New-DefaultNativeCommandRunner }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            $metadata = & $MetadataReader $item.FullName $Runner
            # Hydrated Cloud Files tags are non-name-surrogate metadata, not path redirections.
            if (([uint64]$metadata.tag -band [Convert]::ToUInt32('ffff0fff', 16)) -ne
                [Convert]::ToUInt32('9000001a', 16) -or
                ([int64]$item.Attributes -band 4460544) -ne 0) {
                throw 'Redirecting, offline or unreviewed reparse path refused.'
            }
        }
        $item = if ($item -is [IO.DirectoryInfo]) { $item.Parent } else { $item.Directory }
    }
}

function New-DefaultFileIdentityProvider {
    param([object]$CompatibilityRecord)
    $record = $CompatibilityRecord
    if ($null -eq $record) {
        $record = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText(
            (Join-Path $PSScriptRoot '..\..\config\runbooks\workstation-compatibility.json')))
        Assert-WorkstationCompatibilityRecord $record
    }
    $powerShell = @($record.components | Where-Object id -CEQ PowerShell7)[0]
    $metadataReader = ${function:Read-WorkstationReparseMetadata}
    $physicalPathValidator = ${function:Assert-WorkstationPhysicalPath}
    $metadataRunner = New-DefaultNativeCommandRunner
    $expectedTarget = Join-Path $env:ProgramFiles ('WindowsApps\Microsoft.PowerShell_' +
        $powerShell.version + '.0_x64__8wekyb3d8bbwe\pwsh.exe')
    {
        param($path)
        $canonical = [IO.Path]::GetFullPath($path)
        $aliasRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\'
        if ($canonical.StartsWith($aliasRoot, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $canonical) -ieq 'pwsh.exe') {
            $approvedAliases = @(
                (Join-Path $aliasRoot 'pwsh.exe'),
                (Join-Path $aliasRoot 'Microsoft.PowerShell_8wekyb3d8bbwe\pwsh.exe')
            )
            if ($canonical -notin $approvedAliases) { throw 'Unreviewed PowerShell execution alias.' }
            $metadata = & $metadataReader $canonical $metadataRunner
            if ($metadata.tag -ne [Convert]::ToUInt32('8000001b', 16) -or $metadata.fields.Count -ne 4 -or
                $metadata.fields[0] -cne 'Microsoft.PowerShell_8wekyb3d8bbwe' -or
                $metadata.fields[1] -cne 'Microsoft.PowerShell_8wekyb3d8bbwe!App' -or
                $metadata.fields[2] -ine $expectedTarget -or $metadata.fields[3] -cne '0') {
                throw 'AppExecutionAlias package binding is unproven.'
            }
            $canonical = $expectedTarget
        }
        if ((Split-Path -Leaf $canonical) -ieq 'pwsh.exe') {
            if ($canonical -ine $expectedTarget) { throw 'Unreviewed physical PowerShell target.' }
            $manifestPath = Join-Path (Split-Path $expectedTarget -Parent) 'AppxManifest.xml'
            & $physicalPathValidator $manifestPath $metadataReader $metadataRunner
            if ((Get-FileHash -LiteralPath $manifestPath).Hash.ToLowerInvariant() -cne $powerShell.appxManifestSha256) {
                throw 'Store package manifest changed.'
            }
            [xml]$manifest = [IO.File]::ReadAllText($manifestPath)
            $applications = @($manifest.SelectNodes('//*[local-name()="Application"]') | Where-Object {
                $_.Id -ceq 'App' -and $_.Executable -ceq 'pwsh.exe'
            })
            if ($applications.Count -ne 1) { throw 'Store application executable binding is unproven.' }
            if ((Get-FileHash -LiteralPath $canonical).Hash.ToLowerInvariant() -cne $powerShell.sha256) {
                throw 'Unreviewed physical PowerShell target.'
            }
        }
        $item = Get-Item -LiteralPath $canonical -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Unreviewed executable reparse point.'
        }
        [pscustomobject]@{
            path = $item.FullName
            sha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }.GetNewClosure()
}

function Get-ObservedVersion {
    param([string]$ToolId, [object]$Result)
    $lines = @($Result.stdout | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    if ($ToolId -in @('VisualStudioCode', 'AzureDeveloperCli', 'GitHubCopilotCli', 'WinGet')) {
        $match = [regex]::Match(($lines -join "`n"), '([0-9]+(?:\.[0-9]+)+)')
        if ($match.Success) { return $match.Groups[1].Value }
        return $null
    }
    if ($ToolId -eq 'AzureCli') {
        try {
            $json = ($lines -join "`n") | ConvertFrom-Json
            $value = [string]$json.'azure-cli'
            if ($value -cmatch '^\d+\.\d+\.\d+$') { return $value }
        } catch { }
        return $null
    }
    $pattern = switch ($ToolId) {
        'Git' { '^git version (\d+\.\d+\.\d+\.windows\.\d+)$' }
        'GitHubCli' { '^gh version (\d+\.\d+\.\d+) \(\d{4}-\d{2}-\d{2}\)$' }
        'PowerPlatformCli' { '^Version:\s*(\d+\.\d+\.\d+\+g[0-9a-f]+)(?: \(\.NET \d+\.\d+\.\d+\))?$' }
        'Bicep' { '^Bicep CLI version (\d+\.\d+\.\d+) \([0-9a-f]+\)$' }
        'WindowsPowerShell' { '^(\d+\.\d+\.\d+\.\d+)$' }
        default { '^(\d+\.\d+\.\d+)$' }
    }
    $matchesFound = @(
        foreach ($line in $lines) {
            $match = [regex]::Match($line, $pattern)
            if ($match.Success) { $match.Groups[1].Value }
        }
    )
    if ($matchesFound.Count -eq 1) { return $matchesFound[0] }
    return $null
}

function Test-VersionPolicy {
    param([AllowNull()][string]$ObservedVersion, [object]$VersionPolicy)
    if ([string]::IsNullOrWhiteSpace($ObservedVersion)) { return $false }
    switch ([string]$VersionPolicy.mode) {
        'Exact' { return [string]$VersionPolicy.value -ceq $ObservedVersion }
        'Present' { return $true }
        default { return $false }
    }
}

function Get-WorkstationPesterInstallationRoot {
    param([string]$Id)
    $family = switch -CaseSensitive ($Id) {
        'CurrentUserWindowsPowerShell' { 'WindowsPowerShell' }
        'CurrentUserPowerShell' { 'PowerShell' }
        default { throw 'Unreviewed module installation source.' }
    }
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) ($family + '\Modules\Pester\5.7.1')
}

function Assert-WorkstationPesterInstallation {
    param([object]$Installation)
    $root = Get-WorkstationPesterInstallationRoot $Installation.id
    Assert-WorkstationPhysicalPath $root
    $actual = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force | Where-Object {
        $_.FullName.Substring($root.Length + 1) -cne 'PSGetModuleInfo.xml'
    })
    if ($actual.Count -ne $Installation.files.Count) { throw 'Module package inventory changed.' }
    foreach ($file in $Installation.files) {
        if ($file.path -cnotmatch '^[A-Za-z0-9_.-]+(?:\\[A-Za-z0-9_.-]+)*$' -or
            $file.path -match '(^|\\)\.\.?(\\|$)') { throw 'Invalid module payload path.' }
        $path = Join-Path $root $file.path
        Assert-WorkstationPhysicalPath $path
        if ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $file.sha256) {
            throw 'Module payload changed before import.'
        }
    }
    $root
}

function Invoke-WorkstationTrustedHostProbe {
    param([object]$Installation)
    $root = Assert-WorkstationPesterInstallation $Installation
    $p = Import-Module -Name (Join-Path $root 'Pester.psd1') -Force -PassThru -ErrorAction Stop
    [pscustomobject]@{
        ps = $PSVersionTable.PSVersion.ToString()
        arch = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        windows = ([Environment]::OSVersion.Platform -eq 'Win32NT')
        build = [Environment]::OSVersion.Version.Build
        compat = (Get-Command Import-Module).Parameters.ContainsKey('UseWindowsPowerShell')
        pester = $p.Version.ToString()
        modulePath = $p.Path
        moduleSha256 = (Get-FileHash -LiteralPath $p.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Get-WorkstationHostProbeCommand {
    param([object]$PesterRecord, [ValidateSet('WindowsPowerShell', 'PowerShell7')][string]$HostId = 'WindowsPowerShell')
    if ($null -eq $PesterRecord) {
        $record = ConvertFrom-WorkstationStrictJson ([IO.File]::ReadAllText(
            (Join-Path $PSScriptRoot '..\..\config\runbooks\workstation-compatibility.json')))
        Assert-WorkstationCompatibilityRecord $record
        $PesterRecord = @($record.components | Where-Object id -CEQ Pester)[0]
    }
    $id = if ($HostId -eq 'WindowsPowerShell') { 'CurrentUserWindowsPowerShell' } else { 'CurrentUserPowerShell' }
    $installation = @($PesterRecord.installations | Where-Object id -CEQ $id)[0]
    $data = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
        (ConvertTo-Json -InputObject $installation -Depth 20 -Compress)))
    $helperPath = (Join-Path $PSScriptRoot 'WorkstationTools.ps1').Replace("'", "''")
    @"
`$ErrorActionPreference='Stop'
`$ProgressPreference='SilentlyContinue'
. '$helperPath'
`$installation=ConvertFrom-WorkstationStrictJson ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$data')))
Invoke-WorkstationTrustedHostProbe -Installation `$installation | ConvertTo-Json -Compress
"@
}

function Resolve-ExecutableIdentity {
    param([string]$CommandName, [scriptblock]$Resolver, [scriptblock]$IdentityProvider)
    $unique = @{}
    try {
        foreach ($candidate in @(& $Resolver $CommandName)) {
            $identity = & $IdentityProvider $candidate
            $path = [IO.Path]::GetFullPath([string]$identity.path)
            $hash = [string]$identity.sha256
            if ($hash -notmatch '^[0-9a-fA-F]{64}$') { throw 'Invalid executable hash.' }
            $unique[($path.ToLowerInvariant() + '|' + $hash.ToLowerInvariant())] = $identity
        }
    } catch {
        return [pscustomobject]@{ status = 'Blocked'; path = $null; sha256 = $null; diagnostic = 'Executable identity is unproven.' }
    }
    if ($unique.Count -ne 1) {
        return [pscustomobject]@{ status = $(if ($unique.Count -eq 0) { 'Missing' } else { 'Blocked' })
            path = $null; sha256 = $null; diagnostic = 'Executable missing or physically ambiguous.' }
    }
    $identity = @($unique.Values)[0]
    [pscustomobject]@{ status = 'Ready'; path = $identity.path; sha256 = $identity.sha256; diagnostic = $null }
}

function Assert-WorkstationDeliveryPolicy {
    param([object]$Policy, [object]$Record, [string]$SchemaPath)
    Assert-WorkstationProperties $Policy @('$schema', 'schemaVersion', 'compatibilityRecord', 'platform',
        'interactiveAuthentication', 'tools', 'azureCliExtensions', 'vsCodeExtensions', 'repositoryAssets', 'allowedActions')
    Assert-WorkstationProperties $Policy.platform @('productName', 'minimumBuild')
    if ($Policy.schemaVersion -isnot [string] -or $Policy.platform.productName -isnot [string]) { throw 'Platform/schema names must be strings.' }
    if ($Policy.platform.minimumBuild -isnot [int] -and $Policy.platform.minimumBuild -isnot [long]) { throw 'Platform build must be an integer.' }
    if ($Policy.schemaVersion -cne '1.0' -or $Policy.platform.productName -cne 'Windows 11' -or
        $Policy.platform.minimumBuild -lt 22000) { throw 'Unreviewed platform contract.' }
    $auth = $Policy.interactiveAuthentication
    Assert-WorkstationProperties $auth @('executionHost', 'allowUnattendedExecution', 'allowOidcWorkloadIdentity',
        'allowCredentialParameters', 'methods')
    foreach ($name in 'allowUnattendedExecution', 'allowOidcWorkloadIdentity', 'allowCredentialParameters') {
        if ($auth.$name -isnot [bool]) { throw 'Authentication flags must be JSON booleans.' }
    }
    foreach ($name in 'tools', 'azureCliExtensions', 'vsCodeExtensions', 'repositoryAssets', 'allowedActions') {
        Assert-WorkstationArray -Value $Policy.$name
    }
    Assert-WorkstationArray -Value $auth.methods
    if ($auth.executionHost -cne 'InteractiveWindows11PowerShell' -or $auth.allowUnattendedExecution -or
        $auth.allowOidcWorkloadIdentity -or $auth.allowCredentialParameters -or @($auth.methods).Count -ne 4) {
        throw 'Authentication boundary changed.'
    }
    foreach ($method in $auth.methods) {
        Assert-WorkstationProperties $method @('service', 'mode', 'loginCommand', 'readBackCommand', 'cleanupCommands')
        foreach ($name in 'service', 'mode', 'loginCommand', 'readBackCommand') {
            if ($method.$name -isnot [string]) { throw 'Authentication declarations must be strings.' }
        }
        Assert-WorkstationArray -Value $method.cleanupCommands -MinimumCount 1 -Strings
    }
    if ((@($Policy.tools.id) -join '|') -cne
        'PowerShell7|WindowsPowerShell|Git|VisualStudioCode|GitHubCli|AzureCli|AzureDeveloperCli|PowerPlatformCli|Bicep|Pester|GitHubCopilotCli') {
        throw 'Tool allowlist changed.'
    }
    if (@($Policy.azureCliExtensions).Count -ne 1) { throw 'Extension allowlist changed.' }
    Assert-WorkstationProperties $Policy.azureCliExtensions[0] @('name', 'versionPolicy', 'installDisposition', 'reference')
    Assert-WorkstationProperties $Policy.azureCliExtensions[0].versionPolicy @('mode', 'value')
    if ($Policy.azureCliExtensions[0].name -cne 'azure-devops' -or
        $Policy.azureCliExtensions[0].installDisposition -cne 'Automated' -or
        $Policy.azureCliExtensions[0].reference -cne 'https://learn.microsoft.com/en-us/azure/devops/cli/') {
        throw 'Extension source contract changed.'
    }
    if ((@($Policy.vsCodeExtensions.id) -join '|') -cne
        'ms-vscode.PowerShell|ms-azuretools.vscode-bicep|ms-azuretools.azure-dev|microsoft-IsvExpTools.powerplatform-vscode|GitHub.copilot') {
        throw 'Editor extension allowlist changed.'
    }
    foreach ($extension in $Policy.vsCodeExtensions) {
        Assert-WorkstationProperties $extension @('id', 'installDisposition')
        if ($extension.installDisposition -cne 'Recommended') { throw 'Editor extension disposition changed.' }
    }
    if (@($Policy.repositoryAssets).Count -ne 3) { throw 'Repository assets changed.' }
    foreach ($asset in $Policy.repositoryAssets) {
        Assert-WorkstationProperties $asset @('kind', 'path', 'expected', 'installDisposition')
    }
    if ((@($Policy.allowedActions) -join '|') -cne
        'WinGetInstallExact|InstallPesterExact|InstallBicepComponent|InstallAzureCliExtensionExact|InstallVsCodeExtensionExact') {
        throw 'Allowed actions changed.'
    }
    if ($Policy.compatibilityRecord -cne 'workstation-compatibility.json') { throw 'Unreviewed compatibility reference.' }
    $schema = Get-Content -Raw -LiteralPath $SchemaPath | ConvertFrom-Json
    foreach ($component in $Record.components) {
        $items = @(if ($component.id -ceq 'azure-devops') { @($Policy.azureCliExtensions) } else {
            @($Policy.tools | Where-Object { $_.id -ceq $component.id })
        })
        if ($items.Count -ne 1 -or $items[0].versionPolicy.mode -cne 'Exact' -or
            $items[0].versionPolicy.value -cne $component.version) { throw 'Policy/compatibility version mismatch.' }
    }
    foreach ($tool in $Policy.tools) {
        Assert-WorkstationArray -Value $tool.versionArguments -MinimumCount 1 -Strings
        if ($tool.install.PSObject.Properties.Name -contains 'arguments') {
            Assert-WorkstationArray -Value $tool.install.arguments -MinimumCount 1 -Strings
        }
        $contracts = @($schema.'$defs'.tool.oneOf | Where-Object { $_.properties.id.const -ceq $tool.id })
        if ($contracts.Count -ne 1) { throw 'Unreviewed tool contract.' }
        Assert-WorkstationProperties $tool @('id', 'command', 'versionArguments', 'versionPolicy', 'installDisposition', 'install', 'reference')
        foreach ($property in $contracts[0].properties.PSObject.Properties) {
            if ($property.Value.PSObject.Properties.Name -contains 'const') {
                if ((ConvertTo-Json -InputObject $tool.($property.Name) -Depth 20 -Compress) -cne
                    (ConvertTo-Json -InputObject $property.Value.const -Depth 20 -Compress)) {
                    throw 'Policy tool command, source or parser contract changed.'
                }
            }
        }
    }
}

function Assert-WorkstationX64Executable {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $reader = [IO.BinaryReader]::new($stream)
        $stream.Position = 0x3c
        $offset = $reader.ReadInt32()
        $stream.Position = $offset + 4
        if ($reader.ReadUInt16() -ne 0x8664) { throw 'Unreviewed executable architecture.' }
    } finally { $stream.Dispose() }
}

function Assert-WorkstationProperties {
    param([object]$Value, [string[]]$Names)
    & (Get-WorkstationBootstrapModule) {
        param([object]$raw, [string[]]$fields)
        Assert-TenantLifecycleProperties -InputObject $raw -Fields $fields
    } $Value $Names
}

function Assert-WorkstationCompatibilityRecord {
    param([object]$Record)
    Assert-WorkstationProperties $Record @('$schema', 'schemaVersion', 'review', 'components')
    if ($Record.'$schema' -isnot [string] -or $Record.schemaVersion -isnot [string]) { throw 'Schema declarations must be strings.' }
    Assert-WorkstationArray -Value $Record.components -MinimumCount 9
    if ($Record.schemaVersion -cne '1.0') { throw 'Unsupported compatibility schema.' }
    Assert-WorkstationProperties $Record.review @('kind', 'reviewer', 'reviewedAtUtc', 'isApproval', 'scope')
    foreach ($name in 'kind', 'reviewer', 'reviewedAtUtc', 'scope') {
        if ($Record.review.$name -isnot [string]) { throw 'Review declarations must be strings.' }
    }
    if ($Record.review.kind -cne 'AutomatedTechnicalReview' -or $Record.review.reviewer -cne 'GitHub Copilot' -or
        $Record.review.isApproval -isnot [bool] -or $Record.review.isApproval -or
        [string]::IsNullOrWhiteSpace($Record.review.scope)) { throw 'Technical review is not human approval.' }
    $null = [datetime]::Parse([string]$Record.review.reviewedAtUtc, [Globalization.CultureInfo]::InvariantCulture)
    $sources = @{
        PowerShell7 = 'MicrosoftStore'; WindowsPowerShell = 'WindowsComponent'
        Git = 'GitForWindowsRelease'; GitHubCli = 'GitHubCliRelease'; AzureCli = 'AzureCliMsi'
        Bicep = 'AzureCliBicepComponent'; 'azure-devops' = 'AzureCliExtension'
        PowerPlatformCli = 'DotNetTool'; Pester = 'PowerShellGallery'
    }
    $capabilities = @{
        PowerShell7 = @('WindowsX64Host', 'WindowsCompatibilityParameter', 'Pester571Import')
        WindowsPowerShell = @('WindowsX64Host', 'Pester571Import')
        Git = @('WorktreeHelp'); GitHubCli = @('RepositoryJsonHelp')
        AzureCli = @('VersionJson', 'BundledPythonX64'); Bicep = @('BuildHelp')
        'azure-devops' = @('InstalledExtensionMetadata', 'DevopsHelp')
        PowerPlatformCli = @('PackHelp', 'UnpackHelp', 'DeclaredWebResourceRoundTrip')
        Pester = @('ExactModuleImport')
    }
    if (@($Record.components).Count -ne 9 -or @($Record.components.id | Sort-Object -Unique).Count -ne 9) {
        throw 'Exactly nine unique delivery components are required.'
    }
    foreach ($component in $Record.components) {
        $properties = @('id', 'version', 'source', 'architecture', 'sha256', 'capabilities', 'references')
        if ($component.id -in @('AzureCli', 'PowerPlatformCli')) { $properties += 'payloads' }
        if ($component.id -ceq 'PowerShell7') { $properties += 'appxManifestSha256' }
        if ($component.id -ceq 'Pester') { $properties += 'installations' }
        Assert-WorkstationProperties $component $properties
        foreach ($name in 'id', 'version', 'source', 'architecture', 'sha256') {
            if ($component.$name -isnot [string]) { throw 'Component fields must be JSON strings.' }
        }
        Assert-WorkstationArray -Value $component.capabilities -MinimumCount 1 -Strings
        Assert-WorkstationArray -Value $component.references -MinimumCount 1 -Strings
        if ($component.id -ceq 'PowerShell7' -and $component.appxManifestSha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw 'Unproven Store package manifest.'
        }
        if ($component.id -ceq 'Pester') {
            Assert-WorkstationArray -Value $component.installations -MinimumCount 2
            if (($component.installations.id -join '|') -cne 'CurrentUserWindowsPowerShell|CurrentUserPowerShell') {
                throw 'Unreviewed Pester installation roots.'
            }
            foreach ($installation in $component.installations) {
                Assert-WorkstationProperties $installation @('id', 'files')
                Assert-WorkstationArray -Value $installation.files -MinimumCount 18
                if ($installation.files.Count -ne 18 -or @($installation.files.path | Sort-Object -Unique).Count -ne 18) {
                    throw 'Incomplete Pester source inventory.'
                }
                foreach ($file in $installation.files) {
                    Assert-WorkstationProperties $file @('path', 'sha256')
                    if ($file.path -isnot [string] -or $file.sha256 -isnot [string] -or
                        $file.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
                        $file.path -cnotmatch '^[A-Za-z0-9_.-]+(?:\\[A-Za-z0-9_.-]+)*$' -or
                        $file.path -match '(^|\\)\.\.?(\\|$)') { throw 'Invalid Pester payload pin.' }
                }
                $module = @($installation.files | Where-Object path -CEQ Pester.psm1)
                if ($module.Count -ne 1 -or $module[0].sha256 -cne $component.sha256 -or
                    @($installation.files | Where-Object path -CEQ Pester.psd1).Count -ne 1) {
                    throw 'Pester executable/manifest source pins missing.'
                }
            }
        }
        if ($component.id -in @('AzureCli', 'PowerPlatformCli')) {
            Assert-WorkstationArray -Value $component.payloads -MinimumCount 1
            $expectedPayloads = if ($component.id -eq 'AzureCli') { 'AzureCliPython' } else { 'PacAssembly|SolutionPackagerAssembly' }
            if ((@($component.payloads.id) -join '|') -cne $expectedPayloads) { throw 'Principal source payload pins missing or changed.' }
            foreach ($payload in $component.payloads) {
                Assert-WorkstationProperties $payload @('id', 'sha256')
                if ($payload.sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Unproven principal payload hash.' }
            }
        }
        if (-not $sources.ContainsKey([string]$component.id) -or
            $component.source -cne $sources[[string]$component.id] -or $component.architecture -cne 'X64' -or
            $component.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            $component.version -cnotmatch '^\d+\.\d+\.\d+(?:\.\d+|\.windows\.\d+|\+g[0-9a-f]+)?$' -or
            (@($component.capabilities) -join '|') -cne ($capabilities[[string]$component.id] -join '|')) {
            throw 'Unproven version, source, architecture or capabilities.'
        }
        if (@($component.references).Count -eq 0) { throw 'First-party reference required.' }
        foreach ($reference in $component.references) {
            if ($reference -cnotmatch '^https://(?:learn\.microsoft\.com/|github\.com/(?:PowerShell/PowerShell|git-for-windows/git|cli/cli|Azure/(?:azure-cli|bicep|azure-devops-cli-extension))/|www\.nuget\.org/packages/Microsoft\.PowerApps\.CLI\.Tool/|www\.powershellgallery\.com/packages/Pester/)') {
                throw 'Reference is not a reviewed first-party source.'
            }
        }
    }
}

function Test-WorkstationPacHelp {
    param([object]$Result, [string]$Verb)
    $text = $Result.stdout -join "`n"
    $usage = $text -cmatch ('Usage: pac solution ' + [regex]::Escape($Verb) + ' --zipfile') -and
        $text.Contains('--folder') -and $text.Contains('--packagetype')
    if ($Result.exitCode -eq 0) { return $usage }
    return ($Result.exitCode -eq 1 -and $usage -and
        $text.Contains('Error: A required argument --zipfile is missing.') -and
        $text -notmatch '(?i)unknown|unrecognized|exception')
}

function Get-WorkstationComponentInventory {
    param([string]$Folder)
    $files = @(Get-ChildItem -LiteralPath $Folder -Recurse -Force)
    if (@($files | Where-Object {
        $_.Name -match '(?i)CanvasApps|CodeApps|\.msapp$|^\.git$' -or
        ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    }).Count -gt 0) { throw 'Out-of-scope Code App, Git metadata or reparse input refused.' }
    [xml]$manifest = Get-Content -LiteralPath (Join-Path $Folder 'Other\Solution.xml') -Raw
    [xml]$custom = Get-Content -LiteralPath (Join-Path $Folder 'Other\Customizations.xml') -Raw
    foreach ($document in @($manifest, $custom)) {
        $excluded = @($document.SelectNodes('//*') | Where-Object { $_.LocalName -match '^(?i:CodeApp)|^(?i:CanvasApp)$' })
        if ($excluded.Count -gt 0) { throw 'Out-of-scope Code App XML refused; no component is stripped.' }
    }
    $roots = @($manifest.SelectNodes('//RootComponents/RootComponent'))
    if ($roots.Count -ne 2 -or @($roots | Where-Object { $_.type -ne '61' }).Count -ne 0 -or
        @($custom.SelectNodes('/ImportExportXml/WebResources')).Count -ne 1) {
        throw 'Meaningful declared Web Resource fixture required; empty or unknown components refused.'
    }
    $metadata = @(Get-ChildItem -LiteralPath (Join-Path $Folder 'WebResources') -File -Filter '*.data.xml')
    if ($metadata.Count -ne 2) { throw 'Component metadata missing.' }
    $inventory = @(
        foreach ($file in $metadata) {
            [xml]$xml = Get-Content -LiteralPath $file.FullName -Raw
            $resource = $xml.WebResource
            $name = [string]$resource.Name
            $expectedId = switch ($name) {
                'syn_probe.html' { '11111111-1111-4111-8111-111111111111' }
                'syn_probe.js' { '22222222-2222-4222-8222-222222222222' }
                default { throw 'Unreviewed fixture component.' }
            }
            $type = if ($name -ceq 'syn_probe.html') { '1' } else { '3' }
            $matches = @($roots | Where-Object { $_.schemaName -ceq $name -and $_.behavior -eq '0' })
            if ($matches.Count -ne 1 -or ([guid]$resource.WebResourceId).ToString() -cne $expectedId -or
                [string]$resource.WebResourceType -cne $type) { throw 'Declared component identity/reference mismatch.' }
            $payload = Join-Path $file.DirectoryName $name
            $packed = ([string]$resource.FileName).TrimStart('/').Replace('\', '/')
            if ($packed -cnotmatch '^WebResources/[a-zA-Z0-9_.-]+$' -or
                -not (Test-Path -LiteralPath $payload -PathType Leaf) -or (Get-Item $payload).Length -eq 0) {
                throw 'Component payload or reference missing.'
            }
            [pscustomobject][ordered]@{
                name = $name; id = $expectedId; type = $type
                reference = $packed.ToLowerInvariant()
                bytes = (Get-Item -LiteralPath $payload).Length
                sha256 = (Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
    ) | Sort-Object name
    if (-not ([IO.File]::ReadAllText((Join-Path $Folder 'WebResources\syn_probe.html'))).Contains(
        '<script src="syn_probe.js"></script>')) { throw 'Relative component reference lost.' }
    $inventory
}

function Assert-WorkstationComponentZip {
    param([string]$Path, [object[]]$Expected)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $xmls = @{}
        foreach ($name in @('solution.xml', 'customizations.xml')) {
            $entries = @($zip.Entries | Where-Object { $_.FullName -ieq $name })
            if ($entries.Count -ne 1) { throw 'Packed metadata missing or ambiguous.' }
            $reader = [IO.StreamReader]::new($entries[0].Open())
            try { $xmls[$name] = [xml]$reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        $roots = @($xmls['solution.xml'].SelectNodes('//RootComponents/RootComponent'))
        $resources = @($xmls['customizations.xml'].SelectNodes('//WebResources/WebResource'))
        if ($roots.Count -ne 2 -or $resources.Count -ne 2) { throw 'Packed component loss or unprocessed source.' }
        foreach ($row in $Expected) {
            $rootMatch = @($roots | Where-Object { $_.type -eq '61' -and $_.schemaName -ceq $row.name -and $_.behavior -eq '0' })
            $metadata = @($resources | Where-Object { $_.Name -ceq $row.name })
            if ($rootMatch.Count -ne 1 -or $metadata.Count -ne 1 -or
                ([guid]$metadata[0].WebResourceId).ToString() -cne $row.id -or
                [string]$metadata[0].WebResourceType -cne $row.type) { throw 'Packed component identity lost.' }
            $reference = ([string]$metadata[0].FileName).TrimStart('/').Replace('\', '/').ToLowerInvariant()
            if ($reference -cne $row.reference) { throw 'Packed component reference changed.' }
            $entries = @($zip.Entries | Where-Object { $_.FullName.ToLowerInvariant() -ceq $reference })
            if ($entries.Count -ne 1 -or $entries[0].Length -ne $row.bytes) { throw 'Packed payload missing.' }
            $stream = $entries[0].Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
            finally { $stream.Dispose(); $sha.Dispose() }
            if ($hash -cne $row.sha256) { throw 'Packed payload bytes changed.' }
        }
    } finally { $zip.Dispose() }
}

function Invoke-WorkstationComponentProof {
    param([string]$PacPath, [string]$FixturePath, [string]$OwnedPath, [scriptblock]$Runner)
    $expected = @(Get-WorkstationComponentInventory $FixturePath)
    Copy-Item -LiteralPath $FixturePath -Destination (Join-Path $OwnedPath 'seed') -Recurse
    $steps = @(
        @('pack', 'seed.zip', 'seed'), @('unpack', 'seed.zip', 'u1'),
        @('pack', 'round.zip', 'u1'), @('unpack', 'round.zip', 'u2')
    )
    foreach ($step in $steps) {
        $arguments = @('solution', $step[0], '--zipfile', (Join-Path $OwnedPath $step[1]),
            '--folder', (Join-Path $OwnedPath $step[2]), '--packagetype', 'Unmanaged',
            '--errorlevel', 'Error', '--log', (Join-Path $OwnedPath ($step[0] + '-' + $step[2] + '.log')))
        if ($step[0] -eq 'unpack') { $arguments += '--allowWrite' }
        $native = Invoke-NativeCommand $Runner $PacPath $arguments
        if ($native.exitCode -ne 0) { throw 'Functional component probe failed.' }
        if ($step[0] -eq 'pack') {
            Assert-WorkstationComponentZip (Join-Path $OwnedPath $step[1]) $expected
        } else {
            $actual = @(Get-WorkstationComponentInventory (Join-Path $OwnedPath $step[2]))
            if (($actual | ConvertTo-Json -Compress) -cne ($expected | ConvertTo-Json -Compress)) {
                throw 'Unpack lost a declared component, reference or payload.'
            }
        }
    }
    [pscustomobject]@{ status = 'Proven'; declaredComponents = 2; nativeOperations = 4; referencesPreserved = $true; payloadBytesPreserved = $true }
}
