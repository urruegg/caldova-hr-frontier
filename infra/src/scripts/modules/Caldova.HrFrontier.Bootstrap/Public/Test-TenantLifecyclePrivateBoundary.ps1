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
            $componentProperty = $intentValue.Components.PSObject.Properties[
                [string]$resource.resourceType
            ]
            if ($null -eq $componentProperty) {
                throw [IO.InvalidDataException]::new('Unreviewed state resource.')
            }
            $component = $componentProperty.Value
            if ([string]$component.Mode -ceq 'Existing' -and
                [string]$component.Id -cne [string]$resource.stableId) {
                throw [IO.InvalidDataException]::new('State changed a reviewed stable ID.')
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
    $intentDigestInput = $intentValue |
        ConvertTo-Json -Depth 30 -Compress |
        ConvertFrom-Json

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
