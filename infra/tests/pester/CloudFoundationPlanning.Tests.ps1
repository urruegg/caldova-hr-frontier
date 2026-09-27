Set-StrictMode -Version Latest

Describe 'Cloud foundation planning' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
        $script:Assessment = Get-Content -Raw (Join-Path $PSScriptRoot '..\fixtures\runbooks\cloud-assessment.json') | ConvertFrom-Json
        $script:Tenant = [pscustomobject]@{
            TenantAlias='synthetic'
            TenantId='22222222-2222-2222-2222-222222222222'
            SubscriptionId='11111111-1111-1111-1111-111111111111'
            Components=[pscustomobject]@{
                GitHubRepository=[pscustomobject]@{Mode='Existing';Id='67890'}
                GitHubEnvironment=[pscustomobject]@{Mode='Create'}
                EntraApplication=[pscustomobject]@{Mode='Create'}
                EntraServicePrincipal=[pscustomobject]@{Mode='Create'}
                EntraFederatedIdentityCredential=[pscustomobject]@{Mode='Create'}
                AzureSubscription=[pscustomobject]@{Mode='Existing';Id='11111111-1111-1111-1111-111111111111'}
                AzureDevOpsProject=[pscustomobject]@{Mode='Create'}
                AzureDevOpsServicePrincipalEntitlement=[pscustomobject]@{Mode='Create'}
                PowerPlatformEnvironmentDev=[pscustomobject]@{Mode='Existing';Id='pp-env-dev-synthetic'}
                PowerPlatformEnvironmentTest=[pscustomobject]@{Mode='Existing';Id='pp-env-test-synthetic'}
                PowerPlatformEnvironmentProd=[pscustomobject]@{Mode='Existing';Id='pp-env-prod-synthetic'}
            }

        }
    }

    It 'provides the read-only digest-bound cloud plan entry point' {
        $path = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Get-CloudFoundationPlan.ps1'
        Test-Path -LiteralPath $path | Should -BeTrue
        $command = Get-Command $path
        @($command.Parameters.Keys) | Should -Contain 'TenantAlias'
        @($command.Parameters.Keys) | Should -Contain 'ReportPath'
        @($command.Parameters.Keys) | Should -Contain 'Stages'
        @($command.Parameters.Keys) | Should -Not -Contain 'Apply'
    }

    It 'maps exact IDs, supported drift, manual surfaces, and exclusions to the closed classification set' {
        $plan = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
        ($plan.actions | Where-Object targetType -eq 'GitHubRepository').classification | Should -BeExactly 'NoChange'
        ($plan.actions | Where-Object targetType -eq 'GitHubEnvironment').classification | Should -BeExactly 'Blocked'
        ($plan.actions | Where-Object targetType -eq 'EntraFederatedIdentityCredential').classification | Should -BeExactly 'Blocked'
        ($plan.actions | Where-Object targetType -eq 'PowerPlatformEnvironmentDev').classification | Should -BeExactly 'Manual'
        @($plan.actions | Where-Object { $_.classification -cnotin @('NoChange','Create','Update','Manual','Blocked','Refused') }).Count | Should -Be 0
    }

    It 'automates only reviewed digest-bound provider actions' {
        $plan = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
        @($plan.actions | Where-Object classification -in @('Create','Update') | ForEach-Object action | Sort-Object) |
            Should -Be @('CreateAzureDevOpsProject','CreateEntraTargetApplication','DeployAzureFoundation','UpsertGitHubNonActionsRuleset')
        foreach ($action in $plan.actions) {
            $manifest = $plan.manifestActions | Where-Object {
                $_.action -ceq $action.action -and $_.targetId -ceq $action.targetId
            } | Select-Object -First 1
            if ($action.classification -in @('Create','Update')) {
                $manifest.bodyDigest | Should -Match '^[0-9a-f]{64}$'
            } else {
                $manifest.PSObject.Properties.Name | Should -Not -Contain 'bodyDigest'
            }
        }

    }

    It 'emits a service-principal create only from an exact application and proven appId absence' {
        $assessment = $script:Assessment | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        $assessment.services.entra.application = [pscustomobject]@{
            state='Exact';targetId='app-object-id';applicationExactNameMatchCount=1
            appId='44444444-4444-4444-4444-444444444444'
            providerInput=[pscustomobject]@{displayName='Synthetic Target App'}
        }
        $assessment.services.entra.servicePrincipal = [pscustomobject]@{
            state='Missing';targetId='44444444-4444-4444-4444-444444444444'
            servicePrincipalExactAppIdMatchCount=0
            providerInput=[pscustomobject]@{appId='44444444-4444-4444-4444-444444444444'}
        }
        $plan = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $assessment
        ($plan.actions | Where-Object action -eq 'CreateEntraTargetServicePrincipal').classification |
            Should -BeExactly 'Create'
    }

    It 'classifies a proven missing non-Actions ruleset as POST Create' {
        $assessment = $script:Assessment | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        $assessment.services.github.ruleset.state='Missing'
        $assessment.services.github.ruleset.id='main'
        $assessment.services.github.ruleset.uri='repos/synthetic-owner/synthetic-repository/rulesets'
        $plan=New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $assessment
        $action=$plan.actions | Where-Object targetType -eq 'GitHubRuleset'
        $action.classification | Should -BeExactly 'Create'
        $action.method | Should -BeExactly 'POST'
    }

    It 'is deterministic and emits exact planning manual item fields' {
        $first = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
        $second = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
        (Get-RunbookContentDigest $first) | Should -BeExactly (Get-RunbookContentDigest $second)
        foreach ($item in $script:Assessment.manualItems) {
            @($item.PSObject.Properties.Name) |
                Should -Be @('service','targetId','condition','owner','diagnostic','recovery')
        }
    }

    It 'feeds an eligible live assessment into the planner without fixture-shape translation' {
        $runDirectory = Join-Path $TestDrive 'live-assessment'
        New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
        $sourcePath = Join-Path $runDirectory 'main.bicep'
        [IO.File]::WriteAllText($sourcePath, "targetScope = 'subscription'`n", [Text.UTF8Encoding]::new($false))
        $rulesetInput = [pscustomobject][ordered]@{
            name='Synthetic non-Actions protection';target='branch';enforcement='active'
            conditions=[pscustomobject]@{ref_name=[pscustomobject]@{include=@('~DEFAULT_BRANCH');exclude=@()}}
            rules=@([pscustomobject]@{type='deletion'},[pscustomobject]@{type='non_fast_forward'})
            bypass_actors=@()
        }
        $tenant = [pscustomobject]@{
            TenantAlias='synthetic';TenantId='22222222-2222-2222-2222-222222222222'
            SubscriptionId='11111111-1111-1111-1111-111111111111';DisplayName='Synthetic'
            AdminUpn='admin@example.invalid'
            GitHub=[pscustomobject]@{Owner='synthetic-owner';Repository='synthetic-repository';RepositoryId='67890'}
            AzureDevOps=[pscustomobject]@{OrganizationUrl='https://dev.azure.com/synthetic/';ProjectName='SyntheticProject';ProcessName='Agile';Visibility='private'}
            PrimaryLocation='westeurope';NamingRoot='syn-hr-agentic-abc123'
            Components=[pscustomobject]@{
                EntraApplication=[pscustomobject]@{Mode='Create';Id=$null}
                EntraServicePrincipal=[pscustomobject]@{Mode='Existing';Id='33333333-3333-3333-3333-333333333333'}
            }
            CloudFoundation=[pscustomobject]@{
                SourceBicepPath=$sourcePath;GitHubRuleset=$rulesetInput
                EntraApplicationDisplayName='Synthetic target application'
                ValidationPrincipalId='33333333-3333-3333-3333-333333333333'
            }
        }
        $context = [pscustomobject]@{
            overallStatus='Verified'
            tenantAlias=$tenant.TenantAlias
            verifiedAtUtc='2026-09-26T11:59:00Z'
            azure=[pscustomobject]@{tenantId=$tenant.TenantId;subscriptionId=$tenant.SubscriptionId;userType='user'}
            entra=[pscustomobject]@{activeDirectoryRoleTemplateIds=@('cf1c38e5-3621-4004-a7cb-879624dced7c')}
            azureDevOps=[pscustomobject]@{
                projectIntent='Create';exactNameMatchCount=0;createProjectPermission='Allowed'
                organizationUrl=$tenant.AzureDevOps.OrganizationUrl;actingUserId='ado-user-synthetic'
                subjectDescriptor='aad.synthetic-descriptor'
                createProjectPermissionBit=4
                createProjectPermissionNamespaceId='52d39943-cb85-4d7f-8fa8-c6baac873819'
                createProjectPermissionToken='$PROJECT:vstfs:///Classification/TeamProject/'
            }
        }
        $tools = [pscustomobject]@{}
        foreach ($name in @('az','gh','pac','git')) {
            $tools | Add-Member NoteProperty $name ([pscustomobject]@{
                name=$name;path="C:\SyntheticTools\$name.cmd";version='1.0.0'
                sha256=('a' * 64)
            })
        }
        $runner = {
            param($FilePath,$ArgumentList)
            $command = $ArgumentList -join ' '
            if ($command -eq 'api repos/synthetic-owner/synthetic-repository') {
                return [pscustomobject]@{exitCode=0;stdout='{"id":67890,"name":"synthetic-repository"}';stderr=''}
            }
            if ($command -eq 'api repos/synthetic-owner/synthetic-repository/rulesets') {
                return [pscustomobject]@{exitCode=0;stdout='[{"id":321,"name":"Synthetic non-Actions protection","enforcement":"disabled"}]';stderr=''}
            }
            if ($command -eq 'api repos/synthetic-owner/synthetic-repository/rulesets/321') {
                return [pscustomobject]@{exitCode=0;stdout='{"id":321,"name":"Synthetic non-Actions protection","target":"branch","enforcement":"disabled","conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"rules":[{"type":"deletion"},{"type":"non_fast_forward"}],"bypass_actors":[]}';stderr=''}
            }
            if ($command -like 'devops process list *') {
                return [pscustomobject]@{exitCode=0;stdout='[{"id":"55555555-5555-5555-5555-555555555555","name":"Agile"}]';stderr=''}
            }
            if ($command -like 'devops invoke *') {
                return [pscustomobject]@{exitCode=0;stdout='{"authenticatedUser":{"id":"ado-user-synthetic","subjectDescriptor":"aad.synthetic-descriptor","properties":{"Account":{"$value":"admin@example.invalid"}}}}';stderr=''}
            }
            if ($command -like 'devops security permission namespace list *') {
                return [pscustomobject]@{exitCode=0;stdout='[{"namespaceId":"52d39943-cb85-4d7f-8fa8-c6baac873819","actions":[{"bit":4,"displayName":"Create new projects"}]}]';stderr=''}
            }
            if ($command -like 'devops security permission list *') {
                return [pscustomobject]@{exitCode=0;stdout='[{"token":"$PROJECT:vstfs:///Classification/TeamProject/","acesDictionary":{"aad.synthetic-descriptor":{"allow":4,"deny":0}}}]';stderr=''}
            }
            if ($command -like 'ad app list --display-name *') {
                return [pscustomobject]@{exitCode=0;stdout='[]';stderr=''}
            }
            if ($command -like 'ad sp show --id *') {
                return [pscustomobject]@{exitCode=0;stdout='{"id":"33333333-3333-3333-3333-333333333333","appId":"44444444-4444-4444-4444-444444444444"}';stderr=''}
            }
            if ($command -eq 'bicep format --help') {
                return [pscustomobject]@{exitCode=0;stdout='Usage: az bicep format --file PATH --stdout';stderr=''}
            }
            if ($command -like 'bicep format --file * --stdout') {
                return [pscustomobject]@{exitCode=0;stdout=(Get-Content -Raw -LiteralPath $ArgumentList[3]);stderr=''}
            }
            if ($command -like 'bicep build *') {
                $outputIndex = [Array]::IndexOf($ArgumentList,'--outfile')
                [IO.File]::WriteAllText($ArgumentList[$outputIndex + 1], "{`"resources`":[]}`n", [Text.UTF8Encoding]::new($false))
                return [pscustomobject]@{exitCode=0;stdout='';stderr=''}
            }
            if ($command -like 'deployment sub what-if *') {
                return [pscustomobject]@{exitCode=0;stdout='{"status":"Accepted","properties":{"changes":[]}}';stderr=''}
            }
            if ($command -eq 'rev-parse HEAD') {
                return [pscustomobject]@{exitCode=0;stdout=('b' * 40);stderr=''}
            }
            throw "Unexpected command: $command"
        }

        $assessment = Get-CloudFoundationAssessment -TenantConfiguration $tenant `
            -VerifiedContext $context -ToolResolutions $tools -RunDirectory $runDirectory `
            -NativeCommandRunner $runner -WhatIfValidator { param($Path) $true } `
            -NowUtc ([datetime]'2026-09-26T12:00:00Z')
        $staleContext=$context.PSObject.Copy()
        $staleContext.verifiedAtUtc='2026-09-26T11:54:59Z'
        { Get-CloudFoundationAssessment -TenantConfiguration $tenant -VerifiedContext $staleContext `
            -ToolResolutions $tools -RunDirectory $runDirectory -NativeCommandRunner $runner `
            -WhatIfValidator { $true } -NowUtc ([datetime]'2026-09-26T12:00:00Z') } |
            Should -Throw '*older than five minutes*'
        $plan = New-CloudFoundationActionPlan -TenantConfiguration $tenant -Assessment $assessment

        $assessment.services.azure.reason | Should -BeExactly ''
        @($plan.actions | Where-Object classification -in @('Create','Update') | ForEach-Object action | Sort-Object) |
            Should -Be @('CreateAzureDevOpsProject','CreateEntraTargetApplication','DeployAzureFoundation','UpsertGitHubNonActionsRuleset')
        $assessment.services.github.ruleset.providerInput | Should -Be $rulesetInput
        foreach ($name in @('sourceDigest','templateDigest','parameterDigest','whatIfDigest')) {
            [string]$assessment.services.azure.providerInput.$name | Should -Match '^[0-9a-f]{64}$'
        }
        Test-Path (Join-Path (Split-Path -Parent $sourcePath) 'main.json') | Should -BeFalse
        $assessment.services.azureDevOps.providerInput.permissionBit | Should -Be 4
        $assessment.overallStatus | Should -BeExactly 'Ready'

        foreach ($permissionCase in @(
            @{Name='Denied';Payload='[{"token":"$PROJECT:vstfs:///Classification/TeamProject/","acesDictionary":{"aad.synthetic-descriptor":{"allow":0,"deny":4}}}]';ExitCode=0},
            @{Name='Unavailable';Payload='';ExitCode=1},
            @{Name='Ambiguous';Payload='[{"token":"$PROJECT:vstfs:///Classification/TeamProject/","acesDictionary":{"aad.synthetic-descriptor":{"allow":4,"deny":0}}},{"token":"$PROJECT:vstfs:///Classification/TeamProject/","acesDictionary":{"aad.synthetic-descriptor":{"allow":4,"deny":0}}}]';ExitCode=0}
        )) {
            $baseRunner=$runner;$currentCase=$permissionCase
            $permissionRunner={
                param($FilePath,$ArgumentList)
                if(($ArgumentList -join ' ') -like 'devops security permission list *'){
                    return [pscustomobject]@{exitCode=$currentCase.ExitCode;stdout=$currentCase.Payload;stderr='unavailable'}
                }
                & $baseRunner $FilePath $ArgumentList
            }.GetNewClosure()
            $blockedAssessment = Get-CloudFoundationAssessment -TenantConfiguration $tenant `
                -VerifiedContext $context -ToolResolutions $tools -RunDirectory $runDirectory `
                -NativeCommandRunner $permissionRunner -WhatIfValidator { param($Path) $true } `
                -NowUtc ([datetime]'2026-09-26T12:00:00Z')
            $blockedPlan = New-CloudFoundationActionPlan -TenantConfiguration $tenant -Assessment $blockedAssessment
            $blockedAssessment.services.azureDevOps.state | Should -BeExactly 'Blocked'
            @($blockedPlan.actions | Where-Object action -eq 'CreateAzureDevOpsProject').Count | Should -Be 0
        }

        $baseRunner=$runner
        $withoutFormatRunner={
            param($FilePath,$ArgumentList)
            $command=$ArgumentList -join ' '
            if($command -eq 'bicep format --help'){
                return [pscustomobject]@{exitCode=0;stdout='Usage: az bicep format --file PATH';stderr=''}
            }
            if($command -like 'bicep format --file *'){throw 'stdout-only format must be omitted'}
            & $baseRunner $FilePath $ArgumentList
        }.GetNewClosure()
        $withoutFormat=Get-CloudFoundationAssessment -TenantConfiguration $tenant `
            -VerifiedContext $context -ToolResolutions $tools -RunDirectory $runDirectory `
            -NativeCommandRunner $withoutFormatRunner -WhatIfValidator { param($Path) $true } `
            -NowUtc ([datetime]'2026-09-26T12:00:00Z')
        $withoutFormat.services.azure.state | Should -BeExactly 'Drift'

        foreach($failure in @(
            @{Command='ad app list --display-name Synthetic target application --output json';Service='entra'},
            @{Command='api repos/synthetic-owner/synthetic-repository/rulesets';Service='github'}
        )){
            $baseRunner=$runner;$currentFailure=$failure
            $failureRunner={
                param($FilePath,$ArgumentList)
                if(($ArgumentList -join ' ') -eq $currentFailure.Command){
                    return [pscustomobject]@{exitCode=1;stdout='';stderr='unavailable'}
                }
                & $baseRunner $FilePath $ArgumentList
            }.GetNewClosure()
            $failedAssessment=Get-CloudFoundationAssessment -TenantConfiguration $tenant `
                -VerifiedContext $context -ToolResolutions $tools -RunDirectory $runDirectory `
                -NativeCommandRunner $failureRunner -WhatIfValidator { param($Path) $true } `
                -NowUtc ([datetime]'2026-09-26T12:00:00Z')
            if($failure.Service -eq 'entra'){
                $failedAssessment.services.entra.application.state | Should -BeExactly 'Blocked'
            }else{
                $failedAssessment.services.github.ruleset.state | Should -BeExactly 'Blocked'
            }
            $failedAssessment.overallStatus | Should -BeExactly 'Blocked'
        }
    }
}
