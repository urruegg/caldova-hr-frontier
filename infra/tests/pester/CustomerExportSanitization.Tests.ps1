Set-StrictMode -Version Latest

Describe 'Customer export sanitization' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
    }

    It 'changes only one JSON Pointer and logs digests rather than values' {
        $path = Join-Path $TestDrive 'config.json'
        [IO.File]::WriteAllText($path, '{"tenant":{"alias":"source-lab"},"text":"source-lab"}', [Text.UTF8Encoding]::new($false))
        $log = Invoke-CustomerStructuredReplacement -StagingRoot $TestDrive -Path 'config.json' -Rules @([pscustomobject]@{
            id = 'tenant-alias-json'
            path = 'config.json'
            format = 'Json'
            selector = '/tenant/alias'
            expectedOldValue = 'source-lab'
            newValue = 'customer-synthetic'
            requiredCount = 1
        })
        (Get-Content -Raw $path | ConvertFrom-Json).text | Should -Be 'source-lab'
        $log.replacementCount | Should -Be 1
        ($log | ConvertTo-Json) | Should -Not -Match 'customer-synthetic|source-lab'
    }

    It 'changes the exact reviewed count only in the named Markdown file' {
        $target = Join-Path $TestDrive 'handover.md'
        $other = Join-Path $TestDrive 'other.md'
        $original = "Owner: Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($other, $original, [Text.UTF8Encoding]::new($false))
        $beforeOther = [IO.File]::ReadAllBytes($other)

        $log = Invoke-CustomerStructuredReplacement -StagingRoot $TestDrive -Path 'handover.md' -Rules @([pscustomobject]@{
            id = 'customer-name-handover'
            path = 'handover.md'
            format = 'MarkdownExact'
            expectedOldText = 'Source Reference Organization'
            newText = 'Customer Example Organization'
            requiredCount = 2
        })

        [IO.File]::ReadAllText($target) | Should -Be "Owner: Customer Example Organization`r`nContact Customer Example Organization`r`n"
        [IO.File]::ReadAllBytes($other) | Should -Be $beforeOther
        $log.replacementCount | Should -Be 2
        ($log | ConvertTo-Json -Compress) | Should -Not -Match 'Source Reference Organization|Customer Example Organization'
    }

    It 'leaves Markdown bytes unchanged when the exact count mismatches' {
        $target = Join-Path $TestDrive 'count-mismatch.md'
        $original = "Source Reference Organization`nSource Reference Organization`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $before = [IO.File]::ReadAllBytes($target)
        {
            Invoke-CustomerStructuredReplacement -StagingRoot $TestDrive -Path 'count-mismatch.md' -Rules @([pscustomobject]@{
                id = 'customer-name-count'
                path = 'count-mismatch.md'
                format = 'MarkdownExact'
                expectedOldText = 'Source Reference Organization'
                newText = 'Customer Example Organization'
                requiredCount = 3
            })
        } | Should -Throw '*required occurrence count*'
        [IO.File]::ReadAllBytes($target) | Should -Be $before
    }

    It 'reports every undisposed name and content residual' {
        $residualRoot = Join-Path $TestDrive 'residual-case'
        New-Item -ItemType Directory (Join-Path $residualRoot 'source-lab') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $residualRoot 'source-lab\source-lab-note.md'), 'source-lab', [Text.UTF8Encoding]::new($false))
        $matches = Get-CustomerExportResidual -StagingRoot $residualRoot `
            -Markers @([pscustomobject]@{ id = 'source-alias'; category = 'TenantAlias'; value = 'source-lab'; comparison = 'OrdinalIgnoreCase' }) `
            -Dispositions @() -InspectableBinaries @()
        @($matches | Where-Object disposition -eq 'Undisposed').Count | Should -Be 3
    }
}
