function Get-EntraDiscoveryComponent {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $components = Get-DiscoveryPropertyValue -InputObject $TenantConfiguration -Name 'Components'
    if ($null -eq $components) {
        return $null
    }

    try {
        $componentEntries = Get-ObjectEntryTable -InputObject $components
    }
    catch {
        return $null
    }

    if (-not $componentEntries.Contains($Name)) {
        return $null
    }

    $componentEntries[$Name]
}

function Get-EntraDiscoveryComponentId {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $component = Get-EntraDiscoveryComponent -TenantConfiguration $TenantConfiguration -Name $Name
    if ($null -eq $component) {
        return $null
    }

    if ([string](Get-DiscoveryPropertyValue -InputObject $component -Name 'Mode') -cne 'Existing') {
        return $null
    }

    $id = [string](Get-DiscoveryPropertyValue -InputObject $component -Name 'Id')
    if ([string]::IsNullOrWhiteSpace($id)) {
        return $null
    }

    $id
}

function Get-EntraDiscoveryBootstrapDisplayName {
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration
    )

    $namingRoot = [string](Get-DiscoveryPropertyValue -InputObject $TenantConfiguration -Name 'NamingRoot')
    if ([string]::IsNullOrWhiteSpace($namingRoot)) {
        throw 'Tenant configuration must include NamingRoot for Entra discovery.'
    }

    "$namingRoot-github-bootstrap"
}

function ConvertTo-EntraDiscoveryItems {
    param(
        [AllowNull()]
        [object]$Node
    )

    if ($null -eq $Node) {
        return @()
    }

    $valueNode = Get-DiscoveryPropertyValue -InputObject $Node -Name 'value'
    if ($null -ne $valueNode) {
        return @($valueNode)
    }

    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string]) -and -not ($Node -is [System.Collections.IDictionary])) {
        return @($Node)
    }

    @($Node)
}

function Invoke-EntraDiscoveryRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Arguments
    )

    if ($Operation -cne 'DiscoveryBundle') {
        throw 'Unsupported Entra discovery operation.'
    }

    $tenantConfiguration = $Arguments['TenantConfiguration']
    if ($null -eq $tenantConfiguration) {
        throw 'Entra discovery requires TenantConfiguration.'
    }

    $applicationObjectId = Get-EntraDiscoveryComponentId -TenantConfiguration $tenantConfiguration -Name 'EntraApplication'
    $servicePrincipalObjectId = Get-EntraDiscoveryComponentId -TenantConfiguration $tenantConfiguration -Name 'EntraServicePrincipal'
    $applicationsBody = $null
    $servicePrincipalsBody = $null

    if (-not [string]::IsNullOrWhiteSpace($applicationObjectId)) {
        $applicationsBody = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('rest', '--method', 'get', '--url', "https://graph.microsoft.com/v1.0/applications/$applicationObjectId")).Body
    }
    else {
        $displayName = Get-EntraDiscoveryBootstrapDisplayName -TenantConfiguration $tenantConfiguration
        $encodedDisplayName = [System.Uri]::EscapeDataString("displayName eq '$displayName'")
        $applicationsBody = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('rest', '--method', 'get', '--url', "https://graph.microsoft.com/v1.0/applications?`$filter=$encodedDisplayName")).Body
    }

    $applications = @(ConvertTo-EntraDiscoveryItems -Node $applicationsBody)

    if (-not [string]::IsNullOrWhiteSpace($servicePrincipalObjectId)) {
        $servicePrincipalsBody = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('rest', '--method', 'get', '--url', "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalObjectId")).Body
    }
    elseif ($applications.Count -eq 1) {
        $applicationAppId = [string](Get-DiscoveryPropertyValue -InputObject $applications[0] -Name 'appId')
        if (-not [string]::IsNullOrWhiteSpace($applicationAppId)) {
            $encodedAppId = [System.Uri]::EscapeDataString("appId eq '$applicationAppId'")
            $servicePrincipalsBody = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('rest', '--method', 'get', '--url', "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$encodedAppId")).Body
        }
    }

    $federatedIdentityCredentialsBody = @()
    if ($applications.Count -eq 1) {
        $applicationId = [string](Get-DiscoveryPropertyValue -InputObject $applications[0] -Name 'id')
        if (-not [string]::IsNullOrWhiteSpace($applicationId)) {
            $federatedIdentityCredentialsBody = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('rest', '--method', 'get', '--url', "https://graph.microsoft.com/v1.0/applications/$applicationId/federatedIdentityCredentials")).Body
        }
    }

    $body = [ordered]@{
        applications = $applicationsBody
        servicePrincipals = $servicePrincipalsBody
        federatedIdentityCredentials = $federatedIdentityCredentialsBody
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = $body
    }
}

function Get-EntraDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [guid]$RunId,

        [Parameter(Mandatory)]
        [datetime]$CollectedUtc,

        [scriptblock]$Request = ${function:Invoke-EntraDiscoveryRequest}
    )

    $sourceApi = 'Microsoft Graph v1.0'
    $expectedApplicationId = Get-EntraDiscoveryComponentId -TenantConfiguration $TenantConfiguration -Name 'EntraApplication'
    $expectedServicePrincipalId = Get-EntraDiscoveryComponentId -TenantConfiguration $TenantConfiguration -Name 'EntraServicePrincipal'
    $response = Invoke-BoundedRetry -Request $Request -Operation 'DiscoveryBundle' -Arguments @{ TenantId = [string]$TenantConfiguration.TenantId; TenantConfiguration = $TenantConfiguration }
    $statusCode = Get-DiscoveryStatusCode -Response $response
    if ($statusCode -in @(401, 403)) {
        return New-DiscoveryServiceResult -Name 'Entra' -Status 'Unauthorized' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 404) {
        return New-DiscoveryServiceResult -Name 'Entra' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 408 -or $statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
        return New-DiscoveryServiceResult -Name 'Entra' -Status 'Unavailable' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }

    $body = Get-DiscoveryResponseBody -Response $response
    $applicationsNode = Get-DiscoveryPropertyValue -InputObject $body -Name 'applications'
    if ($null -eq $applicationsNode) {
        $applicationsNode = Get-DiscoveryPropertyValue -InputObject $body -Name 'application' -Required
    }

    $applications = @(ConvertTo-EntraDiscoveryItems -Node $applicationsNode)

    if ($applications.Count -eq 0) {
        return New-DiscoveryServiceResult -Name 'Entra' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    if ($applications.Count -gt 1) {
        $resources = foreach ($candidate in $applications) {
            $candidateId = [string](Get-DiscoveryPropertyValue -InputObject $candidate -Name 'id')
            if ([string]::IsNullOrWhiteSpace($candidateId)) {
                $candidateId = [string](Get-DiscoveryPropertyValue -InputObject $candidate -Name 'appId')
            }

            [pscustomobject]@{
                Type = 'EntraApplication'
                Id = $candidateId
                Name = [string](Get-DiscoveryPropertyValue -InputObject $candidate -Name 'displayName')
                Url = if ($candidateId) { "https://graph.microsoft.com/v1.0/applications/$candidateId" } else { 'https://graph.microsoft.com/v1.0/applications' }
                Scope = "tenant:$($TenantConfiguration.TenantId)"
                Status = 'Ambiguous'
            }
        }
        return New-DiscoveryServiceResult -Name 'Entra' -Status 'Ambiguous' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $resources -RawPayload $body
    }

    $application = $applications[0]

    $appId = [string](Get-DiscoveryPropertyValue -InputObject $application -Name 'id')
    if ([string]::IsNullOrWhiteSpace($appId)) {
        $appId = [string](Get-DiscoveryPropertyValue -InputObject $application -Name 'appId')
    }
    if (-not [string]::IsNullOrWhiteSpace($expectedApplicationId) -and $appId -cne $expectedApplicationId) {
        return New-DiscoveryServiceResult -Name 'Entra' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    $displayName = [string](Get-DiscoveryPropertyValue -InputObject $application -Name 'name')
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        $displayName = [string](Get-DiscoveryPropertyValue -InputObject $application -Name 'displayName')
    }
    $resources = @(
        [pscustomobject][ordered]@{
            Type = 'EntraApplication'
            Id = $appId
            Name = $displayName
            Url = if ($appId) { "https://graph.microsoft.com/v1.0/applications/$appId" } else { 'https://graph.microsoft.com/v1.0/applications' }
            Scope = "tenant:$($TenantConfiguration.TenantId)"
            Status = 'Found'
        }
    )

    $servicePrincipals = @(ConvertTo-EntraDiscoveryItems -Node (Get-DiscoveryPropertyValue -InputObject $body -Name 'servicePrincipals'))
    if ($servicePrincipals.Count -eq 0) {
        $servicePrincipalNode = Get-DiscoveryPropertyValue -InputObject $body -Name 'servicePrincipal'
        if ($null -ne $servicePrincipalNode) {
            $servicePrincipals = @(ConvertTo-EntraDiscoveryItems -Node $servicePrincipalNode)
        }
    }

    foreach ($servicePrincipal in $servicePrincipals) {
        if ($null -eq $servicePrincipal) {
            continue
        }

        $spId = [string](Get-DiscoveryPropertyValue -InputObject $servicePrincipal -Name 'id')
        if ([string]::IsNullOrWhiteSpace($spId)) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($expectedServicePrincipalId) -and $spId -cne $expectedServicePrincipalId) {
            continue
        }

        $servicePrincipalName = [string](Get-DiscoveryPropertyValue -InputObject $servicePrincipal -Name 'displayName')
        if ([string]::IsNullOrWhiteSpace($servicePrincipalName)) {
            $servicePrincipalName = $spId
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'EntraServicePrincipal'
            Id = $spId
            Name = $servicePrincipalName
            Url = "https://graph.microsoft.com/v1.0/servicePrincipals/$spId"
            Scope = "tenant:$($TenantConfiguration.TenantId)"
            Status = 'Found'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($expectedServicePrincipalId) -and (@($resources | Where-Object { $_.Type -ceq 'EntraServicePrincipal' }).Count -eq 0)) {
        return New-DiscoveryServiceResult -Name 'Entra' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    $federatedCredentials = @(ConvertTo-EntraDiscoveryItems -Node (Get-DiscoveryPropertyValue -InputObject $body -Name 'federatedIdentityCredentials'))
    if ($federatedCredentials.Count -eq 0) {
        $federatedCredential = Get-DiscoveryPropertyValue -InputObject $body -Name 'federatedIdentityCredential'
        if ($null -ne $federatedCredential) {
            $federatedCredentials = @(ConvertTo-EntraDiscoveryItems -Node $federatedCredential)
        }
    }

    foreach ($credential in $federatedCredentials) {
        if ($null -eq $credential) {
            continue
        }

        $credentialId = [string](Get-DiscoveryPropertyValue -InputObject $credential -Name 'id')
        if ([string]::IsNullOrWhiteSpace($credentialId)) {
            $credentialId = [string](Get-DiscoveryPropertyValue -InputObject $credential -Name 'name')
        }

        if ([string]::IsNullOrWhiteSpace($credentialId)) {
            continue
        }

        $credentialName = [string](Get-DiscoveryPropertyValue -InputObject $credential -Name 'name')
        if ([string]::IsNullOrWhiteSpace($credentialName)) {
            $credentialName = $credentialId
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'EntraFederatedIdentityCredential'
            Id = $credentialId
            Name = $credentialName
            Url = if ($appId) { "https://graph.microsoft.com/v1.0/applications/$appId/federatedIdentityCredentials/$credentialId" } else { 'https://graph.microsoft.com/v1.0/applications' }
            Scope = "application:$appId"
            Status = 'Found'
        }
    }

    New-DiscoveryServiceResult -Name 'Entra' -Status 'Found' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $resources -RawPayload $body
}