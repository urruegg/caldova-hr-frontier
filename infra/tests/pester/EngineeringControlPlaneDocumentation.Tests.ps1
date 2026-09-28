Describe 'Engineering control plane documentation' {
    BeforeAll {
        $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:AdrPaths = @(
            'docs\adr\0001-azure-devops-as-engineering-control-plane.md'
            'docs\adr\0002-github-first-bootstrap-and-the-role-of-azure-repos.md'
            'docs\adr\0012-per-tenant-github-repository-and-account-topology.md'
        )
        $script:ControlPlanePath = 'infra\docs\13-azure-devops-engineering-control-plane.md'
    }

    It 'records all three Wave 0 decisions as Approved and links the remediation design' {
        foreach ($relativePath in $script:AdrPaths) {
            $content = Get-Content -Raw (Join-Path $script:Root $relativePath)
            $content | Should -Match '\|\s+\*\*Status\*\*\s+\|\s+Approved\s+\|'
            $content | Should -Match '2026-09-28-tenant-1-engineering-platform-remediation-design\.md'
        }
    }

    It 'defines no initial mirror synchronization or shared product source' {
        $adr2 = Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[1])
        $adr2 | Should -Match 'contains no product source'
        $adr2 | Should -Match 'no.+initial disaster-recovery mirror'
    }

    It 'assigns repository validation to GitHub Actions and HR solution CI/CD to Azure Pipelines' {
        $adr1 = Get-Content -Raw (Join-Path $script:Root $script:AdrPaths[0])
        $controlPlane = Get-Content -Raw (Join-Path $script:Root $script:ControlPlanePath)

        $adr1 | Should -Match '\*\*GitHub Actions\*\* owns repository validation'
        $adr1 | Should -Match '\*\*Azure Pipelines\*\* owns HR solution CI/CD'
        $controlPlane | Should -Match '\|\s*Repository validation\s*\|\s*GitHub Actions\s*\|'
        $controlPlane | Should -Match '\|\s*HR solution CI/CD\s*\|\s*Azure Pipelines\s*\|'
        $controlPlane | Should -Not -Match 'may use Azure Pipelines'
    }
}
