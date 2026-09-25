function Invoke-SharePointDiscoveryRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Arguments
    )

    if ($Operation -cne 'SiteMetadata') {
        throw 'Unsupported SharePoint discovery operation.'
    }

    $output = & az rest --method get --url ([string]$Arguments.GraphUrl) --output json 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    if ($exitCode -ne 0) {
        $statusCode = if ($text -match '(?i)\b(401|unauthorized)\b') {
            401
        }
        elseif ($text -match '(?i)\b(403|forbidden)\b') {
            403
        }
        elseif ($text -match '(?i)\b404\b') {
            404
        }
        elseif ($text -match '(?i)\b429\b') {
            429
        }
        else {
            503
        }

        return [pscustomobject]@{
            StatusCode = $statusCode
            Headers = @{}
            Body = $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        return [pscustomobject]@{
            StatusCode = 404
            Headers = @{}
            Body = $null
        }
    }

    try {
        $body = $text | ConvertFrom-Json
    }
    catch {
        throw 'Microsoft Graph returned unexpected non-JSON SharePoint discovery output.'
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = $body
    }
}

function Get-SharePointDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [guid]$RunId,

        [Parameter(Mandatory)]
        [datetime]$CollectedUtc,

        [scriptblock]$Request = ${function:Invoke-SharePointDiscoveryRequest}
    )

    $sourceApi = 'Microsoft Graph v1.0'
    $stageDefinitions = @(
        [pscustomobject]@{ Stage = 'DEV'; Type = 'SharePointSiteDev'; Url = [string]$TenantConfiguration.SharePoint.DevUrl },
        [pscustomobject]@{ Stage = 'TEST'; Type = 'SharePointSiteTest'; Url = [string]$TenantConfiguration.SharePoint.TestUrl },
        [pscustomobject]@{ Stage = 'PROD'; Type = 'SharePointSiteProd'; Url = [string]$TenantConfiguration.SharePoint.ProdUrl }
    )
    $resources = @()
    $rawPayload = @()
    $serviceStatus = 'Found'

    foreach ($stageDefinition in $stageDefinitions) {
        $siteUri = [uri]$stageDefinition.Url
        $sitePath = $siteUri.AbsolutePath.Trim('/')
        $graphUrl = "https://graph.microsoft.com/v1.0/sites/$($siteUri.Host):/$sitePath?`$select=id,displayName,name,webUrl"
        $response = Invoke-BoundedRetry -Request $Request -Operation 'SiteMetadata' -Arguments @{
            Stage = $stageDefinition.Stage
            WebUrl = $stageDefinition.Url
            GraphUrl = $graphUrl
        }
        $statusCode = Get-DiscoveryStatusCode -Response $response
        $body = Get-DiscoveryResponseBody -Response $response
        $rawPayload += [pscustomobject][ordered]@{
            Stage = $stageDefinition.Stage
            StatusCode = $statusCode
            Body = $body
        }

        if ($statusCode -in @(401, 403)) {
            $serviceStatus = 'Unauthorized'
            continue
        }
        if ($statusCode -eq 404) {
            if ($serviceStatus -eq 'Found') {
                $serviceStatus = 'Missing'
            }
            continue
        }
        if ($statusCode -eq 408 -or $statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
            if ($serviceStatus -notin @('Unauthorized')) {
                $serviceStatus = 'Unavailable'
            }
            continue
        }

        $siteId = [string](Get-DiscoveryPropertyValue -InputObject $body -Name 'id')
        $siteName = [string](Get-DiscoveryPropertyValue -InputObject $body -Name 'displayName')
        if ([string]::IsNullOrWhiteSpace($siteName)) {
            $siteName = [string](Get-DiscoveryPropertyValue -InputObject $body -Name 'name')
        }
        $observedUrl = [string](Get-DiscoveryPropertyValue -InputObject $body -Name 'webUrl')
        $expectedUrl = $stageDefinition.Url.TrimEnd('/')
        $normalizedObservedUrl = $observedUrl.TrimEnd('/')
        if ([string]::IsNullOrWhiteSpace($siteId) -or [string]::IsNullOrWhiteSpace($siteName) -or $normalizedObservedUrl -cne $expectedUrl) {
            if ($serviceStatus -notin @('Unauthorized', 'Unavailable')) {
                $serviceStatus = 'Ambiguous'
            }
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = $stageDefinition.Type
            Id = $siteId
            Name = $siteName
            Url = $observedUrl
            Scope = "site:$($stageDefinition.Stage)"
            Status = 'Found'
        }
    }

    if ($resources.Count -ne 3 -and $serviceStatus -eq 'Found') {
        $serviceStatus = 'Ambiguous'
    }

    New-DiscoveryServiceResult `
        -Name 'SharePoint' `
        -Status $serviceStatus `
        -SourceApi $sourceApi `
        -CollectedUtc $CollectedUtc `
        -Resources $resources `
        -RawPayload $rawPayload
}
