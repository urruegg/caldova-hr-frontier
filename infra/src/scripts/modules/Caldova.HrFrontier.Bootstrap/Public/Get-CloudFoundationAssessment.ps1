function Get-CloudFoundationAssessment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolutions,
        [Parameter(Mandatory)] [string]$RunDirectory,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if ([string]$VerifiedContext.overallStatus -cne 'Verified') {
        throw 'Cloud assessment requires a verified delegated context.'
    }
    if ([string]$VerifiedContext.azure.tenantId -cne [string]$TenantConfiguration.TenantId -or
        [string]$VerifiedContext.azure.subscriptionId -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'Verified context does not match the reviewed tenant.'
    }
    $requiredTools = @('az','gh','pac','git')
    $safeTools = [ordered]@{}
    foreach ($name in $requiredTools) {
        $tool = $ToolResolutions.$name
        if ($null -eq $tool -or [string]$tool.name -cne $name -or
            -not [IO.Path]::IsPathRooted([string]$tool.path) -or
            [string]$tool.version -eq '' -or [string]$tool.sha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw "Cloud tool identity is invalid: $name"
        }
        $safeTools[$name] = [pscustomobject][ordered]@{
            name=$name;path=[IO.Path]::GetFullPath([string]$tool.path)
            version=[string]$tool.version;sha256=[string]$tool.sha256
        }
    }

    $snapshot = Get-CloudServiceSnapshot -TenantConfiguration $TenantConfiguration `
        -VerifiedContext $VerifiedContext -ToolResolutions $ToolResolutions `
        -RunDirectory $RunDirectory -NativeCommandRunner $NativeCommandRunner
    $gitResult = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.git `
        -ArgumentList @('rev-parse','HEAD') -Runner $NativeCommandRunner
    $sourceCommit = $gitResult.Trim().ToLowerInvariant()
    if ($sourceCommit -notmatch '^[0-9a-f]{40}$') { throw 'Source commit is not a full Git object ID.' }

    $manual = @(
        [pscustomobject][ordered]@{
            service='PowerPlatform';targetId="powerplatform://$($TenantConfiguration.TenantAlias)"
            condition='Environment creation and configuration are attended.'
            owner='Power Platform administrator';diagnostic='ManualAdapter'
            recovery='Complete exact portal procedure, reassess, and generate a new plan.'
        },
        [pscustomobject][ordered]@{
            service='AzureDevOps';targetId="azuredevops://$($TenantConfiguration.AzureDevOps.OrganizationUrl)$($TenantConfiguration.AzureDevOps.ProjectName)/github-connection"
            condition='The first Azure Boards GitHub connection requires attended authorization.'
            owner='Azure DevOps organization administrator';diagnostic='ConnectionNotVerified'
            recovery='Authorize and read back the reviewed connection, then generate a new plan.'
        }
    )
    $blocked = @(
        [pscustomobject][ordered]@{service='GitHub';reason='GitHub Environment operations are excluded.'}
    )
    $services = [ordered]@{
        github = $snapshot.github
        azure = [pscustomobject][ordered]@{
            state='Blocked';targetId=[string]$TenantConfiguration.SubscriptionId
            reason='A validated external compiled template and accepted what-if are required.'
        }
        azureDevOps = [pscustomobject][ordered]@{
            state = if ([string]$VerifiedContext.azureDevOps.projectIntent -ceq 'Create' -and
                [int]$VerifiedContext.azureDevOps.exactNameMatchCount -eq 0) { 'Missing' } else { 'Exact' }
            projectIntent=[string]$VerifiedContext.azureDevOps.projectIntent
        }
        entra = [pscustomobject][ordered]@{
            application=[pscustomobject][ordered]@{state='Blocked';reason='Exact delegated absence read-back is required.'}
            servicePrincipal=[pscustomobject][ordered]@{state='Blocked';reason='Exact reviewed appId is required.'}
        }
    }
    $unsigned = [ordered]@{
        schemaVersion='1.0'
        tenantAlias=[string]$TenantConfiguration.TenantAlias
        assessedAtUtc=$NowUtc.ToUniversalTime().ToString('o')
        contextDigest=Get-RunbookContentDigest -InputObject $VerifiedContext
        services=[pscustomobject]$services
        permissionDelta=@()
        manualItems=@($manual)
        blockedItems=@($blocked)
        toolVersions=[pscustomobject]$safeTools
        sourceCommit=$sourceCommit
        overallStatus='Blocked'
    }
    $result = [ordered]@{}
    foreach ($entry in $unsigned.GetEnumerator()) { $result[$entry.Key]=$entry.Value }
    $result.assessmentDigest = Get-RunbookContentDigest -InputObject ([pscustomobject]$unsigned)
    [pscustomobject]$result
}
