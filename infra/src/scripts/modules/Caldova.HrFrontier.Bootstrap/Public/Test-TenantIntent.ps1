function Test-TenantIntent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [object]$Evidence
    )

    $validationNowUtc = ConvertFrom-DiscoveryUtcString -Value ([string]$Evidence.CollectionCompletedUtc) -Path 'Evidence.CollectionCompletedUtc'
    Test-DiscoveryEvidence -Evidence $Evidence -NowUtc $validationNowUtc | Out-Null

    $componentEntries = Get-ObjectEntryTable -InputObject $TenantConfiguration.Components
    $serviceEntries = Get-ObjectEntryTable -InputObject $Evidence.Services
    $resourcesByType = @{}

    foreach ($serviceName in $serviceEntries.Keys) {
        foreach ($resource in @($serviceEntries[$serviceName].Resources)) {
            $resourceType = [string]$resource.Type
            if (-not $resourcesByType.ContainsKey($resourceType)) {
                $resourcesByType[$resourceType] = @()
            }
            $resourcesByType[$resourceType] += $resource
        }
    }

    foreach ($componentKey in $componentEntries.Keys) {
        $component = Get-ObjectEntryTable -InputObject $componentEntries[$componentKey]
        $mode = [string]$component.Mode
        if ($mode -notin @('Existing', 'Create')) {
            throw "Components.$componentKey.Mode must be Existing or Create."
        }

        $matchingResources = if ($resourcesByType.ContainsKey($componentKey)) { @($resourcesByType[$componentKey]) } else { @() }
        $foundResources = @($matchingResources | Where-Object { [string]$_.Status -eq 'Found' })
        $ambiguousResources = @($matchingResources | Where-Object { [string]$_.Status -eq 'Ambiguous' })

        if ($mode -eq 'Existing') {
            if (-not $component.Contains('Id') -or [string]::IsNullOrWhiteSpace([string]$component.Id)) {
                throw "Components.$componentKey requires Id in Existing mode."
            }

            if ($ambiguousResources.Count -gt 0) {
                throw "Components.$componentKey cannot be satisfied from ambiguous evidence."
            }

            if ($foundResources.Count -ne 1) {
                throw "Components.$componentKey requires exactly one Found resource candidate."
            }

            if ([string]$foundResources[0].Id -cne [string]$component.Id) {
                throw "Components.$componentKey requires an exact stable Id match."
            }
        }

        if ($mode -eq 'Create') {
            if ($foundResources.Count -gt 0 -or $ambiguousResources.Count -gt 0) {
                throw "Components.$componentKey in Create mode conflicts with discovered resources."
            }
        }
    }

    $true
}