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
}