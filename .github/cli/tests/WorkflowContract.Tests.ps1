BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:workflowPath = Join-Path $script:repositoryRoot '.github\workflows\validate-repository.yml'
    $script:auditWorkflowPath = Join-Path $script:repositoryRoot '.github\workflows\audit-repository.yml'
    $script:validatorPath = Join-Path $script:repositoryRoot '.github\cli\verify-repository-setup.ps1'
    $script:safetyValidatorPath = Join-Path $script:repositoryRoot '.github\cli\verify-repository-safety.ps1'
    $script:pullRequestTemplatePath = Join-Path $script:repositoryRoot '.github\pull_request_template.md'
    $script:rulesetPath = Join-Path $script:repositoryRoot 'infra\src\config\github\main-ruleset.json'
}

Describe 'Repository validation workflow' {
    It 'keeps the stable required status and runs only deterministic core checks' {
        $script:workflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:workflowPath -Raw

        $content | Should -Match '(?m)^permissions:\r?\n  contents: read\r?$'
        $content | Should -Match 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'
        $content | Should -Match '(?m)^\s+name: Repository setup validation\r?$'
        $content | Should -Match '\.github/cli/tests/WorkflowContract\.Tests\.ps1'
        $content | Should -Match 'infra/tests/pester'
        $content | Should -Match 'verify-repository-safety\.ps1'
        $content | Should -Match 'az bicep build --file infra/src/bicep/main\.bicep --stdout'
        $content | Should -Match 'git diff --check origin/main\.\.\.HEAD'
        $content | Should -Not -Match 'verify-repository-setup\.ps1'
        $content | Should -Not -Match '(?m)^\s*(?:pull-requests|contents|id-token):\s*write\r?$'
    }

    It 'runs the comprehensive baseline as a non-blocking advisory workflow' {
        $script:auditWorkflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:auditWorkflowPath -Raw

        $content | Should -Match '(?m)^name: Audit repository baseline\r?$'
        $content | Should -Match '(?m)^on:\r?\n  pull_request:\r?\n  push:\r?\n    branches: \[main\]\r?\n  workflow_dispatch:\r?$'
        $content | Should -Match '(?m)^\s+name: Repository baseline audit \(advisory\)\r?$'
        $content | Should -Not -Match '(?m)^\s+continue-on-error: true\r?$'
        $content | Should -Match 'verify-repository-setup\.ps1 -SkipIntegratedTests -SkipBicepBuild'
        $content | Should -Match "Where-Object Name -notin @\('WorkflowContract\.Tests\.ps1', 'RepositorySafety\.Tests\.ps1'\)"
        $content | Should -Match 'Invoke-Pester -Path \$paths -Output Detailed -CI'
        $content | Should -Not -Match '(?m)^\s*(?:pull-requests|contents|id-token):\s*write\r?$'

        $ruleset = Get-Content -LiteralPath $script:rulesetPath -Raw
        $ruleset | Should -Match '"context": "Repository setup validation"'
        $ruleset | Should -Not -Match 'Repository baseline audit'
    }

    It 'supports baseline-only execution without weakening the default validator' {
        $script:validatorPath | Should -Exist
        $content = Get-Content -LiteralPath $script:validatorPath -Raw

        $content | Should -Match '\[switch\]\$SkipIntegratedTests'
        $content | Should -Match '\[switch\]\$SkipBicepBuild'
        $content | Should -Match '(?m)^if \(-not \$SkipIntegratedTests\) \{\r?$'
        $content | Should -Match '(?m)^if \(-not \$SkipBicepBuild\) \{\r?$'
    }

    It 'selects one Git executable when the runner exposes duplicate command paths' {
        $script:validatorPath | Should -Exist
        $content = Get-Content -LiteralPath $script:validatorPath -Raw

        $content | Should -Match '(?m)^\$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue \| Select-Object -First 1\r?$'
    }

    It 'emits failed Pester test details in the validator summary' {
        $script:validatorPath | Should -Exist
        $content = Get-Content -LiteralPath $script:validatorPath -Raw

        $content | Should -Match '(?m)^\s+FailedTests = if \(`\$null -ne `\$result\) \{ @\(`\$result\.Failed \| ForEach-Object \{'
        $content | Should -Match "failedTests=\{7\}"
        $content | Should -Match '(?m)^\s+`\$failureMessage = `\$failureMessage -replace .+\[REDACTED\].+\r?$'
        $content | Should -Match 'authorization'
        $content | Should -Match 'PRIVATE KEY'
        $content | Should -Match 'sharedaccesssignature'
        $content | Should -Match 'accountkey'
        $content | Should -Match 'api\[_\\s-\]\?key'
        $content | Should -Match '\(\?:sig\|signature\)'
        $content | Should -Match '(?m)^\s+if \(`\$failureMessage\.Length -gt 1000\) \{ `\$failureMessage = `\$failureMessage\.Substring\(0, 1000\) \+ .+\}\r?$'
        $content | Should -Match '(?m)^\s+\}\s+\| Select-Object -First 10\) \} else \{ @\(\) \}\r?$'
    }

    It 'records reviewer acceptance when an advisory audit is not green' {
        $script:pullRequestTemplatePath | Should -Exist
        $content = Get-Content -LiteralPath $script:pullRequestTemplatePath -Raw

        $content | Should -Match 'Advisory baseline audit is green, or reviewer acceptance and rationale are recorded'
    }
}