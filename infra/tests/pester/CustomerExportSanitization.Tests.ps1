Set-StrictMode -Version Latest

Describe 'Customer export sanitization' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1') -Force
        $script:SyntheticPolicy = [pscustomobject]@{
            reservedNames = @('Synthetic Reviewer', 'Customer Example Organization')
            reservedDomains = @('example.com', 'example.org', 'example.net', 'example.invalid')
            reservedIdPrefixes = @('synthetic-')
        }
    }

    function script:Test-SyntheticClassificationCase {
        param($Classification, [string]$ObservedSourceDigest, [bool]$ExpectedOutputMatches)

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $target = Join-Path $root ($Classification.path -replace '/', '\')
        [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
        [IO.File]::WriteAllText($target, 'Reviewer name: Synthetic Reviewer', [Text.UTF8Encoding]::new($false))
        $actualOutputDigest = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $Classification.expectedOutputSha256 = if ($ExpectedOutputMatches) { $actualOutputDigest } else { ('f' * 64) }
        Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit ('a' * 40) `
            -SyntheticDataPolicy $script:SyntheticPolicy -FileClassifications @($Classification) `
            -FileDigests @{ $Classification.path = [pscustomobject]@{
                sourceBlobSha256 = $ObservedSourceDigest
                expectedOutputSha256 = $actualOutputDigest
            } }
    }

    function script:Test-SyntheticFixtureCase {
        param($Classification)

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $target = Join-Path $root ($Classification.path -replace '/', '\')
        [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
        [IO.File]::WriteAllText($target, '{"employeeId":"synthetic-worker-001","email":"worker@example.invalid"}',
            [Text.UTF8Encoding]::new($false))
        $digest = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        $Classification.sourceBlobSha256 = $digest
        $Classification.expectedOutputSha256 = $digest
        Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit ('a' * 40) `
            -SyntheticDataPolicy $script:SyntheticPolicy -FileClassifications @($Classification) `
            -FileDigests @{ $Classification.path = [pscustomobject]@{
                sourceBlobSha256 = $Classification.sourceBlobSha256
                expectedOutputSha256 = $Classification.expectedOutputSha256
            } }
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

    It 'withholds publish readiness for one undisposed residual' {
        $stage = Join-Path $TestDrive 'validation-stage'
        [IO.Directory]::CreateDirectory($stage) | Out-Null
        [IO.File]::WriteAllText((Join-Path $stage 'README.md'), 'Source Reference Organization', [Text.UTF8Encoding]::new($false))

        $manifest = [pscustomobject]@{
            residualMarkers = @([pscustomobject]@{ id = 'source-customer-name'; category = 'CompanyName'; value = 'Source Reference Organization'; comparison = 'Ordinal' })
            residualDispositions = @()
            syntheticDataPolicy = $script:SyntheticPolicy
            inspectableBinaries = @()
            validationSuites = @('Pester')
            replacements = @([pscustomobject]@{
                id = 'customer-name-readme'; path = 'README.md'; format = 'MarkdownExact'; selector = $null; requiredCount = 1
            })
        }
        $assessment = [pscustomobject]@{
            digest = ('b' * 64)
            destinationStableId = 'customer-export:test'
            copyFiles = @('README.md')
            fileClassifications = @([pscustomobject]@{
                path = 'README.md'
                sourceBlobSha256 = ('a' * 64)
                expectedOutputSha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'README.md') -Algorithm SHA256).Hash.ToLowerInvariant()
                classification = 'ReviewedNonPersonal'
                reason = 'Synthetic documentation only.'
            })
            fileDigests = [pscustomobject]@{
                'README.md' = [pscustomobject]@{
                    sourceBlobSha256 = ('a' * 64)
                    expectedOutputSha256 = (Get-FileHash -LiteralPath (Join-Path $stage 'README.md') -Algorithm SHA256).Hash.ToLowerInvariant()
                }
            }
            markerCatalogProof = [pscustomobject]@{ digest = ('c' * 64) }
            sourceSnapshot = [pscustomobject]@{ digest = ('d' * 64) }
            toolIdentities = [pscustomobject]@{ WindowsPowerShell = [pscustomobject]@{ path = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'; sha256 = ('e' * 64) } }
        }
        $executionManifest = [pscustomobject]@{
            kind = 'CustomerExport'
            target = [pscustomobject]@{ type = 'CustomerExport'; stableId = 'customer-export:test' }
            assessmentDigest = ('b' * 64)
        }
        $replacementLog = @([pscustomobject]@{
            ruleId = 'customer-name-readme'; path = 'README.md'; format = 'MarkdownExact'; selector = $null
            replacementCount = 1; oldValueDigest = ('1' * 64); newValueDigest = ('2' * 64)
        })

        $result = Test-CustomerExportContent -StagingRoot $stage -Manifest $manifest `
            -Assessment $assessment -ExecutionManifest $executionManifest `
            -CurrentSourceSnapshot $assessment.sourceSnapshot `
            -ReplacementLog $replacementLog `
            -ValidationRunner { param($id,$file,$arguments,$root) [pscustomobject]@{ suite=$id; executablePath=$file; exitCode=0 } }

        $result.publishReady | Should -BeFalse
        $result.status | Should -Be 'Failed'
        @($result.failures | Where-Object category -eq 'UndisposedResidual').Count | Should -Be 1
    }

    It 'rejects personal patterns across JSON Markdown and text' {
        $root = Join-Path $TestDrive 'personal-data'
        [IO.Directory]::CreateDirectory($root) | Out-Null
        [IO.File]::WriteAllText((Join-Path $root 'record.json'),
            '{"employeeId":"4711","personalEmail":"person@corp.example","dateOfBirth":"1988-04-03"}',
            [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $root 'contact.md'),
            "Employee name: Example Person`nPhone: +41 44 555 01 02`nHome address: 1 Example Street",
            [Text.UTF8Encoding]::new($false))
        $fileDigests = @{}
        foreach ($file in Get-ChildItem -LiteralPath $root -File) {
            $digest = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $fileDigests[$file.Name] = [pscustomobject]@{
                sourceBlobSha256 = $digest
                expectedOutputSha256 = $digest
            }
        }
        $result = Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit ('a' * 40) `
            -SyntheticDataPolicy $script:SyntheticPolicy -FileClassifications @() `
            -FileDigests $fileDigests
        $result.status | Should -Be 'Failed'
        @($result.findings | Select-Object -ExpandProperty category -Unique) | Should -Contain 'Identity'
        @($result.findings | Select-Object -ExpandProperty category -Unique) | Should -Contain 'Contact'
    }

    It 'requires an exact digest-bound classification for an inconclusive file' {
        $classification = [pscustomobject]@{
            path = 'docs/reviewed-example.md'
            sourceBlobSha256 = ('a' * 64)
            expectedOutputSha256 = ('f' * 64)
            classification = 'ReviewedNonPersonal'
            reason = 'Synthetic architecture narrative with no person records.'
        }
        (Test-SyntheticClassificationCase -Classification $classification -ObservedSourceDigest ('a' * 64) -ExpectedOutputMatches $false).status | Should -Be 'Failed'
        (Test-SyntheticClassificationCase -Classification $classification -ObservedSourceDigest ('c' * 64) -ExpectedOutputMatches $true).status | Should -Be 'Failed'
        (Test-SyntheticClassificationCase -Classification $classification -ObservedSourceDigest ('a' * 64) -ExpectedOutputMatches $true).status | Should -Be 'Passed'
    }

    It 'allows only an exact digest-bound synthetic fixture exception' {
        $classification = [pscustomobject]@{
            path = 'infra/tests/fixtures/customer-export/synthetic-profile.json'
            sourceBlobSha256 = ('c' * 64)
            expectedOutputSha256 = ('c' * 64)
            classification = 'SyntheticFixture'
            reason = 'Synthetic local validation profile.'
        }
        (Test-SyntheticFixtureCase -Classification $classification).status | Should -Be 'Passed'
        $classification.path = 'data/synthetic-profile.json'
        (Test-SyntheticFixtureCase -Classification $classification).status | Should -Be 'Failed'
    }
}
