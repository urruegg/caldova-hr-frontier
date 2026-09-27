Set-StrictMode -Version Latest

Describe 'Customer export source isolation' {
    BeforeAll {
        $script:Module = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:Module -Force
    }

    It 'refuses a dirty source and a destination below it' {
        $root = [IO.Path]::GetFullPath($TestDrive)
        $runner = {
            param($file, $args)
            $joined = (@($args) | ForEach-Object {
                if ($_ -is [array]) { $_ -join ' ' } else { [string]$_ }
            }) -join ' '
            if ($joined -match 'status --porcelain=v1 --untracked-files=all') { return "?? decoy.txt" }
            if ($joined -match 'rev-parse --show-toplevel') { return $root }
            if ($joined -match 'rev-parse HEAD') { return ('a' * 40) }
            $effective = @($args)
            if ($effective.Count -eq 1 -and $effective[0] -is [array]) {
                $effective = @($effective[0])
            }
            if ($effective.Count -eq 1 -and $effective[0] -is [string] -and $effective[0] -match '\s') {
                $effective = @(([string]$effective[0]) -split ' ')
            }
            $effective = if (@($effective).Count -ge 3 -and $effective[0] -eq '-C') { @($effective)[2..(@($effective).Count - 1)] } else { @($effective) }
            if (@($effective).Count -eq 0) { return '' }
            return ''
        }.GetNewClosure()
        $git = [pscustomobject]@{ name = 'git.exe'; path = 'C:\Approved\git.exe'; sha256 = ('c' * 64) }
        {
            Get-CustomerExportSourceSnapshot -RepositoryRoot $TestDrive -GitExecutable $git `
                -NativeCommandRunner $runner -GitBlobReader { param($gitPath, $root, $commit, $path) [byte[]]@(0x41) }
        } | Should -Throw
    }

    It 'refuses ambiguous executable resolution without invoking either candidate' {
        $calls = [Collections.Generic.List[string]]::new()
        {
            Resolve-CustomerExportExecutable -Name git.exe `
                -CommandResolver { param($name) @('C:\Approved\git.exe', 'C:\Shadow\git.exe') } `
                -FileIdentityProvider {
                    param($path)
                    [pscustomobject]@{
                        path = $path
                        sha256 = if ($path -like 'C:\Approved\*') { ('a' * 64) } else { ('b' * 64) }
                    }
                }
        } | Should -Throw '*ambiguous*'
        $calls.Count | Should -Be 0
    }

    It 'binds the shared CustomerExport manifest to the assessment and destination target' {
        $assessment = [pscustomobject]@{
            sourceCommit = ('a' * 40)
            digest = ('b' * 64)
            destinationStableId = 'customer-export:synthetic-destination'
            toolIdentities = [ordered]@{
                Git = [ordered]@{ path = 'C:\Approved\git.exe'; sha256 = ('c' * 64); version = 'git version 2.51.0.windows.1' }
                WindowsPowerShell = [ordered]@{ path = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'; sha256 = ('d' * 64); version = '5.1.26100.6584' }
            }
            allowedActions = @(
                [pscustomobject]@{ action = 'CreateCustomerExport'; targetId = 'customer-export:synthetic-destination'; service = 'LocalFileSystem'; method = 'CreateNewDisposableDirectory'; expectedPostcondition = 'Disposable staging exists.' },
                [pscustomobject]@{ action = 'CopyTrackedBlob'; targetId = 'README.md'; service = 'Git'; method = 'ReadCommitBlob'; sourceRelativePath = 'README.md'; destinationRelativePath = 'README.md'; expectedPostcondition = 'Bytes match.' },
                [pscustomobject]@{ action = 'ApplyStructuredReplacement'; targetId = 'config.json#tenant-alias-json'; service = 'LocalFileSystem'; method = 'JsonPointer'; sourceRelativePath = 'config.json'; destinationRelativePath = 'config.json'; replacementRuleId = 'tenant-alias-json'; expectedPostcondition = 'The reviewed exact replacement count is satisfied.' },
                [pscustomobject]@{ action = 'ValidateCustomerExport'; targetId = 'customer-export:synthetic-destination'; service = 'LocalValidation'; method = 'FixedValidationSuites'; expectedPostcondition = 'Checks pass.' },
                [pscustomobject]@{ action = 'PromoteCustomerExport'; targetId = 'customer-export:synthetic-destination'; service = 'LocalFileSystem'; method = 'AtomicDirectoryMove'; expectedPostcondition = 'Destination exists.' }
            )
        }
        $authentication = [pscustomobject]@{
            executionHost = 'InteractiveWindows11PowerShell'
            mode = 'NotApplicable'
        }
        $executionManifest = New-RunbookExecutionManifest -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
            -Kind CustomerExport -TargetStableId $assessment.destinationStableId `
            -SourceCommit $assessment.sourceCommit -AssessmentDigest $assessment.digest `
            -AuthenticationContext $authentication -AllowedActions $assessment.allowedActions `
            -ToolVersions $assessment.toolIdentities `
            -GeneratedAtUtc ([datetime]'2026-09-26T06:00:00Z')

        $executionManifest.target.type | Should -Be 'CustomerExport'
        $executionManifest.target.stableId | Should -Be $assessment.destinationStableId
        Test-RunbookExecutionManifest -Manifest $executionManifest -ApprovedDigest $executionManifest.digest `
            -CurrentSourceCommit $assessment.sourceCommit -CurrentAssessmentDigest $assessment.digest `
            -CurrentAuthenticationContext $authentication `
            -AllowedActionNames @('CreateCustomerExport', 'CopyTrackedBlob', 'ApplyStructuredReplacement', 'ValidateCustomerExport', 'PromoteCustomerExport') `
            -NowUtc ([datetime]'2026-09-26T06:10:00Z') | Should -BeTrue
    }

    It 'refuses an unrepresented source marker from retained tenant configuration' {
        $blobReader = {
            param($gitPath, $root, $commit, $path)
            [Text.UTF8Encoding]::new($false).GetBytes(@'
@{
    TenantAlias = 'source-lab'
    TenantId = '11111111-2222-3333-4444-555555555555'
    AdminUpn = 'admin@source-lab.example.invalid'
    PowerPlatform = @{ DevUrl = 'https://source-lab.crm.example.invalid/' }
}
'@)
        }
        {
            Get-CustomerSourceMarkerCatalog -RepositoryRoot $TestDrive -ExpectedSourceCommit ('a' * 40) `
                -TrackedFiles @([pscustomobject]@{ path = 'infra/src/config/tenants/source.psd1'; mode = '100644' }) `
                -RetainedTenantArtifacts @() -SourceMarkerCatalog @() `
                -GitExecutable ([pscustomobject]@{ path = 'C:\Approved\git.exe'; sha256 = ('b' * 64) }) `
                -GitBlobReader $blobReader
        } | Should -Throw '*unrepresented source marker*'
    }

    It 'accepts a verified reviewed CompanyName assertion outside tenant configuration' {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
            "Owner: Source Reference Organization`n")
        $sha = [BitConverter]::ToString(
            [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        ).Replace('-', '').ToLowerInvariant()
        $catalog = @([pscustomobject]@{
            id = 'source-customer-name'
            category = 'CompanyName'
            value = 'Source Reference Organization'
            comparison = 'Ordinal'
            sources = @([pscustomobject]@{
                path = 'README.md'
                blobSha256 = $sha
                occurrenceCount = 1
            })
        })
        $result = Get-CustomerSourceMarkerCatalog -RepositoryRoot $TestDrive `
            -ExpectedSourceCommit ('a' * 40) `
            -TrackedFiles @([pscustomobject]@{ path = 'README.md'; mode = '100644'; blobSha256 = $sha }) `
            -RetainedTenantArtifacts @() -SourceMarkerCatalog $catalog `
            -GitExecutable ([pscustomobject]@{ path = 'C:\Approved\git.exe'; sha256 = ('b' * 64) }) `
            -GitBlobReader ({ param($gitPath, $root, $commit, $path) $bytes }.GetNewClosure())
        $result.reviewedAssertionsVerified | Should -Be 1
        $result.automaticCandidateCount | Should -Be 0
    }

    It 'refuses a stale reviewed assertion even when its marker value exists' {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes(
            "Owner: Source Reference Organization`n")
        $catalog = @([pscustomobject]@{
            id = 'source-customer-name'
            category = 'CompanyName'
            value = 'Source Reference Organization'
            comparison = 'Ordinal'
            sources = @([pscustomobject]@{
                path = 'README.md'
                blobSha256 = ('f' * 64)
                occurrenceCount = 2
            })
        })
        {
            Get-CustomerSourceMarkerCatalog -RepositoryRoot $TestDrive `
                -ExpectedSourceCommit ('a' * 40) `
                -TrackedFiles @([pscustomobject]@{ path = 'README.md'; mode = '100644'; blobSha256 = ('e' * 64) }) `
                -RetainedTenantArtifacts @() -SourceMarkerCatalog $catalog `
                -GitExecutable ([pscustomobject]@{ path = 'C:\Approved\git.exe'; sha256 = ('b' * 64) }) `
                -GitBlobReader ({ param($gitPath, $root, $commit, $path) $bytes }.GetNewClosure())
        } | Should -Throw '*catalog source assertion*'
    }

    It 'excludes an inconclusive file without an exact reviewed classification' {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes('Reviewer name: Synthetic Reviewer')
        $blobSha = (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash.ToLowerInvariant()
        $snapshot = [pscustomobject]@{
            trackedFiles = @([pscustomobject]@{ path = 'docs/reviewed-example.md'; mode = '100644'; blobSha256 = $blobSha })
        }
        $manifest = [pscustomobject]@{
            retainedTenantArtifacts = @()
            fileClassifications = @()
            replacements = @()
            syntheticDataPolicy = [pscustomobject]@{
                reservedNames = @('Synthetic Reviewer')
                reservedDomains = @('example.invalid')
                reservedIdPrefixes = @('synthetic-')
            }
        }
        $assessment = Get-CustomerExportAssessment -SourceRoot $TestDrive -ExpectedSourceCommit ('a' * 40) `
            -DestinationRoot (Join-Path ([IO.Path]::GetFullPath($TestDrive)) '..\export') `
            -Manifest $manifest -ManifestDigest ('b' * 64) -SourceSnapshot $snapshot `
            -ToolIdentities ([pscustomobject]@{ Git = [pscustomobject]@{ path='C:\Approved\git.exe'; sha256=('c' * 64) } }) `
            -MarkerCatalogProof ([pscustomobject]@{ digest=('d' * 64) }) `
            -GitExecutable ([pscustomobject]@{ path='C:\Approved\git.exe'; sha256=('c' * 64) }) `
            -GitBlobReader ({ param($gitPath,$root,$commit,$path) $bytes }.GetNewClosure())

        @($assessment.copyFiles) | Should -Be @()
        @($assessment.exclusions | Where-Object reason -eq 'ReviewedNonPersonalClassificationRequired').Count | Should -Be 1
    }

    It 'refuses a classification whose expected output digest does not match the computed staged bytes' {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes('Reviewer name: Synthetic Reviewer')
        $blobSha = (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifest = [pscustomobject]@{
            retainedTenantArtifacts = @()
            replacements = @()
            syntheticDataPolicy = [pscustomobject]@{
                reservedNames = @('Synthetic Reviewer')
                reservedDomains = @('example.invalid')
                reservedIdPrefixes = @('synthetic-')
            }
            fileClassifications = @([pscustomobject]@{
                path = 'docs/reviewed-example.md'
                sourceBlobSha256 = $blobSha
                expectedOutputSha256 = ('f' * 64)
                classification = 'ReviewedNonPersonal'
                reason = 'Reviewed narrative.'
            })
        }
        $snapshot = [pscustomobject]@{
            trackedFiles = @([pscustomobject]@{ path = 'docs/reviewed-example.md'; mode = '100644'; blobSha256 = $blobSha })
        }
        {
            Get-CustomerExportAssessment -SourceRoot $TestDrive -ExpectedSourceCommit ('a' * 40) `
                -DestinationRoot (Join-Path ([IO.Path]::GetFullPath($TestDrive)) '..\export-mismatch') `
                -Manifest $manifest -ManifestDigest ('b' * 64) -SourceSnapshot $snapshot `
                -ToolIdentities ([pscustomobject]@{ Git = [pscustomobject]@{ path='C:\Approved\git.exe'; sha256=('c' * 64) } }) `
                -MarkerCatalogProof ([pscustomobject]@{ digest=('d' * 64) }) `
                -GitExecutable ([pscustomobject]@{ path='C:\Approved\git.exe'; sha256=('c' * 64) }) `
                -GitBlobReader ({ param($gitPath,$root,$commit,$path) $bytes }.GetNewClosure())
        } | Should -Throw '*expected output digest*'
    }

    It 'includes the same path only when both source and output digests match exactly' {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes('Reviewer name: Synthetic Reviewer')
        $blobSha = (Get-FileHash -InputStream ([IO.MemoryStream]::new($bytes)) -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifest = [pscustomobject]@{
            retainedTenantArtifacts = @()
            replacements = @()
            syntheticDataPolicy = [pscustomobject]@{
                reservedNames = @('Synthetic Reviewer')
                reservedDomains = @('example.invalid')
                reservedIdPrefixes = @('synthetic-')
            }
            fileClassifications = @([pscustomobject]@{
                path = 'docs/reviewed-example.md'
                sourceBlobSha256 = $blobSha
                expectedOutputSha256 = $blobSha
                classification = 'ReviewedNonPersonal'
                reason = 'Reviewed narrative.'
            })
        }
        $snapshot = [pscustomobject]@{
            trackedFiles = @([pscustomobject]@{ path = 'docs/reviewed-example.md'; mode = '100644'; blobSha256 = $blobSha })
        }
        $assessment = Get-CustomerExportAssessment -SourceRoot $TestDrive -ExpectedSourceCommit ('a' * 40) `
            -DestinationRoot (Join-Path ([IO.Path]::GetFullPath($TestDrive)) '..\export-match') `
            -Manifest $manifest -ManifestDigest ('b' * 64) -SourceSnapshot $snapshot `
            -ToolIdentities ([pscustomobject]@{ Git = [pscustomobject]@{ path='C:\Approved\git.exe'; sha256=('c' * 64) } }) `
            -MarkerCatalogProof ([pscustomobject]@{ digest=('d' * 64) }) `
            -GitExecutable ([pscustomobject]@{ path='C:\Approved\git.exe'; sha256=('c' * 64) }) `
            -GitBlobReader ({ param($gitPath,$root,$commit,$path) $bytes }.GetNewClosure())

        @($assessment.copyFiles) | Should -Be @('docs/reviewed-example.md')
        $assessment.fileDigests.'docs/reviewed-example.md'.expectedOutputSha256 | Should -Be $blobSha
    }
}
