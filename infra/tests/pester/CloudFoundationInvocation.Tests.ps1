Set-StrictMode -Version Latest

Describe 'Dormant cloud foundation entry points' {
    BeforeAll {
        $script:PlanScript = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Get-CloudFoundationPlan.ps1'
        $script:InvokeScript = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Invoke-CloudFoundation.ps1'
    }

    It 'stops the planner before reading configuration or starting native tools' {
        $reportPath = Join-Path $TestDrive 'planner-output'
        $nativeRunner = { throw 'Native execution must remain unreachable.' }

        {
            & $script:PlanScript -TenantAlias synthetic `
                -TenantConfigurationPath 'C:\absent\tenant.psd1' `
                -ReportPath $reportPath `
                -NativeCommandRunner $nativeRunner
        } | Should -Throw '*retired from the current sprint*'

        $reportPath | Should -Not -Exist
    }

    It 'stops the apply entry point before reading approved artifacts or dispatching providers' {
        $reportPath = Join-Path $TestDrive 'apply-output'
        $nativeRunner = { throw 'Provider execution must remain unreachable.' }

        {
            & $script:InvokeScript -TenantAlias synthetic `
                -TenantConfigurationPath 'C:\absent\tenant.psd1' `
                -ExecutionManifestPath 'C:\absent\manifest.json' `
                -AssessmentPath 'C:\absent\assessment.json' `
                -ReportPath $reportPath `
                -ApprovedDigest ('a' * 64) `
                -NativeCommandRunner $nativeRunner `
                -Apply
        } | Should -Throw '*retired from the current sprint*'

        $reportPath | Should -Not -Exist
    }
}
