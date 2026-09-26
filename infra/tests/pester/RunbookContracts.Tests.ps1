Set-StrictMode -Version Latest

Describe 'Shared runbook output contracts' {
    BeforeAll {
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force
    }

    It 'refuses report paths in a Git working tree or staging root' {
        $repo = Join-Path $TestDrive 'repo'
        $stage = Join-Path $TestDrive 'stage'
        New-Item -ItemType Directory -Path (Join-Path $repo '.git'), $stage -Force | Out-Null
        { Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) -Path (Join-Path $repo 'report') -RepositoryRoot $repo } |
            Should -Throw '*outside every Git working tree*'
        { Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) -Path (Join-Path $stage 'report') -RepositoryRoot $repo -StagingRoot $stage } |
            Should -Throw '*outside the staging root*'
    }

    It 'writes stable BOM-free JSON and hashes the exact canonical bytes' {
        $value = [ordered]@{ z = 2; a = [ordered]@{ y = 1; b = 0 } }
        $path = Join-Path $TestDrive 'canonical.json'
        Write-CanonicalJson -InputObject $value -Path $path | Should -Be $path
        $bytes = [IO.File]::ReadAllBytes($path)
        $bytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
        [Text.Encoding]::UTF8.GetString($bytes) | Should -Be "{`"a`":{`"b`":0,`"y`":1},`"z`":2}`n"
        (Get-RunbookContentDigest -InputObject $value) |
            Should -Be ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-', '').ToLowerInvariant())
    }

    It 'refreshes only the process PATH from machine and user values' {
        InModuleScope Caldova.HrFrontier.Bootstrap {
            $machineBefore = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            $userBefore = [Environment]::GetEnvironmentVariable('Path', 'User')
            $processBefore = $env:Path
            try {
                $result = Update-RunbookProcessPath
                $result | Should -Be $env:Path
                [Environment]::GetEnvironmentVariable('Path', 'Machine') | Should -Be $machineBefore
                [Environment]::GetEnvironmentVariable('Path', 'User') | Should -Be $userBefore
            }
            finally {
                $env:Path = $processBefore
            }
        }
    }

    It 'exports every new public contract from both module declarations' {
        $expected = @(
            'Resolve-RunbookReportPath',
            'Write-CanonicalJson',
            'Get-RunbookContentDigest',
            'Update-RunbookProcessPath'
        )
        $manifest = Test-ModuleManifest $script:ModulePath
        foreach ($name in $expected) {
            $manifest.ExportedFunctions.Keys | Should -Contain $name
            Get-Command $name -Module Caldova.HrFrontier.Bootstrap | Should -Not -BeNullOrEmpty
        }
    }
}
