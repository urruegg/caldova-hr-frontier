Set-StrictMode -Version Latest

Describe 'Cloud foundation provider mutations' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:RunDirectory = Join-Path $TestDrive 'external-run'
        [IO.Directory]::CreateDirectory($script:RunDirectory) | Out-Null
        $script:Tenant = [pscustomobject]@{
            GitHub=[pscustomobject]@{Owner='synthetic-owner';Repository='synthetic-repository';RepositoryId='67890'}
            SubscriptionId='11111111-1111-1111-1111-111111111111'
            AzureDevOps=[pscustomobject]@{OrganizationUrl='https://dev.azure.com/synthetic/';ProjectName='SyntheticProject'}
        }
        $script:Context = [pscustomobject]@{
            overallStatus='Verified'
            github=[pscustomobject]@{login='synthetic-admin';repositoryId='67890'}
            azure=[pscustomobject]@{subscriptionId=$script:Tenant.SubscriptionId;userType='user'}
            azureDevOps=[pscustomobject]@{organizationUrl=$script:Tenant.AzureDevOps.OrganizationUrl;actingUserId='ado-user-synthetic'}
        }
        $script:Tools = [pscustomobject]@{
            gh=[pscustomobject]@{name='gh';path='C:\SyntheticTools\gh.exe';version='2.80.0';sha256=('b'*64)}
            az=[pscustomobject]@{name='az';path='C:\SyntheticTools\az.cmd';version='2.77.0';sha256=('a'*64)}
        }
        $script:ProviderInput = [pscustomobject][ordered]@{
            name='main';target='branch';enforcement='active'
            rules=@([pscustomobject]@{type='deletion'},[pscustomobject]@{type='non_fast_forward'})
        }
        $script:Action = [pscustomobject][ordered]@{
            service='GitHub';targetType='GitHubRuleset';targetId='321';classification='Update'
            action='UpsertGitHubNonActionsRuleset';method='PUT'
            uri='repos/synthetic-owner/synthetic-repository/rulesets/321'
            providerInput=$script:ProviderInput
            bodyDigest=Get-RunbookContentDigest $script:ProviderInput
        }
    }

    BeforeEach { $script:Calls = [Collections.Generic.List[object]]::new() }

    It 'updates a non-Actions ruleset and reads the exact target back' {
        $script:RulesetReads = 0
        $runner = {
            param($FilePath,$ArgumentList)
            $script:Calls.Add([pscustomobject]@{FilePath=$FilePath;ArgumentList=$ArgumentList})
            $args = $ArgumentList -join ' '
            if ($args -eq 'api repos/synthetic-owner/synthetic-repository') {
                return [pscustomobject]@{exitCode=0;stdout='{"id":67890,"permissions":{"admin":true}}';stderr=''}
            }
            if ($args -eq 'api repos/synthetic-owner/synthetic-repository/rulesets/321') {
                $script:RulesetReads++
                $body = if ($script:RulesetReads -eq 1) {'{"id":321,"name":"main","target":"branch","enforcement":"evaluate","rules":[]}'}
                    else {'{"id":321,"name":"main","target":"branch","enforcement":"active","rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}'}
                return [pscustomobject]@{exitCode=0;stdout=$body;stderr=''}
            }
            if ($args -match '^api --method PUT .* --input ') {
                return [pscustomobject]@{exitCode=0;stdout='{"id":321}';stderr=''}
            }
            throw "Unexpected: $args"
        }
        $result = Invoke-CloudFoundationAction -Action $script:Action -TenantConfiguration $script:Tenant `
            -VerifiedContext $script:Context -ToolResolutions $script:Tools `
            -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner
        $result.status | Should -BeExactly 'Changed'
        $result.readBack.rulesetId | Should -BeExactly '321'
        $result.readBack.bodyDigest | Should -BeExactly $script:Action.bodyDigest
        @($script:Calls.FilePath | Select-Object -Unique) | Should -Be @('C:\SyntheticTools\gh.exe')
        @(Get-ChildItem $script:RunDirectory -Filter 'github-*.json').Count | Should -Be 0
    }

    It 'does not write an exact ruleset and rejects prohibited rule types' {
        $runner = {
            param($FilePath,$ArgumentList)
            $script:Calls.Add([pscustomobject]@{FilePath=$FilePath;ArgumentList=$ArgumentList})
            $args = $ArgumentList -join ' '
            if ($args -eq 'api repos/synthetic-owner/synthetic-repository') {
                return [pscustomobject]@{exitCode=0;stdout='{"id":67890,"permissions":{"admin":true}}';stderr=''}
            }

            [pscustomobject]@{exitCode=0;stdout='{"id":321,"name":"main","target":"branch","enforcement":"active","rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}';stderr=''}
        }
        $result = Invoke-CloudFoundationAction -Action $script:Action -TenantConfiguration $script:Tenant `
            -VerifiedContext $script:Context -ToolResolutions $script:Tools `
            -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner
        $result.status | Should -BeExactly 'NoChange'
        ($script:Calls.ArgumentList -join "`n") | Should -Not -Match '--method'

        $bad = $script:Action.PSObject.Copy()
        $bad.providerInput = [pscustomobject]@{name='main';target='branch';enforcement='active';rules=@([pscustomobject]@{type='required_status_checks'})}
        $bad.bodyDigest = Get-RunbookContentDigest $bad.providerInput
        { Invoke-CloudFoundationAction -Action $bad -TenantConfiguration $script:Tenant `
            -VerifiedContext $script:Context -ToolResolutions $script:Tools `
            -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner } | Should -Throw '*non-Actions*'
    }

    It 'creates a proven missing non-Actions ruleset and reads its returned ID' {
        $action=$script:Action.PSObject.Copy()
        $action.targetId='main';$action.classification='Create';$action.method='POST'
        $action.uri='repos/synthetic-owner/synthetic-repository/rulesets'
        $runner={
            param($FilePath,$ArgumentList)
            $script:Calls.Add([pscustomobject]@{FilePath=$FilePath;ArgumentList=$ArgumentList})
            $command=$ArgumentList -join ' '
            if($command -eq 'api repos/synthetic-owner/synthetic-repository'){
                return [pscustomobject]@{exitCode=0;stdout='{"id":67890,"permissions":{"admin":true}}';stderr=''}
            }
            if($command -eq 'api repos/synthetic-owner/synthetic-repository/rulesets'){
                return [pscustomobject]@{exitCode=0;stdout='[]';stderr=''}
            }
            if($command -match '^api --method POST .* --input '){
                return [pscustomobject]@{exitCode=0;stdout='{"id":444}';stderr=''}
            }
            if($command -eq 'api repos/synthetic-owner/synthetic-repository/rulesets/444'){
                return [pscustomobject]@{exitCode=0;stdout='{"id":444,"name":"main","target":"branch","enforcement":"active","rules":[{"type":"deletion"},{"type":"non_fast_forward"}]}';stderr=''}
            }
            throw "Unexpected command: $command"
        }
        $result=Invoke-CloudFoundationAction -Action $action -TenantConfiguration $script:Tenant `
            -VerifiedContext $script:Context -ToolResolutions $script:Tools `
            -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner
        $result.status | Should -BeExactly 'Changed'
        $result.readBack.rulesetId | Should -BeExactly '444'
    }

    It 'rejects unknown, non-mutating, and body-tampered actions before provider execution' {
        foreach ($change in @(
            @{action='Unknown';service='GitHub'},
            @{action='UpsertGitHubNonActionsRuleset';service='Azure'},
            @{action='UpsertGitHubNonActionsRuleset';service='GitHub';classification='Manual'},
            @{action='UpsertGitHubNonActionsRuleset';service='GitHub';bodyDigest=('0'*64)}
        )) {
            $candidate = $script:Action.PSObject.Copy()
            foreach ($key in $change.Keys) { $candidate.$key = $change[$key] }
            { Invoke-CloudFoundationAction -Action $candidate -TenantConfiguration $script:Tenant `
                -VerifiedContext $script:Context -ToolResolutions $script:Tools `
                -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
                -NativeCommandRunner { throw 'must not execute' } } | Should -Throw
        }
    }

    It 'refuses Azure deployment when any approved chain artifact drifts or what-if validation fails' {
        $paths = [ordered]@{
            source=Join-Path $script:RunDirectory 'source.bicep'
            template=Join-Path $script:RunDirectory 'template.json'
            parameter=Join-Path $script:RunDirectory 'parameters.json'
            whatIf=Join-Path $script:RunDirectory 'whatif.json'
        }
        foreach ($entry in $paths.GetEnumerator()) {
            [IO.File]::WriteAllText($entry.Value,"$($entry.Key)-approved",[Text.UTF8Encoding]::new($false))
        }
        $input = [pscustomobject][ordered]@{
            sourcePath=$paths.source;sourceDigest=(Get-FileHash $paths.source -Algorithm SHA256).Hash.ToLowerInvariant()
            templatePath=$paths.template;templateDigest=(Get-FileHash $paths.template -Algorithm SHA256).Hash.ToLowerInvariant()
            parameterPath=$paths.parameter;parameterDigest=(Get-FileHash $paths.parameter -Algorithm SHA256).Hash.ToLowerInvariant()
            whatIfPath=$paths.whatIf;whatIfDigest=(Get-FileHash $paths.whatIf -Algorithm SHA256).Hash.ToLowerInvariant()
            validationPrincipalId='33333333-3333-3333-3333-333333333333'
            deploymentName='cf-synthetic-bbbbbbbbbbbb';location='westeurope'
        }
        foreach ($name in @('source','template','parameter','whatIf')) {
            [IO.File]::WriteAllText($paths[$name],"$name-drift",[Text.UTF8Encoding]::new($false))
            $action = [pscustomobject]@{
                service='Azure';targetType='AzureSubscription';targetId=$script:Tenant.SubscriptionId
                classification='Update';action='DeployAzureFoundation';method='AZCLI'
                uri="azure://subscriptions/$($script:Tenant.SubscriptionId)"
                providerInput=$input;bodyDigest=Get-RunbookContentDigest $input
            }
            { Invoke-CloudFoundationAction -Action $action -TenantConfiguration $script:Tenant `
                -VerifiedContext $script:Context -ToolResolutions $script:Tools `
                -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
                -NativeCommandRunner { throw 'provider mutation must not execute' } `
                -WhatIfValidator { $true } } | Should -Throw '*bytes changed*'
            [IO.File]::WriteAllText($paths[$name],"$name-approved",[Text.UTF8Encoding]::new($false))
        }
        $action = [pscustomobject]@{
            service='Azure';targetType='AzureSubscription';targetId=$script:Tenant.SubscriptionId
            classification='Update';action='DeployAzureFoundation';method='AZCLI'
            uri="azure://subscriptions/$($script:Tenant.SubscriptionId)"
            providerInput=$input;bodyDigest=Get-RunbookContentDigest $input
        }
        { Invoke-CloudFoundationAction -Action $action -TenantConfiguration $script:Tenant `
            -VerifiedContext $script:Context -ToolResolutions $script:Tools `
            -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner { throw 'provider mutation must not execute' } `
            -WhatIfValidator { $false } } | Should -Throw '*what-if boundary*'
    }

    It 'rechecks effective Azure DevOps project permission before project discovery or create' {
        $input = [pscustomobject][ordered]@{
            organizationUrl='https://dev.azure.com/synthetic/';name='SyntheticProject'
            processName='Agile';processId='55555555-5555-5555-5555-555555555555'
            sourceControl='git';visibility='private'
            permissionNamespaceId='52d39943-cb85-4d7f-8fa8-c6baac873819';permissionBit=4
            permissionToken='$PROJECT:vstfs:///Classification/TeamProject/'
            subjectDescriptor='aad.synthetic-descriptor'
        }
        $action = [pscustomobject]@{
            service='AzureDevOps';targetType='AzureDevOpsProject';targetId='azuredevops://synthetic/SyntheticProject'
            classification='Create';action='CreateAzureDevOpsProject';method='AZCLI'
            uri='azuredevops://synthetic/SyntheticProject';providerInput=$input
            bodyDigest=Get-RunbookContentDigest $input
        }
        $runner = {
            param($FilePath,$ArgumentList)
            $script:Calls.Add(($ArgumentList -join ' '))
            $command=$ArgumentList -join ' '
            if ($command -like 'devops invoke *') {
                return [pscustomobject]@{exitCode=0;stdout='{"authenticatedUser":{"id":"ado-user-synthetic","subjectDescriptor":"aad.synthetic-descriptor","properties":{"Account":{"$value":"admin@example.invalid"}}}}';stderr=''}
            }
            if ($command -like 'devops security permission namespace list *') {
                return [pscustomobject]@{exitCode=0;stdout='[{"namespaceId":"52d39943-cb85-4d7f-8fa8-c6baac873819","actions":[{"bit":4,"displayName":"Create new projects"}]}]';stderr=''}
            }
            if ($command -like 'devops security permission list *') {
                return [pscustomobject]@{exitCode=0;stdout='[{"token":"$PROJECT:vstfs:///Classification/TeamProject/","acesDictionary":{"aad.synthetic-descriptor":{"allow":0,"deny":4}}}]';stderr=''}
            }
            throw "Unexpected command: $command"
        }
        { Invoke-CloudFoundationAction -Action $action -TenantConfiguration $script:Tenant `
            -VerifiedContext $script:Context -ToolResolutions $script:Tools `
            -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner } | Should -Throw '*Create new projects permission*'
        ($script:Calls -join "`n") | Should -Not -Match 'project (list|create)'
    }

    It 'deploys the exact externally validated template and parameter bytes' {
        $sourcePath=Join-Path $script:RunDirectory 'approved.bicep'
        $templatePath=Join-Path $script:RunDirectory 'approved.template.json'
        $parameterPath=Join-Path $script:RunDirectory 'approved.parameters.json'
        $whatIfPath=Join-Path $script:RunDirectory 'approved.whatif.json'
        foreach($item in @(
            @($sourcePath,'source'),@($templatePath,'template'),
            @($parameterPath,'parameters'),@($whatIfPath,'whatif')
        )){[IO.File]::WriteAllText($item[0],$item[1],[Text.UTF8Encoding]::new($false))}
        $input=[pscustomobject][ordered]@{
            sourcePath=$sourcePath;sourceDigest=(Get-FileHash $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
            templatePath=$templatePath;templateDigest=(Get-FileHash $templatePath -Algorithm SHA256).Hash.ToLowerInvariant()
            parameterPath=$parameterPath;parameterDigest=(Get-FileHash $parameterPath -Algorithm SHA256).Hash.ToLowerInvariant()
            whatIfPath=$whatIfPath;whatIfDigest=(Get-FileHash $whatIfPath -Algorithm SHA256).Hash.ToLowerInvariant()
            validationPrincipalId='33333333-3333-3333-3333-333333333333'
            deploymentName='cf-synthetic-bbbbbbbbbbbb';location='westeurope'
        }
        $action=[pscustomobject]@{
            service='Azure';targetType='AzureSubscription';targetId=$script:Tenant.SubscriptionId
            classification='Update';action='DeployAzureFoundation';method='AZCLI'
            uri="azure://subscriptions/$($script:Tenant.SubscriptionId)"
            providerInput=$input;bodyDigest=Get-RunbookContentDigest $input
        }
        $runner={
            param($FilePath,$ArgumentList)
            $script:Calls.Add([pscustomobject]@{FilePath=$FilePath;ArgumentList=$ArgumentList})
            $command=$ArgumentList -join ' '
            if($command -like 'deployment sub create *'){
                return [pscustomobject]@{exitCode=0;stdout='{"id":"deployment-id"}';stderr=''}
            }
            if($command -like 'deployment sub show *'){
                return [pscustomobject]@{exitCode=0;stdout='{"id":"deployment-id","name":"cf-synthetic-bbbbbbbbbbbb","provisioningState":"Succeeded","outputs":{}}';stderr=''}
            }
            throw "Unexpected command: $command"
        }
        $result=Invoke-CloudFoundationAction -Action $action -TenantConfiguration $script:Tenant `
            -VerifiedContext $script:Context -ToolResolutions $script:Tools `
            -RunDirectory $script:RunDirectory -RepositoryRoot $script:RepositoryRoot `
            -NativeCommandRunner $runner -WhatIfValidator { $true }
        $result.readBack.provisioningState | Should -BeExactly 'Succeeded'
        $create=($script:Calls | Where-Object { $_.ArgumentList[0] -eq 'deployment' -and $_.ArgumentList[2] -eq 'create' }).ArgumentList
        $create[[Array]::IndexOf($create,'--template-file')+1] | Should -BeExactly $templatePath
        $create[[Array]::IndexOf($create,'--parameters')+1] | Should -BeExactly "@$parameterPath"
    }
}
