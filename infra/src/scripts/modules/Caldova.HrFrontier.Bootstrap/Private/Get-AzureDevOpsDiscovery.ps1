function ConvertTo-AzureDevOpsDiscoveryItems {
    param(
        [AllowNull()]
        [object]$Node
    )

    if ($null -eq $Node) {
        return @()
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string]) -and -not ($Node -is [System.Collections.IDictionary])) {
        return @($Node)
    }

    $entries = Get-ObjectEntryTable -InputObject $Node
    if ($entries.Contains('value')) {
        return @($entries['value'])
    }

    @($Node)
}

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
    $adminUpn = [string]$Arguments.AdminUpn
    if ([string]::IsNullOrWhiteSpace($adminUpn)) {
        throw 'Azure DevOps discovery requires the reviewed administrator UPN.'
    }

    $base = $organizationUrl.TrimEnd('/')
    $encodedProject = [System.Uri]::EscapeDataString($projectName)
    $reviewedUser = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'user', 'show', '--user', $adminUpn, '--organization', $organizationUrl, '--output', 'json')).Body
    $project = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'project', 'show', '--project', $projectName, '--organization', $organizationUrl, '--output', 'json')).Body
    $repositories = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'git', '--resource', 'repositories', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
    $serviceEndpoints = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'serviceendpoint', '--resource', 'endpoints', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
    $environments = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'distributedtask', '--resource', 'environments', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body
    $pipelines = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('devops', 'invoke', '--organization', $organizationUrl, '--area', 'pipelines', '--resource', 'pipelines', '--route-parameters', "project=$projectName", '--api-version', '7.1')).Body

    $checks = @()
    foreach ($resourceDefinition in @(
        [pscustomobject]@{ Type = 'endpoint'; Items = @(ConvertTo-AzureDevOpsDiscoveryItems -Node $serviceEndpoints) },
        [pscustomobject]@{ Type = 'environment'; Items = @(ConvertTo-AzureDevOpsDiscoveryItems -Node $environments) }
    )) {
        foreach ($resource in @($resourceDefinition.Items)) {
            $resourceId = [string](Get-DiscoveryPropertyValue -InputObject $resource -Name 'id')
            if ([string]::IsNullOrWhiteSpace($resourceId)) {
                continue
            }

            $checkResponse = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @(
                'devops', 'invoke',
                '--organization', $organizationUrl,
                '--area', 'pipelinesChecks',
                '--resource', 'configurations',
                '--route-parameters', "project=$projectName",
                '--query-parameters', "resourceType=$($resourceDefinition.Type)", "resourceId=$resourceId",
                '--output', 'json'
            )).Body
            $checks += @(ConvertTo-AzureDevOpsDiscoveryItems -Node $checkResponse)
        }
    }

    $projectId = [string](Get-DiscoveryPropertyValue -InputObject $project -Name 'id' -Required)
    $reviewedUserNode = Get-DiscoveryPropertyValue -InputObject $reviewedUser -Name 'user'
    $userDescriptor = if ($null -ne $reviewedUserNode) {
        [string](Get-DiscoveryPropertyValue -InputObject $reviewedUserNode -Name 'descriptor')
    }
    else {
        [string](Get-DiscoveryPropertyValue -InputObject $reviewedUser -Name 'descriptor')
    }
    if ([string]::IsNullOrWhiteSpace($userDescriptor)) {
        throw 'Azure DevOps discovery did not return the reviewed administrator descriptor.'
    }

    $projectPermissionToken = '$PROJECT:vstfs:///Classification/TeamProject/' + $projectId
    $effectivePermissions = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @(
        'devops', 'security', 'permission', 'list',
        '--organization', $organizationUrl,
        '--namespace-id', '52d39943-cb85-4d7f-8fa8-c6baac873819',
        '--subject', $userDescriptor,
        '--token', $projectPermissionToken,
        '--output', 'json'
    )).Body

    $body = [ordered]@{
        reviewedUser = $reviewedUser
        project = $project
        repositories = $repositories
        serviceEndpoints = $serviceEndpoints
        environments = $environments
        pipelines = $pipelines
        checks = $checks
        effectivePermissions = $effectivePermissions
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
    $response = Invoke-BoundedRetry -Request $Request -Operation 'DiscoveryBundle' -Arguments @{ OrganizationUrl = [string]$TenantConfiguration.AzureDevOps.OrganizationUrl; ProjectName = [string]$TenantConfiguration.AzureDevOps.ProjectName; AdminUpn = [string]$TenantConfiguration.AdminUpn }
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

    $reviewedUser = Get-DiscoveryPropertyValue -InputObject $body -Name 'reviewedUser'
    if ($null -ne $reviewedUser) {
        $reviewedUserId = [string](Get-DiscoveryPropertyValue -InputObject $reviewedUser -Name 'id')
        if ([string]::IsNullOrWhiteSpace($reviewedUserId)) {
            throw 'Azure DevOps reviewed administrator entitlement did not return a stable id.'
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDevOpsUserEntitlement'
            Id = $reviewedUserId
            Name = 'Reviewed administrator entitlement'
            Scope = $organizationScope
            Status = 'Found'
        }
    }

    foreach ($item in @(ConvertTo-AzureDevOpsDiscoveryItems -Node (Get-DiscoveryPropertyValue -InputObject $body -Name 'repositories'))) {
        if ($null -eq $item) {
            continue
        }

        $repositoryId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($repositoryId)) {
            continue
        }

        $repositorySize = Get-DiscoveryPropertyValue -InputObject $item -Name 'size'
        $repositoryDefaultBranch = Get-DiscoveryPropertyValue -InputObject $item -Name 'defaultBranch'

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDevOpsRepository'
            Id = $repositoryId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            Url = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'webUrl')
            Scope = $organizationScope
            Status = 'Found'
            Size = if ($null -eq $repositorySize) { 0 } else { [long]$repositorySize }
            DefaultBranch = [string]$repositoryDefaultBranch
        }
    }

    foreach ($propertyName in @('serviceEndpoints', 'environments', 'pipelines', 'checks')) {
        foreach ($item in @(ConvertTo-AzureDevOpsDiscoveryItems -Node (Get-DiscoveryPropertyValue -InputObject $body -Name $propertyName))) {
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
            }

            $itemName = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            if ($propertyName -ceq 'checks' -and [string]::IsNullOrWhiteSpace($itemName)) {
                $checkType = Get-DiscoveryPropertyValue -InputObject $item -Name 'type'
                if ($null -ne $checkType) {
                    $itemName = [string](Get-DiscoveryPropertyValue -InputObject $checkType -Name 'name')
                }
            }

            $resources += [pscustomobject][ordered]@{
                Type = $type
                Id = $itemId
                Name = $itemName
                Scope = $organizationScope
                Status = 'Found'
            }
        }
    }

    foreach ($permission in @(ConvertTo-AzureDevOpsDiscoveryItems -Node (Get-DiscoveryPropertyValue -InputObject $body -Name 'effectivePermissions'))) {
        $legacyPermissionId = [string](Get-DiscoveryPropertyValue -InputObject $permission -Name 'id')
        $legacyPermissionName = [string](Get-DiscoveryPropertyValue -InputObject $permission -Name 'name')
        if (-not [string]::IsNullOrWhiteSpace($legacyPermissionId) -and -not [string]::IsNullOrWhiteSpace($legacyPermissionName)) {
            $resources += [pscustomobject][ordered]@{
                Type = 'AzureDevOpsEffectivePermission'
                Id = $legacyPermissionId
                Name = $legacyPermissionName
                Scope = $organizationScope
                Status = 'Found'
            }
            continue
        }

        $permissionToken = [string](Get-DiscoveryPropertyValue -InputObject $permission -Name 'token')
        $aces = Get-DiscoveryPropertyValue -InputObject $permission -Name 'acesDictionary'
        if ([string]::IsNullOrWhiteSpace($permissionToken) -or $null -eq $aces -or @($aces.PSObject.Properties).Count -eq 0) {
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDevOpsEffectivePermission'
            Id = $permissionToken
            Name = 'Reviewed administrator project permissions'
            Scope = $organizationScope
            Status = 'Found'
        }
    }

    New-DiscoveryServiceResult -Name 'AzureDevOps' -Status 'Found' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $resources -RawPayload $body
}