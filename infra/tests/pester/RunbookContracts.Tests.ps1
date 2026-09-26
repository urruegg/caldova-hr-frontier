Set-StrictMode -Version Latest

Describe 'Shared runbook output contracts' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
    }

    Describe 'Execution manifest integrity' {
        It 'binds approval to normalized actions source and assessment' {
            $manifest = New-RunbookExecutionManifest `
                -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
                -Kind Workstation `
                -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
                -SourceCommit ('a' * 40) `
                -AssessmentDigest ('b' * 64) `
                -AuthenticationContext ([pscustomobject]@{
                    executionHost = 'InteractiveWindows11PowerShell'
                    mode = 'NotRequired'
                }) `
                -AllowedActions @([pscustomobject]@{
                    action = 'WinGetInstallExact'
                    targetId = 'Git.Git'
                    packageSource = 'winget'
                    packageId = 'Git.Git'
                    scope = 'machine'
                    expectedPostcondition = 'git.exe resolves and git --version exits 0'
                }) `
                -ToolVersions ([ordered]@{ PowerShell7 = '7.5.3' }) `
                -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')

            $manifest.digest | Should -Match '^[0-9a-f]{64}$'
            Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $manifest.digest `
                -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
                -CurrentAuthenticationContext ([pscustomobject]@{
                    executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                }) `
                -AllowedActionNames @('WinGetInstallExact') `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') | Should -BeTrue

            { Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest ('c' * 64) `
                -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
                -CurrentAuthenticationContext ([pscustomobject]@{
                    executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                }) `
                -AllowedActionNames @('WinGetInstallExact') } |
                Should -Throw '*approved digest*'
        }

        It 'refuses stale manifests and unrecognized action properties' {
            $manifest = New-RunbookExecutionManifest -RunId ([guid]::NewGuid()) -Kind Workstation `
                -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
                -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
                -AuthenticationContext ([pscustomobject]@{
                    executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                }) `
                -AllowedActions @([pscustomobject]@{ action = 'InstallPesterExact'; targetId = 'Pester' }) `
                -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T04:00:00Z')
            $manifest.allowedActions[0] | Add-Member NoteProperty arguments '--force'
            { Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $manifest.digest `
                -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
                -CurrentAuthenticationContext ([pscustomobject]@{
                    executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                }) `
                -AllowedActionNames @('InstallPesterExact') `
                -NowUtc ([datetime]'2026-09-26T05:00:00Z') } | Should -Throw
        }

        It 'rejects a retargeted or duplicate action manifest even when its digest is recomputed' {
                $manifest = New-RunbookExecutionManifest -RunId ([guid]::NewGuid()) -Kind Workstation `
                    -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
                    -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
                    -AuthenticationContext ([pscustomobject]@{
                        executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                    }) `
                    -AllowedActions @([pscustomobject]@{
                        action = 'InstallPesterExact'; targetId = 'Pester'
                    }) -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')
                $manifest.target.type = 'CloudFoundation'
                $manifest.allowedActions = @($manifest.allowedActions[0], $manifest.allowedActions[0])
                $unsigned = [ordered]@{}
                foreach ($property in $manifest.PSObject.Properties.Name | Where-Object { $_ -ne 'digest' }) {
                    $unsigned[$property] = $manifest.$property
                }
                $manifest.digest = Get-RunbookContentDigest -InputObject $unsigned

                { Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $manifest.digest `
                    -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
                    -CurrentAuthenticationContext ([pscustomobject]@{
                        executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                    }) -AllowedActionNames @('InstallPesterExact') `
                    -NowUtc ([datetime]'2026-09-26T05:10:00Z') } | Should -Throw
        }

        It 'never copies arbitrary input into evidence' {
            $record = ConvertTo-RunbookEvidenceRecord -RunId ([guid]::NewGuid()) `
                -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z') -SourceCommit ('a' * 40) `
                -AssessmentDigest ('b' * 64) -PlanDigest ('c' * 64) -ManifestDigest ('d' * 64) `
                -OperatorId 'synthetic-operator' -ShouldProcessDecision NotApplicable `
                -Operation 'AssessTool' -Classification Refused -Status Refused `
                -TargetId 'AzureCli' -ErrorCategory 'ContextMismatch' `
                -ToolVersions ([ordered]@{ PowerShell7 = '7.5.3' }) `
                -ReadBack ([pscustomobject]@{
                    status = 'Failed'; resourceId = '/subscriptions/synthetic/resourceGroups/rg'
                    provisioningState = 'Failed'; bodyDigest = ('e' * 64)
                }) `
                -ManualItems @([pscustomobject]@{
                    service = 'Azure'; targetId = 'synthetic-target'; condition = 'PermissionDenied'
                    owner = 'Cloud service owner'; diagnostic = 'RoleNotActive'
                    recovery = 'Activate the approved role and generate a new plan.'
                }) `
                -RecoveryItems @([pscustomobject]@{
                    service = 'Azure'; targetId = 'synthetic-target'; lastProvenState = 'NotCreated'
                    safeDiagnostic = 'RoleNotActive'; owner = 'Cloud service owner'
                    nextAction = 'Activate the approved role and reassess.'
                    requiresNewPlan = $true; requiresNewApproval = $true
                })
                $record.toolVersions.PowerShell7 | Should -Be '7.5.3'
            ($record | ConvertTo-Json -Depth 20) | Should -Not -Match '(?i)token|authorization|cookie|secret'
            { ConvertTo-RunbookEvidenceRecord -RunId ([guid]::NewGuid()) `
                -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z') -SourceCommit ('a' * 40) `
                -AssessmentDigest ('b' * 64) -OperatorId 'synthetic-operator' `
                -ShouldProcessDecision NotApplicable -Operation 'AssessTool' `
                -Classification NoChange -Status Verified -TargetId 'Git' `
                -ReadBack ([pscustomobject]@{ access_token = 'synthetic-prohibited-value' }) } |
                Should -Throw '*prohibited evidence field*'
        }

        It 'requires resource and stage collections to be arrays' {
            $common = @{
                RunId = [guid]::NewGuid()
                GeneratedAtUtc = [datetime]'2026-09-26T05:00:00Z'
                SourceCommit = ('a' * 40)
                AssessmentDigest = ('b' * 64)
                OperatorId = 'synthetic-operator'
                ShouldProcessDecision = 'NotApplicable'
                Operation = 'AssessTool'
                Classification = 'NoChange'
                Status = 'Verified'
            }
            { ConvertTo-RunbookEvidenceRecord @common `
                -ReadBack ([pscustomobject]@{ resourceIds = 'not-an-array' }) } |
                Should -Throw
            { ConvertTo-RunbookEvidenceRecord @common `
                -FinalContext ([pscustomobject]@{
                    stages = [pscustomobject]@{
                        stage = 'dev'; powerPlatformProfileName = 'profile'
                        powerPlatformEnvironmentId = 'environment'
                        powerPlatformEnvironmentUrl = 'https://example.invalid'
                        sharePointSiteId = 'site'; sharePointWebUrl = 'https://example.invalid/site'
                    }
                }) } | Should -Throw
        }
    }

    It 'refuses report paths in a Git working tree or staging root' {
        $repo = Join-Path $TestDrive 'repo'
        $stage = Join-Path $TestDrive 'stage'
        New-Item -ItemType Directory -Path (Join-Path $repo '.git'), $stage -Force | Out-Null
        { Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) -Path (Join-Path $repo 'report') -RepositoryRoot $repo } |
            Should -Throw '*outside every Git working tree*'
        { Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) -Path (Join-Path $stage 'report') -RepositoryRoot $repo -StagingRoot $stage } |
            Should -Throw '*outside the staging root*'
    }

    It 'writes stable BOM-free JSON and hashes the exact canonical bytes' {
        $value = [ordered]@{ z = 2; a = [ordered]@{ y = 1; b = 0 } }
        $path = Join-Path $TestDrive 'canonical.json'
        Write-CanonicalJson -InputObject $value -Path $path | Should -Be $path
        $bytes = [IO.File]::ReadAllBytes($path)
        $bytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
        [Text.Encoding]::UTF8.GetString($bytes) | Should -Be "{`"a`":{`"b`":0,`"y`":1},`"z`":2}`n"
        (Get-RunbookContentDigest -InputObject $value) |
            Should -Be ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-', '').ToLowerInvariant())
    }

    It 'refreshes only the process PATH from machine and user values' {
        InModuleScope Caldova.HrFrontier.Bootstrap {
            $machineBefore = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            $userBefore = [Environment]::GetEnvironmentVariable('Path', 'User')
            $processBefore = $env:Path
            try {
                $result = Update-RunbookProcessPath
                $result | Should -Be $env:Path
                [Environment]::GetEnvironmentVariable('Path', 'Machine') | Should -Be $machineBefore
                [Environment]::GetEnvironmentVariable('Path', 'User') | Should -Be $userBefore
            }
            finally {
                $env:Path = $processBefore
            }
        }
    }

    It 'exports every new public contract from both module declarations' {
        $expected = @(
            'Resolve-RunbookReportPath',
            'Write-CanonicalJson',
            'Get-RunbookContentDigest',
            'Update-RunbookProcessPath'
        )
        $manifest = Test-ModuleManifest $script:ModulePath
        foreach ($name in $expected) {
            $manifest.ExportedFunctions.Keys | Should -Contain $name
            Get-Command $name -Module Caldova.HrFrontier.Bootstrap | Should -Not -BeNullOrEmpty
        }
    }
}
