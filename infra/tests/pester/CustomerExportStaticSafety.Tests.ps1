Set-StrictMode -Version Latest

Describe 'Customer export static safety' {
    BeforeAll {
        $script:Entry = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\New-CustomerRepositoryExport.ps1'
        $script:Validator = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Test-CustomerRepositoryExport.ps1'
    }

    It 'keeps forbidden authentication and remote interfaces out of both entry points' {
        $forbiddenParameters = '(?i)token|secret|credential|password|pat|authorization|devicecode|remote|organization'
        $forbiddenText = '(?i)(GH_TOKEN|GITHUB_TOKEN|AZURE_DEVOPS_EXT_PAT|SYSTEM_ACCESSTOKEN|--with-token|az\s+devops\s+login|oidc|workload.identity|workflow_dispatch|api/repos/.+/environments|git\s+(init|remote|push|fetch|pull|checkout|switch|reset|clean|filter-branch)|New-GitHubRepository|Publish-Customer)'
        foreach ($path in @($script:Entry, $script:Validator)) {
            $text = Get-Content -Raw -LiteralPath $path
            $text | Should -Not -Match $forbiddenText
        }
    }

    It 'keeps should-process and mutator boundaries in the reviewed scripts' {
        (Get-Content -Raw -LiteralPath $script:Entry) | Should -Match 'SupportsShouldProcess'
        (Get-Content -Raw -LiteralPath $script:Entry) | Should -Match 'ShouldProcess'
        (Get-Content -Raw -LiteralPath $script:Validator) | Should -Not -Match '\[switch\]\$Apply'
    }
}
