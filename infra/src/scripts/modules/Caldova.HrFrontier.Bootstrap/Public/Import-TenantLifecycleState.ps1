function Import-TenantLifecycleState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$PublicTenantKey
    )

    try {
        if (-not [IO.Path]::IsPathRooted($Path)) {
            throw [IO.InvalidDataException]::new('Invalid path.')
        }
        $fullPath = [IO.Path]::GetFullPath($Path)
        if (-not [IO.File]::Exists($fullPath)) {
            throw [IO.InvalidDataException]::new('State is absent.')
        }

        $state = Get-Content -Raw -LiteralPath $fullPath -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop
        Test-TenantLifecycleContract -Kind State -InputObject $state | Out-Null
    }
    catch {
        throw [IO.InvalidDataException]::new('TenantLifecycle.State.Invalid')
    }

    if ($PublicTenantKey -cnotmatch '^tenant[1-9][0-9]*$' -or
        [string]$state.publicTenantKey -cne $PublicTenantKey) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.State.PublicTenantKey')
    }

    $state
}
