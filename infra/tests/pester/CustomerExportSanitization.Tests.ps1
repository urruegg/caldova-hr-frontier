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

    function script:Get-CustomerExportResidualArtifacts {
        param(
            [Parameter(Mandatory)][string]$Root,
            [string[]]$Extensions = @('.tmp', '.bak')
        )

        @(Get-ChildItem -LiteralPath $Root -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in $Extensions })
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

    It 'restores the original target bytes and cleans temp files after replace failure' {
        $caseRoot = Join-Path $TestDrive 'replace-failure'
        [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
        $target = Join-Path $caseRoot 'atomic-failure.md'
        $original = "Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $state = [pscustomobject]@{ replaceCalls = 0 }
        $ops = [pscustomobject]@{
            WriteAllBytes = { param($path, [byte[]]$bytes) [IO.File]::WriteAllBytes($path, $bytes) }
            ReadAllBytes = { param($path) [IO.File]::ReadAllBytes($path) }
            Exists = { param($path) Test-Path -LiteralPath $path }
            Delete = { param($path) Remove-Item -LiteralPath $path -Force }
            Move = { param($source, $destination) [IO.File]::Move($source, $destination) }
            Replace = {
                param($source, $destination, $backup)
                $state.replaceCalls++
                if ($state.replaceCalls -eq 1) {
                    [IO.File]::Copy($destination, $backup, $true)
                    Remove-Item -LiteralPath $destination -Force
                    throw 'synthetic replace failure'
                }
                [IO.File]::Move($source, $destination)
            }.GetNewClosure()
        }

        {
            Invoke-CustomerStructuredReplacement -StagingRoot $caseRoot -Path 'atomic-failure.md' -Rules @([pscustomobject]@{
                id = 'customer-name-atomic'
                path = 'atomic-failure.md'
                format = 'MarkdownExact'
                expectedOldText = 'Source Reference Organization'
                newText = 'Customer Example Organization'
                requiredCount = 2
            }) -FileOperations $ops
        } | Should -Throw '*restored*'

        [IO.File]::ReadAllText($target) | Should -Be $original
        @(Get-CustomerExportResidualArtifacts -Root $caseRoot).Count | Should -Be 0
    }

    It 'keeps the restored-result exception when restore-backup cleanup fails' {
        $caseRoot = Join-Path $TestDrive 'restore-backup-delete-failure'
        [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
        $target = Join-Path $caseRoot 'restore-backup-delete-failure.md'
        $original = "Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $state = [pscustomobject]@{ replaceCalls = 0; restoreBackupPath = $null }
        $ops = [pscustomobject]@{
            WriteAllBytes = { param($path, [byte[]]$bytes) [IO.File]::WriteAllBytes($path, $bytes) }
            ReadAllBytes = { param($path) [IO.File]::ReadAllBytes($path) }
            Exists = { param($path) Test-Path -LiteralPath $path }
            Delete = {
                param($path)
                if ($path -eq $state.restoreBackupPath) {
                    throw 'synthetic restore-backup cleanup failure'
                }
                Remove-Item -LiteralPath $path -Force
            }.GetNewClosure()
            Move = { param($source, $destination) [IO.File]::Move($source, $destination) }
            Replace = {
                param($source, $destination, $backup)
                $state.replaceCalls++
                if ($state.replaceCalls -eq 1) {
                    [IO.File]::Copy($destination, $backup, $true)
                    throw 'synthetic replace failure'
                }
                $state.restoreBackupPath = $backup
                [IO.File]::Replace($source, $destination, $backup, $false)
            }.GetNewClosure()
        }

        {
            Invoke-CustomerStructuredReplacement -StagingRoot $caseRoot -Path 'restore-backup-delete-failure.md' -Rules @([pscustomobject]@{
                id = 'customer-name-restore-backup-delete-failure'
                path = 'restore-backup-delete-failure.md'
                format = 'MarkdownExact'
                expectedOldText = 'Source Reference Organization'
                newText = 'Customer Example Organization'
                requiredCount = 2
            }) -FileOperations $ops -WarningAction Continue
        } | Should -Throw '*restored*'

        [IO.File]::ReadAllText($target) | Should -Be $original
    }

    It 'retains the backup and reports the safe recovery path when restoration fails' {
        $caseRoot = Join-Path $TestDrive 'restore-failure'
        [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
        $target = Join-Path $caseRoot 'restore-failure.md'
        $original = "Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $state = [pscustomobject]@{ replaceCalls = 0; backupPath = $null }
        $ops = [pscustomobject]@{
            WriteAllBytes = { param($path, [byte[]]$bytes) [IO.File]::WriteAllBytes($path, $bytes) }
            ReadAllBytes = { param($path) [IO.File]::ReadAllBytes($path) }
            Exists = { param($path) Test-Path -LiteralPath $path }
            Delete = { param($path) Remove-Item -LiteralPath $path -Force }
            Move = {
                param($source, $destination)
                if ($source -like '*.restore.tmp') {
                    throw 'synthetic restoration failure'
                }
                [IO.File]::Move($source, $destination)
            }
            Replace = {
                param($source, $destination, $backup)
                $state.replaceCalls++
                if ($state.replaceCalls -eq 1) {
                    $state.backupPath = $backup
                    [IO.File]::Copy($destination, $backup, $true)
                    Remove-Item -LiteralPath $destination -Force
                    throw 'synthetic replace failure'
                }
                [IO.File]::Move($source, $destination)
            }.GetNewClosure()
        }

        {
            Invoke-CustomerStructuredReplacement -StagingRoot $caseRoot -Path 'restore-failure.md' -Rules @([pscustomobject]@{
                id = 'customer-name-restore'
                path = 'restore-failure.md'
                format = 'MarkdownExact'
                expectedOldText = 'Source Reference Organization'
                newText = 'Customer Example Organization'
                requiredCount = 2
            }) -FileOperations $ops
        } | Should -Throw ("*{0}*" -f [WildcardPattern]::Escape($state.backupPath))

        $state.backupPath | Should -Exist
        @(Get-CustomerExportResidualArtifacts -Root $caseRoot -Extensions @('.tmp')).Count | Should -Be 0
    }

    It 'does not let finally temp cleanup failures replace the restoration exception' {
        $caseRoot = Join-Path $TestDrive 'finally-delete-failure'
        [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
        $target = Join-Path $caseRoot 'finally-delete-failure.md'
        $original = "Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $state = [pscustomobject]@{ replaceCalls = 0; failedDeletePath = $null }
        $ops = [pscustomobject]@{
            WriteAllBytes = { param($path, [byte[]]$bytes) [IO.File]::WriteAllBytes($path, $bytes) }
            ReadAllBytes = { param($path) [IO.File]::ReadAllBytes($path) }
            Exists = { param($path) Test-Path -LiteralPath $path }
            Delete = {
                param($path)
                if ($path -like '*.tmp' -and $null -eq $state.failedDeletePath) {
                    $state.failedDeletePath = $path
                    throw 'synthetic temp cleanup failure'
                }
                Remove-Item -LiteralPath $path -Force
            }.GetNewClosure()
            Move = { param($source, $destination) [IO.File]::Move($source, $destination) }
            Replace = {
                param($source, $destination, $backup)
                $state.replaceCalls++
                if ($state.replaceCalls -eq 1) {
                    [IO.File]::Copy($destination, $backup, $true)
                    Remove-Item -LiteralPath $destination -Force
                    throw 'synthetic replace failure'
                }
                [IO.File]::Move($source, $destination)
            }.GetNewClosure()
        }

        {
            Invoke-CustomerStructuredReplacement -StagingRoot $caseRoot -Path 'finally-delete-failure.md' -Rules @([pscustomobject]@{
                id = 'customer-name-finally-delete-failure'
                path = 'finally-delete-failure.md'
                format = 'MarkdownExact'
                expectedOldText = 'Source Reference Organization'
                newText = 'Customer Example Organization'
                requiredCount = 2
            }) -FileOperations $ops -WarningAction Continue
        } | Should -Throw '*restored*'

        [IO.File]::ReadAllText($target) | Should -Be $original
    }

    It 'does not let finally exists failures replace the restoration exception' {
        $caseRoot = Join-Path $TestDrive 'finally-exists-failure'
        [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
        $target = Join-Path $caseRoot 'finally-exists-failure.md'
        $original = "Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $state = [pscustomobject]@{ replaceCalls = 0; existsFailureSeen = $false }
        $ops = [pscustomobject]@{
            WriteAllBytes = { param($path, [byte[]]$bytes) [IO.File]::WriteAllBytes($path, $bytes) }
            ReadAllBytes = { param($path) [IO.File]::ReadAllBytes($path) }
            Exists = {
                param($path)
                if (($path -like '*.tmp') -and (-not $state.existsFailureSeen)) {
                    $state.existsFailureSeen = $true
                    throw 'synthetic exists failure'
                }
                Test-Path -LiteralPath $path
            }.GetNewClosure()
            Delete = { param($path) Remove-Item -LiteralPath $path -Force }
            Move = { param($source, $destination) [IO.File]::Move($source, $destination) }
            Replace = {
                param($source, $destination, $backup)
                $state.replaceCalls++
                if ($state.replaceCalls -eq 1) {
                    [IO.File]::Copy($destination, $backup, $true)
                    Remove-Item -LiteralPath $destination -Force
                    throw 'synthetic replace failure'
                }
                [IO.File]::Move($source, $destination)
            }.GetNewClosure()
        }

        {
            Invoke-CustomerStructuredReplacement -StagingRoot $caseRoot -Path 'finally-exists-failure.md' -Rules @([pscustomobject]@{
                id = 'customer-name-finally-exists-failure'
                path = 'finally-exists-failure.md'
                format = 'MarkdownExact'
                expectedOldText = 'Source Reference Organization'
                newText = 'Customer Example Organization'
                requiredCount = 2
            }) -FileOperations $ops -WarningAction Continue
        } | Should -Throw '*restored*'

        [IO.File]::ReadAllText($target) | Should -Be $original
    }

    It 'does not let warning action stop replace the primary restoration exception' {
        $caseRoot = Join-Path $TestDrive 'warning-stop-cleanup'
        [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
        $target = Join-Path $caseRoot 'warning-stop-cleanup.md'
        $original = "Source Reference Organization`r`nContact Source Reference Organization`r`n"
        [IO.File]::WriteAllText($target, $original, [Text.UTF8Encoding]::new($false))
        $state = [pscustomobject]@{ replaceCalls = 0; cleanupFailureSeen = $false }
        $ops = [pscustomobject]@{
            WriteAllBytes = { param($path, [byte[]]$bytes) [IO.File]::WriteAllBytes($path, $bytes) }
            ReadAllBytes = { param($path) [IO.File]::ReadAllBytes($path) }
            Exists = { param($path) Test-Path -LiteralPath $path }
            Delete = {
                param($path)
                if (($path -like '*.tmp') -and (-not $state.cleanupFailureSeen)) {
                    $state.cleanupFailureSeen = $true
                    throw 'synthetic temp cleanup failure'
                }
                Remove-Item -LiteralPath $path -Force
            }.GetNewClosure()
            Move = { param($source, $destination) [IO.File]::Move($source, $destination) }
            Replace = {
                param($source, $destination, $backup)
                $state.replaceCalls++
                if ($state.replaceCalls -eq 1) {
                    [IO.File]::Copy($destination, $backup, $true)
                    Remove-Item -LiteralPath $destination -Force
                    throw 'synthetic replace failure'
                }
                [IO.File]::Move($source, $destination)
            }.GetNewClosure()
        }

        {
            Invoke-CustomerStructuredReplacement -StagingRoot $caseRoot -Path 'warning-stop-cleanup.md' -Rules @([pscustomobject]@{
                id = 'customer-name-warning-stop-cleanup'
                path = 'warning-stop-cleanup.md'
                format = 'MarkdownExact'
                expectedOldText = 'Source Reference Organization'
                newText = 'Customer Example Organization'
                requiredCount = 2
            }) -FileOperations $ops -WarningAction Stop
        } | Should -Throw '*restored*'

        [IO.File]::ReadAllText($target) | Should -Be $original
    }

    It 'leaves no temp or backup files after a successful atomic publish' {
        $caseRoot = Join-Path $TestDrive 'atomic-success'
        [IO.Directory]::CreateDirectory($caseRoot) | Out-Null
        $target = Join-Path $caseRoot 'atomic-success.md'
        [IO.File]::WriteAllText($target,
            "Source Reference Organization`r`nContact Source Reference Organization`r`n",
            [Text.UTF8Encoding]::new($false))

        $warnings = @()
        Invoke-CustomerStructuredReplacement -StagingRoot $caseRoot -Path 'atomic-success.md' -Rules @([pscustomobject]@{
            id = 'customer-name-success'
            path = 'atomic-success.md'
            format = 'MarkdownExact'
            expectedOldText = 'Source Reference Organization'
            newText = 'Customer Example Organization'
            requiredCount = 2
        }) -WarningVariable warnings -WarningAction Continue | Out-Null

        @(Get-CustomerExportResidualArtifacts -Root $caseRoot).Count | Should -Be 0
        $warnings | Should -BeNullOrEmpty
    }

    It 'classifies inspectable non-NUL binary content only when explicitly allowlisted' {
        InModuleScope Caldova.HrFrontier.Bootstrap {
            $bytes = [byte[]](0x1B, 0x50, 0x4B, 0x03)
            $digest = Get-CustomerExportSha256 -Bytes $bytes
            $result = Get-CustomerExportTextKind -Path 'docs/diagram.bin' -Bytes $bytes -InspectableBinaries @([pscustomobject]@{
                path = 'docs/diagram.bin'
                sha256 = $digest
                reason = 'Reviewed synthetic binary fixture.'
            })
            $result.kind | Should -Be 'InspectableBinary'
            { Get-CustomerExportTextKind -Path 'docs/diagram.bin' -Bytes $bytes -InspectableBinaries @() } | Should -Throw '*allowlisted*'
        }
    }

    It 'rejects UTF-8 BOM, UTF-16 BOM, invalid UTF-8, and mixed newline text' {
        InModuleScope Caldova.HrFrontier.Bootstrap {
            { Get-CustomerExportTextKind -Path 'docs/bom.md' -Bytes ([byte[]](0xEF,0xBB,0xBF,0x41)) -InspectableBinaries @() } | Should -Throw '*UTF-8 without BOM*'
            { Get-CustomerExportTextKind -Path 'docs/utf16.md' -Bytes ([byte[]](0xFF,0xFE,0x41,0x00)) -InspectableBinaries @() } | Should -Throw '*UTF-8 without BOM*'
            { Get-CustomerExportTextKind -Path 'docs/invalid.md' -Bytes ([byte[]](0xC3,0x28)) -InspectableBinaries @() } | Should -Throw '*valid UTF-8*'
            { Get-CustomerExportTextKind -Path 'docs/mixed.md' -Bytes ([Text.UTF8Encoding]::new($false).GetBytes("line1`r`nline2`n")) -InspectableBinaries @() } | Should -Throw '*newline*'
        }
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

    It 'requires exact reviewed classification for unsupported UTF-8 text formats' {
        $root = Join-Path $TestDrive 'unsupported-text'
        [IO.Directory]::CreateDirectory($root) | Out-Null
        $path = Join-Path $root 'records.csv'
        [IO.File]::WriteAllText($path, "employeeId,name`n4711,Jane Doe", [Text.UTF8Encoding]::new($false))
        $digest = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()

        $result = Test-CustomerExportSyntheticData -StagingRoot $root -SourceCommit ('a' * 40) `
            -SyntheticDataPolicy $script:SyntheticPolicy -FileClassifications @() `
            -FileDigests @{ 'records.csv' = [pscustomobject]@{
                sourceBlobSha256 = $digest
                expectedOutputSha256 = $digest
            } }

        $result.status | Should -Be 'Failed'
        @($result.findings | Where-Object category -eq 'ReviewedNonPersonalClassificationRequired').Count |
            Should -Be 1
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
