[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$TenantConfigurationPath,

    [Parameter(DontShow)]
    [scriptblock]$AzRequest,

    [Parameter(DontShow)]
    [scriptblock]$GitHubRequest,

    [Parameter(DontShow)]
    [scriptblock]$AzureDevOpsRequest,

    [Parameter(DontShow)]
    [scriptblock]$NativeCommandRunner,

    [Parameter(DontShow)]
    [scriptblock]$HttpRequestRunner,

    [string]$PlanOutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
}

function Get-DefaultTenantConfigurationPath {
    param(
        [Parameter(Mandatory)]
        [string]$TenantAliasValue
    )

    Join-Path $PSScriptRoot "..\config\tenants\$TenantAliasValue.psd1"
}

function New-OrderedDictionary {
    param(
        [Parameter(Mandatory)]
        [hashtable]$InputObject
    )

    $ordered = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($key in $InputObject.Keys) {
        $ordered.Add([string]$key, $InputObject[$key])
    }

    $ordered
}

function ConvertTo-Hashtable {
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return @{}
    }

    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table[[string]$key] = $InputObject[$key]
        }

        return $table
    }

    $table = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
            $table[$property.Name] = $property.Value
        }
    }

    $table
}

function ConvertTo-OrderedData {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string] -or $Value -is [ValueType]) {
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $ordered[[string]$key] = ConvertTo-OrderedData -Value $Value[$key]
        }

        return [pscustomobject]$ordered
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $items = @()
        foreach ($item in $Value) {
            $items += ConvertTo-OrderedData -Value $item
        }

        return $items
    }

    $properties = @($Value.PSObject.Properties)
    if ($properties.Count -gt 0) {
        $ordered = [ordered]@{}
        foreach ($property in $properties) {
            if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
                $ordered[$property.Name] = ConvertTo-OrderedData -Value $property.Value
            }
        }

        return [pscustomobject]$ordered
    }

    $Value
}

function ConvertFrom-JsonText {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $Text | ConvertFrom-Json
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $result = & $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    $resultTable = ConvertTo-Hashtable -InputObject $result
    if (-not $resultTable.ContainsKey('ExitCode')) {
        throw "Native command '$FilePath' did not return ExitCode."
    }

    [pscustomobject]@{
        ExitCode = [int]$resultTable.ExitCode
        StdOut = if ($resultTable.ContainsKey('StdOut')) { [string]$resultTable.StdOut } else { '' }
        StdErr = if ($resultTable.ContainsKey('StdErr')) { [string]$resultTable.StdErr } else { '' }
    }
}

function Invoke-NativeJsonCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [switch]$AllowNotFound
    )

    $commandResult = Invoke-NativeCommand -Runner $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    if ($commandResult.ExitCode -ne 0) {
        if ($AllowNotFound -and $commandResult.StdErr -match 'not found|could not be found|does not exist|404') {
            return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = $null }
        }

        throw "$FilePath $($ArgumentList -join ' ') failed with exit code $($commandResult.ExitCode)."
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = ConvertFrom-JsonText -Text $commandResult.StdOut
    }
}

function Invoke-HttpJson {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [AllowNull()]
        [hashtable]$Headers,

        [AllowNull()]
        [object]$Body
    )

    $response = & $Runner -Method $Method -Uri $Uri -Headers $Headers -Body $Body
    $responseTable = ConvertTo-Hashtable -InputObject $response
    if (-not $responseTable.ContainsKey('StatusCode')) {
        throw "HTTP request '$Method $Uri' did not return StatusCode."
    }

    $responseBody = if (-not $responseTable.ContainsKey('Body') -or $null -eq $responseTable.Body) {
        $null
    }
    elseif ($responseTable.Body -is [string]) {
        ConvertFrom-JsonText -Text $responseTable.Body
    }
    else {
        $responseTable.Body
    }

    [pscustomobject]@{
        StatusCode = [int]$responseTable.StatusCode
        Headers = if ($responseTable.ContainsKey('Headers')) { $responseTable.Headers } else { @{} }
        Body = $responseBody
    }
}

function Get-OnlyCollectionCandidateOrNull {
    param(
        [AllowNull()]
        [object]$Collection,

        [Parameter(Mandatory)]
        [string]$AmbiguousMessage
    )

    $items = @($Collection)
    if ($items.Count -gt 1) {
        throw $AmbiguousMessage
    }

    if ($items.Count -eq 0) {
        return $null
    }

    $items[0]
}

function Get-GraphAccessHeaders {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner
    )

    $tokenResponse = Invoke-NativeJsonCommand -Runner $Runner -FilePath 'az' -ArgumentList @('account', 'get-access-token', '--resource-type', 'ms-graph', '--output', 'json')
    $tokenBody = Get-ResponseBodyOrNull -Response $tokenResponse
    if ($null -eq $tokenBody -or [string]::IsNullOrWhiteSpace([string]$tokenBody.accessToken)) {
        throw 'Microsoft Graph access token acquisition failed.'
    }

    @{
        Authorization = 'Bearer {0}' -f [string]$tokenBody.accessToken
        Accept = 'application/json'
        'Content-Type' = 'application/json'
    }
}

function Get-GitHubAccessHeaders {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner
    )

    $token = if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $env:GITHUB_TOKEN
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:GH_TOKEN)) {
        $env:GH_TOKEN
    }
    else {
        $tokenCommand = Invoke-NativeCommand -Runner $Runner -FilePath 'gh' -ArgumentList @('auth', 'token')
        if ($tokenCommand.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($tokenCommand.StdOut)) {
            throw 'GitHub token acquisition failed.'
        }

        $tokenCommand.StdOut.Trim()
    }

    @{
        Authorization = 'Bearer {0}' -f $token
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'Content-Type' = 'application/json'
    }
}

function Get-AzureDevOpsAccessHeaders {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner
    )

    $tokenResponse = Invoke-NativeJsonCommand -Runner $Runner -FilePath 'az' -ArgumentList @('account', 'get-access-token', '--resource', '499b84ac-1321-427f-aa17-267ca6975798', '--output', 'json')
    $tokenBody = Get-ResponseBodyOrNull -Response $tokenResponse
    if ($null -eq $tokenBody -or [string]::IsNullOrWhiteSpace([string]$tokenBody.accessToken)) {
        throw 'Azure DevOps access token acquisition failed.'
    }

    @{
        Authorization = 'Bearer {0}' -f [string]$tokenBody.accessToken
        Accept = 'application/json'
        'Content-Type' = 'application/json'
    }
}

function Get-AzureDevOpsOrganizationName {
    param(
        [Parameter(Mandatory)]
        [string]$OrganizationUrl
    )

    $uri = [System.Uri]$OrganizationUrl
    ($uri.AbsolutePath.Trim('/') -split '/')[0]
}

function Assert-ReviewedStableId {
    param(
        [Parameter(Mandatory)]
        [object]$Component,

        [AllowNull()]
        [string]$ObservedId,

        [Parameter(Mandatory)]
        [string]$ComponentName
    )

    if ($Component.Mode -ne 'Existing') {
        return
    }

    if ([string]::IsNullOrWhiteSpace($ObservedId)) {
        throw "$ComponentName stable Id was not returned by the reviewed read-back."
    }

    if ($ObservedId -cne [string]$Component.Id) {
        throw "$ComponentName stable Id does not match the reviewed state."
    }
}

function Write-BomlessJsonAtomically {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value
    )

    $directory = Split-Path -Parent $Path
    if (-not [System.IO.Directory]::Exists($directory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    $tempPath = Join-Path $directory ([guid]::NewGuid().ToString() + '.tmp')
    try {
        $json = $Value | ConvertTo-Json -Depth 30
        [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path) {
            [System.IO.File]::Delete($Path)
        }

        [System.IO.File]::Move($tempPath, $Path)
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            [System.IO.File]::Delete($tempPath)
        }
    }
}

function Resolve-AllowedPlanOutputPath {
    param(
        [Parameter(Mandatory)]
        [string]$CandidatePath
    )

    $resolved = [System.IO.Path]::GetFullPath($CandidatePath)
    $allowedRoots = @([System.IO.Path]::GetTempPath())
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $allowedRoots += [System.IO.Path]::GetFullPath($env:RUNNER_TEMP)
    }

    foreach ($root in $allowedRoots) {
        $normalizedRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
        if ($resolved.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $resolved
        }
    }

    throw 'PlanOutputPath must resolve under the system temporary directory or RUNNER_TEMP.'
}

function New-AdapterResponse {
    param(
        [Parameter(Mandatory)]
        [object]$Result,

        [Parameter(Mandatory)]
        [string]$AdapterName,

        [Parameter(Mandatory)]
        [string]$Operation
    )

    if ($null -eq $Result) {
        throw "$AdapterName adapter operation '$Operation' returned no response."
    }

    $resultTable = ConvertTo-Hashtable -InputObject $Result
    if (-not $resultTable.ContainsKey('StatusCode')) {
        throw "$AdapterName adapter operation '$Operation' must return StatusCode."
    }

    [pscustomobject]@{
        StatusCode = [int]$resultTable.StatusCode
        Headers = if ($resultTable.ContainsKey('Headers')) { $resultTable.Headers } else { @{} }
        Body = if ($resultTable.ContainsKey('Body')) { $resultTable.Body } else { $null }
    }
}

function Invoke-RequestAdapter {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Adapter,

        [Parameter(Mandatory)]
        [string]$AdapterName,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [hashtable]$Arguments
    )

    $response = & $Adapter -Operation $Operation -Arguments (New-OrderedDictionary -InputObject $Arguments)
    New-AdapterResponse -Result $response -AdapterName $AdapterName -Operation $Operation
}

function Get-ResponseBodyOrNull {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    if ($Response.StatusCode -eq 404) {
        return $null
    }

    if ($Response.StatusCode -lt 200 -or $Response.StatusCode -ge 300) {
        throw "Adapter request failed with status code $($Response.StatusCode)."
    }

    $Response.Body
}

function Get-ComponentDefinition {
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $components = ConvertTo-Hashtable -InputObject $Configuration.Components
    if (-not $components.ContainsKey($Name)) {
        throw "Components.$Name is required for bootstrap planning."
    }

    $component = ConvertTo-Hashtable -InputObject $components[$Name]
    if (-not $component.ContainsKey('Mode')) {
        throw "Components.$Name.Mode is required."
    }

    $mode = [string]$component.Mode
    if ($mode -notin @('Existing', 'Create')) {
        throw "Components.$Name.Mode must be Existing or Create."
    }

    if ($mode -eq 'Existing' -and (-not $component.ContainsKey('Id') -or [string]::IsNullOrWhiteSpace([string]$component.Id))) {
        throw "Components.$Name requires a stable Id in Existing mode."
    }

    [pscustomobject]@{
        Name = $Name
        Mode = $mode
        Id = if ($component.ContainsKey('Id')) { [string]$component.Id } else { $null }
    }
}

function Get-RequiredPermissions {
    @(
        [pscustomobject]@{
            Resource = 'Microsoft Dataverse'
            ResourceAppId = '00000007-0000-0000-c000-000000000000'
            PermissionType = 'Scope'
            Permission = 'user_impersonation'
        },
        [pscustomobject]@{
            Resource = 'Microsoft Graph'
            ResourceAppId = '00000003-0000-0000-c000-000000000000'
            PermissionType = 'Role'
            Permission = 'Application.Read.All'
        }
    )
}

function Test-ExactPermissionSet {
    param(
        [AllowNull()]
        [object[]]$ObservedPermissions
    )

    $expected = Get-RequiredPermissions
    $observed = @($ObservedPermissions | ForEach-Object {
        [pscustomobject]@{
            Resource = [string]$_.resourceDisplayName
            Permission = [string]$_.permissionName
            PermissionType = [string]$_.permissionType
        }
    })

    if ($observed.Count -ne $expected.Count) {
        return $false
    }

    foreach ($required in $expected) {
        $match = $observed | Where-Object {
            $_.Resource -ceq $required.Resource -and $_.Permission -ceq $required.Permission -and $_.PermissionType -ceq $required.PermissionType
        }

        if (@($match).Count -ne 1) {
            return $false
        }
    }

    $true
}

function Assert-ApplicationState {
    param(
        [Parameter(Mandatory)]
        [object]$Application,

        [Parameter(Mandatory)]
        [string]$ExpectedDisplayName,

        [string]$ExpectedObjectId
    )

    if ([string]$Application.displayName -cne $ExpectedDisplayName) {
        throw 'Entra application display name does not match the reviewed state.'
    }

    if ([string]$Application.signInAudience -cne 'AzureADMyOrg') {
        throw 'Entra application sign-in audience does not match the reviewed state.'
    }

    if ($ExpectedObjectId -and [string]$Application.id -cne $ExpectedObjectId) {
        throw 'Entra application stable Id does not match the reviewed state.'
    }

    if (@($Application.passwordCredentials).Count -ne 0 -or @($Application.keyCredentials).Count -ne 0) {
        throw 'Entra application credential collections must be empty.'
    }
}

function Assert-ServicePrincipalState {
    param(
        [Parameter(Mandatory)]
        [object]$ServicePrincipal,

        [Parameter(Mandatory)]
        [string]$ExpectedAppId,

        [string]$ExpectedObjectId
    )

    if ([string]$ServicePrincipal.appId -cne $ExpectedAppId) {
        throw 'Entra service principal appId does not match the reviewed application.'
    }

    if ($ExpectedObjectId -and [string]$ServicePrincipal.id -cne $ExpectedObjectId) {
        throw 'Entra service principal stable Id does not match the reviewed state.'
    }
}

function Assert-FederatedCredentialState {
    param(
        [Parameter(Mandatory)]
        [object]$FederatedCredential,

        [Parameter(Mandatory)]
        [string]$ExpectedSubject
    )

    if ([string]$FederatedCredential.issuer -cne 'https://token.actions.githubusercontent.com') {
        throw 'The federated credential issuer does not match the reviewed state.'
    }

    $audiences = @($FederatedCredential.audiences)
    if ($audiences.Count -ne 1 -or [string]$audiences[0] -cne 'api://AzureADTokenExchange') {
        throw 'The federated credential audience does not match the reviewed state.'
    }

    if ([string]$FederatedCredential.subject -cne $ExpectedSubject) {
        throw 'The federated credential subject does not match the reviewed state.'
    }
}

function Assert-GitHubEnvironmentState {
    param(
        [Parameter(Mandatory)]
        [object]$Environment,

        [Parameter(Mandatory)]
        [string]$ExpectedEnvironmentName,

        [Parameter(Mandatory)]
        [int]$ExpectedReviewerId
    )

    if ([string]$Environment.name -cne $ExpectedEnvironmentName) {
        throw 'GitHub Environment name does not match the reviewed state.'
    }

    if ([bool]$Environment.protected_branches -or -not [bool]$Environment.custom_branch_policies) {
        throw 'GitHub Environment branch policy does not match the reviewed state.'
    }

    if ([bool]$Environment.prevent_self_review) {
        throw 'GitHub Environment self-review protection does not match the reviewed state.'
    }

    $reviewers = @($Environment.reviewers)
    if ($reviewers.Count -ne 1) {
        throw 'GitHub Environment reviewers do not match the reviewed state.'
    }

    if ([int]$reviewers[0].reviewer_id -ne $ExpectedReviewerId -or [string]$reviewers[0].login -cne 'urruegg') {
        throw 'GitHub Environment reviewers do not match the reviewed state.'
    }

    $branches = @($Environment.branch_name_patterns)
    if ($branches.Count -ne 1 -or [string]$branches[0] -cne 'main') {
        throw 'GitHub Environment protected branches do not match the reviewed state.'
    }

    $environmentTable = ConvertTo-Hashtable -InputObject $Environment
    $deploymentPolicies = @()
    if ($environmentTable.ContainsKey('deployment_policies')) {
        $deploymentPolicies = @($environmentTable['deployment_policies'])
    }
    if ($deploymentPolicies.Count -ne 1 -or [string]$deploymentPolicies[0].type -cne 'branch' -or [string]$deploymentPolicies[0].name -cne 'main') {
        throw 'GitHub Environment deployment policies do not match the reviewed main-only state.'
    }
}

function Assert-EnvironmentVariableState {
    param(
        [Parameter(Mandatory)]
        [object]$Variable,

        [Parameter(Mandatory)]
        [string]$ExpectedName,

        [Parameter(Mandatory)]
        [string]$ExpectedValue
    )

    if ([string]$Variable.name -cne $ExpectedName -or [string]$Variable.value -cne $ExpectedValue) {
        throw 'GitHub environment variable read-back does not match the reviewed state.'
    }
}

function Assert-AzureDevOpsEntitlementState {
    param(
        [Parameter(Mandatory)]
        [object]$Entitlement,

        [Parameter(Mandatory)]
        [string]$ExpectedPrincipalId
    )

    if ([string]$Entitlement.principalId -cne $ExpectedPrincipalId) {
        throw 'Azure DevOps entitlement principal does not match the reviewed state.'
    }

    if ([string]$Entitlement.accessLevel.accountLicenseType -cne 'express') {
        throw 'Azure DevOps entitlement access level does not match the reviewed state.'
    }
}

function Assert-AzureDevOpsReadersMembershipState {
    param(
        [Parameter(Mandatory)]
        [object]$Membership
    )

    if (-not [bool]$Membership.isMember) {
        throw 'Azure DevOps Readers membership does not match the reviewed state.'
    }
}

function Add-PlanItem {
    param(
        [System.Collections.Generic.List[object]]$Plan,

        [Parameter(Mandatory)]
        [ref]$Order,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [string]$TargetType,

        [string]$TargetId,

        [string]$TargetName,

        [Parameter(Mandatory)]
        [string]$Mode,

        [Parameter(Mandatory)]
        [string]$Status,

        [AllowNull()]
        [object]$Properties
    )

    $Order.Value = [int]$Order.Value + 1
    $Plan.Add([pscustomobject]([ordered]@{
        Order = $Order.Value
        Operation = $Operation
        TargetType = $TargetType
        TargetId = $TargetId
        TargetName = $TargetName
        Mode = $Mode
        Status = $Status
        Properties = ConvertTo-OrderedData -Value $Properties
    })) | Out-Null
}

function New-PowerPlatformPrerequisites {
    param(
        [Parameter(Mandatory)]
        [object]$Configuration
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $order = 0
    foreach ($componentName in @('PowerPlatformEnvironmentDev', 'PowerPlatformEnvironmentTest', 'PowerPlatformEnvironmentProd')) {
        $component = Get-ComponentDefinition -Configuration $Configuration -Name $componentName
        if ($component.Mode -cne 'Existing') {
            throw "$componentName must remain Existing until the attended Power Platform checkpoint runs."
        }

        $order++
        $items.Add([pscustomobject]([ordered]@{
            Order = $order
            Operation = 'AttendPowerPlatformApplicationUserSetup'
            TargetType = $component.Name
            TargetId = $component.Id
            TargetName = $component.Name
            Mode = $component.Mode
            Status = 'AttendedCheckpoint'
            Properties = [pscustomobject]([ordered]@{
                RequiredAction = 'AddApplicationUser'
                RequiresExplicitApproval = $true
                MinimumRole = 'ReviewedMetadataReadMinimum'
                ProhibitedRoles = @('System Administrator')
            })
        })) | Out-Null
    }

    $items
}

function New-DefaultAzRequest {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$NativeRunner,

        [Parameter(Mandatory)]
        [scriptblock]$HttpRunner
    )

    $getGraphAccessHeaders = ${function:Get-GraphAccessHeaders}
    $invokeNativeJsonCommand = ${function:Invoke-NativeJsonCommand}
    $invokeNativeCommand = ${function:Invoke-NativeCommand}
    $invokeHttpJson = ${function:Invoke-HttpJson}
    $getResponseBodyOrNull = ${function:Get-ResponseBodyOrNull}

    {
        param(
            [Parameter(Mandatory)]
            [string]$Operation,

            [Parameter(Mandatory)]
            [System.Collections.Specialized.OrderedDictionary]$Arguments
        )

        $graphHeaders = & $getGraphAccessHeaders -Runner $NativeRunner

        switch ($Operation) {
            'GetInteractiveContext' {
                $contextResponse = & $invokeNativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @('account', 'show', '--output', 'json')
                $contextBody = & $getResponseBodyOrNull -Response $contextResponse
                return [pscustomobject]@{
                    StatusCode = 200
                    Headers = @{}
                    Body = [pscustomobject]@{
                        TenantId = [string]$contextBody.tenantId
                        SubscriptionId = [string]$contextBody.id
                        UserPrincipalName = [string]$contextBody.user.name
                        UserType = [string]$contextBody.user.type
                    }
                }
            }
            'GetApplicationByObjectId' {
                return (& $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://graph.microsoft.com/v1.0/applications/{0}" -f [string]$Arguments['ObjectId']) -Headers $graphHeaders -Body $null)
            }
            'ListApplicationsByDisplayName' {
                $filter = "displayName eq '$($Arguments['DisplayName'])'"
                $url = "https://graph.microsoft.com/v1.0/applications?`$filter=$([System.Uri]::EscapeDataString($filter))"
                $response = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri $url -Headers $graphHeaders -Body $null
                if ($response.StatusCode -eq 404) {
                    return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @() }
                }

                $body = & $getResponseBodyOrNull -Response $response
                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @($body.value) }
            }
            'CreateApplication' {
                return (& $invokeNativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @('ad', 'app', 'create', '--display-name', [string]$Arguments['DisplayName'], '--sign-in-audience', 'AzureADMyOrg', '--output', 'json'))
            }
            'GetServicePrincipalByAppId' {
                $filter = "appId eq '$($Arguments['AppId'])'"
                $url = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$([System.Uri]::EscapeDataString($filter))"
                $response = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri $url -Headers $graphHeaders -Body $null
                if ($response.StatusCode -eq 404) {
                    return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @() }
                }

                $body = & $getResponseBodyOrNull -Response $response
                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @($body.value) }
            }
            'GetServicePrincipalByObjectId' {
                return (& $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://graph.microsoft.com/v1.0/servicePrincipals/{0}" -f [string]$Arguments['ObjectId']) -Headers $graphHeaders -Body $null)
            }
            'CreateServicePrincipal' {
                return (& $invokeNativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @('ad', 'sp', 'create', '--id', [string]$Arguments['AppId'], '--output', 'json'))
            }
            'GetApplicationPermissions' {
                $applicationResponse = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://graph.microsoft.com/v1.0/applications/{0}?`$select=requiredResourceAccess" -f [string]$Arguments['ApplicationObjectId']) -Headers $graphHeaders -Body $null
                $applicationBody = & $getResponseBodyOrNull -Response $applicationResponse
                if ($null -eq $applicationBody) {
                    return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @() }
                }

                $permissions = [System.Collections.Generic.List[object]]::new()
                foreach ($resourceRequirement in @($applicationBody.requiredResourceAccess)) {
                    $resourceAppId = [string]$resourceRequirement.resourceAppId
                    $filter = "appId eq '$resourceAppId'"
                    $catalogUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=$([System.Uri]::EscapeDataString($filter))&`$select=displayName,oauth2PermissionScopes,appRoles"
                    $catalogResponse = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri $catalogUri -Headers $graphHeaders -Body $null
                    $catalogBody = & $getResponseBodyOrNull -Response $catalogResponse
                    $catalogCandidates = @($catalogBody.value)
                    if ($catalogCandidates.Count -ne 1) {
                        throw "Microsoft Graph permission catalog lookup was ambiguous for resource application '$resourceAppId'."
                    }

                    $catalog = $catalogCandidates[0]
                    foreach ($resourceAccess in @($resourceRequirement.resourceAccess)) {
                        $permissionType = [string]$resourceAccess.type
                        $definitions = if ($permissionType -ceq 'Scope') { @($catalog.oauth2PermissionScopes) } elseif ($permissionType -ceq 'Role') { @($catalog.appRoles) } else { @() }
                        $matches = @($definitions | Where-Object { [string]$_.id -ceq [string]$resourceAccess.id })
                        if ($matches.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$matches[0].value)) {
                            throw "Microsoft Graph permission definition lookup failed for resource application '$resourceAppId'."
                        }

                        $permissions.Add([pscustomobject]@{
                            resourceAppId = $resourceAppId
                            resourceDisplayName = [string]$catalog.displayName
                            permissionType = $permissionType
                            permissionName = [string]$matches[0].value
                        }) | Out-Null
                    }
                }

                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = @($permissions) }
            }
            'AddApplicationPermission' {
                $permissionPairs = @(
                    @('00000007-0000-0000-c000-000000000000', 'user_impersonation=Scope'),
                    @('00000003-0000-0000-c000-000000000000', 'Application.Read.All=Role')
                )

                foreach ($permissionPair in $permissionPairs) {
                    $commandResult = & $invokeNativeCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @('ad', 'app', 'permission', 'add', '--id', [string]$Arguments['ApplicationAppId'], '--api', $permissionPair[0], '--api-permissions', $permissionPair[1])
                    if ($commandResult.ExitCode -ne 0) {
                        throw 'Application permission update failed.'
                    }
                }

                return [pscustomobject]@{ StatusCode = 204; Headers = @{}; Body = $null }
            }
            'GrantAdminConsent' {
                $commandResult = & $invokeNativeCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @('ad', 'app', 'permission', 'admin-consent', '--id', [string]$Arguments['ApplicationAppId'])
                if ($commandResult.ExitCode -ne 0) {
                    throw 'Application admin consent failed.'
                }

                return [pscustomobject]@{ StatusCode = 202; Headers = @{}; Body = $null }
            }
            'GetFederatedCredential' {
                return (& $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://graph.microsoft.com/v1.0/applications/{0}/federatedIdentityCredentials/{1}" -f [string]$Arguments['ApplicationObjectId'], [string]$Arguments['Name']) -Headers $graphHeaders -Body $null)
            }
            'CreateFederatedCredential' {
                $body = @{ name = [string]$Arguments['Name']; issuer = [string]$Arguments['Issuer']; subject = [string]$Arguments['Subject']; audiences = @([string]$Arguments['Audience']) } | ConvertTo-Json -Compress
                return (& $invokeNativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @('ad', 'app', 'federated-credential', 'create', '--id', [string]$Arguments['ApplicationObjectId'], '--parameters', $body, '--output', 'json'))
            }
            default {
                throw "Unsupported Az operation '$Operation'."
            }
        }
    }.GetNewClosure()
}

function New-DefaultGitHubRequest {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$NativeRunner,

        [Parameter(Mandatory)]
        [scriptblock]$HttpRunner
    )

    $getGitHubAccessHeaders = ${function:Get-GitHubAccessHeaders}
    $invokeNativeCommand = ${function:Invoke-NativeCommand}
    $invokeHttpJson = ${function:Invoke-HttpJson}
    $getResponseBodyOrNull = ${function:Get-ResponseBodyOrNull}
    $convertToHashtable = ${function:ConvertTo-Hashtable}

    {
        param(
            [Parameter(Mandatory)]
            [string]$Operation,

            [Parameter(Mandatory)]
            [System.Collections.Specialized.OrderedDictionary]$Arguments
        )

        $headers = & $getGitHubAccessHeaders -Runner $NativeRunner

        switch ($Operation) {
            'GetRepository' {
                $response = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://api.github.com/repos/{0}/{1}" -f [string]$Arguments['Owner'], [string]$Arguments['Repository']) -Headers $headers -Body $null
                $body = & $getResponseBodyOrNull -Response $response
                $bodyTable = & $convertToHashtable -InputObject $body
                $ownerTable = & $convertToHashtable -InputObject $bodyTable['owner']
                $permissionsTable = & $convertToHashtable -InputObject $bodyTable['permissions']
                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ Id = [string]$bodyTable['id']; Name = [string]$bodyTable['name']; Owner = [pscustomobject]@{ Login = [string]$ownerTable['login']; Id = [string]$ownerTable['id'] }; FullName = [string]$bodyTable['full_name']; Permissions = [pscustomobject]@{ Admin = [bool]$permissionsTable['admin'] } } }
            }
            'GetOidcCustomization' {
                return (& $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://api.github.com/repos/{0}/{1}/actions/oidc/customization/sub" -f [string]$Arguments['Owner'], [string]$Arguments['Repository']) -Headers $headers -Body $null)
            }
            'GetUserByLogin' {
                return (& $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://api.github.com/users/{0}" -f [string]$Arguments['Login']) -Headers $headers -Body $null)
            }
            'GetEnvironment' {
                $response = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://api.github.com/repos/{0}/{1}/environments/{2}" -f [string]$Arguments['Owner'], [string]$Arguments['Repository'], [string]$Arguments['EnvironmentName']) -Headers $headers -Body $null
                if ($response.StatusCode -eq 404) {
                    return $response
                }

                $body = & $getResponseBodyOrNull -Response $response
                $reviewerRule = @($body.protection_rules | Where-Object type -eq 'required_reviewers' | Select-Object -First 1)
                $deploymentPolicy = $body.deployment_branch_policy
                $branchPolicies = @()
                if ([bool]$deploymentPolicy.custom_branch_policies) {
                    $branchPolicyResponse = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://api.github.com/repos/{0}/{1}/environments/{2}/deployment-branch-policies" -f [string]$Arguments['Owner'], [string]$Arguments['Repository'], [string]$Arguments['EnvironmentName']) -Headers $headers -Body $null
                    $branchPolicyBody = & $getResponseBodyOrNull -Response $branchPolicyResponse
                    $branchPolicies = @($branchPolicyBody.branch_policies)
                }

                return [pscustomobject]@{
                    StatusCode = 200
                    Headers = @{}
                    Body = [pscustomobject]@{
                        id = [string]$body.id
                        name = [string]$body.name
                        protected_branches = [bool]$deploymentPolicy.protected_branches
                        custom_branch_policies = [bool]$deploymentPolicy.custom_branch_policies
                        reviewers = @($reviewerRule.reviewers | ForEach-Object { [pscustomobject]@{ type = [string]$_.type; reviewer_id = [int]$_.reviewer.id; login = [string]$_.reviewer.login } })
                        prevent_self_review = if ($reviewerRule.Count -gt 0) { [bool]$reviewerRule[0].prevent_self_review } else { $false }
                        branch_name_patterns = @($branchPolicies | Where-Object { [string]$_.type -ceq 'branch' } | ForEach-Object { [string]$_.name })
                        deployment_policies = @($branchPolicies | ForEach-Object { [pscustomobject]@{ id = [string]$_.id; name = [string]$_.name; type = [string]$_.type } })
                    }
                }
            }
            'PutEnvironment' {
                $body = [ordered]@{
                    prevent_self_review = $false
                    reviewers = @(
                        [ordered]@{
                            type = 'User'
                            id = [int]$Arguments['ReviewerId']
                        }
                    )
                    deployment_branch_policy = [ordered]@{
                        protected_branches = $false
                        custom_branch_policies = $true
                    }
                }

                $environmentUri = "https://api.github.com/repos/{0}/{1}/environments/{2}" -f [string]$Arguments['Owner'], [string]$Arguments['Repository'], [string]$Arguments['EnvironmentName']
                $response = & $invokeHttpJson -Runner $HttpRunner -Method 'PUT' -Uri $environmentUri -Headers $headers -Body $body
                $policyUri = "$environmentUri/deployment-branch-policies"
                $policyResponse = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri $policyUri -Headers $headers -Body $null
                $policyBody = & $getResponseBodyOrNull -Response $policyResponse
                $branchPolicies = @($policyBody.branch_policies)
                $unexpectedPolicies = @($branchPolicies | Where-Object { [string]$_.type -cne 'branch' -or [string]$_.name -cne 'main' })
                if ($unexpectedPolicies.Count -gt 0) {
                    throw 'GitHub Environment has unexpected deployment branch policies; remove them through a separately reviewed action.'
                }

                $mainPolicies = @($branchPolicies | Where-Object { [string]$_.type -ceq 'branch' -and [string]$_.name -ceq 'main' })
                if ($mainPolicies.Count -eq 0) {
                    $null = & $invokeHttpJson -Runner $HttpRunner -Method 'POST' -Uri $policyUri -Headers $headers -Body ([ordered]@{ name = 'main'; type = 'branch' })
                }
                elseif ($mainPolicies.Count -gt 1) {
                    throw 'GitHub Environment has ambiguous main deployment branch policies.'
                }

                return $response
            }
            'GetEnvironmentVariable' {
                return (& $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://api.github.com/repos/{0}/{1}/environments/{2}/variables/{3}" -f [string]$Arguments['Owner'], [string]$Arguments['Repository'], [string]$Arguments['EnvironmentName'], [string]$Arguments['Name']) -Headers $headers -Body $null)
            }
            'SetEnvironmentVariable' {
                $commandResult = & $invokeNativeCommand -Runner $NativeRunner -FilePath 'gh' -ArgumentList @('variable', 'set', [string]$Arguments['Name'], '--env', [string]$Arguments['EnvironmentName'], '--body', [string]$Arguments['Value'])
                if ($commandResult.ExitCode -ne 0) {
                    throw "GitHub operation '$Operation' failed."
                }

                return [pscustomobject]@{ StatusCode = 204; Body = $null }
            }
            default {
                throw "Unsupported GitHub operation '$Operation'."
            }
        }
    }.GetNewClosure()
}

function New-DefaultAzureDevOpsRequest {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$HttpRunner,

        [Parameter(Mandatory)]
        [scriptblock]$NativeRunner,

        [Parameter(Mandatory)]
        [string]$OrganizationUrl,

        [Parameter(Mandatory)]
        [string]$ProjectName
    )

    $getAzureDevOpsAccessHeaders = ${function:Get-AzureDevOpsAccessHeaders}
    $getAzureDevOpsOrganizationName = ${function:Get-AzureDevOpsOrganizationName}
    $invokeHttpJson = ${function:Invoke-HttpJson}
    $getResponseBodyOrNull = ${function:Get-ResponseBodyOrNull}

    {
        param(
            [Parameter(Mandatory)]
            [string]$Operation,

            [Parameter(Mandatory)]
            [System.Collections.Specialized.OrderedDictionary]$Arguments
        )

        $headers = & $getAzureDevOpsAccessHeaders -Runner $NativeRunner
        $organizationName = & $getAzureDevOpsOrganizationName -OrganizationUrl $OrganizationUrl
        $encodedProjectName = [System.Uri]::EscapeDataString($ProjectName)

        switch ($Operation) {
            'GetServicePrincipalEntitlement' {
            $response = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://vsaex.dev.azure.com/{0}/_apis/userentitlements?api-version=7.1-preview.3&subjectTypes=servicePrincipal" -f $organizationName) -Headers $headers -Body $null
                $body = & $getResponseBodyOrNull -Response $response
                $candidates = @($body.members | Where-Object { [string]$_.user.originId -ceq [string]$Arguments['PrincipalObjectId'] })
                if ($candidates.Count -gt 1) {
                    throw 'Ambiguous Azure DevOps service principal entitlement candidates matched the reviewed principal.'
                }

                if ($candidates.Count -eq 0) {
                    return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = $null }
                }

                $candidate = $candidates[0]
                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = [string]$candidate.id; principalId = [string]$candidate.user.originId; descriptor = [string]$candidate.user.descriptor; accessLevel = $candidate.accessLevel } }
            }
            'CreateServicePrincipalEntitlement' {
                $body = [ordered]@{
                    accessLevel = [ordered]@{ accountLicenseType = 'express'; licensingSource = 'account' }
                    user = [ordered]@{ originId = [string]$Arguments['PrincipalObjectId']; subjectKind = 'servicePrincipal' }
                }
                return (& $invokeHttpJson -Runner $HttpRunner -Method 'POST' -Uri ("https://vsaex.dev.azure.com/{0}/_apis/userentitlements?api-version=7.1-preview.3" -f $organizationName) -Headers $headers -Body $body)
            }
            'GetProjectReadersGroup' {
                $response = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://dev.azure.com/{0}/{1}/_apis/graph/groups?scopeDescriptor=project&api-version=7.1-preview.1" -f $organizationName, $encodedProjectName) -Headers $headers -Body $null
                $body = & $getResponseBodyOrNull -Response $response
                $candidates = @($body.value | Where-Object { [string]$_.displayName -ceq 'Readers' })
                if ($candidates.Count -ne 1) {
                    throw 'Azure DevOps Readers group lookup failed.'
                }

                $candidate = $candidates[0]
                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ descriptor = [string]$candidate.descriptor; displayName = [string]$candidate.displayName } }
            }
            'GetReadersMembership' {
                $memberDescriptor = [string]$Arguments['PrincipalDescriptor']
                if ([string]::IsNullOrWhiteSpace($memberDescriptor)) {
                    throw 'Azure DevOps service principal descriptor is required for Readers membership lookup.'
                }

                $groupDescriptor = [string]$Arguments['GroupDescriptor']
                $response = & $invokeHttpJson -Runner $HttpRunner -Method 'GET' -Uri ("https://dev.azure.com/{0}/_apis/graph/memberships/{1}/{2}?api-version=7.1-preview.1" -f $organizationName, $memberDescriptor, $groupDescriptor) -Headers $headers -Body $null
                if ($response.StatusCode -eq 404) {
                    return $response
                }

                $body = & $getResponseBodyOrNull -Response $response
                return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = [pscustomobject]@{ id = if ([string]::IsNullOrWhiteSpace([string]$body.id)) { "$memberDescriptor/$groupDescriptor" } else { [string]$body.id }; isMember = $true; memberDescriptor = $memberDescriptor; containerDescriptor = $groupDescriptor } }
            }
            'AddReadersMembership' {
                $memberDescriptor = [string]$Arguments['PrincipalDescriptor']
                if ([string]::IsNullOrWhiteSpace($memberDescriptor)) {
                    throw 'Azure DevOps service principal descriptor is required for Readers membership update.'
                }

                return (& $invokeHttpJson -Runner $HttpRunner -Method 'PUT' -Uri ("https://dev.azure.com/{0}/_apis/graph/memberships/{1}/{2}?api-version=7.1-preview.1" -f $organizationName, $memberDescriptor, [string]$Arguments['GroupDescriptor']) -Headers $headers -Body ([ordered]@{}))
            }
            default {
                throw "Unsupported Azure DevOps operation '$Operation'."
            }
        }
    }.GetNewClosure()
}

function New-DefaultNativeCommandRunner {
    {
        param(
            [Parameter(Mandatory)]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [string[]]$ArgumentList
        )

        $merged = & $FilePath @ArgumentList 2>&1
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            StdOut = ($merged | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
            StdErr = ''
        }
    }
}

function New-DefaultHttpRequestRunner {
    {
        param(
            [Parameter(Mandatory)]
            [string]$Method,

            [Parameter(Mandatory)]
            [string]$Uri,

            [AllowNull()]
            [hashtable]$Headers,

            [AllowNull()]
            [object]$Body
        )

        $requestParameters = @{
            Method = $Method
            Uri = $Uri
            UseBasicParsing = $true
            ErrorAction = 'Stop'
        }

        if ($Headers) {
            $requestParameters.Headers = $Headers
        }

        if ($null -ne $Body) {
            $requestParameters.ContentType = 'application/json'
            $requestParameters.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 20 -Compress }
        }

        try {
            $response = Invoke-WebRequest @requestParameters
            return [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Headers = @{}; Body = [string]$response.Content }
        }
        catch [System.Net.WebException] {
            $webResponse = $_.Exception.Response
            if ($null -eq $webResponse) {
                throw
            }

            $reader = New-Object System.IO.StreamReader($webResponse.GetResponseStream())
            try {
                $content = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }

            return [pscustomobject]@{ StatusCode = [int]$webResponse.StatusCode; Headers = @{}; Body = $content }
        }
    }
}

if (-not $NativeCommandRunner) {
    $NativeCommandRunner = New-DefaultNativeCommandRunner
}

if (-not $HttpRequestRunner) {
    $HttpRequestRunner = New-DefaultHttpRequestRunner
}

if (-not $AzRequest) {
    $AzRequest = New-DefaultAzRequest -NativeRunner $NativeCommandRunner -HttpRunner $HttpRequestRunner
}

if (-not $GitHubRequest) {
    $GitHubRequest = New-DefaultGitHubRequest -NativeRunner $NativeCommandRunner -HttpRunner $HttpRequestRunner
}

$repositoryRoot = Get-RepositoryRoot
$moduleManifestPath = Get-ModuleManifestPath
Import-Module $moduleManifestPath -Force

$resolvedConfigurationPath = if ([string]::IsNullOrWhiteSpace($TenantConfigurationPath)) {
    Get-DefaultTenantConfigurationPath -TenantAliasValue $TenantAlias
}
else {
    [System.IO.Path]::GetFullPath($TenantConfigurationPath)
}

$configuration = Import-TenantConfiguration -Path $resolvedConfigurationPath -ValidationStage Bootstrap

if (-not $AzureDevOpsRequest) {
    $AzureDevOpsRequest = New-DefaultAzureDevOpsRequest -HttpRunner $HttpRequestRunner -NativeRunner $NativeCommandRunner -OrganizationUrl ([string]$configuration.AzureDevOps.OrganizationUrl) -ProjectName ([string]$configuration.AzureDevOps.ProjectName)
}

$requiredComponents = @(
    'EntraApplication',
    'EntraServicePrincipal',
    'GitHubEnvironment',
    'AzureDevOpsServicePrincipalEntitlement',
    'AzureDevOpsReadersMembership',
    'PowerPlatformEnvironmentDev',
    'PowerPlatformEnvironmentTest',
    'PowerPlatformEnvironmentProd'
)

$resolvedComponents = [ordered]@{}
foreach ($componentName in $requiredComponents) {
    $resolvedComponents[$componentName] = Get-ComponentDefinition -Configuration $configuration -Name $componentName
}

$expectedDisplayName = '{0}-github-bootstrap' -f [string]$configuration.NamingRoot
$expectedEnvironmentName = [string]$configuration.GitHub.EnvironmentName
$expectedSubject = Get-GitHubOidcSubject -Owner $configuration.GitHub.Owner -OwnerId $configuration.GitHub.OwnerId -Repository $configuration.GitHub.Repository -RepositoryId $configuration.GitHub.RepositoryId -TenantAlias $configuration.TenantAlias

$contextResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetInteractiveContext' -Arguments @{}
$context = Get-ResponseBodyOrNull -Response $contextResponse
if ($null -eq $context) {
    throw 'Interactive Azure administrator context is required.'
}

if ([string]$context.TenantId -cne [string]$configuration.TenantId -or [string]$context.SubscriptionId -cne [string]$configuration.SubscriptionId) {
    throw 'Interactive Azure context does not match the reviewed tenant or subscription.'
}

if ([string]$context.UserType -cne 'user') {
    throw 'Interactive Azure administrator context must use an attended user context.'
}

if ([string]$context.UserPrincipalName -cne [string]$configuration.AdminUpn) {
    throw 'Interactive Azure administrator UPN does not match the reviewed selector.'
}

$repositoryResponse = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'GetRepository' -Arguments @{
    Owner = [string]$configuration.GitHub.Owner
    Repository = [string]$configuration.GitHub.Repository
}
$repository = Get-ResponseBodyOrNull -Response $repositoryResponse
if ($null -eq $repository) {
    throw 'Reviewed GitHub repository metadata could not be read.'
}

if ($repository -is [string]) {
    $repository = ConvertFrom-JsonText -Text $repository
}

$repositoryTable = ConvertTo-Hashtable -InputObject $repository
$repositoryOwner = ConvertTo-Hashtable -InputObject $(if ($repositoryTable.ContainsKey('Owner')) { $repositoryTable['Owner'] } else { $repositoryTable['owner'] })
$repositoryPermissions = ConvertTo-Hashtable -InputObject $(if ($repositoryTable.ContainsKey('Permissions')) { $repositoryTable['Permissions'] } else { $repositoryTable['permissions'] })
$repositoryName = if ($repositoryTable.ContainsKey('Name')) { [string]$repositoryTable['Name'] } else { [string]$repositoryTable['name'] }
$repositoryId = if ($repositoryTable.ContainsKey('Id')) { [string]$repositoryTable['Id'] } else { [string]$repositoryTable['id'] }
$repositoryOwnerLogin = if ($repositoryOwner.ContainsKey('Login')) { [string]$repositoryOwner['Login'] } else { [string]$repositoryOwner['login'] }
$repositoryOwnerId = if ($repositoryOwner.ContainsKey('Id')) { [string]$repositoryOwner['Id'] } else { [string]$repositoryOwner['id'] }

if ($repositoryName -cne [string]$configuration.GitHub.Repository -or $repositoryId -cne [string]$configuration.GitHub.RepositoryId -or $repositoryOwnerLogin -cne [string]$configuration.GitHub.Owner -or $repositoryOwnerId -cne [string]$configuration.GitHub.OwnerId) {
    throw ("Reviewed GitHub repository metadata does not match the tenant configuration. Observed Name='{0}' Id='{1}' Owner='{2}' OwnerId='{3}'." -f $repositoryName, $repositoryId, $repositoryOwnerLogin, $repositoryOwnerId)
}

if (-not [bool]$(if ($repositoryPermissions.ContainsKey('Admin')) { $repositoryPermissions['Admin'] } else { $repositoryPermissions['admin'] })) {
    throw 'GitHub repository-admin permission is required.'
}

$oidcResponse = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'GetOidcCustomization' -Arguments @{
    Owner = [string]$configuration.GitHub.Owner
    Repository = [string]$configuration.GitHub.Repository
}
$oidcCustomization = Get-ResponseBodyOrNull -Response $oidcResponse
if ($null -eq $oidcCustomization) {
    throw 'GitHub OIDC customization could not be read.'
}

if (-not [bool]$oidcCustomization.use_default -or -not [bool]$oidcCustomization.use_immutable_subject -or [string]$oidcCustomization.sub_claim_prefix -cne $expectedSubject) {
    throw 'OIDC customization does not match the reviewed immutable Environment subject.'
}

$reviewerResponse = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'GetUserByLogin' -Arguments @{ Login = 'urruegg' }
$reviewer = Get-ResponseBodyOrNull -Response $reviewerResponse
if ($null -eq $reviewer -or [string]$reviewer.login -cne 'urruegg') {
    throw 'GitHub reviewer resolution failed for urruegg.'
}

$applicationComponent = $resolvedComponents['EntraApplication']
$application = $null
if ($applicationComponent.Mode -eq 'Existing') {
    $applicationResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetApplicationByObjectId' -Arguments @{ ObjectId = $applicationComponent.Id }
    $application = Get-ResponseBodyOrNull -Response $applicationResponse
    if ($null -eq $application) {
        throw 'Entra application stable Id did not resolve to an application.'
    }

    Assert-ApplicationState -Application $application -ExpectedDisplayName $expectedDisplayName -ExpectedObjectId $applicationComponent.Id
}
else {
    $applicationsResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'ListApplicationsByDisplayName' -Arguments @{ DisplayName = $expectedDisplayName }
    $candidates = @((Get-ResponseBodyOrNull -Response $applicationsResponse))
    if ($candidates.Count -gt 1) {
        throw 'Ambiguous Entra application candidates matched the reviewed display name.'
    }

    if ($candidates.Count -eq 1) {
        $application = $candidates[0]
        Assert-ApplicationState -Application $application -ExpectedDisplayName $expectedDisplayName
    }
}

$servicePrincipalComponent = $resolvedComponents['EntraServicePrincipal']
$servicePrincipal = $null
if ($null -ne $application) {
    $servicePrincipalResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetServicePrincipalByAppId' -Arguments @{ AppId = [string]$application.appId }
    $servicePrincipal = Get-OnlyCollectionCandidateOrNull -Collection (Get-ResponseBodyOrNull -Response $servicePrincipalResponse) -AmbiguousMessage 'Ambiguous Entra service principal candidates matched the reviewed application.'
    if ($null -ne $servicePrincipal) {
        Assert-ServicePrincipalState -ServicePrincipal $servicePrincipal -ExpectedAppId ([string]$application.appId) -ExpectedObjectId $(if ($servicePrincipalComponent.Mode -eq 'Existing') { $servicePrincipalComponent.Id } else { $null })
    }
}

if ($servicePrincipalComponent.Mode -eq 'Existing' -and $null -eq $servicePrincipal) {
    throw 'Entra service principal stable Id did not resolve through the reviewed application.'
}

$permissionResponse = if ($null -ne $application) {
    Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetApplicationPermissions' -Arguments @{ ApplicationObjectId = [string]$application.id; ApplicationAppId = [string]$application.appId }
}
else {
    [pscustomobject]@{ StatusCode = 200; Body = @() }
}
$applicationPermissions = @((Get-ResponseBodyOrNull -Response $permissionResponse))
$permissionsExact = if ($null -ne $application) { Test-ExactPermissionSet -ObservedPermissions $applicationPermissions } else { $false }

$federatedCredentialResponse = if ($null -ne $application) {
    Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetFederatedCredential' -Arguments @{ ApplicationObjectId = [string]$application.id; Name = 'github-bootstrap' }
}
else {
    [pscustomobject]@{ StatusCode = 404; Body = $null }
}
$federatedCredential = Get-ResponseBodyOrNull -Response $federatedCredentialResponse
if ($null -ne $federatedCredential) {
    Assert-FederatedCredentialState -FederatedCredential $federatedCredential -ExpectedSubject $expectedSubject
}

$environmentComponent = $resolvedComponents['GitHubEnvironment']
$environmentResponse = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'GetEnvironment' -Arguments @{ Owner = [string]$configuration.GitHub.Owner; Repository = [string]$configuration.GitHub.Repository; EnvironmentName = $expectedEnvironmentName }
$environment = Get-ResponseBodyOrNull -Response $environmentResponse
$environmentExact = $false
if ($null -ne $environment) {
    Assert-ReviewedStableId -Component $environmentComponent -ObservedId ([string]$environment.id) -ComponentName 'GitHub Environment'
    try {
        Assert-GitHubEnvironmentState -Environment $environment -ExpectedEnvironmentName $expectedEnvironmentName -ExpectedReviewerId ([int]$reviewer.id)
        $environmentExact = $true
    }
    catch {
        if ($environmentComponent.Mode -eq 'Existing') {
            throw
        }
    }
}

$variableDefinitions = @(
    [pscustomobject]@{ Name = 'AZURE_CLIENT_ID'; Value = if ($null -ne $application) { [string]$application.appId } else { $null }; Source = 'ApplicationAppId' },
    [pscustomobject]@{ Name = 'AZURE_TENANT_ID'; Value = [string]$configuration.TenantId; Source = 'TenantConfiguration' },
    [pscustomobject]@{ Name = 'AZURE_SUBSCRIPTION_ID'; Value = [string]$configuration.SubscriptionId; Source = 'TenantConfiguration' }
)

$entitlementComponent = $resolvedComponents['AzureDevOpsServicePrincipalEntitlement']
$entitlementResponse = if ($null -ne $servicePrincipal) {
    Invoke-RequestAdapter -Adapter $AzureDevOpsRequest -AdapterName 'AzureDevOps' -Operation 'GetServicePrincipalEntitlement' -Arguments @{ PrincipalObjectId = [string]$servicePrincipal.id }
}
else {
    [pscustomobject]@{ StatusCode = 404; Body = $null }
}
$entitlement = Get-ResponseBodyOrNull -Response $entitlementResponse
if ($null -ne $entitlement) {
    Assert-ReviewedStableId -Component $entitlementComponent -ObservedId ([string]$entitlement.id) -ComponentName 'Azure DevOps entitlement'
    Assert-AzureDevOpsEntitlementState -Entitlement $entitlement -ExpectedPrincipalId ([string]$servicePrincipal.id)
}
elseif ($entitlementComponent.Mode -eq 'Existing') {
    throw 'Azure DevOps entitlement stable Id did not resolve to the reviewed service principal.'
}

$readersGroupResponse = Invoke-RequestAdapter -Adapter $AzureDevOpsRequest -AdapterName 'AzureDevOps' -Operation 'GetProjectReadersGroup' -Arguments @{ ProjectName = [string]$configuration.AzureDevOps.ProjectName }
$readersGroup = Get-ResponseBodyOrNull -Response $readersGroupResponse
if ($null -eq $readersGroup -or [string]$readersGroup.displayName -cne 'Readers') {
    throw 'Azure DevOps Readers group lookup failed.'
}

$membershipComponent = $resolvedComponents['AzureDevOpsReadersMembership']
$membershipResponse = if ($null -ne $servicePrincipal -and $null -ne $entitlement) {
    $entitlementTable = ConvertTo-Hashtable -InputObject $entitlement
    $principalDescriptor = if ($entitlementTable.ContainsKey('descriptor') -and -not [string]::IsNullOrWhiteSpace([string]$entitlementTable['descriptor'])) { [string]$entitlementTable['descriptor'] } else { [string]$servicePrincipal.id }
    Invoke-RequestAdapter -Adapter $AzureDevOpsRequest -AdapterName 'AzureDevOps' -Operation 'GetReadersMembership' -Arguments @{ GroupDescriptor = [string]$readersGroup.descriptor; PrincipalObjectId = [string]$servicePrincipal.id; PrincipalDescriptor = $principalDescriptor }
}
else {
    [pscustomobject]@{ StatusCode = 200; Body = [pscustomobject]@{ isMember = $false } }
}
$membership = Get-ResponseBodyOrNull -Response $membershipResponse
if ($null -eq $membership) {
    $membership = [pscustomobject]@{ isMember = $false }
}
$membershipTable = ConvertTo-Hashtable -InputObject $membership
$membershipIsMember = $membershipTable.ContainsKey('isMember') -and [bool]$membershipTable['isMember']
$membershipId = if ($membershipTable.ContainsKey('id')) { [string]$membershipTable['id'] } else { $null }
if ($membershipIsMember) {
    Assert-ReviewedStableId -Component $membershipComponent -ObservedId $membershipId -ComponentName 'Azure DevOps Readers membership'
}

if ($membershipComponent.Mode -eq 'Existing' -and -not $membershipIsMember) {
    throw 'Azure DevOps Readers membership stable Id did not resolve to the reviewed principal and group.'
}

$plan = [System.Collections.Generic.List[object]]::new()
$order = 0

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureEntraApplication' -TargetType 'EntraApplication' -TargetId $(if ($null -ne $application) { [string]$application.id } elseif ($applicationComponent.Mode -eq 'Existing') { $applicationComponent.Id } else { $null }) -TargetName $expectedDisplayName -Mode $applicationComponent.Mode -Status $(if ($null -ne $application) { 'Existing' } else { 'PlannedCreate' }) -Properties ([ordered]@{ DisplayName = $expectedDisplayName; SignInAudience = 'AzureADMyOrg' })

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureEntraServicePrincipal' -TargetType 'EntraServicePrincipal' -TargetId $(if ($null -ne $servicePrincipal) { [string]$servicePrincipal.id } elseif ($servicePrincipalComponent.Mode -eq 'Existing') { $servicePrincipalComponent.Id } else { $null }) -TargetName $expectedDisplayName -Mode $servicePrincipalComponent.Mode -Status $(if ($null -ne $servicePrincipal) { 'Existing' } else { 'PlannedCreate' }) -Properties ([ordered]@{ ApplicationDisplayName = $expectedDisplayName; ApplicationAppId = if ($null -ne $application) { [string]$application.appId } else { $null } })

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureApplicationPermissions' -TargetType 'EntraApplicationPermissions' -TargetId $(if ($null -ne $application) { [string]$application.id } else { $null }) -TargetName $expectedDisplayName -Mode $applicationComponent.Mode -Status $(if ($permissionsExact) { 'Existing' } else { 'PlannedCreate' }) -Properties ([ordered]@{ RequiredPermissions = Get-RequiredPermissions })

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'GrantAdminConsent' -TargetType 'AdminConsent' -TargetId $(if ($null -ne $application) { [string]$application.id } else { $null }) -TargetName $expectedDisplayName -Mode 'Attended' -Status 'AttendedCheckpoint' -Properties ([ordered]@{ Attended = $true; Permissions = Get-RequiredPermissions })

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureFederatedCredential' -TargetType 'FederatedCredential' -TargetId 'github-bootstrap' -TargetName 'github-bootstrap' -Mode $environmentComponent.Mode -Status $(if ($null -ne $federatedCredential) { 'Existing' } else { 'PlannedCreate' }) -Properties ([ordered]@{ Issuer = 'https://token.actions.githubusercontent.com'; Audience = 'api://AzureADTokenExchange'; Subject = $expectedSubject })

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureGitHubEnvironment' -TargetType 'GitHubEnvironment' -TargetId $(if ($null -ne $environment) { [string]$environment.id } else { $null }) -TargetName $expectedEnvironmentName -Mode $environmentComponent.Mode -Status $(if ($environmentExact) { 'Existing' } elseif ($null -ne $environment) { 'PlannedUpdate' } else { 'PlannedCreate' }) -Properties ([ordered]@{ Name = $expectedEnvironmentName; Branches = @('main'); PreventSelfReview = $false; RequiredReviewers = @('urruegg') })

foreach ($variable in $variableDefinitions) {
    Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureGitHubEnvironmentVariable' -TargetType 'GitHubEnvironmentVariable' -TargetId $variable.Name -TargetName $variable.Name -Mode 'Create' -Status 'PlannedCreate' -Properties ([ordered]@{ Name = $variable.Name; Value = $variable.Value; Source = $variable.Source })
}

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureAzureDevOpsServicePrincipalEntitlement' -TargetType 'AzureDevOpsServicePrincipalEntitlement' -TargetId $(if ($null -ne $entitlement) { [string]$entitlement.id } else { $null }) -TargetName ([string]$configuration.AzureDevOps.ProjectName) -Mode $entitlementComponent.Mode -Status $(if ($null -ne $entitlement) { 'Existing' } else { 'PlannedCreate' }) -Properties ([ordered]@{ AccessLevel = 'Basic'; ProjectName = [string]$configuration.AzureDevOps.ProjectName })

Add-PlanItem -Plan $plan -Order ([ref]$order) -Operation 'EnsureAzureDevOpsReadersMembership' -TargetType 'AzureDevOpsReadersMembership' -TargetId $(if ($membershipIsMember) { $membershipId } else { [string]$readersGroup.descriptor }) -TargetName 'Readers' -Mode $membershipComponent.Mode -Status $(if ($membershipIsMember) { 'Existing' } else { 'PlannedCreate' }) -Properties ([ordered]@{ Group = 'Readers'; BroadGroupAssignment = $false })

$powerPlatformPrerequisites = New-PowerPlatformPrerequisites -Configuration $configuration

$result = [pscustomobject]([ordered]@{
    Plan = @($plan)
    PowerPlatformPrerequisites = @($powerPlatformPrerequisites)
})

if ($PlanOutputPath) {
    $resolvedPlanOutputPath = Resolve-AllowedPlanOutputPath -CandidatePath $PlanOutputPath
    Write-BomlessJsonAtomically -Path $resolvedPlanOutputPath -Value $result
}

$mutationQueue = @(
    [pscustomobject]@{ Operation = 'EnsureEntraApplication'; Target = $expectedDisplayName },
    [pscustomobject]@{ Operation = 'EnsureEntraServicePrincipal'; Target = $expectedDisplayName },
    [pscustomobject]@{ Operation = 'EnsureApplicationPermissions'; Target = $expectedDisplayName },
    [pscustomobject]@{ Operation = 'GrantAdminConsent'; Target = $expectedDisplayName },
    [pscustomobject]@{ Operation = 'EnsureFederatedCredential'; Target = 'github-bootstrap' },
    [pscustomobject]@{ Operation = 'EnsureGitHubEnvironment'; Target = $expectedEnvironmentName }
)

foreach ($variable in $variableDefinitions) {
    $mutationQueue += [pscustomobject]@{ Operation = 'EnsureGitHubEnvironmentVariable'; Target = $variable.Name }
}

$mutationQueue += [pscustomobject]@{ Operation = 'EnsureAzureDevOpsServicePrincipalEntitlement'; Target = [string]$configuration.AzureDevOps.ProjectName }
$mutationQueue += [pscustomobject]@{ Operation = 'EnsureAzureDevOpsReadersMembership'; Target = 'Readers' }

foreach ($item in $mutationQueue) {
    $null = $PSCmdlet.ShouldProcess($item.Target, $item.Operation)
}

if ($WhatIfPreference) {
    return $result
}

if ($null -eq $application) {
    if ($applicationComponent.Mode -eq 'Existing') {
        throw 'Entra application stable Id did not resolve to an application.'
    }

    if (-not $PSCmdlet.ShouldProcess($expectedDisplayName, 'EnsureEntraApplication')) {
        throw 'Application creation was declined.'
    }

    $createdApplicationResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'CreateApplication' -Arguments @{ DisplayName = $expectedDisplayName }
    $createdApplication = Get-ResponseBodyOrNull -Response $createdApplicationResponse
    $applicationReadBackResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetApplicationByObjectId' -Arguments @{ ObjectId = [string]$createdApplication.id }
    $application = Get-ResponseBodyOrNull -Response $applicationReadBackResponse
    Assert-ApplicationState -Application $application -ExpectedDisplayName $expectedDisplayName
}

if ($null -eq $servicePrincipal) {
    if ($servicePrincipalComponent.Mode -eq 'Existing') {
        throw 'Entra service principal stable Id did not resolve through the reviewed application.'
    }

    if (-not $PSCmdlet.ShouldProcess($expectedDisplayName, 'EnsureEntraServicePrincipal')) {
        throw 'Service principal creation was declined.'
    }

    $createdServicePrincipalResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'CreateServicePrincipal' -Arguments @{ AppId = [string]$application.appId }
    $createdServicePrincipal = Get-ResponseBodyOrNull -Response $createdServicePrincipalResponse
    $servicePrincipalReadBackResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetServicePrincipalByAppId' -Arguments @{ AppId = [string]$application.appId }
    $servicePrincipal = Get-ResponseBodyOrNull -Response $servicePrincipalReadBackResponse
    if ($null -eq $servicePrincipal) {
        $servicePrincipal = $createdServicePrincipal
    }

    Assert-ServicePrincipalState -ServicePrincipal $servicePrincipal -ExpectedAppId ([string]$application.appId)
}

if (-not $permissionsExact) {
    if ($applicationComponent.Mode -ne 'Create') {
        throw 'Entra application permissions do not match the reviewed set.'
    }

    if (-not $PSCmdlet.ShouldProcess($expectedDisplayName, 'EnsureApplicationPermissions')) {
        throw 'Permission updates were declined.'
    }

    $null = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'AddApplicationPermission' -Arguments @{ ApplicationObjectId = [string]$application.id; ApplicationAppId = [string]$application.appId }
    $permissionResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetApplicationPermissions' -Arguments @{ ApplicationObjectId = [string]$application.id; ApplicationAppId = [string]$application.appId }
    $applicationPermissions = @((Get-ResponseBodyOrNull -Response $permissionResponse))
    if (-not (Test-ExactPermissionSet -ObservedPermissions $applicationPermissions)) {
        throw 'Entra application permissions do not match the reviewed set.'
    }
}

if (-not $PSCmdlet.ShouldProcess($expectedDisplayName, 'GrantAdminConsent')) {
    throw 'Admin consent was declined.'
}

$null = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GrantAdminConsent' -Arguments @{ ApplicationObjectId = [string]$application.id; ApplicationAppId = [string]$application.appId }

if ($null -eq $federatedCredential) {
    if ($environmentComponent.Mode -ne 'Create') {
        throw 'The federated credential was not found in Existing mode.'
    }

    if (-not $PSCmdlet.ShouldProcess('github-bootstrap', 'EnsureFederatedCredential')) {
        throw 'Federated credential creation was declined.'
    }

    $null = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'CreateFederatedCredential' -Arguments @{ ApplicationObjectId = [string]$application.id; Name = 'github-bootstrap'; Issuer = 'https://token.actions.githubusercontent.com'; Audience = 'api://AzureADTokenExchange'; Subject = $expectedSubject }
    $federatedCredentialResponse = Invoke-RequestAdapter -Adapter $AzRequest -AdapterName 'Az' -Operation 'GetFederatedCredential' -Arguments @{ ApplicationObjectId = [string]$application.id; Name = 'github-bootstrap' }
    $federatedCredential = Get-ResponseBodyOrNull -Response $federatedCredentialResponse
}

Assert-FederatedCredentialState -FederatedCredential $federatedCredential -ExpectedSubject $expectedSubject

if (-not $environmentExact) {
    if ($environmentComponent.Mode -ne 'Create') {
        throw 'GitHub Environment does not match the reviewed state.'
    }

    if (-not $PSCmdlet.ShouldProcess($expectedEnvironmentName, 'EnsureGitHubEnvironment')) {
        throw 'GitHub Environment update was declined.'
    }

    $null = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'PutEnvironment' -Arguments @{ Owner = [string]$configuration.GitHub.Owner; Repository = [string]$configuration.GitHub.Repository; EnvironmentName = $expectedEnvironmentName; ReviewerId = [int]$reviewer.id }
    $environmentResponse = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'GetEnvironment' -Arguments @{ Owner = [string]$configuration.GitHub.Owner; Repository = [string]$configuration.GitHub.Repository; EnvironmentName = $expectedEnvironmentName }
    $environment = Get-ResponseBodyOrNull -Response $environmentResponse
}

Assert-GitHubEnvironmentState -Environment $environment -ExpectedEnvironmentName $expectedEnvironmentName -ExpectedReviewerId ([int]$reviewer.id)

foreach ($variable in $variableDefinitions) {
    $expectedValue = if ($variable.Name -eq 'AZURE_CLIENT_ID') { [string]$application.appId } else { [string]$variable.Value }
    if (-not $PSCmdlet.ShouldProcess($variable.Name, 'EnsureGitHubEnvironmentVariable')) {
        throw 'GitHub environment variable update was declined.'
    }

    $null = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'SetEnvironmentVariable' -Arguments @{ Owner = [string]$configuration.GitHub.Owner; Repository = [string]$configuration.GitHub.Repository; EnvironmentName = $expectedEnvironmentName; Name = $variable.Name; Value = $expectedValue }
    $variableResponse = Invoke-RequestAdapter -Adapter $GitHubRequest -AdapterName 'GitHub' -Operation 'GetEnvironmentVariable' -Arguments @{ Owner = [string]$configuration.GitHub.Owner; Repository = [string]$configuration.GitHub.Repository; EnvironmentName = $expectedEnvironmentName; Name = $variable.Name }
    $environmentVariable = Get-ResponseBodyOrNull -Response $variableResponse
    Assert-EnvironmentVariableState -Variable $environmentVariable -ExpectedName $variable.Name -ExpectedValue $expectedValue
}

if ($null -eq $entitlement) {
    if ($entitlementComponent.Mode -ne 'Create') {
        throw 'Azure DevOps entitlement does not match the reviewed state.'
    }

    if (-not $PSCmdlet.ShouldProcess([string]$configuration.AzureDevOps.ProjectName, 'EnsureAzureDevOpsServicePrincipalEntitlement')) {
        throw 'Azure DevOps entitlement creation was declined.'
    }

    $null = Invoke-RequestAdapter -Adapter $AzureDevOpsRequest -AdapterName 'AzureDevOps' -Operation 'CreateServicePrincipalEntitlement' -Arguments @{ PrincipalObjectId = [string]$servicePrincipal.id }
    $entitlementResponse = Invoke-RequestAdapter -Adapter $AzureDevOpsRequest -AdapterName 'AzureDevOps' -Operation 'GetServicePrincipalEntitlement' -Arguments @{ PrincipalObjectId = [string]$servicePrincipal.id }
    $entitlement = Get-ResponseBodyOrNull -Response $entitlementResponse
}

Assert-ReviewedStableId -Component $entitlementComponent -ObservedId ([string]$entitlement.id) -ComponentName 'Azure DevOps entitlement'
Assert-AzureDevOpsEntitlementState -Entitlement $entitlement -ExpectedPrincipalId ([string]$servicePrincipal.id)

if (-not $membershipIsMember) {
    if ($membershipComponent.Mode -ne 'Create') {
        throw 'Azure DevOps Readers membership does not match the reviewed state.'
    }

    if (-not $PSCmdlet.ShouldProcess('Readers', 'EnsureAzureDevOpsReadersMembership')) {
        throw 'Azure DevOps Readers membership update was declined.'
    }

    $entitlementTable = ConvertTo-Hashtable -InputObject $entitlement
    $principalDescriptor = if ($entitlementTable.ContainsKey('descriptor') -and -not [string]::IsNullOrWhiteSpace([string]$entitlementTable['descriptor'])) { [string]$entitlementTable['descriptor'] } else { [string]$servicePrincipal.id }
    $null = Invoke-RequestAdapter -Adapter $AzureDevOpsRequest -AdapterName 'AzureDevOps' -Operation 'AddReadersMembership' -Arguments @{ GroupDescriptor = [string]$readersGroup.descriptor; PrincipalObjectId = [string]$servicePrincipal.id; PrincipalDescriptor = $principalDescriptor }
    $membershipResponse = Invoke-RequestAdapter -Adapter $AzureDevOpsRequest -AdapterName 'AzureDevOps' -Operation 'GetReadersMembership' -Arguments @{ GroupDescriptor = [string]$readersGroup.descriptor; PrincipalObjectId = [string]$servicePrincipal.id; PrincipalDescriptor = $principalDescriptor }
    $membership = Get-ResponseBodyOrNull -Response $membershipResponse
    $membershipTable = ConvertTo-Hashtable -InputObject $membership
    $membershipIsMember = $membershipTable.ContainsKey('isMember') -and [bool]$membershipTable['isMember']
    $membershipId = if ($membershipTable.ContainsKey('id')) { [string]$membershipTable['id'] } else { $null }
}

if ($membershipIsMember) {
    Assert-ReviewedStableId -Component $membershipComponent -ObservedId $membershipId -ComponentName 'Azure DevOps Readers membership'
}
Assert-AzureDevOpsReadersMembershipState -Membership $membership

$result