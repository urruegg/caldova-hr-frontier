BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:workflowPath = Join-Path $script:repositoryRoot '.github\workflows\validate-repository.yml'
    $script:validatorPath = Join-Path $script:repositoryRoot '.github\cli\verify-repository-setup.ps1'
}

Describe 'Lean repository validation workflow' {
    It 'keeps exactly one least-privilege workflow and one stable job' {
        $workflowRoot = Join-Path $script:repositoryRoot '.github\workflows'
        $workflows = @(Get-ChildItem -LiteralPath $workflowRoot -Filter '*.yml' -File)
        $workflows.Name | Should -Be @('validate-repository.yml')
        $content = Get-Content -Raw -LiteralPath $workflows[0].FullName
        $content | Should -Match '(?m)^permissions:\r?\n  contents: read\r?$'
        $content | Should -Match 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'
        $jobs = ($content -split '(?m)^jobs:\r?$', 2)[1]
        @([regex]::Matches($jobs, '(?m)^\s{2}[a-z][a-z0-9_-]*:\r?$')).Count | Should -Be 1
        $content | Should -Match '(?m)^\s+name: Repository setup validation\r?$'
        $content | Should -Not -Match '(?m)^\s*(?:id-token|actions|pull-requests):\s+write\r?$'
    }

    It 'runs every maintained test safety build and merge-base whitespace check' {
        $content = Get-Content -Raw -LiteralPath $script:workflowPath
        $content | Should -Match 'Get-ChildItem.+\.github[/\\]cli[/\\]tests.+\*\.Tests\.ps1'
        $content | Should -Match "'infra[/\\]tests[/\\]pester'"
        $content | Should -Match "'hr[/\\]tests[/\\]pester'"
        $content | Should -Match 'verify-repository-safety\.ps1'
        $content | Should -Match 'Get-ChildItem.+infra[/\\]src[/\\]bicep.+\*\.bicep.+-Recurse'
        $content | Should -Match 'git merge-base'
        $content | Should -Match 'git diff --check'
        $content | Should -Not -Match 'HEAD~\d+'
    }

    It 'does not require tracked Tenant 1 artifacts after the attended removal commit' {
        $tokens = $null
        $parseErrors = $null
        $validatorAst = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:validatorPath,
            [ref]$tokens,
            [ref]$parseErrors
        )
        $parseErrors.Count | Should -Be 0
        $requiredPathsAssignment = $validatorAst.Find({
            param($node)

            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -ceq 'phase3RequiredPaths'
        }, $true)
        $requiredPathsAssignment | Should -Not -BeNullOrEmpty

        $requiredPaths = @($requiredPathsAssignment.Right.FindAll({
            param($node)

            $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
        }, $true) | ForEach-Object Value)
        $requiredPaths | Should -Not -Contain 'infra/src/config/tenants/caldova25156897.psd1'
        $requiredPaths | Should -Not -Contain 'infra/evidence/discovery/caldova25156897.json'
    }
}
