function Get-PowerPlatformEnvironmentEntries {
    param(
        [AllowNull()]
        [object]$Body
    )

    if ($null -eq $Body) {
        return @()
    }

    if ($Body -is [System.Collections.IEnumerable] -and -not ($Body -is [string]) -and -not ($Body -is [System.Collections.IDictionary])) {
        return @($Body)
    }

    foreach ($propertyName in @('value', 'environments', 'items')) {
        $propertyValue = Get-DiscoveryPropertyValue -InputObject $Body -Name $propertyName
        if ($null -ne $propertyValue) {
            return @($propertyValue)
        }
    }

    $environment = Get-DiscoveryPropertyValue -InputObject $Body -Name 'environment'
    if ($null -ne $environment) {
        return @($environment)
    }

    @()
}

function Get-PowerPlatformEnvironmentUrl {
    param(
        [Parameter(Mandatory)]
        [object]$Environment
    )

    foreach ($propertyName in @('url', 'environmentUrl', 'instanceUrl')) {
        $value = [string](Get-DiscoveryPropertyValue -InputObject $Environment -Name $propertyName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    $properties = Get-DiscoveryPropertyValue -InputObject $Environment -Name 'properties'
    if ($null -ne $properties) {
        foreach ($propertyName in @('linkedEnvironmentMetadata.instanceUrl', 'environmentUrl', 'instanceUrl')) {
            if ($propertyName -eq 'linkedEnvironmentMetadata.instanceUrl') {
                $linkedMetadata = Get-DiscoveryPropertyValue -InputObject $properties -Name 'linkedEnvironmentMetadata'
                if ($null -ne $linkedMetadata) {
                    $linkedValue = [string](Get-DiscoveryPropertyValue -InputObject $linkedMetadata -Name 'instanceUrl')
                    if (-not [string]::IsNullOrWhiteSpace($linkedValue)) {
                        return $linkedValue
                    }
                }

                continue
            }

            $value = [string](Get-DiscoveryPropertyValue -InputObject $properties -Name $propertyName)
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value
            }
        }
    }

    $null
}

function Get-PowerPlatformEnvironmentName {
    param(
        [Parameter(Mandatory)]
        [object]$Environment,

        [Parameter(Mandatory)]
        [string]$FallbackStage
    )

    foreach ($propertyName in @('name', 'displayName', 'friendlyName')) {
        $value = [string](Get-DiscoveryPropertyValue -InputObject $Environment -Name $propertyName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    "Power Platform $FallbackStage"
}

function Get-PowerPlatformEnvironmentId {
    param(
        [Parameter(Mandatory)]
        [object]$Environment
    )

    foreach ($propertyName in @('id', 'environmentId')) {
        $value = [string](Get-DiscoveryPropertyValue -InputObject $Environment -Name $propertyName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    $null
}

function Get-PowerPlatformProbeRecord {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Stage
    )

    foreach ($item in @($InputObject)) {
        $entries = Get-ObjectEntryTable -InputObject $item
        if ([string]$entries.Stage -ceq $Stage) {
            return $entries
        }
    }

    $null
}

function Invoke-PowerPlatformDiscoveryRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Arguments
    )

    if ($Operation -cne 'EnvironmentMetadata') {
        throw 'Unsupported Power Platform discovery operation.'
    }

    $body = (Invoke-DiscoveryNativeCommand -FilePath 'pac' -ArgumentList @('admin', 'list', '--json')).Body
    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = $body
    }
}

function Get-PowerPlatformDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [guid]$RunId,

        [Parameter(Mandatory)]
        [datetime]$CollectedUtc,

        [ValidateSet('Interactive', 'ExistingContext')]
        [string]$AuthenticationMode = 'Interactive',

        [string]$ProbePath,

        [object]$BaselineEvidence,

        [scriptblock]$Request = ${function:Invoke-PowerPlatformDiscoveryRequest}
    )

    $sourceApi = 'Power Platform Admin API'
    if ($AuthenticationMode -eq 'ExistingContext') {
        if ([string]::IsNullOrWhiteSpace($ProbePath) -or -not (Test-Path -LiteralPath $ProbePath)) {
            throw 'ExistingContext Power Platform discovery requires a probe file.'
        }

        if ($null -eq $BaselineEvidence) {
            throw 'ExistingContext Power Platform discovery requires committed baseline evidence.'
        }

        $probeContent = Get-Content -Raw -LiteralPath $ProbePath | ConvertFrom-Json
        $probeItems = @($probeContent)
        if ($probeItems.Count -ne 3) {
            throw 'Power Platform probe results must include exactly DEV, TEST, and PROD.'
        }

        $dev = Get-PowerPlatformProbeRecord -InputObject $probeItems -Stage 'DEV'
        $test = Get-PowerPlatformProbeRecord -InputObject $probeItems -Stage 'TEST'
        $prod = Get-PowerPlatformProbeRecord -InputObject $probeItems -Stage 'PROD'
        if ($null -eq $dev -or $null -eq $test -or $null -eq $prod) {
            throw 'Power Platform probe results must include DEV, TEST, and PROD stages.'
        }

        $stageMap = [ordered]@{ DEV = $dev; TEST = $test; PROD = $prod }
        if ((@($stageMap.Keys | ForEach-Object { [string]$stageMap[$_].Stage } | Select-Object -Unique).Count) -ne 3) {
            throw 'Power Platform probe results must not duplicate stages.'
        }

        foreach ($record in @($dev, $test, $prod)) {
            foreach ($key in $record.Keys) {
                if ($key -notin @('Stage', 'Url', 'Status', 'CollectedUtc', 'ActionRevision')) {
                    throw 'Power Platform probe results contain unsupported fields.'
                }
            }

            ConvertFrom-DiscoveryUtcString -Value ([string]$record.CollectedUtc) -Path "PowerPlatformProbe.$($record.Stage).CollectedUtc" | Out-Null
            if ([string]::IsNullOrWhiteSpace([string]$record.ActionRevision)) {
                throw 'Power Platform probe results require ActionRevision.'
            }
        }

        $baselineService = Get-ObjectEntryTable -InputObject (Get-DiscoveryPropertyValue -InputObject $BaselineEvidence.Services -Name 'PowerPlatform' -Required)
        $baselineResources = @($baselineService.Resources)
        $joinedResources = @()
        $ambiguousResources = @()
        foreach ($stage in @('DEV', 'TEST', 'PROD')) {
            $type = switch ($stage) {
                'DEV' { 'PowerPlatformEnvironmentDev' }
                'TEST' { 'PowerPlatformEnvironmentTest' }
                'PROD' { 'PowerPlatformEnvironmentProd' }
            }

            $expectedUrl = switch ($stage) {
                'DEV' { [string]$TenantConfiguration.PowerPlatform.DevUrl }
                'TEST' { [string]$TenantConfiguration.PowerPlatform.TestUrl }
                'PROD' { [string]$TenantConfiguration.PowerPlatform.ProdUrl }
            }

            $probeRecord = $stageMap[$stage]
            if ([string]$probeRecord.Status -cne 'Found') {
                $baselineMatch = @($baselineResources | Where-Object { [string]$_.Type -ceq $type })
                if ($baselineMatch.Count -eq 1) {
                    $ambiguousResources += [pscustomobject][ordered]@{
                        Type = $type
                        Id = [string]$baselineMatch[0].Id
                        Name = [string]$baselineMatch[0].Name
                        Url = [string]$baselineMatch[0].Url
                        Scope = [string]$baselineMatch[0].Scope
                        Status = 'Ambiguous'
                    }
                }

                continue
            }

            $matchingBaseline = @($baselineResources | Where-Object { [string]$_.Type -ceq $type -and [string]$_.Status -ceq 'Found' })
            if ($matchingBaseline.Count -ne 1) {
                if ($matchingBaseline.Count -gt 0) {
                    foreach ($candidate in $matchingBaseline) {
                        $ambiguousResources += [pscustomobject][ordered]@{
                            Type = $type
                            Id = [string]$candidate.Id
                            Name = [string]$candidate.Name
                            Url = [string]$candidate.Url
                            Scope = [string]$candidate.Scope
                            Status = 'Ambiguous'
                        }
                    }
                }

                continue
            }

            $baselineResource = $matchingBaseline[0]
            if ([string]$probeRecord.Url -cne $expectedUrl -or [string]$baselineResource.Url -cne $expectedUrl) {
                $ambiguousResources += [pscustomobject][ordered]@{
                    Type = $type
                    Id = [string]$baselineResource.Id
                    Name = [string]$baselineResource.Name
                    Url = [string]$baselineResource.Url
                    Scope = [string]$baselineResource.Scope
                    Status = 'Ambiguous'
                }
                continue
            }

            $joinedResources += [pscustomobject][ordered]@{
                Type = $type
                Id = [string]$baselineResource.Id
                Name = [string]$baselineResource.Name
                Url = [string]$baselineResource.Url
                Scope = [string]$baselineResource.Scope
                Status = 'Found'
            }
        }

        if ($joinedResources.Count -ne 3) {
            return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Ambiguous' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $ambiguousResources -RawPayload $probeItems
        }

        return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Found' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $joinedResources -RawPayload $probeItems
    }

    $response = Invoke-BoundedRetry -Request $Request -Operation 'EnvironmentMetadata' -Arguments @{ TenantId = [string]$TenantConfiguration.TenantId }
    $statusCode = Get-DiscoveryStatusCode -Response $response
    if ($statusCode -in @(401, 403)) {
        return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Unauthorized' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 404) {
        return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 408 -or $statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
        return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Unavailable' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }

    $body = Get-DiscoveryResponseBody -Response $response
    $environments = @(Get-PowerPlatformEnvironmentEntries -Body $body)
    if ($environments.Count -eq 0) {
        return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Unauthorized' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    $stageDefinitions = @(
        [pscustomobject]@{ Stage = 'DEV'; Type = 'PowerPlatformEnvironmentDev'; Url = [string]$TenantConfiguration.PowerPlatform.DevUrl },
        [pscustomobject]@{ Stage = 'TEST'; Type = 'PowerPlatformEnvironmentTest'; Url = [string]$TenantConfiguration.PowerPlatform.TestUrl },
        [pscustomobject]@{ Stage = 'PROD'; Type = 'PowerPlatformEnvironmentProd'; Url = [string]$TenantConfiguration.PowerPlatform.ProdUrl }
    )

    $missingStage = $null
    $ambiguousResources = @()
    $resources = @()
    foreach ($stageDefinition in $stageDefinitions) {
        $matches = @($environments | Where-Object { (Get-PowerPlatformEnvironmentUrl -Environment $_) -ceq $stageDefinition.Url })
        if ($matches.Count -eq 0) {
            $missingStage = $stageDefinition.Stage
            continue
        }

        if ($matches.Count -gt 1) {
            foreach ($candidate in $matches) {
                $candidateId = Get-PowerPlatformEnvironmentId -Environment $candidate
                $ambiguousResources += [pscustomobject][ordered]@{
                    Type = $stageDefinition.Type
                    Id = $candidateId
                    Name = Get-PowerPlatformEnvironmentName -Environment $candidate -FallbackStage $stageDefinition.Stage
                    Url = $stageDefinition.Url
                    Scope = "environment:$($stageDefinition.Stage)"
                    Status = 'Ambiguous'
                }
            }

            continue
        }

        $environment = $matches[0]
    $environmentId = Get-PowerPlatformEnvironmentId -Environment $environment
        if ([string]::IsNullOrWhiteSpace($environmentId)) {
            $ambiguousResources += [pscustomobject][ordered]@{
                Type = $stageDefinition.Type
                Id = $environmentId
                Name = Get-PowerPlatformEnvironmentName -Environment $environment -FallbackStage $stageDefinition.Stage
                Url = $stageDefinition.Url
                Scope = "environment:$($stageDefinition.Stage)"
                Status = 'Ambiguous'
            }
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = $stageDefinition.Type
            Id = $environmentId
            Name = Get-PowerPlatformEnvironmentName -Environment $environment -FallbackStage $stageDefinition.Stage
            Url = $stageDefinition.Url
            Scope = "environment:$($stageDefinition.Stage)"
            Status = 'Found'
        }
    }

    if ($ambiguousResources.Count -gt 0) {
        return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Ambiguous' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $ambiguousResources -RawPayload $body
    }

    if ($null -ne $missingStage) {
        return New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    New-DiscoveryServiceResult -Name 'PowerPlatform' -Status 'Found' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $resources -RawPayload $body
}