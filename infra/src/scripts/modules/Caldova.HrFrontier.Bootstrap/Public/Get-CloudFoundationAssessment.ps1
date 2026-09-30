function Get-CloudFoundationAssessment {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolutions,
        [Parameter(Mandatory)] [string]$RunDirectory,
        [Parameter(Mandatory)] [string]$RepositoryRoot,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner,
        [scriptblock]$WhatIfValidator,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    if (-not [IO.Path]::IsPathRooted($RepositoryRoot)) {
        throw 'Cloud assessment repository root must be an absolute path.'
    }
    $canonicalRepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot)
    if (-not (Test-Path -LiteralPath $canonicalRepositoryRoot -PathType Container)) {
        throw 'Cloud assessment repository root does not exist.'
    }
    if ([string]$VerifiedContext.overallStatus -cne 'Verified') {
        throw 'Cloud assessment requires a verified delegated context.'
    }
    if ([string]$VerifiedContext.tenantAlias -cne [string]$TenantConfiguration.TenantAlias) {
        throw 'Verified context tenant alias does not match the reviewed tenant.'
    }
    $verifiedAt=[datetime]::MinValue
    if (-not [datetime]::TryParse(
        [string]$VerifiedContext.verifiedAtUtc,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$verifiedAt
    ) -or ($NowUtc.ToUniversalTime() - $verifiedAt.ToUniversalTime()).TotalMinutes -gt 5) {
        throw 'Verified delegated context is older than five minutes.'
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
        -ArgumentList @('-C',$canonicalRepositoryRoot,'rev-parse','HEAD') -Runner $NativeCommandRunner
    $sourceCommit = $gitResult.Trim().ToLowerInvariant()
    if ($sourceCommit -notmatch '^[0-9a-f]{40}$') { throw 'Source commit is not a full Git object ID.' }

    $organizationUrl = ([string]$TenantConfiguration.AzureDevOps.OrganizationUrl).TrimEnd('/') + '/'
    $adoContext = $VerifiedContext.azureDevOps
    $adoIdentityReady=$false
    try {
        $adoConnection=Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
            'devops','invoke','--organization',$organizationUrl,'--area','location',
            '--resource','connectionData','--api-version','7.1-preview.1','--output','json'
        ) -Runner $NativeCommandRunner -Json
        $adoAccount=[string]$adoConnection.authenticatedUser.properties.Account.'$value'
        $adoIdentityReady=(
            [string]$adoConnection.authenticatedUser.id -ceq [string]$adoContext.actingUserId -and
            [string]$adoConnection.authenticatedUser.subjectDescriptor -ceq [string]$adoContext.subjectDescriptor -and
            [string]::Equals($adoAccount,[string]$TenantConfiguration.AdminUpn,[StringComparison]::OrdinalIgnoreCase)
        )
    } catch { $adoIdentityReady=$false }
    $adoPermission = if ([string]$adoContext.projectIntent -ceq 'Create' -and $adoIdentityReady) {
        Get-AzureDevOpsCreateProjectPermission -OrganizationUrl $organizationUrl `
            -SubjectDescriptor ([string]$adoContext.subjectDescriptor) `
            -ToolResolution $ToolResolutions.az -NativeCommandRunner $NativeCommandRunner
    } else {
        [pscustomobject]@{state='NotApplicable';namespaceId='';permissionBit=$null;token=''}
    }
    $adoState = if ([string]$adoContext.projectIntent -ceq 'Create' -and
        [int]$adoContext.exactNameMatchCount -eq 0 -and
        [string]$adoPermission.state -ceq 'Allowed') { 'Missing' }
        elseif ($adoIdentityReady -and [string]$adoContext.projectIntent -ceq 'Existing' -and
            -not [string]::IsNullOrWhiteSpace([string]$adoContext.projectId)) { 'Exact' }
        else { 'Blocked' }
    $processName=if($TenantConfiguration.AzureDevOps.PSObject.Properties.Name -contains 'ProcessName'){
        [string]$TenantConfiguration.AzureDevOps.ProcessName
    }else{''}
    $visibility=if($TenantConfiguration.AzureDevOps.PSObject.Properties.Name -contains 'Visibility'){
        [string]$TenantConfiguration.AzureDevOps.Visibility
    }else{''}
    if ($adoState -ceq 'Missing' -and
        ([string]::IsNullOrWhiteSpace($processName) -or
         [string]::IsNullOrWhiteSpace($visibility))) {
        $adoState='Blocked'
    }
    $processes = @()
    if ($adoState -ceq 'Missing') {
        try {
            $processes = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
                'devops','process','list','--organization',$organizationUrl,'--output','json'
            ) -Runner $NativeCommandRunner -Json | Where-Object {
                [string]$_.name -ceq $processName
            })
        } catch { $adoState='Blocked' }
        if ($processes.Count -ne 1) { $adoState='Blocked' }
    }
    $adoInput = [pscustomobject][ordered]@{
        organizationUrl=$organizationUrl;name=[string]$TenantConfiguration.AzureDevOps.ProjectName
        processName=$processName
        processId=$(if($processes.Count -eq 1){[string]$processes[0].id}else{''})
        sourceControl='git';visibility=$visibility
        permissionNamespaceId=[string]$adoPermission.namespaceId
        permissionBit=$adoPermission.permissionBit
        permissionToken=[string]$adoPermission.token
        subjectDescriptor=[string]$adoContext.subjectDescriptor
    }

    $entraApplication = [pscustomobject][ordered]@{
        state='Blocked';targetId='';applicationExactNameMatchCount=0;providerInput=$null
        symmetricAuthCount=0;asymmetricAuthCount=0
        reason='Reviewed Entra application intent is unavailable.'
    }
    $entraServicePrincipal = [pscustomobject][ordered]@{
        state='Blocked';targetId='';providerInput=$null
        reason='Reviewed Entra service-principal intent is unavailable.'
    }
    $appComponent = $TenantConfiguration.Components.EntraApplication
    $spComponent = $TenantConfiguration.Components.EntraServicePrincipal
    $entraWriteRoleIds=@(
        'cf1c38e5-3621-4004-a7cb-879624dced7c',
        '158c047a-c907-4556-b7ef-446551a6b5f7'
    )
    $activeRoleIds=if($VerifiedContext.PSObject.Properties.Name -contains 'entra'){
        @($VerifiedContext.entra.activeDirectoryRoleTemplateIds)
    }else{@()}
    $entraWriteReady=@($activeRoleIds | Where-Object { $_ -cin $entraWriteRoleIds }).Count -gt 0
    $cloud = if ($TenantConfiguration.PSObject.Properties.Name -contains 'CloudFoundation') {
        $TenantConfiguration.CloudFoundation
    } else { $null }
    $displayName = if ($null -ne $cloud -and
        $cloud.PSObject.Properties.Name -contains 'EntraApplicationDisplayName') {
        [string]$cloud.EntraApplicationDisplayName
    } else { '' }
    if ($entraWriteReady -and $null -ne $appComponent -and [string]$appComponent.Mode -ceq 'Create' -and
        -not [string]::IsNullOrWhiteSpace($displayName)) {
        try {
            $apps = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
                'ad','app','list','--display-name',$displayName,'--output','json'
            ) -Runner $NativeCommandRunner -Json | Where-Object { [string]$_.displayName -ceq $displayName })
            $entraApplication = [pscustomobject][ordered]@{
                state=$(if($apps.Count -eq 0){'Missing'}else{'Blocked'});targetId=$displayName
                applicationExactNameMatchCount=$apps.Count
                providerInput=[pscustomobject][ordered]@{displayName=$displayName}
                reason=$(if($apps.Count -eq 0){''}else{'Exact-name absence was not proven.'})
            }
        }
        catch {
            $entraApplication = [pscustomobject][ordered]@{
                state='Blocked';targetId=$displayName;applicationExactNameMatchCount=0
                providerInput=[pscustomobject][ordered]@{displayName=$displayName}
                reason='Entra application absence read-back was unavailable.'
            }
        }
    }
    elseif ($null -ne $appComponent -and [string]$appComponent.Mode -ceq 'Existing') {
        $app = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
            'ad','app','show','--id',[string]$appComponent.Id,'--output','json'
        ) -Runner $NativeCommandRunner -Json
        $desiredDisplayName=if([string]::IsNullOrWhiteSpace($displayName)){
            [string]$app.displayName
        }else{$displayName}
        $hasCredentialReadBack=(
            $app.PSObject.Properties.Name -contains 'passwordCredentials' -and
            $app.PSObject.Properties.Name -contains 'keyCredentials'
        )
        $symmetricAuthCount=if($hasCredentialReadBack){@($app.passwordCredentials).Count}else{-1}
        $asymmetricAuthCount=if($hasCredentialReadBack){@($app.keyCredentials).Count}else{-1}
        $credentialFree=($hasCredentialReadBack -and
            $symmetricAuthCount -eq 0 -and $asymmetricAuthCount -eq 0)
        $entraApplication = [pscustomobject][ordered]@{
            state=$(if(-not $credentialFree){'Blocked'}
                elseif([string]$app.displayName -ceq $desiredDisplayName){'Exact'}
                elseif($entraWriteReady){'Drift'}else{'Blocked'})
            targetId=[string]$app.id;applicationExactNameMatchCount=1
            providerInput=[pscustomobject][ordered]@{displayName=$desiredDisplayName}
            appId=[string]$app.appId
            symmetricAuthCount=$symmetricAuthCount;asymmetricAuthCount=$asymmetricAuthCount
            reason=$(if(-not $credentialFree){
                'Entra application is not proven credential-free.'
            }else{''})
        }
    }
    if ($null -ne $spComponent -and [string]$spComponent.Mode -ceq 'Existing') {
        $sp = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
            'ad','sp','show','--id',[string]$spComponent.Id,'--output','json'
        ) -Runner $NativeCommandRunner -Json
        $entraServicePrincipal = [pscustomobject][ordered]@{
            state=$(if([string]$sp.id -ceq [string]$spComponent.Id){'Exact'}else{'Blocked'})
            targetId=[string]$sp.id;providerInput=[pscustomobject][ordered]@{appId=[string]$sp.appId}
            reason=''
        }
    }
    elseif ($entraWriteReady -and $null -ne $spComponent -and [string]$spComponent.Mode -ceq 'Create' -and
        [string]$entraApplication.state -ceq 'Exact' -and
        -not [string]::IsNullOrWhiteSpace([string]$entraApplication.appId)) {
        $appId=[string]$entraApplication.appId
        try {
            $servicePrincipals=@(Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
                'ad','sp','list','--filter',"appId eq '$appId'",'--output','json'
            ) -Runner $NativeCommandRunner -Json | Where-Object { [string]$_.appId -ceq $appId })
            $entraServicePrincipal=[pscustomobject][ordered]@{
                state=$(if($servicePrincipals.Count -eq 0){'Missing'}else{'Blocked'})
                targetId=$appId;servicePrincipalExactAppIdMatchCount=$servicePrincipals.Count
                providerInput=[pscustomobject][ordered]@{appId=$appId}
                reason=$(if($servicePrincipals.Count -eq 0){''}else{'Exact appId absence was not proven.'})
            }
        }
        catch {
            $entraServicePrincipal=[pscustomobject][ordered]@{
                state='Blocked';targetId=$appId;servicePrincipalExactAppIdMatchCount=0
                providerInput=[pscustomobject][ordered]@{appId=$appId}
                reason='Entra service-principal absence read-back was unavailable.'
            }
        }
    }

    $azure = [pscustomobject][ordered]@{
        state='Blocked';targetId=[string]$TenantConfiguration.SubscriptionId
        reason='A validated external compiled template and accepted what-if are required.'
        uri="azure://subscriptions/$($TenantConfiguration.SubscriptionId)";providerInput=$null
    }
    $validationPrincipalId = if ($null -ne $cloud -and
        $cloud.PSObject.Properties.Name -contains 'ValidationPrincipalId') {
        [string]$cloud.ValidationPrincipalId
    } elseif ($null -ne $spComponent -and [string]$spComponent.Mode -ceq 'Existing') {
        [string]$spComponent.Id
    } else { '' }
    $contextPrincipalId=if($VerifiedContext.PSObject.Properties.Name -contains 'principal'){
        [string]$VerifiedContext.principal.id
    }else{''}
    $validationPrincipalApproved=(
        $validationPrincipalId -match '^[0-9a-fA-F-]{36}$' -and
        $null -ne $spComponent -and [string]$spComponent.Mode -ceq 'Existing' -and
        [string]$spComponent.Id -ceq $validationPrincipalId -and
        ([string]::IsNullOrWhiteSpace($contextPrincipalId) -or
         $contextPrincipalId -cne $validationPrincipalId)
    )
    if ($validationPrincipalApproved) {
        try {
            $sourcePath = if ($null -ne $cloud -and
                $cloud.PSObject.Properties.Name -contains 'SourceBicepPath') {
                [IO.Path]::GetFullPath([string]$cloud.SourceBicepPath)
            } else {
                [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\bicep\main.bicep'))
            }
            $sourceDigest = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
            try {
                $formatHelp = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
                    'bicep','format','--help'
                ) -Runner $NativeCommandRunner
            } catch { $formatHelp='' }
            if ($formatHelp -match '(?m)(?:^|\s)--stdout(?:\s|$)') {
                $formatted = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
                    'bicep','format','--file',$sourcePath,'--stdout'
                ) -Runner $NativeCommandRunner
                if ([string]::IsNullOrWhiteSpace($formatted)) {
                    throw 'Bicep stdout formatting produced no content.'
                }
            }
            if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $sourceDigest) {
                throw 'Bicep source changed during read-only formatting.'
            }
            $templatePath = Join-Path $RunDirectory 'cloud-foundation.template.json'
            Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
                'bicep','build','--file',$sourcePath,'--outfile',$templatePath
            ) -Runner $NativeCommandRunner | Out-Null
            if (-not (Test-Path -LiteralPath $templatePath)) { throw 'External Bicep build did not produce a template.' }
            $parameters = [pscustomobject][ordered]@{
                '$schema'='https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
                contentVersion='1.0.0.0'
                parameters=[pscustomobject][ordered]@{
                    tenant=[pscustomobject][ordered]@{value=[pscustomobject][ordered]@{
                        tenantAlias=[string]$TenantConfiguration.TenantAlias
                        location=[string]$TenantConfiguration.PrimaryLocation
                        namingRoot=[string]$TenantConfiguration.NamingRoot
                        platformResourceGroupName=Get-TenantResourceName -NamingRoot $TenantConfiguration.NamingRoot -ResourceType ResourceGroup
                        logAnalyticsWorkspaceName=Get-TenantResourceName -NamingRoot $TenantConfiguration.NamingRoot -ResourceType LogAnalytics
                        policyAssignments=@()
                    }}
                }
            }
            $parameterPath = Join-Path $RunDirectory 'cloud-foundation.parameters.json'
            Write-CanonicalJson -InputObject $parameters -Path $parameterPath -Replace | Out-Null
            $whatIfPath = Join-Path $RunDirectory 'cloud-foundation.whatif.json'
            $whatIf = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.az -ArgumentList @(
                'deployment','sub','what-if','--location',[string]$TenantConfiguration.PrimaryLocation,
                '--template-file',$templatePath,'--parameters',"@$parameterPath",
                '--result-format','FullResourcePayloads','--no-pretty-print','--output','json'
            ) -Runner $NativeCommandRunner
            [IO.File]::WriteAllText($whatIfPath,$whatIf,[Text.UTF8Encoding]::new($false))
            $valid = if ($null -ne $WhatIfValidator) {
                & $WhatIfValidator $whatIfPath
            } else {
                $validatorPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\Test-WhatIfBoundary.ps1'))
                & $validatorPath -WhatIfPayloadPath $whatIfPath -ExpectedPrincipalObjectId $validationPrincipalId
                $true
            }
            if (-not $valid) { throw 'Azure what-if boundary validation failed.' }
            $azureInput=[pscustomobject][ordered]@{
                sourcePath=$sourcePath;sourceDigest=$sourceDigest;templatePath=$templatePath
                templateDigest=(Get-FileHash $templatePath -Algorithm SHA256).Hash.ToLowerInvariant()
                parameterPath=$parameterPath
                parameterDigest=(Get-FileHash $parameterPath -Algorithm SHA256).Hash.ToLowerInvariant()
                whatIfPath=$whatIfPath
                whatIfDigest=(Get-FileHash $whatIfPath -Algorithm SHA256).Hash.ToLowerInvariant()
                validationPrincipalId=$validationPrincipalId
                deploymentName="cf-$($TenantConfiguration.TenantAlias)-$($sourceCommit.Substring(0,12))"
                location=[string]$TenantConfiguration.PrimaryLocation
            }
            $azure=[pscustomobject][ordered]@{
                state='Drift';targetId=[string]$TenantConfiguration.SubscriptionId;reason=''
                uri="azure://subscriptions/$($TenantConfiguration.SubscriptionId)/deployments/$($azureInput.deploymentName)"
                providerInput=$azureInput
            }
        } catch {
            $azure.reason='Azure planning chain was not proven: ' + $_.Exception.Message
        }
    }

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
        azure = $azure
        azureDevOps = [pscustomobject][ordered]@{
            state=$adoState
            targetId=$(if($adoState -ceq 'Exact'){[string]$adoContext.projectId}else{"azuredevops://$organizationUrl$($TenantConfiguration.AzureDevOps.ProjectName)"})
            projectIntent=[string]$adoContext.projectIntent;providerInput=$adoInput
            permissionState=[string]$adoPermission.state
        }
        entra = [pscustomobject][ordered]@{
            permissionState=$(if($entraWriteReady){'Allowed'}else{'Blocked'})
            application=$entraApplication
            servicePrincipal=$entraServicePrincipal
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
        repositoryRoot=$canonicalRepositoryRoot
        sourceCommit=$sourceCommit
        overallStatus=$(if ($azure.state -in @('Missing','Drift','Exact') -and
            $adoState -in @('Missing','Exact') -and
            $entraApplication.state -in @('Missing','Exact','Drift') -and
            $entraServicePrincipal.state -in @('Missing','Exact') -and
            ($null -eq $snapshot.github.ruleset -or
             $snapshot.github.ruleset.state -in @('Missing','Drift','Exact')) -and
            $snapshot.github.repository.state -ceq 'Exact') {'Ready'}else{'Blocked'})
    }
    $result = [ordered]@{}
    foreach ($entry in $unsigned.GetEnumerator()) { $result[$entry.Key]=$entry.Value }
    $result.assessmentDigest = Get-RunbookContentDigest -InputObject ([pscustomobject]$unsigned)
    [pscustomobject]$result
}
