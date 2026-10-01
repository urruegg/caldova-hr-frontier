function Get-HrAiBuilderFieldContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Field contract file '$Path' was not found."
    }

    $contract = Read-HrAiBuilderJson -Path $Path -Description 'Field contract'
    $fields = @($contract.fields)
    if ($fields.Count -ne 17 -or [int]$contract.field_count -ne 17) {
        throw "Field contract file '$Path' must contain exactly 17 fields."
    }

    $names = @($fields | ForEach-Object { [string]$_.name })
    $bomIds = @($fields | ForEach-Object { [string]$_.bom_id })

    if (@($names | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
        throw "Field contract file '$Path' contains duplicate field names."
    }

    if (@($bomIds | Group-Object | Where-Object Count -gt 1).Count -gt 0) {
        throw "Field contract file '$Path' contains duplicate BoM IDs."
    }

    foreach ($field in $fields) {
        foreach ($propertyName in 'bom_id', 'name', 'ai_builder_type', 'normalization') {
            if (-not $field.PSObject.Properties.Name.Contains($propertyName) -or [string]::IsNullOrWhiteSpace([string]$field.$propertyName)) {
                throw "Field contract file '$Path' is missing required field property '$propertyName'."
            }
        }
    }

    $sortedBomIds = @($bomIds | Sort-Object)
    if (-not (Compare-HrAiBuilderSequence -Left $bomIds -Right $sortedBomIds)) {
        throw "Field contract file '$Path' is not ordered by BoM ID."
    }

    return @($fields)
}
