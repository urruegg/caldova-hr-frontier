function Invoke-GitHubDiscoveryRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Arguments
    )

    if ($Operation -cne 'DiscoveryBundle') {
        throw 'Unsupported GitHub discovery operation.'
    }

    $repositoryPath = "repos/{0}/{1}" -f $Arguments.Owner, $Arguments.Repository
    $environmentName = [string]$Arguments.EnvironmentName
    $requiredEndpoints = [ordered]@{
        repository = $repositoryPath
        oidcCustomization = "$repositoryPath/actions/oidc/customization/sub"
        rulesets = "$repositoryPath/rulesets"
    }
    $remainingEndpoints = [ordered]@{
        actionsPermissions = "$repositoryPath/actions/permissions"
        workflows = "$repositoryPath/actions/workflows"
        collaborator = "$repositoryPath/collaborators/$($Arguments.Owner)/permission"
    }
    $body = [ordered]@{
    }
    foreach ($endpoint in $requiredEndpoints.GetEnumerator()) {
        $response = Invoke-DiscoveryNativeCommand -FilePath 'gh' -ArgumentList @('api', [string]$endpoint.Value)
        if ([int]$response.StatusCode -ne 200) {
            return $response
        }

        $body[$endpoint.Key] = $response.Body
    }

    $environmentResponse = Invoke-DiscoveryNativeCommand -FilePath 'gh' -ArgumentList @('api', "$repositoryPath/environments/$environmentName")
    if ([int]$environmentResponse.StatusCode -eq 404) {
        $body.environment = $null
        $body.environmentStatus = 'Missing'
        $body.variables = @()
    }
    elseif ([int]$environmentResponse.StatusCode -ne 200) {
        return $environmentResponse
    }
    else {
        $body.environment = $environmentResponse.Body
        $body.environmentStatus = 'Found'
        $variablesResponse = Invoke-DiscoveryNativeCommand -FilePath 'gh' -ArgumentList @('api', "$repositoryPath/environments/$environmentName/variables")
        if ([int]$variablesResponse.StatusCode -ne 200) {
            return $variablesResponse
        }
        $body.variables = $variablesResponse.Body
    }

    foreach ($endpoint in $remainingEndpoints.GetEnumerator()) {
        $response = Invoke-DiscoveryNativeCommand -FilePath 'gh' -ArgumentList @('api', [string]$endpoint.Value)
        if ([int]$response.StatusCode -ne 200) {
            return $response
        }

        $body[$endpoint.Key] = $response.Body
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = $body
    }
}

function Get-GitHubDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TenantConfiguration,

        [Parameter(Mandatory)]
        [guid]$RunId,

        [Parameter(Mandatory)]
        [datetime]$CollectedUtc,

        [scriptblock]$Request = ${function:Invoke-GitHubDiscoveryRequest}
    )

    $sourceApi = 'GitHub REST v3'
    $arguments = [ordered]@{
        Owner = [string]$TenantConfiguration.GitHub.Owner
        OwnerId = [string]$TenantConfiguration.GitHub.OwnerId
        Repository = [string]$TenantConfiguration.GitHub.Repository
        RepositoryId = [string]$TenantConfiguration.GitHub.RepositoryId
        EnvironmentName = [string]$TenantConfiguration.GitHub.EnvironmentName
    }
    $response = Invoke-BoundedRetry -Request $Request -Operation 'DiscoveryBundle' -Arguments $arguments
    $statusCode = Get-DiscoveryStatusCode -Response $response
    if ($statusCode -in @(401, 403)) {
        return New-DiscoveryServiceResult -Name 'GitHub' -Status 'Unauthorized' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 404) {
        return New-DiscoveryServiceResult -Name 'GitHub' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }
    if ($statusCode -eq 408 -or $statusCode -eq 429 -or ($statusCode -ge 500 -and $statusCode -le 599)) {
        return New-DiscoveryServiceResult -Name 'GitHub' -Status 'Unavailable' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload (Get-DiscoveryResponseBody -Response $response)
    }

    $body = Get-DiscoveryResponseBody -Response $response
    $repository = Get-DiscoveryPropertyValue -InputObject $body -Name 'repository' -Required
    if ($repository -is [System.Array]) {
        if (@($repository).Count -eq 0) {
            return New-DiscoveryServiceResult -Name 'GitHub' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
        }
        if (@($repository).Count -gt 1) {
            $candidates = foreach ($item in @($repository)) {
                [pscustomobject]@{
                    Type = 'GitHubRepository'
                    Id = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'id')
                    Name = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'name')
                    Url = [string](Get-DiscoveryPropertyValue -InputObject $item -Name 'html_url')
                    Scope = "repo:$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)"
                    Status = 'Ambiguous'
                }
            }
            return New-DiscoveryServiceResult -Name 'GitHub' -Status 'Ambiguous' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources $candidates -RawPayload $body
        }

        $repository = @($repository)[0]
    }

    if ($null -eq $repository) {
        return New-DiscoveryServiceResult -Name 'GitHub' -Status 'Missing' -SourceApi $sourceApi -CollectedUtc $CollectedUtc -RawPayload $body
    }

    $repositoryName = [string](Get-DiscoveryPropertyValue -InputObject $repository -Name 'name' -Required)
    $repositoryUrl = [string](Get-DiscoveryPropertyValue -InputObject $repository -Name 'url')
    if ([string]::IsNullOrWhiteSpace($repositoryUrl)) {
        $repositoryUrl = [string](Get-DiscoveryPropertyValue -InputObject $repository -Name 'html_url')
    }

    $repositoryId = [string](Get-DiscoveryPropertyValue -InputObject $repository -Name 'id')
    if ([string]::IsNullOrWhiteSpace($repositoryId)) {
        $repositoryId = [string](Get-DiscoveryPropertyValue -InputObject $repository -Name 'repositoryId')
    }

    $ownerId = [string](Get-DiscoveryPropertyValue -InputObject $repository -Name 'ownerId')
    if ([string]::IsNullOrWhiteSpace($ownerId)) {
        $owner = Get-DiscoveryPropertyValue -InputObject $repository -Name 'owner'
        if ($null -ne $owner) {
            $ownerId = [string](Get-DiscoveryPropertyValue -InputObject $owner -Name 'id')
        }
    }

    $environment = Get-DiscoveryPropertyValue -InputObject $body -Name 'environment'
    $environmentName = if ($null -ne $environment) { [string](Get-DiscoveryPropertyValue -InputObject $environment -Name 'name') } else { [string](Get-DiscoveryPropertyValue -InputObject $repository -Name 'environment') }
    $environmentCollectionStatus = [string](Get-DiscoveryPropertyValue -InputObject $body -Name 'environmentStatus')
    if ([string]::IsNullOrWhiteSpace($environmentCollectionStatus) -and -not [string]::IsNullOrWhiteSpace($environmentName)) {
        $environmentCollectionStatus = 'Found'
    }
    $oidcSettings = Get-DiscoveryPropertyValue -InputObject $body -Name 'oidcCustomization' -Required
    $expectedPrefix = Get-GitHubOidcSubject -Owner $TenantConfiguration.GitHub.Owner -OwnerId $TenantConfiguration.GitHub.OwnerId -Repository $TenantConfiguration.GitHub.Repository -RepositoryId $TenantConfiguration.GitHub.RepositoryId -TenantAlias $TenantConfiguration.TenantAlias
    $useDefault = [bool](Get-DiscoveryPropertyValue -InputObject $oidcSettings -Name 'use_default')
    $useImmutable = [bool](Get-DiscoveryPropertyValue -InputObject $oidcSettings -Name 'use_immutable_subject')
    $subjectPrefix = [string](Get-DiscoveryPropertyValue -InputObject $oidcSettings -Name 'sub_claim_prefix' -Required)
    $expectedRepositoryId = [string]$TenantConfiguration.GitHub.RepositoryId
    $expectedOwnerId = [string]$TenantConfiguration.GitHub.OwnerId
    $identityMatches = -not [string]::IsNullOrWhiteSpace($repositoryId) -and -not [string]::IsNullOrWhiteSpace($ownerId) -and $repositoryId -ceq $expectedRepositoryId -and $ownerId -ceq $expectedOwnerId
    $oidcMatches = -not $useDefault -and $useImmutable -and $subjectPrefix -ceq $expectedPrefix
    $repositoryStatus = if ($identityMatches) { 'Found' } else { 'Ambiguous' }
    $oidcStatus = if ($oidcMatches) { 'Found' } else { 'Ambiguous' }
    $environmentStatus = if ($environmentCollectionStatus -ceq 'Missing') { 'Missing' } elseif ($environmentCollectionStatus -ceq 'Found' -and $environmentName -ceq $TenantConfiguration.GitHub.EnvironmentName) { 'Found' } else { 'Ambiguous' }
    $status = if ($repositoryStatus -ceq 'Ambiguous' -or $oidcStatus -ceq 'Ambiguous' -or $environmentStatus -ceq 'Ambiguous') { 'Ambiguous' } elseif ($environmentStatus -ceq 'Missing') { 'Missing' } else { 'Found' }
    $repositoryResource = [pscustomobject][ordered]@{
        Type = 'GitHubRepository'
        Id = $repositoryId
        Name = $repositoryName
        Url = $repositoryUrl
        Scope = "repo:$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)"
        Status = $repositoryStatus
    }

    $oidcResource = [pscustomobject][ordered]@{
        Type = 'GitHubOidcCustomization'
        Id = $expectedPrefix
        Name = 'Immutable OIDC subject'
        Scope = "repo:$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)"
        Status = $oidcStatus
    }

    $environmentResource = [pscustomobject][ordered]@{
        Type = 'GitHubEnvironment'
        Id = [string]$TenantConfiguration.GitHub.EnvironmentName
        Name = [string]$TenantConfiguration.GitHub.EnvironmentName
        Url = "https://github.com/$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)/settings/environments"
        Scope = "repo:$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)"
        Status = $environmentStatus
    }

    New-DiscoveryServiceResult -Name 'GitHub' -Status $status -SourceApi $sourceApi -CollectedUtc $CollectedUtc -Resources @($repositoryResource, $oidcResource, $environmentResource) -RawPayload $body
}