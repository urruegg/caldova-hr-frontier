function ConvertFrom-TenantLifecycleJson {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$InputObject
    )

    process {
        $parameters = @{
            InputObject = $InputObject
        }
        $command = Get-Command `
            -Name ConvertFrom-Json `
            -CommandType Cmdlet `
            -ErrorAction Stop
        if ($command.Parameters.ContainsKey('Depth')) {
            $parameters.Depth = 100
        }
        if ($command.Parameters.ContainsKey('DateKind')) {
            $parameters.DateKind = 'String'
        }
        ConvertFrom-Json @parameters
    }
}

function ConvertTo-TenantLifecycleCanonicalJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject
    )

    process {
        $canonical = ConvertTo-CanonicalJsonValue `
            -Value $InputObject `
            -RemainingDepth 30
        return (
            $canonical |
                ConvertTo-Json -Depth 30 -Compress
        ) + "`n"
    }
}
