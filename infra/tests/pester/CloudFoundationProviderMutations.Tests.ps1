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
}
