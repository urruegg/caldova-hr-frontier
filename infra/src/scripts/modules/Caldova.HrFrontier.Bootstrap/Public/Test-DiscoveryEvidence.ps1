function Test-DiscoveryEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Evidence,

        [datetime]$NowUtc = [datetime]::UtcNow,

        [switch]$SkipAuthorizationGate
    )

    $topLevelEntries = Get-ObjectEntryTable -InputObject $Evidence
    $requiredTopLevel = @('SchemaVersion', 'ToolVersion', 'RunId', 'CollectionStartedUtc', 'CollectionCompletedUtc', 'TenantAlias', 'TenantId', 'Principal', 'Services')
    foreach ($key in $topLevelEntries.Keys) {
        if ($key -notin $requiredTopLevel) {
            throw "Evidence.$key is not allowed by the closed schema."
        }
    }
    foreach ($key in $requiredTopLevel) {
        if (-not $topLevelEntries.Contains($key)) {
            throw "Evidence is missing required property $key."
        }
    }

    if ([string]$topLevelEntries.SchemaVersion -cne '1.0') {
        throw 'Evidence.SchemaVersion must equal 1.0.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$topLevelEntries.ToolVersion)) {
        throw 'Evidence.ToolVersion is required.'
    }

    $runId = [guid]::Empty
    if (-not [guid]::TryParse([string]$topLevelEntries.RunId, [ref]$runId)) {
        throw 'Evidence.RunId must be a GUID.'
    }

    $collectionStartedUtc = ConvertFrom-DiscoveryUtcString -Value ([string]$topLevelEntries.CollectionStartedUtc) -Path 'Evidence.CollectionStartedUtc'
    $collectionCompletedUtc = ConvertFrom-DiscoveryUtcString -Value ([string]$topLevelEntries.CollectionCompletedUtc) -Path 'Evidence.CollectionCompletedUtc'
    $nowValue = if ($NowUtc.Kind -eq [System.DateTimeKind]::Utc) { $NowUtc } else { $NowUtc.ToUniversalTime() }
    if ($collectionCompletedUtc -lt $collectionStartedUtc) {
        throw 'Evidence.CollectionCompletedUtc must not be earlier than CollectionStartedUtc.'
    }
    if ($collectionStartedUtc -gt $nowValue) {
        throw 'Evidence.CollectionStartedUtc must not be in the future.'
    }
    if (-not $SkipAuthorizationGate -and $collectionStartedUtc.AddHours(24) -le $nowValue) {
        throw 'Evidence older than 24 hours is not accepted.'
    }

    $principalEntries = Get-ObjectEntryTable -InputObject $topLevelEntries.Principal
    foreach ($principalKey in $principalEntries.Keys) {
        if ($principalKey -notin @('Type', 'Id', 'ClientId', 'Upn')) {
            throw "Evidence.Principal.$principalKey is not allowed by the closed schema."
        }
    }
    if ([string]$principalEntries.Type -notin @('User', 'ServicePrincipal')) {
        throw 'Evidence.Principal.Type must be User or ServicePrincipal.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$principalEntries.Id)) {
        throw 'Evidence.Principal.Id is required.'
    }

    $serviceEntries = Get-ObjectEntryTable -InputObject $topLevelEntries.Services
    $requiredServices = @('GitHub', 'Entra', 'Azure', 'AzureDevOps', 'PowerPlatform')
    foreach ($serviceKey in $serviceEntries.Keys) {
        if ($serviceKey -notin $requiredServices) {
            throw "Evidence.Services.$serviceKey is not allowed by the closed schema."
        }
    }
    foreach ($serviceKey in $requiredServices) {
        if (-not $serviceEntries.Contains($serviceKey)) {
            throw "Evidence.Services is missing required service $serviceKey."
        }
    }

    foreach ($serviceKey in $requiredServices) {
        $service = $serviceEntries[$serviceKey]
        $serviceRecord = Get-ObjectEntryTable -InputObject $service
        foreach ($propertyName in $serviceRecord.Keys) {
            if ($propertyName -notin @('Name', 'RunId', 'Status', 'SourceApi', 'CollectedUtc', 'ResponseSha256', 'Resources')) {
                throw "Evidence.Services.$serviceKey.$propertyName is not allowed by the closed schema."
            }
        }

        if ([string]$serviceRecord.Name -cne $serviceKey) {
            throw "Evidence.Services.$serviceKey.Name must equal the service key."
        }
        if ([string]$serviceRecord.RunId -cne $runId.Guid) {
            throw "Evidence.Services.$serviceKey.RunId must equal Evidence.RunId."
        }

        $status = [string]$serviceRecord.Status
        if ($status -notin @('Found', 'Missing', 'Unauthorized', 'Unavailable', 'Ambiguous')) {
            throw "Evidence.Services.$serviceKey.Status is invalid."
        }

        if (-not $SkipAuthorizationGate -and $status -in @('Unauthorized', 'Unavailable', 'Ambiguous')) {
            throw "Evidence.Services.$serviceKey failed the discovery gate with status $status."
        }

        if ([string]::IsNullOrWhiteSpace([string]$serviceRecord.SourceApi)) {
            throw "Evidence.Services.$serviceKey.SourceApi is required."
        }

        ConvertFrom-DiscoveryUtcString -Value ([string]$serviceRecord.CollectedUtc) -Path "Evidence.Services.$serviceKey.CollectedUtc" | Out-Null
        if ([string]$serviceRecord.ResponseSha256 -cnotmatch '^[a-f0-9]{64}$') {
            throw "Evidence.Services.$serviceKey.ResponseSha256 must be a lowercase SHA-256 hex string."
        }

        $resources = @($serviceRecord.Resources)
        if ($status -eq 'Found' -and $resources.Count -lt 1) {
            throw "Evidence.Services.$serviceKey with Found status must include at least one resource."
        }
        if ($status -eq 'Ambiguous' -and $resources.Count -lt 1) {
            throw "Evidence.Services.$serviceKey with Ambiguous status must include review candidates."
        }

        foreach ($resource in $resources) {
            $resourceRecord = Get-ObjectEntryTable -InputObject $resource
            foreach ($resourceKey in $resourceRecord.Keys) {
                if ($resourceKey -notin @('Type', 'Id', 'Name', 'Url', 'Scope', 'Status', 'EvidenceReference')) {
                    throw "Evidence.Services.$serviceKey.Resources.$resourceKey is not allowed by the closed schema."
                }
            }

            foreach ($requiredKey in @('Type', 'Id', 'Name', 'Status', 'EvidenceReference')) {
                if (-not $resourceRecord.Contains($requiredKey)) {
                    throw "Evidence.Services.$serviceKey.Resources requires $requiredKey."
                }
            }

            if ([string]::IsNullOrWhiteSpace([string]$resourceRecord.Type) -or [string]$resourceRecord.Type -cnotmatch '^[A-Za-z][A-Za-z0-9]*$') {
                throw "Evidence.Services.$serviceKey.Resources.Type must be a stable component key."
            }
            if ([string]::IsNullOrWhiteSpace([string]$resourceRecord.Id)) {
                throw "Evidence.Services.$serviceKey.Resources.Id is required."
            }
            if ([string]::IsNullOrWhiteSpace([string]$resourceRecord.Name)) {
                throw "Evidence.Services.$serviceKey.Resources.Name is required."
            }
            if ([string]$resourceRecord.Status -notin @('Found', 'Missing', 'Unauthorized', 'Unavailable', 'Ambiguous')) {
                throw "Evidence.Services.$serviceKey.Resources.Status is invalid."
            }

            $referenceRecord = Get-ObjectEntryTable -InputObject $resourceRecord.EvidenceReference
            foreach ($referenceKey in $referenceRecord.Keys) {
                if ($referenceKey -notin @('Service', 'SourceApi', 'Scope', 'CollectedUtc', 'ResponseSha256')) {
                    throw "Evidence.Services.$serviceKey.Resources.EvidenceReference.$referenceKey is not allowed by the closed schema."
                }
            }
            foreach ($requiredKey in @('Service', 'SourceApi', 'Scope', 'CollectedUtc', 'ResponseSha256')) {
                if (-not $referenceRecord.Contains($requiredKey)) {
                    throw "Evidence.Services.$serviceKey.Resources.EvidenceReference requires $requiredKey."
                }
            }

            if ([string]$referenceRecord.Service -cne $serviceKey) {
                throw "Evidence.Services.$serviceKey.Resources.EvidenceReference.Service must equal the service key."
            }
            if ([string]$referenceRecord.SourceApi -cne [string]$serviceRecord.SourceApi) {
                throw "Evidence.Services.$serviceKey.Resources.EvidenceReference.SourceApi must match the service SourceApi."
            }
            if ([string]::IsNullOrWhiteSpace([string]$referenceRecord.Scope)) {
                throw "Evidence.Services.$serviceKey.Resources.EvidenceReference.Scope is required."
            }
            ConvertFrom-DiscoveryUtcString -Value ([string]$referenceRecord.CollectedUtc) -Path "Evidence.Services.$serviceKey.Resources.EvidenceReference.CollectedUtc" | Out-Null
            if ([string]$referenceRecord.ResponseSha256 -cne [string]$serviceRecord.ResponseSha256) {
                throw "Evidence.Services.$serviceKey.Resources.EvidenceReference.ResponseSha256 must match the service hash."
            }
        }
    }

    $approvedUpn = if ($principalEntries.Contains('Upn')) { [string]$principalEntries.Upn } else { $null }
    Test-ProhibitedData -InputObject $Evidence -ApprovedUpn $approvedUpn | Out-Null
    $true
}