Set-StrictMode -Version Latest

BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:ideaRoot = Join-Path $script:repositoryRoot 'docs\ideas'
    $script:useCaseRoot = Join-Path $script:repositoryRoot 'hr\docs\use-cases'
}

Describe 'Central idea portfolio and HR use-case detail' {
    It 'uses one central idea root and one HR detail root' {
        $script:ideaRoot | Should -Exist
        $script:useCaseRoot | Should -Exist
        (Join-Path $script:repositoryRoot 'hr\docs\ideas') | Should -Not -Exist
    }

    It 'retains all nineteen HR use-case idea records centrally' {
        $ideas = @(Get-ChildItem -LiteralPath $script:ideaRoot -Filter 'uc-*.md' -File)
        $ideas.Count | Should -Be 19
        foreach ($number in 1..19) {
            $pattern = 'uc-{0:d4}-*.md' -f $number
            @(Get-ChildItem -LiteralPath $script:ideaRoot -Filter $pattern -File).Count |
                Should -Be 1
        }
    }

    It 'marks UC-0001 graduated and defers Board synchronization' {
        $idea = Get-Content -LiteralPath (
            Join-Path $script:ideaRoot 'uc-0001-personal-master-data-completion-agent.md'
        ) -Raw
        $idea | Should -Match '\| \*\*Status\*\* \| Graduated \|'
        $catalogue = Get-Content -LiteralPath (Join-Path $script:ideaRoot 'README.md') -Raw
        $catalogue | Should -Match 'Deferred - not synchronized'
        $catalogue | Should -Not -Match 'AB#\d+'
    }
}
