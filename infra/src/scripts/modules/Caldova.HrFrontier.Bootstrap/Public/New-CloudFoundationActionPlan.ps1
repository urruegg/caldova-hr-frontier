function New-CloudFoundationActionPlan {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$Assessment
    )

    $actions = [Collections.Generic.List[object]]::new()
    function Add-CloudAction {
        param($Service,$TargetType,$TargetId,$Classification,$Action,$Scope,$ExpectedPostcondition,$Method,$Uri,$ProviderInput)
        $item = [ordered]@{
            service=$Service;targetType=$TargetType;targetId=$TargetId
            classification=$Classification;action=$Action;scope=$Scope
            expectedPostcondition=$ExpectedPostcondition
        }
        if ($Classification -in @('Create','Update')) {
            if ($null -eq $ProviderInput) { throw "Mutation action '$Action' requires providerInput." }
            $item.method=$Method
            $item.uri=$Uri
            $item.providerInput=$ProviderInput
            $item.bodyDigest=Get-RunbookContentDigest -InputObject $ProviderInput
        }
        elseif ($Classification -eq 'NoChange') {
            $item.method='GET'
            $item.uri=$Uri
        }
        $actions.Add([pscustomobject]$item)
    }

    $repo = $Assessment.services.github.repository
    Add-CloudAction GitHub GitHubRepository ([string]$repo.id) `
        $(if ([string]$repo.state -ceq 'Exact') {'NoChange'} else {'Refused'}) `
        $(if ([string]$repo.state -ceq 'Exact') {'VerifyExistingResource'} else {'RefuseMismatchedTarget'}) `
        "github://$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)" `
        'Repository ID and administrator access match reviewed intent.' GET ([string]$repo.uri) $null

    if ($null -ne $Assessment.services.github.ruleset) {
        $rules = @($Assessment.services.github.ruleset.providerInput.rules | ForEach-Object type)
        $unsupported = @($rules | Where-Object { $_ -cnotin @('deletion','non_fast_forward','pull_request') })
        $class = if ($unsupported.Count -gt 0) {'Blocked'}
            elseif ([string]$Assessment.services.github.ruleset.state -ceq 'Missing') {'Create'}
            elseif ([string]$Assessment.services.github.ruleset.state -ceq 'Drift') {'Update'}
            elseif ([string]$Assessment.services.github.ruleset.state -ceq 'Exact') {'NoChange'}
            else {'Blocked'}
        Add-CloudAction GitHub GitHubRuleset ([string]$Assessment.services.github.ruleset.id) $class `
            $(if ($class -in @('Create','Update')) {'UpsertGitHubNonActionsRuleset'}
              elseif($class -eq 'NoChange') {'VerifyExistingResource'}
              else {'ResolveBlockedIntent'}) `
            "github://$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)" `
            'Non-Actions ruleset matches its canonical approved body.' `
            $(if($class -eq 'Create'){'POST'}elseif($class -eq 'NoChange'){'GET'}else{'PUT'}) `
            ([string]$Assessment.services.github.ruleset.uri) $Assessment.services.github.ruleset.providerInput
    }

    $entraApp = $Assessment.services.entra.application
    $appClass = if ([string]$entraApp.state -ceq 'Missing' -and
        [int]$entraApp.applicationExactNameMatchCount -eq 0) {'Create'}
        elseif ([string]$entraApp.state -ceq 'Exact') {'NoChange'}
        elseif ([string]$entraApp.state -ceq 'Drift') {'Update'}
        else {'Blocked'}
    Add-CloudAction Entra EntraApplication ([string]$entraApp.targetId) $appClass `
        $(if($appClass -eq 'Create'){'CreateEntraTargetApplication'}
          elseif($appClass -eq 'Update'){'UpdateEntraTargetApplication'}
          elseif($appClass -eq 'NoChange'){'VerifyExistingResource'}
          else{'ResolveBlockedIntent'}) `
        "entra://$($TenantConfiguration.TenantId)" 'Target application metadata and empty auth collections match.' `
        AZCLI 'entra://applications' $entraApp.providerInput

    $entraSp = $Assessment.services.entra.servicePrincipal
    $spClass = if ([string]$entraApp.state -ceq 'Exact' -and
        [string]$entraSp.state -ceq 'Missing' -and
        [int]$entraSp.servicePrincipalExactAppIdMatchCount -eq 0) {'Create'}
        elseif ([string]$entraSp.state -ceq 'Exact') {'NoChange'}
        else {'Blocked'}
    Add-CloudAction Entra EntraServicePrincipal ([string]$entraSp.targetId) $spClass `
        $(if($spClass -eq 'Create'){'CreateEntraTargetServicePrincipal'}
          elseif($spClass -eq 'NoChange'){'VerifyExistingResource'}
          else{'ResolveBlockedIntent'}) `
        "entra://$($TenantConfiguration.TenantId)" 'Target service principal resolves by the reviewed appId.' `
        AZCLI 'entra://servicePrincipals' $entraSp.providerInput

    $azure = $Assessment.services.azure
    $azureClass = if ([string]$azure.state -in @('Missing','Drift')) {'Update'}
        elseif([string]$azure.state -ceq 'Exact') {'NoChange'}
        else {'Blocked'}
    Add-CloudAction Azure AzureSubscription ([string]$azure.targetId) $azureClass `
        $(if($azureClass -eq 'Update'){'DeployAzureFoundation'}
          elseif($azureClass -eq 'NoChange'){'VerifyExistingResource'}
          else{'ResolveBlockedIntent'}) `
        "/subscriptions/$($TenantConfiguration.SubscriptionId)" `
        'Deployment Succeeded and every approved resource ID matches the accepted what-if.' `
        AZCLI ([string]$azure.uri) $azure.providerInput

    $ado = $Assessment.services.azureDevOps
    $adoClass = if ([string]$ado.state -ceq 'Missing' -and [string]$ado.projectIntent -ceq 'Create') {'Create'}
        elseif([string]$ado.state -ceq 'Exact' -and [string]$ado.projectIntent -ceq 'Existing') {'NoChange'}
        else {'Blocked'}
    Add-CloudAction AzureDevOps AzureDevOpsProject ([string]$ado.targetId) $adoClass `
        $(if($adoClass -eq 'Create'){'CreateAzureDevOpsProject'}
          elseif($adoClass -eq 'NoChange'){'VerifyExistingResource'}
          else{'ResolveBlockedIntent'}) `
        ([string]$TenantConfiguration.AzureDevOps.OrganizationUrl) `
        'Returned project ID, name, process, visibility, organization, and state match.' `
        AZCLI ([string]$ado.targetId) $ado.providerInput

    $blockedTypes = @(
        'EntraFederatedIdentityCredential','GitHubEnvironment',
        'AzureDevOpsServicePrincipalEntitlement','AzureDevOpsReadersMembership',
        'AzureDevOpsServiceConnection'
    )
    $manualTypes = @(
        'PowerPlatformEnvironmentDev','PowerPlatformEnvironmentTest','PowerPlatformEnvironmentProd',
        'SharePointSiteDev','SharePointSiteTest','SharePointSiteProd',
        'AzureDevOpsApproval','AzureDevOpsCheck','AzureBoardsGitHubConnection'
    )
    foreach ($component in $TenantConfiguration.Components.PSObject.Properties) {
        $componentId = if ($component.Value.PSObject.Properties.Name -contains 'Id' -and
            -not [string]::IsNullOrWhiteSpace([string]$component.Value.Id)) {
            [string]$component.Value.Id
        } else { [string]$component.Name }
        if ($component.Name -in $blockedTypes) {
            Add-CloudAction ($component.Name -replace '(Environment|Federated.*|Service.*|Readers.*)$','') `
                $component.Name $componentId Blocked ResolveBlockedIntent `
                ([string]$TenantConfiguration.TenantAlias) 'Unsupported path remains blocked.' $null $null $null
        }
        elseif ($component.Name -in $manualTypes) {
            Add-CloudAction ($component.Name -replace 'Environment.*$','') `
                $component.Name $componentId Manual CompleteAttendedManualAction `
                ([string]$TenantConfiguration.TenantAlias) 'Attended portal action requires independent read-back.' $null $null $null
        }
    }

    $sorted = @($actions | Sort-Object service,targetType,targetId)
    $manifestActions = @(
        foreach ($item in $sorted) {
            $projection = [ordered]@{
                action=[string]$item.action;targetId=[string]$item.targetId
                service=[string]$item.service;scope=[string]$item.scope
                expectedPostcondition=[string]$item.expectedPostcondition
            }
            if ($item.classification -eq 'NoChange') {
                $projection.method='GET';$projection.uri=[string]$item.uri
            }
            elseif ($item.classification -in @('Create','Update')) {
                $projection.method=[string]$item.method;$projection.uri=[string]$item.uri
                $projection.bodyDigest=[string]$item.bodyDigest
            }
            [pscustomobject]$projection
        }
    )
    $manifestComparison = [Comparison[object]] {
        param($left,$right)
        $result=[StringComparer]::Ordinal.Compare([string]$left.action,[string]$right.action)
        if($result -eq 0){
            $result=[StringComparer]::Ordinal.Compare([string]$left.targetId,[string]$right.targetId)
        }
        $result
    }
    [Array]::Sort($manifestActions,$manifestComparison)
    [pscustomobject][ordered]@{
        schemaVersion='1.0'
        target=[pscustomobject][ordered]@{type='CloudFoundation';stableId=[string]$TenantConfiguration.TenantId}
        actions=$sorted
        manifestActions=$manifestActions
        manualItems=@($Assessment.manualItems)
        blockedItems=@($Assessment.blockedItems)
    }
}
