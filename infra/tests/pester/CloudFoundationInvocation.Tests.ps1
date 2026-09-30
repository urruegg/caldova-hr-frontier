Set-StrictMode -Version Latest

Describe 'Cloud foundation invocation' {
    BeforeAll {
        $script:InvokeScript = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Invoke-CloudFoundation.ps1'
    }

    It 'provides explicit Apply, exact digest, and ShouldProcess controls' {
        Test-Path -LiteralPath $script:InvokeScript | Should -BeTrue
        $command = Get-Command $script:InvokeScript
        @($command.Parameters.Keys) | Should -Contain 'Apply'
        @($command.Parameters.Keys) | Should -Contain 'ApprovedDigest'
        @($command.Parameters.Keys) | Should -Contain 'WhatIf'
        @($command.Parameters.Keys) | Should -Contain 'Confirm'
    }

    It 'requires Apply before reading a manifest or invoking a provider' {
        { & $script:InvokeScript -TenantAlias synthetic `
            -ExecutionManifestPath 'C:\absent\manifest.json' `
            -AssessmentPath 'C:\absent\assessment.json' `
            -ApprovedDigest ('a' * 64) } | Should -Throw '*explicit -Apply*'
    }

    It 'contains exact drift revalidation, context, ShouldProcess, and recovery gates' {
        $content = Get-Content -Raw -LiteralPath $script:InvokeScript
        $content | Should -Match 'Assert-ApprovedCloudToolResolutions'
        $content | Should -Match 'Test-RunbookExecutionManifest'
        $content | Should -Match 'CurrentSourceCommit'
        $content | Should -Match 'CurrentAssessmentDigest'
        $content | Should -Match 'CurrentAuthenticationContext'
        $content | Should -Match '\$PSCmdlet\.ShouldProcess'
        $content | Should -Match 'Test-CloudDelegatedContext'
        $content | Should -Match 'Invoke-CloudFoundationAction'
        $content | Should -Match 'PartialMutation'
        $content | Should -Match 'requiresNewApproval'
        $content | Should -Not -Match 'Expected(SourceCommit|AssessmentDigest|Authentication)'
    }

    It 'stops on Azure DevOps permission drift before dispatching any approved mutation' {
        $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $modulePath = Join-Path $repositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $modulePath -Force
        $tenantPath = Join-Path $TestDrive 'tenant.psd1'
        $tenantText = @'
@{
    SchemaVersion = '1.0'
    TenantAlias = 'caldova25156897'
    DisplayName = 'Synthetic Tenant'
    TenantId = '22222222-2222-2222-2222-222222222222'
    AdminUpn = 'admin@synthetic.example'
    SubscriptionId = '11111111-1111-1111-1111-111111111111'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'syn'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'abc123'
    NamingRoot = 'syn-hr-agentic-abc123'
    LifecycleState = 'IntentReviewed'
    GitHub = @{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = 'bootstrap-caldova25156897'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://dev.azure.com/synthetic/'
        ProjectName = 'Synthetic HR Frontier'
    }
    PowerPlatform = @{
        DevUrl = 'https://syntheticdev.crm17.dynamics.com/'
        TestUrl = 'https://synthetictest.crm17.dynamics.com/'
        ProdUrl = 'https://synthetic.crm17.dynamics.com/'
    }
    Components = @{
        GitHubRepository = @{ Mode = 'Existing'; Id = '1371297722' }
        GitHubEnvironment = @{ Mode = 'Create' }
        EntraApplication = @{ Mode = 'Create' }
        EntraServicePrincipal = @{ Mode = 'Create' }
        EntraFederatedIdentityCredential = @{ Mode = 'Create' }
        AzureSubscription = @{ Mode = 'Existing'; Id = '11111111-1111-1111-1111-111111111111' }
        AzureDevOpsProject = @{ Mode = 'Create' }
        AzureDevOpsServicePrincipalEntitlement = @{ Mode = 'Create' }
        PowerPlatformEnvironmentDev = @{ Mode = 'Existing'; Id = 'pp-env-dev-synthetic' }
        PowerPlatformEnvironmentTest = @{ Mode = 'Existing'; Id = 'pp-env-test-synthetic' }
        PowerPlatformEnvironmentProd = @{ Mode = 'Existing'; Id = 'pp-env-prod-synthetic' }
    }
}
'@
        [IO.File]::WriteAllText($tenantPath,$tenantText,[Text.UTF8Encoding]::new($false))
        $tenant = Import-TenantConfiguration -Path $tenantPath -ValidationStage Bootstrap
        $runDirectory = Join-Path $TestDrive 'invoke'
        [IO.Directory]::CreateDirectory($runDirectory) | Out-Null
        $toolPaths=[ordered]@{}
        foreach($name in @('az','gh','pac','git')) {
            $path=Join-Path $runDirectory "$name.cmd"
            [IO.File]::WriteAllText($path,"@echo 1.0.0`r`n",[Text.ASCIIEncoding]::new())
            $toolPaths[$name]=$path
        }
        $resolver = {
            param($name)
            [pscustomobject]@{Source=$toolPaths[$name]}
        }.GetNewClosure()
        $tools=[ordered]@{}
        foreach($name in $toolPaths.Keys) {
            $tools[$name]=Resolve-CloudNativeTool -Name $name -ApplicationResolver $resolver
        }
        $assessment=[pscustomobject]@{
            schemaVersion='1.0';tenantAlias=$tenant.TenantAlias
            assessedAtUtc='2026-09-26T12:00:00Z';contextDigest=('1'*64)
            services=[pscustomobject]@{
                github=[pscustomobject]@{repository=[pscustomobject]@{
                    state='Exact';id=$tenant.GitHub.RepositoryId
                    uri="repos/$($tenant.GitHub.Owner)/$($tenant.GitHub.Repository)"
                }}
                azure=[pscustomobject]@{state='Blocked';targetId=$tenant.SubscriptionId;reason='prerequisite';providerInput=$null}
                entra=[pscustomobject]@{
                    application=[pscustomobject]@{state='Blocked';targetId='app';applicationExactNameMatchCount=0;providerInput=$null}
                    servicePrincipal=[pscustomobject]@{state='Blocked';targetId='sp';servicePrincipalExactAppIdMatchCount=0;providerInput=$null}
                }
                azureDevOps=[pscustomobject]@{
                    state='Missing';projectIntent='Create';targetId='azuredevops://project'
                    providerInput=[pscustomobject][ordered]@{
                        organizationUrl=$tenant.AzureDevOps.OrganizationUrl;name=$tenant.AzureDevOps.ProjectName
                        processName='Agile';processId='55555555-5555-5555-5555-555555555555'
                        sourceControl='git';visibility='private'
                        permissionNamespaceId='52d39943-cb85-4d7f-8fa8-c6baac873819';permissionBit=4
                        permissionToken='$PROJECT:vstfs:///Classification/TeamProject/'
                        subjectDescriptor='aad.synthetic-descriptor'
                    }
                }
            }
            permissionDelta=@();manualItems=@();blockedItems=@();toolVersions=[pscustomobject]$tools
            repositoryRoot=$repositoryRoot;sourceCommit=('b'*40)
            overallStatus='Ready';assessmentDigest=('c'*64)
        }
        $plan=New-CloudFoundationActionPlan -TenantConfiguration $tenant -Assessment $assessment
        $authentication=[pscustomobject][ordered]@{
            executionHost='InteractiveWindows11PowerShell';mode='AzureCliDelegatedContext'
            accountId='azure-user';tenantId=$tenant.TenantId;subscriptionId=$tenant.SubscriptionId
            githubHost='github.com';githubLogin='synthetic-admin'
            azureDevOpsOrganizationUrl=$tenant.AzureDevOps.OrganizationUrl
            azureDevOpsActingUserId='ado-user-synthetic'
        }
        $now=[datetime]'2026-09-26T12:00:00Z'
        $manifest=New-RunbookExecutionManifest -RunId ([guid]::NewGuid()) -Kind CloudFoundation `
            -TargetStableId $tenant.TenantId -SourceCommit $assessment.sourceCommit `
            -AssessmentDigest $assessment.assessmentDigest -AuthenticationContext $authentication `
            -AllowedActions $plan.manifestActions -ToolVersions ([pscustomobject]$tools) -GeneratedAtUtc $now
        $manifestPath=Join-Path $runDirectory 'execution-manifest.json'
        $assessmentPath=Join-Path $runDirectory 'assessment.json'
        Write-CanonicalJson $manifest $manifestPath | Out-Null
        Write-CanonicalJson $assessment $assessmentPath | Out-Null
        $reloadedAssessment=Get-Content -Raw $assessmentPath | ConvertFrom-Json
        $reloadedPlan=New-CloudFoundationActionPlan -TenantConfiguration $tenant -Assessment $reloadedAssessment
        @($reloadedPlan.manifestActions | ForEach-Object {"$($_.action)|$($_.targetId)"}) |
            Should -Be @($manifest.allowedActions | ForEach-Object {"$($_.action)|$($_.targetId)"})
        (Get-RunbookContentDigest $reloadedPlan.manifestActions) |
            Should -BeExactly (Get-RunbookContentDigest $manifest.allowedActions)
        $calls=[Collections.Generic.List[string]]::new()
        $sourceState=[pscustomobject]@{commit=$assessment.sourceCommit}
        $runner={
            param($FilePath,$ArgumentList)
            $command=$ArgumentList -join ' ';$calls.Add($command)
            if($command -eq 'account show --output json'){return [pscustomobject]@{exitCode=0;stdout=("{`"id`":`"$($tenant.SubscriptionId)`",`"tenantId`":`"$($tenant.TenantId)`",`"user`":{`"type`":`"user`"}}");stderr=''}}
            if($command -eq 'ad signed-in-user show --output json'){return [pscustomobject]@{exitCode=0;stdout=("{`"id`":`"azure-user`",`"userPrincipalName`":`"$($tenant.AdminUpn)`"}");stderr=''}}
            if($command -like 'rest --method get *'){return [pscustomobject]@{exitCode=0;stdout='{"value":[]}';stderr=''}}
            if($command -eq 'auth status --hostname github.com'){return [pscustomobject]@{exitCode=0;stdout='account synthetic-admin';stderr=''}}
            if($command -eq 'api user'){return [pscustomobject]@{exitCode=0;stdout='{"id":123,"login":"synthetic-admin"}';stderr=''}}
            if($command -eq "api repos/$($tenant.GitHub.Owner)/$($tenant.GitHub.Repository)"){return [pscustomobject]@{exitCode=0;stdout=("{`"id`":$($tenant.GitHub.RepositoryId),`"full_name`":`"$($tenant.GitHub.Owner)/$($tenant.GitHub.Repository)`",`"permissions`":{`"admin`":true}}");stderr=''}}
            if($command -like 'devops invoke *'){return [pscustomobject]@{exitCode=0;stdout=("{`"authenticatedUser`":{`"id`":`"ado-user-synthetic`",`"subjectDescriptor`":`"aad.synthetic-descriptor`",`"properties`":{`"Account`":{`"`$value`":`"$($tenant.AdminUpn)`"}}}}");stderr=''}}
            if($command -like 'devops project list *'){return [pscustomobject]@{exitCode=0;stdout='[]';stderr=''}}
            if($command -like 'devops security permission namespace list *'){return [pscustomobject]@{exitCode=0;stdout='[{"namespaceId":"52d39943-cb85-4d7f-8fa8-c6baac873819","actions":[{"bit":4,"displayName":"Create new projects"}]}]';stderr=''}}
            if($command -like 'devops security permission list *'){return [pscustomobject]@{exitCode=0;stdout='[{"token":"$PROJECT:vstfs:///Classification/TeamProject/","acesDictionary":{"aad.synthetic-descriptor":{"allow":0,"deny":4}}}]';stderr=''}}
            if($command -eq 'auth list --json'){return [pscustomobject]@{exitCode=0;stdout='[{"name":"hr-caldova25156897-dev","selected":true}]';stderr=''}}
            if($command -like 'org who *'){return [pscustomobject]@{exitCode=0;stdout=("{`"environmentUrl`":`"$($tenant.PowerPlatform.DevUrl)`",`"environmentId`":`"$($tenant.Components.PowerPlatformEnvironmentDev.Id)`",`"user`":`"$($tenant.AdminUpn)`"}");stderr=''}}
            if($command -eq "-C $repositoryRoot rev-parse HEAD"){return [pscustomobject]@{exitCode=0;stdout=$sourceState.commit;stderr=''}}
            throw "Unexpected command: $command"
        }.GetNewClosure()

        $otherCwd=Join-Path $TestDrive 'different-caller-repository'
        [IO.Directory]::CreateDirectory($otherCwd) | Out-Null
        Push-Location $otherCwd
        try {
            { & $script:InvokeScript -TenantAlias $tenant.TenantAlias -TenantConfigurationPath $tenantPath `
                -ExecutionManifestPath $manifestPath -AssessmentPath $assessmentPath -ReportPath $runDirectory `
                -ApprovedDigest $manifest.digest -Stages DEV -Apply -Confirm:$false `
                -NativeToolResolver $resolver -NativeCommandRunner $runner `
                -InteractiveHostProbe { [pscustomobject]@{isInteractive=$true;platform='Windows 11'} } -NowUtc $now } |
                Should -Throw '*permission changed before Apply*'
        }
        finally { Pop-Location }
        ($calls -join "`n") | Should -Not -Match '(api --method (PUT|POST|PATCH|DELETE)|ad app create|deployment sub create|devops project create)'
        $calls | Should -Contain "-C $repositoryRoot rev-parse HEAD"

        $assessment.repositoryRoot='C:\different-repository'
        Write-CanonicalJson $assessment $assessmentPath -Replace | Out-Null
        { & $script:InvokeScript -TenantAlias $tenant.TenantAlias -TenantConfigurationPath $tenantPath `
            -ExecutionManifestPath $manifestPath -AssessmentPath $assessmentPath -ReportPath $runDirectory `
            -ApprovedDigest $manifest.digest -Stages DEV -Apply -Confirm:$false `
            -NativeToolResolver $resolver -NativeCommandRunner $runner `
            -InteractiveHostProbe { [pscustomobject]@{isInteractive=$true;platform='Windows 11'} } -NowUtc $now } |
            Should -Throw '*repository root*'

        $assessment.repositoryRoot=$repositoryRoot
        Write-CanonicalJson $assessment $assessmentPath -Replace | Out-Null
        $sourceState.commit=('d'*40)
        { & $script:InvokeScript -TenantAlias $tenant.TenantAlias -TenantConfigurationPath $tenantPath `
            -ExecutionManifestPath $manifestPath -AssessmentPath $assessmentPath -ReportPath $runDirectory `
            -ApprovedDigest $manifest.digest -Stages DEV -Apply -Confirm:$false `
            -NativeToolResolver $resolver -NativeCommandRunner $runner `
            -InteractiveHostProbe { [pscustomobject]@{isInteractive=$true;platform='Windows 11'} } -NowUtc $now } |
            Should -Throw '*source commit*'
    }
}
