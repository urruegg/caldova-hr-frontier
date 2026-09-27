function Test-CloudDelegatedContext {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [ValidateSet('DEV','TEST','PROD')] [string[]]$Stages = @('DEV','TEST','PROD'),
        [Parameter(Mandatory)] [object]$ToolResolutions,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner,
        [Parameter(Mandatory)] [scriptblock]$InteractiveHostProbe
    )

    $hostState = & $InteractiveHostProbe
    if ($null -eq $hostState -or -not [bool]$hostState.isInteractive -or
        [string]$hostState.platform -notmatch '^Windows 11') {
        throw 'Cloud foundation requires an interactive Windows 11 host.'
    }
    foreach ($required in @('az','gh','pac')) {
        if ($null -eq $ToolResolutions.$required) {
            throw "Cloud tool resolution is missing: $required"
        }
    }

    $az = $ToolResolutions.az
    $gh = $ToolResolutions.gh
    $pac = $ToolResolutions.pac
    $account = Invoke-CloudNativeCommand -ToolResolution $az -ArgumentList @(
        'account','show','--output','json'
    ) -Runner $NativeCommandRunner -Json
    if ([string]$account.user.type -cne 'user') {
        throw 'Azure context must use one attended delegated user.'
    }
    if ([string]$account.tenantId -cne [string]$TenantConfiguration.TenantId -or
        [string]$account.id -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'Azure tenant or subscription does not match reviewed intent.'
    }
    $signedInUser = Invoke-CloudNativeCommand -ToolResolution $az -ArgumentList @(
        'ad','signed-in-user','show','--output','json'
    ) -Runner $NativeCommandRunner -Json
    if (-not [string]::Equals(
        [string]$signedInUser.userPrincipalName,
        [string]$TenantConfiguration.AdminUpn,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Azure delegated user does not match reviewed intent.'
    }
    $roles = Invoke-CloudNativeCommand -ToolResolution $az -ArgumentList @(
        'rest','--method','get','--url',
        'https://graph.microsoft.com/v1.0/me/transitiveMemberOf/microsoft.graph.directoryRole?$select=id,displayName,roleTemplateId',
        '--output','json'
    ) -Runner $NativeCommandRunner -Json

    $authStatus = Invoke-CloudNativeCommand -ToolResolution $gh -ArgumentList @(
        'auth','status','--hostname','github.com'
    ) -Runner $NativeCommandRunner
    $authMatch = [regex]::Match($authStatus, 'account\s+([^\s;]+)', 'IgnoreCase')
    if (-not $authMatch.Success) { throw 'GitHub delegated login could not be verified.' }
    $githubUser = Invoke-CloudNativeCommand -ToolResolution $gh -ArgumentList @(
        'api','user'
    ) -Runner $NativeCommandRunner -Json
    if ([string]$githubUser.login -cne $authMatch.Groups[1].Value) {
        throw 'GitHub delegated login does not match the authenticated account.'
    }
    $repository = Invoke-CloudNativeCommand -ToolResolution $gh -ArgumentList @(
        'api',"repos/$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)"
    ) -Runner $NativeCommandRunner -Json
    if ([string]$repository.id -cne [string]$TenantConfiguration.GitHub.RepositoryId -or
        [string]$repository.full_name -cne "$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)" -or
        -not [bool]$repository.permissions.admin) {
        throw 'GitHub repository identity or administrator permission does not match reviewed intent.'
    }

    $organizationUrl = ([string]$TenantConfiguration.AzureDevOps.OrganizationUrl).TrimEnd('/') + '/'
    $connection = Invoke-CloudNativeCommand -ToolResolution $az -ArgumentList @(
        'devops','invoke','--organization',$organizationUrl,'--area','location',
        '--resource','connectionData','--api-version','7.1-preview.1','--output','json'
    ) -Runner $NativeCommandRunner -Json
    $adoUser = $connection.authenticatedUser
    $adoAccount = [string]$adoUser.properties.Account.'$value'
    if ([string]::IsNullOrWhiteSpace([string]$adoUser.id) -or
        [string]::IsNullOrWhiteSpace([string]$adoUser.subjectDescriptor) -or
        -not [string]::Equals($adoAccount, [string]$TenantConfiguration.AdminUpn,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Azure DevOps delegated user does not match reviewed intent.'
    }

    $projectComponent = $TenantConfiguration.Components.AzureDevOpsProject
    $ado = [ordered]@{
        organizationUrl = $organizationUrl
        actingUserId = [string]$adoUser.id
        subjectDescriptor = [string]$adoUser.subjectDescriptor
        accountName = $adoAccount
        projectIntent = [string]$projectComponent.Mode
    }
    if ([string]$projectComponent.Mode -ceq 'Existing') {
        $project = Invoke-CloudNativeCommand -ToolResolution $az -ArgumentList @(
            'devops','project','show','--organization',$organizationUrl,
            '--project',[string]$projectComponent.Id,'--output','json'
        ) -Runner $NativeCommandRunner -Json
        if ([string]$project.id -cne [string]$projectComponent.Id -or
            [string]$project.name -cne [string]$TenantConfiguration.AzureDevOps.ProjectName) {
            throw 'Azure DevOps project identity does not match reviewed intent.'
        }
        $ado.projectId = [string]$project.id
    }
    elseif ([string]$projectComponent.Mode -ceq 'Create') {
        $projectName = [string]$TenantConfiguration.AzureDevOps.ProjectName
        $escapedName = $projectName.Replace("'","''")
        $projects = @(Invoke-CloudNativeCommand -ToolResolution $az -ArgumentList @(
            'devops','project','list','--organization',$organizationUrl,'--query',
            "value[?name=='$escapedName'].{id:id,name:name,state:state,visibility:visibility}",
            '--output','json'
        ) -Runner $NativeCommandRunner -Json)
        $matches = @($projects | Where-Object { [string]$_.name -ceq $projectName })
        if ($matches.Count -gt 1) { throw 'Azure DevOps project exact-name result is ambiguous.' }
        $ado.requestedProjectName = $projectName
        $ado.exactNameMatchCount = $matches.Count
        if ($matches.Count -eq 1) { $ado.conflictingProjectId = [string]$matches[0].id }
        $permission = Get-AzureDevOpsCreateProjectPermission -OrganizationUrl $organizationUrl `
            -SubjectDescriptor ([string]$adoUser.subjectDescriptor) -ToolResolution $az `
            -NativeCommandRunner $NativeCommandRunner
        $ado.createProjectPermission = [string]$permission.state
        $ado.createProjectPermissionBit = $permission.permissionBit
        $ado.createProjectPermissionNamespaceId = [string]$permission.namespaceId
        $ado.createProjectPermissionToken = [string]$permission.token
    }
    else {
        throw 'Azure DevOps project intent must be Existing or Create.'
    }

    $profiles = @(Invoke-CloudNativeCommand -ToolResolution $pac -ArgumentList @(
        'auth','list','--json'
    ) -Runner $NativeCommandRunner -Json)
    $stageResults = @()
    foreach ($stage in $Stages) {
        $profileName = 'hr-{0}-{1}' -f $TenantConfiguration.TenantAlias, $stage.ToLowerInvariant()
        if ($profileName.Length -gt 60) {
            throw 'The deterministic PAC profile name exceeds the supported reviewed limit.'
        }
        $profileMatches = @($profiles | Where-Object { [string]$_.name -ceq $profileName })
        if ($profileMatches.Count -ne 1) {
            throw "PAC profile '$profileName' must resolve exactly once."
        }
        if (-not [bool]$profileMatches[0].selected) {
            Invoke-CloudNativeCommand -ToolResolution $pac -ArgumentList @(
                'auth','select','--name',$profileName
            ) -Runner $NativeCommandRunner | Out-Null
        }
        $titleStage = $stage.Substring(0,1) + $stage.Substring(1).ToLowerInvariant()
        $environmentUrl = [string]$TenantConfiguration.PowerPlatform."${titleStage}Url"
        $environment = Invoke-CloudNativeCommand -ToolResolution $pac -ArgumentList @(
            'org','who','--environment',$environmentUrl,'--json'
        ) -Runner $NativeCommandRunner -Json
        $component = $TenantConfiguration.Components."PowerPlatformEnvironment$titleStage"
        if ([string]$environment.environmentUrl.TrimEnd('/') -cne $environmentUrl.TrimEnd('/') -or
            ($null -ne $component -and [string]$component.Id -and
             [string]$environment.environmentId -cne [string]$component.Id) -or
            -not [string]::Equals([string]$environment.user, [string]$TenantConfiguration.AdminUpn,
                [StringComparison]::OrdinalIgnoreCase)) {
            throw "Power Platform $stage context does not match reviewed intent."
        }
        $stageResults += [pscustomobject][ordered]@{
            stage = $stage
            profileName = $profileName
            environmentId = [string]$environment.environmentId
            environmentUrl = [string]$environment.environmentUrl
        }
    }

    [pscustomobject][ordered]@{
        overallStatus = 'Verified'
        tenantAlias = [string]$TenantConfiguration.TenantAlias
        verifiedAtUtc = [datetime]::UtcNow.ToString('o')
        principal = [pscustomobject][ordered]@{
            id = [string]$signedInUser.id
            upn = [string]$signedInUser.userPrincipalName
        }
        azure = [pscustomobject][ordered]@{
            tenantId = [string]$account.tenantId
            subscriptionId = [string]$account.id
            userType = [string]$account.user.type
        }
        github = [pscustomobject][ordered]@{
            host = 'github.com'
            login = [string]$githubUser.login
            userId = [string]$githubUser.id
            repositoryId = [string]$repository.id
            repositoryFullName = [string]$repository.full_name
        }
        azureDevOps = [pscustomobject]$ado
        entra = [pscustomobject][ordered]@{
            activeDirectoryRoleIds = @($roles.value | ForEach-Object id)
            activeDirectoryRoleTemplateIds = @($roles.value | ForEach-Object roleTemplateId)
        }
        powerPlatform = @($stageResults)
    }
}
