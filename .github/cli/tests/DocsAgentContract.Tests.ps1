BeforeAll {
    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

Describe 'Documentation agent contract' {
    It 'exists with the focused tool boundary and English metadata ownership' {
        $path = Join-Path $repositoryRoot '.github\agents\docs-agent.agent.md'
        $path | Should -Exist
        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match '(?m)^name: docs-agent\r?$'
        $content | Should -Match '(?m)^tools: \[read, search, edit, todo\]\r?$'
        $content | Should -Match 'standard six-field metadata header'
        $content | Should -Match 'written in English'
        $content | Should -Not -Match '(?m)^tools:.*execute'
    }

    It 'is directly anchored from both repository instruction files' {
        foreach ($relativePath in @('AGENTS.md', '.github/copilot-instructions.md')) {
            $content = Get-Content -LiteralPath (Join-Path $repositoryRoot $relativePath) -Raw
            $content | Should -Match '\.github/agents/docs-agent\.agent\.md'
        }
    }

    It 'anchors the conditional Mermaid visualization standard in policy and the docs agent' {
        $policy = Get-Content -LiteralPath (Join-Path $repositoryRoot 'docs\README.md') -Raw
        $agent = Get-Content -LiteralPath (Join-Path $repositoryRoot '.github\agents\docs-agent.agent.md') -Raw

        $policy | Should -Match '(?is)Mermaid.*(?:flows|states|sequences|relationships|architecture)'
        $policy | Should -Match '(?is)(?:does not|must not).*replace.*(?:tables|requirements|identifiers|prose)'
        $agent | Should -Match '(?is)Mermaid.*(?:flows|states|sequences|relationships|architecture)'
        $agent | Should -Match '(?is)(?:does not|must not).*replace.*(?:tables|requirements|identifiers|prose)'
    }

    It 'uses Mermaid for the AI Builder design and field BoM visual explanations' {
        $design = Get-Content -LiteralPath (
            Join-Path $repositoryRoot 'docs\superpowers\specs\2026-09-25-tenant-2-ai-builder-models-design.md'
        ) -Raw
        $bom = Get-Content -LiteralPath (
            Join-Path $repositoryRoot (
                'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\' +
                'bom-0001-peopledoc-master-data-ai-builder-fields.md'
            )
        ) -Raw

        @([regex]::Matches($design, '(?m)^```mermaid\r?$')).Count | Should -BeGreaterOrEqual 3
        @([regex]::Matches($bom, '(?m)^```mermaid\r?$')).Count | Should -BeGreaterOrEqual 1
    }

    It 'provides a traceable AI Builder test input and outcome BoM' {
        $relativePath = (
            'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\' +
            'bom-0002-ai-builder-test-inputs-and-outcomes.md'
        )
        $path = Join-Path $repositoryRoot $relativePath
        $path | Should -Exist

        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match '(?m)^```mermaid\r?$'
        $content | Should -Match '`run_id`'
        $content | Should -Match 'Not run - no evidence'
        foreach ($metric in @(
            'Exact-match accuracy',
            'Precision',
            'Recall',
            'Missing-field precision',
            'False-value rate',
            'Confidence distribution'
        )) {
            $content | Should -Match ([regex]::Escape($metric))
        }

        $catalogue = Get-Content -LiteralPath (
            Join-Path $repositoryRoot (
                'hr\docs\ideas\uc-0001-personal-master-data-completion-agent\README.md'
            )
        ) -Raw
        $catalogue | Should -Match ([regex]::Escape('bom-0002-ai-builder-test-inputs-and-outcomes.md'))
    }
}