BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:workflowPath = Join-Path $script:repositoryRoot '.github\workflows\validate-repository.yml'
    $script:validatorPath = Join-Path $script:repositoryRoot '.github\cli\verify-repository-setup.ps1'
}

Describe 'Repository validation workflow' {
    It 'has least privilege, a pinned checkout action, and runs both validator and Pester' {
        $script:workflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:workflowPath -Raw

        $content | Should -Match '(?m)^permissions:\r?\n  contents: read\r?$'
        $content | Should -Match 'actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683'
        $content | Should -Match '(?m)^\s+name: Repository setup validation\r?$'
        $content | Should -Match 'verify-repository-setup\.ps1'
        $content | Should -Match 'Invoke-Pester'
        $content | Should -Not -Match '(?m)^\s*(?:pull-requests|contents|id-token):\s*write\r?$'
    }

    It 'declares the intended workflow name and triggers' {
        $script:workflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:workflowPath -Raw

        $content | Should -Match '(?m)^name: Validate repository\r?$'
        $content | Should -Match '(?m)^on:\r?\n  pull_request:\r?\n  push:\r?\n    branches: \[main\]\r?\n  workflow_dispatch:\r?$'
    }

    It 'defines the validate job with exact indentation and limits' {
        $script:workflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:workflowPath -Raw

        $content | Should -Match '(?m)^jobs:\r?\n  validate:\r?\n    name: Repository setup validation\r?\n    runs-on: windows-2025\r?\n    timeout-minutes: 15\r?\n    steps:\r?$'
    }

    It 'pins checkout and Pester with the intended step shape' {
        $script:workflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:workflowPath -Raw

        $content | Should -Match '(?m)^      - name: Check out repository\r?\n        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683\r?\n        with:\r?\n          fetch-depth: 0\r?$'
        $content | Should -Match '(?m)^      - name: Install pinned Pester\r?\n        shell: powershell\r?\n        run: Install-Module Pester -RequiredVersion 5\.7\.1 -Scope CurrentUser -Force -SkipPublisherCheck\r?$'
    }

    It 'runs the validator, contract suite, and branch whitespace check' {
        $script:workflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:workflowPath -Raw

        $content | Should -Match '(?m)^        run: powershell -NoProfile -ExecutionPolicy Bypass -File \.github/cli/verify-repository-setup\.ps1\r?$'
        $content | Should -Match '(?m)^        run: Invoke-Pester \.github/cli/tests -Output Detailed -CI\r?$'
        $content | Should -Match '(?m)^        run: git diff --check origin/main\.\.\.HEAD\r?$'
    }

    It 'does not consume secrets or grant write and identity-token permissions' {
        $script:workflowPath | Should -Exist
        $content = Get-Content -LiteralPath $script:workflowPath -Raw

        $content | Should -Not -Match '\$\{\{\s*secrets\.'
        $content | Should -Not -Match '(?m)^\s*(?:pull-requests|contents|id-token):\s*write\r?$'
    }

    It 'selects one Git executable when the runner exposes duplicate command paths' {
        $script:validatorPath | Should -Exist
        $content = Get-Content -LiteralPath $script:validatorPath -Raw

        $content | Should -Match '(?m)^\$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue \| Select-Object -First 1\r?$'
    }
}