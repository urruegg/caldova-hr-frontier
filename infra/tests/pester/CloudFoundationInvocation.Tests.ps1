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
}
