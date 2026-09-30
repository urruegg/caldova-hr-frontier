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
        $normalizedDocuments = $documents | ForEach-Object {
            ($_ -replace '\s+', ' ').Trim()
        }
        $allDocuments = $normalizedDocuments -join ' '

        for ($index = 0; $index -lt $documents.Count; $index++) {
            $content = $documents[$index]
            $normalized = $normalizedDocuments[$index]
            $content | Should -Match '\|\s+\*\*Status\*\*\s+\|\s+Approved\s+\|'
            $content | Should -Match '2026-09-28-tenant-1-lean-engineering-platform-design\.md'
            $normalized | Should -Match 'A private Azure Repo, OIDC bootstrap, `bootstrap-tenant1` Environment, cloud workflow retrieval, and Basic-to-Agile conversion are not current targets\.'
        }

        $allDocuments | Should -Not -Match 'private Azure Repo.{0,100}\b(?:is|remains|becomes)\s+(?:an?\s+)?(?:approved\s+)?current targets?'
        $allDocuments | Should -Not -Match 'bootstrap-tenant1.{0,100}\b(?:is|remains|becomes)\s+(?:an?\s+)?(?:approved\s+)?current targets?'
        $allDocuments | Should -Not -Match '(?<!not )convert(?:s|ed|ing)?.{0,100}\bBasic\b.{0,40}\bAgile\b'
    }

    It 'keeps GitHub as source authority Boards as backlog and Azure Pipelines as future delivery' {
        $adr1 = (Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[0])) -replace '\s+', ' '
        $adr1 | Should -Match 'GitHub is the sole product-source and pull-request authority\.'
        $adr1 | Should -Match 'Azure Boards is the single delivery backlog and remains on the built-in Basic process\.'
        $adr1 | Should -Match 'Repository validation runs in GitHub Actions\.'
        $adr1 | Should -Match 'A future Azure Pipeline connects directly to GitHub'
        $adr1 | Should -Match 'no Azure Pipeline is created this sprint\.'
    }

    It 'keeps the solo-owner profile and excludes bootstrap cloud retrieval and mirroring' {
        $adr2 = (Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[1])) -replace '\s+', ' '
        $adr2 | Should -Match 'OIDC bootstrap.+cloud workflow retrieval.+are not current targets\.'
        $adr2 | Should -Match 'solo-owner profile has zero mandatory approvals'
        $adr2 | Should -Match 'does not require CODEOWNERS review'
        $adr2 | Should -Match 'No initial or current mirror is approved'
    }

    It 'labels the superseded topology as historical alternatives rather than Option A' {
        $adr1 = Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[0])
        $adr1 | Should -Not -Match '(?m)^### Option [A-C]\s+—'
        ([regex]::Matches($adr1, '(?m)^### Historical alternative —')).Count | Should -Be 3
    }
}
