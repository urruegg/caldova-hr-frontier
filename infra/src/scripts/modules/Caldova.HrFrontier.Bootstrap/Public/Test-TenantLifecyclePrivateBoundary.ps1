function Test-TenantLifecyclePrivateBoundary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PublicTenantKey,

        [Parameter(Mandatory)]
        [string]$IntentPath,

        [Parameter(Mandatory)]
        [string]$StatePath,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [scriptblock]$NativeCommandRunner
    )

    if ($PublicTenantKey -cnotmatch '^tenant[1-9][0-9]*$' -or
        -not [IO.Path]::IsPathRooted($IntentPath) -or
        -not [IO.Path]::IsPathRooted($StatePath) -or
        -not [IO.Path]::IsPathRooted($RepositoryRoot)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Path')
    }

    try {
        $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
        $intent = [IO.Path]::GetFullPath($IntentPath)
        $state = [IO.Path]::GetFullPath($StatePath)
        $tenantRoot = Join-Path $root 'infra\src\config\tenants'
        $expectedIntent = Join-Path $tenantRoot "$PublicTenantKey.local.psd1"
        $expectedState = Join-Path $tenantRoot "$PublicTenantKey.state.local.json"
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Path')
    }

    $pathComparer = [StringComparer]::OrdinalIgnoreCase
    if (-not [IO.Directory]::Exists($root) -or
        -not $pathComparer.Equals($intent, $expectedIntent) -or
        -not $pathComparer.Equals($state, $expectedState)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Path')
    }
    if (-not [IO.File]::Exists($intent) -or -not [IO.File]::Exists($state)) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Files')
    }

    try {
        $intentValue = Import-TenantConfiguration `
            -Path $intent `
            -ValidationStage Discovery `
            -ExpectedPublicTenantKey $PublicTenantKey
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Intent')
    }

    try {
        $stateValue = Import-TenantLifecycleState `
            -Path $state `
            -PublicTenantKey $PublicTenantKey
        foreach ($resource in @($stateValue.resources)) {
            $matchingComponents = @(
                foreach (
                    $componentProperty in @(
                        $intentValue.Components.PSObject.Properties
                    )
                ) {
                    $component = $componentProperty.Value
                    $componentProperties = @(
                        $component.PSObject.Properties
                    )
                    $componentNames = @(
                        $componentProperties |
                            ForEach-Object { [string]$_.Name }
                    )
                    $mode = [string]$component.Mode
                    $expectedNames = @(
                        'Provider',
                        'ResourceType',
                        'LogicalName',
                        'Mode'
                    )
                    if ($mode -ceq 'Existing') {
                        $expectedNames += 'Id'
                    }
                    if ($mode -cnotin @('Existing', 'Create') -or
                        $componentProperties.Count -ne
                            $expectedNames.Count -or
                        @(
                            $expectedNames |
                                Where-Object {
                                    $componentNames -cnotcontains $_
                                }
                        ).Count -ne 0) {
                        throw [IO.InvalidDataException]::new(
                            'Invalid reviewed component.'
                        )
                    }
                    if ([string]$component.Provider -ceq
                            [string]$resource.provider -and
                        [string]$component.ResourceType -ceq
                            [string]$resource.resourceType -and
                        [string]$component.LogicalName -ceq
                            [string]$resource.logicalName) {
                        $component
                    }
                }
            )
            if ($matchingComponents.Count -ne 1) {
                throw [IO.InvalidDataException]::new(
                    'Unreviewed state resource.'
                )
            }
            $component = $matchingComponents[0]
            if ([string]$component.Mode -ceq 'Existing' -and
                ($null -eq $resource.stableId -or
                    [string]$component.Id -cne
                        [string]$resource.stableId)) {
                throw [IO.InvalidDataException]::new('State changed a reviewed stable ID.')
            }
            if ([string]$component.Mode -ceq 'Create' -and
                $component.PSObject.Properties.Name -ccontains 'Id') {
                throw [IO.InvalidDataException]::new(
                    'Create intent asserted a stable ID.'
                )
            }
        }
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.State')
    }

    $intentLabel = "infra/src/config/tenants/$PublicTenantKey.local.psd1"
    $stateLabel = "infra/src/config/tenants/$PublicTenantKey.state.local.json"
    $intentGit = Test-TenantLifecycleGitBoundary `
        -RepositoryRoot $root `
        -RelativeLabel $intentLabel `
        -NativeCommandRunner $NativeCommandRunner
    $stateGit = Test-TenantLifecycleGitBoundary `
        -RepositoryRoot $root `
        -RelativeLabel $stateLabel `
        -NativeCommandRunner $NativeCommandRunner
    $intentDigestInput = ConvertFrom-TenantLifecycleJson -InputObject (
        $intentValue | ConvertTo-Json -Depth 30 -Compress
    )

    [pscustomobject][ordered]@{
        publicTenantKey = $PublicTenantKey
        intent = [pscustomobject][ordered]@{
            label = $intentLabel
            exists = $true
            ignored = [bool]$intentGit.ignored
            tracked = [bool]$intentGit.tracked
            schemaValid = $true
            digest = Get-RunbookContentDigest -InputObject $intentDigestInput
        }
        state = [pscustomobject][ordered]@{
            label = $stateLabel
            exists = $true
            ignored = [bool]$stateGit.ignored
            tracked = [bool]$stateGit.tracked
            schemaValid = $true
            digest = Get-RunbookContentDigest -InputObject $stateValue
        }
    }
}
