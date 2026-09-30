Set-StrictMode -Version Latest

Describe 'Exact empty Azure Repo proof' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Assert-AzureRepoEmptyProof.ps1'
        $script:RepositoryId = '11111111-1111-1111-1111-111111111111'
        $script:ProjectId = '22222222-2222-2222-2222-222222222222'

        function script:New-ValidProofParameters {
            @{
                AzureRepoId = $script:RepositoryId
                ProjectId = $script:ProjectId
                Repository = [pscustomobject]@{
                    id = $script:RepositoryId
                    name = 'Synthetic HR Frontier'
                    project = [pscustomobject]@{
                        id = $script:ProjectId
                    }
                    size = [long]0
                    defaultBranch = $null
                }
                Refs = [pscustomobject]@{
                    count = 0
                    value = [object[]]@()
                }
                Items = [pscustomobject]@{
                    count = 0
                    value = [object[]]@()
                }
            }
        }
    }

    It 'accepts only exact IDs and explicit empty response contracts' {
        $parameters = New-ValidProofParameters
        $result = & $script:ScriptPath @parameters

        $result.repositoryId | Should -BeExactly $script:RepositoryId
        $result.projectId | Should -BeExactly $script:ProjectId
        $result.repositoryName | Should -BeExactly 'Synthetic HR Frontier'
        $result.size | Should -Be 0
        $result.defaultBranch | Should -BeNullOrEmpty
        $result.refCount | Should -Be 0
        $result.itemCount | Should -Be 0
        $result.predicates.sizeIsZero | Should -BeTrue
        $result.predicates.defaultBranchIsEmpty | Should -BeTrue
        $result.predicates.refsAreEmpty | Should -BeTrue
        $result.predicates.itemsAreEmpty | Should -BeTrue
    }

    It 'accepts an explicitly empty default branch string' {
        $parameters = New-ValidProofParameters
        $parameters.Repository.defaultBranch = ''

        $result = & $script:ScriptPath @parameters

        $result.defaultBranch | Should -BeExactly ''
    }

    It 'rejects malformed repository response contracts' -TestCases @(
        @{
            Name = 'empty object'
            Mutate = { param($Parameters) $Parameters.Repository = [pscustomobject]@{} }
        }
        @{
            Name = 'missing size'
            Mutate = {
                param($Parameters)
                $Parameters.Repository.PSObject.Properties.Remove('size')
            }
        }
        @{
            Name = 'string size'
            Mutate = { param($Parameters) $Parameters.Repository.size = '0' }
        }
        @{
            Name = 'missing defaultBranch'
            Mutate = {
                param($Parameters)
                $Parameters.Repository.PSObject.Properties.Remove('defaultBranch')
            }
        }
        @{
            Name = 'wrong defaultBranch type'
            Mutate = { param($Parameters) $Parameters.Repository.defaultBranch = 0 }
        }
        @{
            Name = 'foreign repository ID'
            Mutate = {
                param($Parameters)
                $Parameters.Repository.id = '33333333-3333-3333-3333-333333333333'
            }
        }
        @{
            Name = 'foreign project ID'
            Mutate = {
                param($Parameters)
                $Parameters.Repository.project.id = '44444444-4444-4444-4444-444444444444'
            }
        }
        @{
            Name = 'missing project object'
            Mutate = {
                param($Parameters)
                $Parameters.Repository.PSObject.Properties.Remove('project')
            }
        }
    ) {
        param($Name, $Mutate)

        $parameters = New-ValidProofParameters
        & $Mutate $parameters

        { & $script:ScriptPath @parameters } | Should -Throw '*repository*'
    }

    It 'rejects malformed refs and items envelopes' -TestCases @(
        @{
            Name = 'empty refs object'
            Target = 'Refs'
            Value = [pscustomobject]@{}
        }
        @{
            Name = 'missing refs count'
            Target = 'Refs'
            Value = [pscustomobject]@{ value = [object[]]@() }
        }
        @{
            Name = 'string refs count'
            Target = 'Refs'
            Value = [pscustomobject]@{ count = '0'; value = [object[]]@() }
        }
        @{
            Name = 'null refs value'
            Target = 'Refs'
            Value = [pscustomobject]@{ count = 0; value = $null }
        }
        @{
            Name = 'non-array refs value'
            Target = 'Refs'
            Value = [pscustomobject]@{ count = 0; value = [pscustomobject]@{} }
        }
        @{
            Name = 'inconsistent refs count'
            Target = 'Refs'
            Value = [pscustomobject]@{ count = 0; value = [object[]]@([pscustomobject]@{ name = 'refs/heads/main' }) }
        }
        @{
            Name = 'non-empty refs'
            Target = 'Refs'
            Value = [pscustomobject]@{ count = 1; value = [object[]]@([pscustomobject]@{ name = 'refs/heads/main' }) }
        }
        @{
            Name = 'empty items object'
            Target = 'Items'
            Value = [pscustomobject]@{}
        }
        @{
            Name = 'missing items value'
            Target = 'Items'
            Value = [pscustomobject]@{ count = 0 }
        }
        @{
            Name = 'wrong items value type'
            Target = 'Items'
            Value = [pscustomobject]@{ count = 0; value = 'empty' }
        }
        @{
            Name = 'inconsistent items count'
            Target = 'Items'
            Value = [pscustomobject]@{ count = 1; value = [object[]]@() }
        }
        @{
            Name = 'non-empty items'
            Target = 'Items'
            Value = [pscustomobject]@{ count = 1; value = [object[]]@([pscustomobject]@{ path = '/' }) }
        }
    ) {
        param($Name, $Target, $Value)

        $parameters = New-ValidProofParameters
        $parameters[$Target] = $Value

        { & $script:ScriptPath @parameters } | Should -Throw "*$Target*"
    }
}
