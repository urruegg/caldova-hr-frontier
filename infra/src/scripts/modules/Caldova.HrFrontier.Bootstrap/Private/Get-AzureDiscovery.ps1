function Invoke-AzureDiscoveryRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Arguments
    )

    if ($Operation -cne 'DiscoveryBundle') {
        throw 'Unsupported Azure discovery operation.'
    }

    $subscriptionScope = "/subscriptions/$($Arguments.SubscriptionId)"
    $query = "resources | where subscriptionId =~ '$($Arguments.SubscriptionId)'"
    $subscriptionBody = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('account', 'show', '--subscription', $Arguments.SubscriptionId, '--output', 'json')).Body
    $body = [ordered]@{
        subscription = $subscriptionBody
        resources = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('graph', 'query', '-q', $query, '--output', 'json')).Body
        roleAssignments = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('role', 'assignment', 'list', '--scope', $subscriptionScope, '--output', 'json')).Body
        policyAssignments = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('policy', 'assignment', 'list', '--scope', $subscriptionScope, '--output', 'json')).Body
        diagnosticSettings = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('monitor', 'diagnostic-settings', 'subscription', 'list', '--subscription', $Arguments.SubscriptionId, '--output', 'json')).Body
        providerState = (Invoke-DiscoveryNativeCommand -FilePath 'az' -ArgumentList @('provider', 'show', '--namespace', 'Microsoft.Authorization', '--subscription', $Arguments.SubscriptionId, '--output', 'json')).Body
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = $body
    }
}

function Get-AzureDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [guid]$RunId,

        [Parameter(Mandatory)]
        [datetime]$CollectedUtc,

        [scriptblock]$Request = ${function:Invoke-AzureDiscoveryRequest}
    )

    $sourceApi = 'Azure Resource Graph + ARM'
    $response = Invoke-BoundedRetry -Request $Request -Operation 'DiscoveryBundle' -Arguments @{ SubscriptionId = [string]$TenantConfiguration.SubscriptionId }
    $statusCode = Get-DiscoveryStatusCode -Response $response
    if ($statusCode -in @(401, 403)) {
        return New-DiscoveryServiceResult -Name 'Azure' -Status 'Unauthorized' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 404) {
        return New-DiscoveryServiceResult -Name 'Azure' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 408 -or $statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
        return New-DiscoveryServiceResult -Name 'Azure' -Status 'Unavailable' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }

    $body = Get-DiscoveryResponseBody -Response $response
    $subscription = Get-DiscoveryPropertyValue -InputObject $body -Name 'subscription' -Required
    if ($null -eq $subscription) {
        return New-DiscoveryServiceResult -Name 'Azure' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    $subscriptionId = [string](Get-DiscoveryPropertyValue -InputObject $subscription -Name 'id')
    if ([string]::IsNullOrWhiteSpace($subscriptionId)) {
        $subscriptionId = [string](Get-DiscoveryPropertyValue -InputObject $subscription -Name 'subscriptionId')
    }

    $subscriptionName = [string](Get-DiscoveryPropertyValue -InputObject $subscription -Name 'name')
    if ([string]::IsNullOrWhiteSpace($subscriptionName)) {
        $subscriptionName = [string](Get-DiscoveryPropertyValue -InputObject $subscription -Name 'displayName')
    }
    $resources = @(
        [pscustomobject][ordered]@{
            Type = 'AzureSubscription'
            Id = $subscriptionId
            Name = $subscriptionName
            Url = "https://management.azure.com/subscriptions/$subscriptionId"
            Scope = "/subscriptions/$subscriptionId"
            Status = 'Found'
        }
    )

    foreach ($item in @(Get-DiscoveryPropertyValue -InputObject $body -Name 'resources')) {
        if ($null -eq $item) {
            continue
        }

        $resourceId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($resourceId)) {
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureResource'
            Id = $resourceId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            Url = "https://management.azure.com$resourceId"
            Scope = "/subscriptions/$subscriptionId"
            Status = 'Found'
        }
    }

    foreach ($item in @(Get-DiscoveryPropertyValue -InputObject $body -Name 'roleAssignments')) {
        if ($null -eq $item) {
            continue
        }

        $roleAssignmentId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($roleAssignmentId)) {
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureRoleAssignment'
            Id = $roleAssignmentId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'roleDefinitionId')
            Scope = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'scope')
            Status = 'Found'
        }
    }

    foreach ($item in @(Get-DiscoveryPropertyValue -InputObject $body -Name 'policyAssignments')) {
        if ($null -eq $item) {
            continue
        }

        $policyAssignmentId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($policyAssignmentId)) {
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzurePolicyAssignment'
            Id = $policyAssignmentId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            Scope = "/subscriptions/$subscriptionId"
            Status = 'Found'
        }
    }

    foreach ($item in @(Get-DiscoveryPropertyValue -InputObject $body -Name 'diagnosticSettings')) {
        if ($null -eq $item) {
            continue
        }

        $diagnosticSettingId = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
        if ([string]::IsNullOrWhiteSpace($diagnosticSettingId)) {
            continue
        }

        $resources += [pscustomobject][ordered]@{
            Type = 'AzureDiagnosticSetting'
            Id = $diagnosticSettingId
            Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
            Scope = "/subscriptions/$subscriptionId"
            Status = 'Found'
        }
    }

    $providerState = Get-DiscoveryPropertyValue -InputObject $body -Name 'providerState'
    if ($null -ne $providerState) {
        $providerNamespace = [string](Get-DiscoveryPropertyValue -InputObject $providerState -Name 'namespace')
        $providerRegistrationState = [string](Get-DiscoveryPropertyValue -InputObject $providerState -Name 'registrationState')
        if (-not [string]::IsNullOrWhiteSpace($providerNamespace)) {
            $resources += [pscustomobject][ordered]@{
                Type = 'AzureProviderState'
                Id = $providerNamespace
                Name = $providerRegistrationState
                Scope = "/subscriptions/$subscriptionId"
                Status = 'Found'
            }
        }
    }

    New-DiscoveryServiceResult -Name 'Azure' -Status 'Found' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $resources -RawPayload $body
}