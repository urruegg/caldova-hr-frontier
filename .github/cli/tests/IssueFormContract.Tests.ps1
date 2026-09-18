BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:issueTemplateRoot = Join-Path $script:repositoryRoot '.github\ISSUE_TEMPLATE'
    $metadataModulePath = Join-Path $PSScriptRoot '..\modules\DocumentationMetadata.psm1'
    Import-Module $metadataModulePath -Force

    function Get-FileContentIfPresent {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return ''
        }

        return [IO.File]::ReadAllText($Path)
    }
}

Describe 'Active issue forms' {
    It 'contains the exact four-file set' {
        $actual = @(Get-ChildItem $script:issueTemplateRoot -File |
            Sort-Object Name |
            ForEach-Object Name)

        $actual | Should -Be @(
            '01-bug.yml',
            '02-feature.yml',
            '03-frontier-intake.yml',
            'config.yml'
        )
    }

    It 'retains bug and feature bytes and adds reviewed intake controls' {
        (Get-FileHash (Join-Path $script:issueTemplateRoot '01-bug.yml') -Algorithm SHA256).Hash.ToLowerInvariant() |
            Should -Be '8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a'
        (Get-FileHash (Join-Path $script:issueTemplateRoot '02-feature.yml') -Algorithm SHA256).Hash.ToLowerInvariant() |
            Should -Be '748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4'

        $intake = Get-FileContentIfPresent -Path (
            Join-Path $script:issueTemplateRoot '03-frontier-intake.yml'
        )
        $intake | Should -Match 'Do not include personal data'
        $intake | Should -Match 'Employee journey stage'

        $config = Get-FileContentIfPresent -Path (
            Join-Path $script:issueTemplateRoot 'config.yml'
        )
        $config | Should -Match 'https://dev.azure.com/caldova25156897'
        $config | Should -Match 'docs/operating-model/04-hitl-governance.md'
    }

    It 'keeps the reviewed personal and special-category data prohibition' {
        $intake = Get-FileContentIfPresent -Path (
            Join-Path $script:issueTemplateRoot '03-frontier-intake.yml'
        )

        $intake | Should -Match 'health, absence, compensation, performance or disciplinary information'
        $intake | Should -Match 'I confirm this report contains no personal or special-category data\.'
    }

    It 'uses LF and space indentation for the Task 6 issue controls' {
        foreach ($fileName in @('03-frontier-intake.yml', 'config.yml')) {
            $content = Get-FileContentIfPresent -Path (
                Join-Path $script:issueTemplateRoot $fileName
            )

            $content.Contains("`r") | Should -BeFalse
            $content.IndexOf([char]"`t") | Should -Be -1
            @($content.Split("`n") | Where-Object { $_ -match '[ \t]+$' }) |
                Should -BeNullOrEmpty
        }

        $expectedConfig = @(
            'blank_issues_enabled: false'
            'contact_links:'
            '  - name: Backlog and delivery tracking'
            '    url: https://dev.azure.com/caldova25156897'
            '    about: Work is planned and tracked in Azure Boards. This repository is the build plane.'
            '  - name: Governance and data rules'
            '    url: https://github.com/urruegg/caldova-hr-frontier/blob/main/docs/operating-model/04-hitl-governance.md'
            '    about: Read before raising anything that might contain personal data.'
            ''
        ) -join "`n"
        Get-FileContentIfPresent -Path (Join-Path $script:issueTemplateRoot 'config.yml') |
            Should -BeExactly $expectedConfig
    }
}

Describe 'CODEOWNERS contract' {
    It 'assigns the default and explicit domain paths to the repository owner' {
        $path = Join-Path $script:repositoryRoot '.github\CODEOWNERS'
        $path | Should -Exist
        $effectiveLines = @((Get-FileContentIfPresent -Path $path).Split("`n") |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#', [StringComparison]::Ordinal) })
        $entries = @($effectiveLines | ForEach-Object {
            $entryMatch = [regex]::Match(
                $_,
                '^(?<Pattern>\S+)\s+(?<Owners>@\S+(?:\s+@\S+)*)$',
                [Text.RegularExpressions.RegexOptions]::CultureInvariant
            )
            $entryMatch.Success | Should -BeTrue -Because "CODEOWNERS entry must be valid: $_"
            if ($entryMatch.Success) {
                [pscustomobject]@{
                    Pattern = $entryMatch.Groups['Pattern'].Value
                    Owners = $entryMatch.Groups['Owners'].Value
                }
            }
        })

        foreach ($expectedPattern in @(
            '*',
            '/.github/',
            '/AGENTS.md',
            '/docs/',
            '/infra/',
            '/hr/',
            '/data/'
        )) {
            $matchingEntries = @($entries | Where-Object Pattern -CEQ $expectedPattern)
            $matchingEntries.Count | Should -Be 1
            $matchingEntries[0].Owners | Should -BeExactly '@urruegg'
        }

        $approvedScheduledDirectories = @('/infra/', '/hr/', '/data/')
        foreach ($entry in $entries) {
            if ($entry.Pattern -ceq '*') {
                continue
            }

            $entry.Pattern.IndexOfAny([char[]]@('*', '?', '[')) |
                Should -Be -1 -Because "owned path must be literal: $($entry.Pattern)"
            if ($approvedScheduledDirectories -ccontains $entry.Pattern) {
                continue
            }

            $relativePath = $entry.Pattern.TrimStart('/').TrimEnd('/').Replace('/', '\')
            Test-Path -LiteralPath (Join-Path $script:repositoryRoot $relativePath) |
                Should -BeTrue -Because "owned path must exist: $($entry.Pattern)"
        }
    }
}

Describe 'Dependabot contract' {
    It 'checks GitHub Actions dependencies from the repository root every week' {
        $path = Join-Path $script:repositoryRoot '.github\dependabot.yml'
        $path | Should -Exist
        $content = Get-FileContentIfPresent -Path $path

        $content | Should -Match '(?m)^version:\s*2\r?$'
        $content | Should -Match '(?m)^\s*-\s+package-ecosystem:\s*"github-actions"\r?$'
        $content | Should -Match '(?m)^\s+directory:\s*"/"\r?$'
        $content | Should -Match '(?m)^\s+interval:\s*"weekly"\r?$'
    }
}

Describe 'Pull request template contract' {
    It 'has valid repository metadata and the reviewed collaboration sections' {
        $path = Join-Path $script:repositoryRoot '.github\pull_request_template.md'
        $path | Should -Exist
        $content = Get-FileContentIfPresent -Path $path
        $lines = @($content.Replace("`r`n", "`n").Replace("`r", "`n").Split("`n"))

        @(Test-DocumentationMetadataContent `
            -Content $content `
            -DocumentRelativePath '.github/pull_request_template.md').Count |
            Should -Be 0
        $lines | Should -Contain '# Pull Request'
        $lines | Should -Contain '| **Version** | 1.0 |'
        $lines | Should -Contain '| **Date** | 2026-09-17 |'
        $lines | Should -Contain '| **Author** | docs-agent (Voice of Knowledge) |'
        $lines | Should -Contain '| **Status** | Proposed Baseline |'
        $lines | Should -Contain '| **Scope** | Repository |'
        $lines | Should -Contain '| **References** | [Approved Architecture Baseline Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Phase 1 Governance and GitHub Intake Review](../docs/reviews/2026-09-17-phase-1-governance-github-intake.md) |'

        foreach ($section in @(
            '## Work item',
            '## Journey stage',
            '### Scope',
            '### Governance',
            '### Validation evidence',
            '### Documentation',
            '### Impact',
            '### Review handoff',
            '## Evidence',
            '## Review first'
        )) {
            $lines | Should -Contain $section
        }
    }

    It 'uses the exact public multi-tenant governance checklist' {
        $content = Get-FileContentIfPresent -Path (
            Join-Path $script:repositoryRoot '.github\pull_request_template.md'
        )
        $lines = @($content.Replace("`r`n", "`n").Replace("`r", "`n").Split("`n"))
        $noSecrets = '- [ ] No secrets, credentials, access tokens, personal HR data, or unreviewed tenant values introduced'
        $approvedMetadata = '- [ ] Any committed tenant identifier or service URL is approved non-secret metadata covered by the tenant manifest and evidence policy'

        @($lines | Where-Object { $_ -ceq $noSecrets }).Count | Should -Be 1
        @($lines | Where-Object { $_ -ceq $approvedMetadata }).Count | Should -Be 1
        $content | Should -Not -Match 'tenant manifest (?:exists|is present|has been created)'
    }

    It 'describes DEV TEST and PROD as Power Platform ALM impact' {
        $content = Get-FileContentIfPresent -Path (
            Join-Path $script:repositoryRoot '.github\pull_request_template.md'
        )
        $lines = @($content.Replace("`r`n", "`n").Replace("`r", "`n").Split("`n"))

        $lines | Should -Contain 'The DEV, TEST, and PROD checkboxes describe Power Platform ALM impact, not Azure infrastructure environments.'
        foreach ($environment in @('DEV', 'TEST', 'PROD')) {
            $lines | Should -Contain "- [ ] $environment"
        }
    }
}

Describe '.gitignore collaboration additions' {
    It 'preserves worktree Superpowers and selective VS Code rules' {
        $path = Join-Path $script:repositoryRoot '.gitignore'
        $rules = @(Get-Content -LiteralPath $path | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#', [StringComparison]::Ordinal) })

        $rules | Should -Contain '.wt/'
        $rules | Should -Contain '/.superpowers/'
        $rules | Should -Contain '.vscode/*'
        foreach ($allowRule in @(
            '!.vscode/settings.json',
            '!.vscode/tasks.json',
            '!.vscode/launch.json',
            '!.vscode/extensions.json',
            '!.vscode/*.code-snippets'
        )) {
            $rules | Should -Contain $allowRule
        }
        $rules | Should -Not -Contain '.vscode/'
        $rules | Should -Not -Contain '/.vscode/'
    }

    It 'contains every approved additive rule exactly once' {
        $path = Join-Path $script:repositoryRoot '.gitignore'
        $rules = @(Get-Content -LiteralPath $path | ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#', [StringComparison]::Ordinal) })

        foreach ($approvedRule in @(
            'dist/',
            'build/',
            '*.zip',
            '*.cdsproj.user',
            '.pac/',
            '*.tfstate',
            '*.tfstate.*',
            '.terraform/',
            'npm-debug.log*',
            '.idea/',
            '*.swp',
            '.DS_Store',
            '*.pem',
            '*.key',
            '.env.*',
            'local.settings.json'
        )) {
            @($rules | Where-Object { $_ -ceq $approvedRule }).Count |
                Should -Be 1 -Because "approved rule must appear exactly once: $approvedRule"
        }
    }
}