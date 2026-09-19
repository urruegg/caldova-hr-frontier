function Invoke-AzureDevOpsDiscoveryRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Arguments
    )

    if ($Operation -cne 'DiscoveryBundle') {
        throw 'Unsupported Azure DevOps discovery operation.'
    }

    $organizationUrl = [string]$Arguments.OrganizationUrl
    $projectName = [string]$Arguments.ProjectName
    $base = $organizationUrl.TrimEnd('/')
    $encodedProject = [System.Uri]::EscapeDataString($projectName)
    $body = [ordered]@{
        connectionData = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--area', 'connectionData', '--resource', 'connectionData', '--organization', $organizationUrl, '--route-parameters', 'connectOptions=1', '--api-version', '7.1')).Body
        project = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'core', '--resource', 'projects', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
        repositories = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'git', '--resource', 'repositories', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
        serviceEndpoints = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'serviceendpoint', '--resource', 'endpoints', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
        environments = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'distributedtask', '--resource', 'environments', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
        pipelines = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'pipelines', '--resource', 'pipelines', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
        checks = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'pipelinesChecks', '--resource', 'configurations', '--route-parameters', "project=$projectName", '--api-version', '7.1-preview.1')).Body
        effectivePermissions = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'security', 'permission', 'list', '--organization', $organizationUrl, '--project', $projectName, '--output', 'json')).Body
        projectUrl = "$base/$encodedProject"
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = $body
    }
}

function Get-AzureDevOpsDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [guid]$RunId,

        [Parameter(Mandatory)]
        [datetime]$CollectedUtc,

        [scriptblock]$Request = ${function:Invoke-AzureDevOpsDiscoveryRequest}
    )

    $sourceApi = 'Azure DevOps REST 7.1'
    $response = Invoke-BoundedRetry -Request $Request -Operation 'DiscoveryBundle' -Arguments @{ OrganizationUrl = [string]$TenantConfiguration.AzureDevOps.OrganizationUrl; ProjectName = [string]$TenantConfiguration.AzureDevOps.ProjectName }
    $statusCode = Get-DiscoveryStatusCode -Response $response
    if ($statusCode -in @(401, 403)) {
        return New-DiscoveryServiceResult -Name 'AzureDevOps' -Status 'Unauthorized' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 404) {
        return New-DiscoveryServiceResult -Name 'AzureDevOps' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 408 -or $statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
        return New-DiscoveryServiceResult -Name 'AzureDevOps' -Status 'Unavailable' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }

    $body = Get-DiscoveryResponseBody -Response $response
    $project = Get-DiscoveryPropertyValue -InputObject $body -Name 'project' -Required
    if ($null -eq $project) {
        return New-DiscoveryServiceResult -Name 'AzureDevOps' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    $projectId = [string](Get-DiscoveryPropertyValue -InputObject $project -Name 'id' -Required)
    $projectName = [string](Get-DiscoveryPropertyValue -InputObject $project -Name 'name')
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        $projectName = [string](Get-DiscoveryPropertyValue -InputObject $project -Name 'ProjectName')
    }

    $projectUrl = [string](Get-DiscoveryPropertyValue -InputObject $project -Name 'url')
    if ([string]::IsNullOrWhiteSpace($projectUrl)) {
        $projectUrl = [string](Get-DiscoveryPropertyValue -InputObject $body -Name 'projectUrl')
    }
    $organizationScope = [string]$TenantConfiguration.AzureDevOps.OrganizationUrl
    $resources = @(
        [pscustomobject][ordered]@{
            Type = 'AzureDevOpsProject'
            Id = $projectId
            Name = $projectName
            Url = $projectUrl
            Scope = $organizationScope
            Status = 'Found'
        }
    )

    $connectionData = Get-DiscoveryPropertyValue -InputObject $body -Name 'connectionData'
    if ($null -ne $connectionData) {
        $connectionDataId = [string](Get-DiscoveryPropertyValue -InputObject $connectionData -Name 'id')
        if ([string]::IsNullOrWhiteSpace($connectionDataId)) {
            $connectionDataId = 'connection-data'
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDevOpsConnectionData'
            Id = $connectionDataId
            Name = 'Connection data'
            Scope = $organizationScope
            Status = 'Found'
        }
    }

    foreach ($item in @(Get-DiscoveryPropertyValue -InputObject $body -Name 'repositories')) {
        if ($null -eq $item) {
            continue
        }

        $repositoryId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($repositoryId)) {
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDevOpsRepository'
            Id = $repositoryId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            Url = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'webUrl')
            Scope = $organizationScope
            Status = 'Found'
        }
    }

    foreach ($propertyName in @('serviceEndpoints', 'environments', 'pipelines', 'checks', 'effectivePermissions')) {
        foreach ($item in @(Get-DiscoveryPropertyValue -InputObject $body -Name $propertyName)) {
            if ($null -eq $item) {
                continue
            }

            $itemId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
            if ([string]::IsNullOrWhiteSpace($itemId)) {
                continue
            }

            $type = switch ($propertyName) {
                'serviceEndpoints' { 'AzureDevOpsServiceEndpoint' }
                'environments' { 'AzureDevOpsEnvironment' }
                'pipelines' { 'AzureDevOpsPipeline' }
                'checks' { 'AzureDevOpsCheck' }
                'effectivePermissions' { 'AzureDevOpsEffectivePermission' }
            }

            $resources += [pscustomobject][ordered]@{
                Type = $type
                Id = $itemId
                Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
                Scope = $organizationScope
                Status = 'Found'
            }
        }
    }

    New-DiscoveryServiceResult -Name 'AzureDevOps' -Status 'Found' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $resources -RawPayload $body
}