Describe 'Engineering control plane documentation' {
    BeforeAll {
        $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:AdrPaths = @(
            'docs\adr\0001-azure-devops-as-engineering-control-plane.md'
            'docs\adr\0002-github-first-bootstrap-and-the-role-of-azure-repos.md'
            'docs\adr\0012-per-tenant-github-repository-and-account-topology.md'
        )
    }

    It 'records Option A as the approved current target' {
        $documents = $script:AdrPaths | ForEach-Object {
            Get-Content -Raw (Join-Path $script:Root $_)
        }
        foreach ($content in $documents) {
            $content | Should -Match '\|\s+\*\*Status\*\*\s+\|\s+Approved\s+\|'
            $content | Should -Match '2026-09-28-tenant-1-lean-engineering-platform-design\.md'
        }
        ($documents -join "`n") | Should -Not -Match 'private Azure Repo.+current target'
        ($documents -join "`n") | Should -Not -Match 'bootstrap-tenant1.+current target'
        ($documents -join "`n") | Should -Not -Match 'convert.+Basic.+Agile'
    }

    It 'keeps GitHub as source authority Boards as backlog and Azure Pipelines as future delivery' {
        $adr1 = Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[0])
        $adr1 | Should -Match 'GitHub.+sole product-source'
        $adr1 | Should -Match 'Azure Boards.+single delivery backlog'
        $adr1 | Should -Match 'future Azure Pipeline.+directly.+GitHub'
        $adr1 | Should -Not -Match 'Azure Pipeline.+current sprint'
    }
}
