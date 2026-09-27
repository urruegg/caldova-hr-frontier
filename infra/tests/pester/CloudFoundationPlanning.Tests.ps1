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

    It 'is deterministic and emits exact planning manual item fields' {
        $first = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
        $second = New-CloudFoundationActionPlan -TenantConfiguration $script:Tenant -Assessment $script:Assessment
        (Get-RunbookContentDigest $first) | Should -BeExactly (Get-RunbookContentDigest $second)
        foreach ($item in $script:Assessment.manualItems) {
            @($item.PSObject.Properties.Name) |
                Should -Be @('service','targetId','condition','owner','diagnostic','recovery')
        }
    }
}
