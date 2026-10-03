Set-StrictMode -Version Latest

Describe 'Shared runbook output contracts' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        @(Get-Module Caldova.HrFrontier.Bootstrap -All) | Remove-Module -Force -ErrorAction SilentlyContinue
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

        It 'rejects a recomputed manifest with an unsupported execution host' {
            $manifest = New-RunbookExecutionManifest -RunId ([guid]::NewGuid()) -Kind Workstation `
                    -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
                    -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
                    -AuthenticationContext ([pscustomobject]@{
                        executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                    }) -AllowedActions @([pscustomobject]@{
                        action = 'InstallPesterExact'; targetId = 'Pester'
                    }) -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')
            $manifest.authentication.executionHost = 'UnattendedPipeline'
            $unsigned = [ordered]@{}
            foreach ($property in $manifest.PSObject.Properties.Name | Where-Object { $_ -ne 'digest' }) {
                    $unsigned[$property] = $manifest.$property
            }
            $manifest.digest = Get-RunbookContentDigest -InputObject $unsigned

            { Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $manifest.digest `
                    -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
                    -CurrentAuthenticationContext $manifest.authentication `
                    -AllowedActionNames @('InstallPesterExact') `
                    -NowUtc ([datetime]'2026-09-26T05:10:00Z') } |
                    Should -Throw '*authentication host*'
        }

        It 'rejects a recomputed manifest with an unsupported authentication mode' {
            $manifest = New-RunbookExecutionManifest -RunId ([guid]::NewGuid()) -Kind Workstation `
                    -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
                    -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
                    -AuthenticationContext ([pscustomobject]@{
                        executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                    }) -AllowedActions @([pscustomobject]@{
                        action = 'InstallPesterExact'; targetId = 'Pester'
                    }) -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')
            $manifest.authentication.mode = 'ClientSecret'
            $unsigned = [ordered]@{}
            foreach ($property in $manifest.PSObject.Properties.Name | Where-Object { $_ -ne 'digest' }) {
                    $unsigned[$property] = $manifest.$property
            }
            $manifest.digest = Get-RunbookContentDigest -InputObject $unsigned

            { Test-RunbookExecutionManifest -Manifest $manifest -ApprovedDigest $manifest.digest `
                    -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
                    -CurrentAuthenticationContext $manifest.authentication `
                    -AllowedActionNames @('InstallPesterExact') `
                    -NowUtc ([datetime]'2026-09-26T05:10:00Z') } |
                    Should -Throw '*authentication mode*'
        }

        It 'validates a manifest with empty tool versions after canonical JSON round-trip' {
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
                    action = 'InstallVsCodeExtensionExact'
                    targetId = 'GitHub.copilot'
                    expectedPostcondition = 'VS Code reports extension GitHub.copilot'
                }) `
                -ToolVersions @{} `
                -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')
            $path = Join-Path $TestDrive 'empty-toolversions-manifest.json'
            Write-CanonicalJson -InputObject $manifest -Path $path | Out-Null
            $roundTrip = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json

            { Test-RunbookExecutionManifest -Manifest $roundTrip -ApprovedDigest $roundTrip.digest `
                -CurrentSourceCommit ('a' * 40) -CurrentAssessmentDigest ('b' * 64) `
                -CurrentAuthenticationContext ([pscustomobject]@{
                    executionHost = 'InteractiveWindows11PowerShell'; mode = 'NotRequired'
                }) `
                -AllowedActionNames @('InstallVsCodeExtensionExact') `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') } | Should -Not -Throw
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

        It 'rejects nested objects in ToolVersions' {
            { ConvertTo-RunbookEvidenceRecord `
                -RunId ([guid]::NewGuid()) -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z') `
                -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
                -OperatorId 'synthetic-operator' -Operation 'AssessTool' `
                -Classification NoChange -Status Verified -ShouldProcessDecision NotApplicable `
                -ToolVersions ([ordered]@{ PowerShell7 = [pscustomobject]@{ version = '7.5.3' } }) } |
                Should -Throw '*display-safe scalar*'
        }

        It 'rejects nested objects in ReadBack and FinalContext scalar fields' {
            $common = @{
                RunId = [guid]::NewGuid()
                GeneratedAtUtc = [datetime]'2026-09-26T05:00:00Z'
                SourceCommit = ('a' * 40)
                AssessmentDigest = ('b' * 64)
                OperatorId = 'synthetic-operator'
                Operation = 'AssessTool'
                Classification = 'NoChange'
                Status = 'Verified'
                ShouldProcessDecision = 'NotApplicable'
            }
            { ConvertTo-RunbookEvidenceRecord @common `
                -ReadBack ([pscustomobject]@{ status = [pscustomobject]@{ value = 'Verified' } }) } |
                Should -Throw '*display-safe scalar*'
            { ConvertTo-RunbookEvidenceRecord @common `
                -FinalContext ([pscustomobject]@{ principalId = [pscustomobject]@{ value = 'principal' } }) } |
                Should -Throw '*display-safe scalar*'
        }

        It 'rejects nested objects in manual and recovery item scalar fields' {
            $common = @{
                RunId = [guid]::NewGuid()
                GeneratedAtUtc = [datetime]'2026-09-26T05:00:00Z'
                SourceCommit = ('a' * 40)
                AssessmentDigest = ('b' * 64)
                OperatorId = 'synthetic-operator'
                Operation = 'AssessTool'
                Classification = 'NoChange'
                Status = 'Verified'
                ShouldProcessDecision = 'NotApplicable'
            }
            { ConvertTo-RunbookEvidenceRecord @common -ManualItems @([pscustomobject]@{
                    service = 'Azure'; targetId = 'target'; condition = 'Review'
                    owner = 'Owner'; diagnostic = [pscustomobject]@{ value = 'Nested' }
                    recovery = 'Review the item.'
                }) } | Should -Throw '*display-safe scalar*'
            { ConvertTo-RunbookEvidenceRecord @common -RecoveryItems @([pscustomobject]@{
                    service = 'Azure'; targetId = 'target'; lastProvenState = 'Unknown'
                    safeDiagnostic = [pscustomobject]@{ value = 'Nested' }; owner = 'Owner'
                    nextAction = 'Reassess.'; requiresNewPlan = $true
                    requiresNewApproval = $true
                }) } | Should -Throw '*display-safe scalar*'
        }
    }

    Describe 'Tenant lifecycle umbrella public contract' {
        BeforeAll {
            $script:TenantLifecyclePath = Join-Path $PSScriptRoot (
                '..\..\src\scripts\runbooks\Invoke-TenantLifecycle.ps1'
            )
            $script:TenantLifecycleTokens = $null
            $script:TenantLifecycleErrors = $null
            $script:TenantLifecycleAst = [Management.Automation.Language.Parser]::ParseFile(
                $script:TenantLifecyclePath,
                [ref]$script:TenantLifecycleTokens,
                [ref]$script:TenantLifecycleErrors
            )
        }

        It 'exposes the exact coordinate-only signature in order' {
            $script:TenantLifecycleErrors.Count | Should -Be 0
            (
                $script:TenantLifecycleAst.ParamBlock.Parameters.Name.VariablePath.UserPath -join ','
            ) | Should -BeExactly (
                'RunId,EvidenceRoot,RepositoryRoot,ExpectedSourceCommit,' +
                'PublicTenantKey,TenantConfigurationPath,TenantStatePath,Stages,' +
                'Mode,SubsystemInvoker,NowUtc'
            )
        }

        It 'closes the coordinate-only signature values at binding time' {
            $parameterText = @{}
            foreach ($parameter in $script:TenantLifecycleAst.ParamBlock.Parameters) {
                $parameterText[$parameter.Name.VariablePath.UserPath] =
                    $parameter.Extent.Text
            }

            $parameterText.RunId |
                Should -Match '\[guid\]\$RunId'
            $parameterText.ExpectedSourceCommit |
                Should -Match "\^\[0-9a-fA-F\]\{40\}\$"
            $parameterText.PublicTenantKey |
                Should -Match "ValidateSet\('tenant1'\)"
            $parameterText.Stages | Should -Match (
                "ValidateSet\('Workstation','PrivateBoundary','Foundation'," +
                "'DevDelivery','ReadBack','Acceptance','TenantReplica'\)"
            )
            $parameterText.Mode |
                Should -Match "ValidateSet\('Assess','Plan','Verify'\)"
            $parameterText.Mode |
                Should -Match '\$Mode\s*=\s*''Assess'''
            $parameterText.SubsystemInvoker |
                Should -Match 'Parameter\(DontShow\)'
            $parameterText.NowUtc |
                Should -Match '\$NowUtc\s*=\s*\[datetime\]::UtcNow'
            $script:TenantLifecycleAst.ParamBlock.Attributes.Extent.Text |
                Should -Not -Match 'SupportsShouldProcess'
        }

        It 'fails Verify closed before invoker and evidence paths until verification is implemented' {
            $evidenceRoot = Join-Path $TestDrive 'verify-transitional-evidence'
            $parameters = @{
                RunId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
                EvidenceRoot = $evidenceRoot
                RepositoryRoot = (Join-Path $TestDrive 'unreachable-repository')
                ExpectedSourceCommit = 'a' * 40
                PublicTenantKey = 'tenant1'
                TenantConfigurationPath = Join-Path $TestDrive 'unreachable-tenant1.local.psd1'
                TenantStatePath = Join-Path $TestDrive 'unreachable-tenant1.state.local.json'
                Stages = @('Foundation')
                Mode = 'Verify'
            }

            $withoutInvokerError = try {
                & $script:TenantLifecyclePath @parameters
                $null
            }
            catch {
                $_
            }

            $withoutInvokerError.Exception.Message |
                Should -BeExactly 'TenantLifecycle.Verify.NotImplemented'
            Test-Path -LiteralPath $evidenceRoot |
                Should -BeFalse

            $invokerProbe = [pscustomobject]@{ Calls = 0 }
            $parameters.SubsystemInvoker = {
                $invokerProbe.Calls++
                throw 'The transitional Verify guard must remain unreachable.'
            }.GetNewClosure()
            $withInvokerError = try {
                & $script:TenantLifecyclePath @parameters
                $null
            }
            catch {
                $_
            }

            $withInvokerError.Exception.Message |
                Should -BeExactly 'TenantLifecycle.SubsystemInvoker.NotAllowed'
            $invokerProbe.Calls | Should -Be 0
            Test-Path -LiteralPath $evidenceRoot |
                Should -BeFalse
        }

        It 'rejects retired umbrella authority during coordinate-only signature binding' -ForEach @(
            @{ ParameterName = 'Apply'; Value = $true }
            @{ ParameterName = 'ExecutionManifestPath'; Value = 'manifest.synthetic.json' }
            @{ ParameterName = 'ApprovedDigest'; Value = ('a' * 64) }
            @{ ParameterName = 'BindingObserver'; Value = { param($Checkpoint, $Stage) } }
            @{ ParameterName = 'CurrentBindingProvider'; Value = { [pscustomobject]@{} } }
        ) {
            param($ParameterName, $Value)

            $parameters = @{
                RunId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
                EvidenceRoot = $TestDrive
                RepositoryRoot = $TestDrive
                ExpectedSourceCommit = 'a' * 40
                PublicTenantKey = 'tenant1'
                TenantConfigurationPath = Join-Path $TestDrive 'tenant1.local.psd1'
                TenantStatePath = Join-Path $TestDrive 'tenant1.state.local.json'
                Stages = @('Foundation')
            }
            $parameters[$ParameterName] = $Value

            $errorRecord = try {
                & $script:TenantLifecyclePath @parameters
                $null
            }
            catch {
                $_
            }

            $errorRecord | Should -Not -BeNullOrEmpty
            $errorRecord.Exception |
                Should -BeOfType ([Management.Automation.ParameterBindingException])
            $errorRecord.FullyQualifiedErrorId |
                Should -Match 'NamedParameterNotFound'
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
