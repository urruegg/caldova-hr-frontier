function ConvertTo-DiscoveryEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$ServiceResults,

        [Parameter(Mandatory)]
        [guid]$RunId,

        [Parameter(Mandatory)]
        [datetime]$CollectionStartedUtc,

        [Parameter(Mandatory)]
        [datetime]$CollectionCompletedUtc,

        [Parameter(Mandatory)]
        [object]$Principal,

        [string]$ToolVersion = '1.0.0'
    )

    $requiredServices = @('GitHub', 'Entra', 'Azure', 'AzureDevOps', 'PowerPlatform')
    $allowedServices = @($requiredServices + 'SharePoint')
    foreach ($serviceName in $requiredServices) {
        if (-not $ServiceResults.Contains($serviceName)) {
            throw "ServiceResults must include $serviceName."
        }
    }

    foreach ($serviceName in $ServiceResults.Keys) {
        if ($serviceName -notin $allowedServices) {
            throw "Unexpected service result '$serviceName'."
        }
    }

    $principalEntries = Get-ObjectEntryTable -InputObject $Principal
    $principalAllowed = @('Type', 'Id', 'ClientId', 'Upn')
    foreach ($principalKey in $principalEntries.Keys) {
        if ($principalKey -notin $principalAllowed) {
            throw "Principal.$principalKey is not allowed by the closed schema."
        }
    }

    if ([string]$principalEntries.Type -notin @('User', 'ServicePrincipal')) {
        throw 'Principal.Type must be User or ServicePrincipal.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$principalEntries.Id)) {
        throw 'Principal.Id is required.'
    }

    if ($principalEntries.Contains('Upn')) {
        $upn = [string]$principalEntries.Upn
        if ([string]::IsNullOrWhiteSpace($upn) -or $upn -inotmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') {
            throw 'Principal.Upn must be a valid user principal name.'
        }

        if ($upn -ine [string]$TenantConfiguration.AdminUpn) {
            throw 'Principal.Upn must match the reviewed tenant AdminUpn.'
        }
    }

    $principalGraph = [ordered]@{
        Type = [string]$principalEntries.Type
        Id = [string]$principalEntries.Id
    }
    if ($principalEntries.Contains('ClientId') -and -not [string]::IsNullOrWhiteSpace([string]$principalEntries.ClientId)) {
        $principalGraph.ClientId = [string]$principalEntries.ClientId
    }
    if ($principalEntries.Contains('Upn') -and -not [string]::IsNullOrWhiteSpace([string]$principalEntries.Upn)) {
        $principalGraph.Upn = [string]$principalEntries.Upn
    }

    $servicesGraph = [ordered]@{}
    foreach ($serviceName in $allowedServices) {
        if (-not $ServiceResults.Contains($serviceName)) {
            continue
        }

        $serviceResult = $ServiceResults[$serviceName]
        $serviceEntries = Get-ObjectEntryTable -InputObject $serviceResult
        $status = [string]$serviceEntries.Status
        if ($status -notin @('Found', 'Missing', 'Unauthorized', 'Unavailable', 'Ambiguous')) {
            throw "Service result $serviceName has an invalid status."
        }

        $sourceApi = [string]$serviceEntries.SourceApi
        if ([string]::IsNullOrWhiteSpace($sourceApi)) {
            throw "Service result $serviceName must include SourceApi."
        }

        $collectedUtc = ConvertTo-DiscoveryUtcString -Value ([datetime]$serviceEntries.CollectedUtc)
        $responseSha256 = Get-DiscoverySha256 -InputObject $serviceEntries.RawPayload
        $resources = @()
        $resourceValues = @()
        if ($serviceEntries.Contains('Resources') -and $serviceEntries.Resources) {
            $resourceValues = @($serviceEntries.Resources)
        }

        foreach ($resourceValue in $resourceValues) {
            $resourceEntries = Get-ObjectEntryTable -InputObject $resourceValue
            $resourceType = [string]$resourceEntries.Type
            $resourceId = [string]$resourceEntries.Id
            $resourceName = [string]$resourceEntries.Name
            $resourceStatus = if ($resourceEntries.Contains('Status')) { [string]$resourceEntries.Status } else { $status }
            if ($resourceStatus -notin @('Found', 'Missing', 'Unauthorized', 'Unavailable', 'Ambiguous')) {
                throw "Resource $resourceType in $serviceName has an invalid status."
            }

            if ([string]::IsNullOrWhiteSpace($resourceType) -or [string]::IsNullOrWhiteSpace($resourceId) -or [string]::IsNullOrWhiteSpace($resourceName)) {
                throw "Resources for $serviceName require Type, Id, and Name."
            }

            $resourceGraph = [ordered]@{
                Type = $resourceType
                Id = $resourceId
                Name = $resourceName
            }
            if ($resourceEntries.Contains('Url') -and -not [string]::IsNullOrWhiteSpace([string]$resourceEntries.Url)) {
                $resourceGraph.Url = [string]$resourceEntries.Url
            }
            if ($resourceEntries.Contains('Scope') -and -not [string]::IsNullOrWhiteSpace([string]$resourceEntries.Scope)) {
                $resourceGraph.Scope = [string]$resourceEntries.Scope
            }
            $resourceGraph.Status = $resourceStatus
            $resourceGraph.EvidenceReference = [ordered]@{
                Service = $serviceName
                SourceApi = $sourceApi
                Scope = if ($resourceEntries.Contains('Scope') -and -not [string]::IsNullOrWhiteSpace([string]$resourceEntries.Scope)) { [string]$resourceEntries.Scope } else { $serviceName }
                CollectedUtc = $collectedUtc
                ResponseSha256 = $responseSha256
            }
            $resources += [pscustomobject]$resourceGraph
        }

        $servicesGraph[$serviceName] = [pscustomobject][ordered]@{
            Name = $serviceName
            RunId = $RunId.Guid
            Status = $status
            SourceApi = $sourceApi
            CollectedUtc = $collectedUtc
            ResponseSha256 = $responseSha256
            Resources = @($resources)
        }
    }

    $evidence = [pscustomobject][ordered]@{
        SchemaVersion = '1.0'
        ToolVersion = $ToolVersion
        RunId = $RunId.Guid
        CollectionStartedUtc = ConvertTo-DiscoveryUtcString -Value $CollectionStartedUtc
        CollectionCompletedUtc = ConvertTo-DiscoveryUtcString -Value $CollectionCompletedUtc
        TenantAlias = [string]$TenantConfiguration.TenantAlias
        TenantId = [string]$TenantConfiguration.TenantId
        Principal = [pscustomobject]$principalGraph
        Services = [pscustomobject]$servicesGraph
    }

    Test-ProhibitedData -InputObject $evidence -ApprovedUpn ([string]$TenantConfiguration.AdminUpn) | Out-Null
    Test-DiscoveryEvidence -Evidence $evidence -NowUtc $CollectionCompletedUtc | Out-Null

    $evidence
}