Set-StrictMode -Version Latest

$global:CustomerExportEntryPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\New-CustomerRepositoryExport.ps1'
$global:CustomerExportValidatorPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Test-CustomerRepositoryExport.ps1'

function script:New-CustomerExportFixture {
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'
    $report = Join-Path $root 'report'
    $destination = Join-Path $root 'export'
    [IO.Directory]::CreateDirectory($source) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $source '.git\hooks')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $source '.github\workflows')) | Out-Null

    $tenantPath = Join-Path $source 'infra\src\config\tenants\customer-synthetic.json'
    $readmePath = Join-Path $source 'README.md'
    [IO.Directory]::CreateDirectory((Split-Path $tenantPath -Parent)) | Out-Null
    [IO.File]::WriteAllText($tenantPath, '{"tenantAlias":"source-lab"}', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($readmePath,
        "Owner: Source Reference Organization`r`nContact Source Reference Organization`r`n",
        [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $source '.github\workflows\sentinel.yml'), 'name: sentinel', [Text.UTF8Encoding]::new($false))

    $tenantBytes = [IO.File]::ReadAllBytes($tenantPath)
    $tenantDigest = (Get-FileHash -LiteralPath $tenantPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $readmeBytes = [IO.File]::ReadAllBytes($readmePath)
    $readmeDigest = (Get-FileHash -LiteralPath $readmePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $readmeExpected = [Text.UTF8Encoding]::new($false).GetBytes(
        "Owner: Customer Example Organization`r`nContact Customer Example Organization`r`n")
    $readmeExpectedDigest = (Get-FileHash -InputStream ([IO.MemoryStream]::new($readmeExpected)) -Algorithm SHA256).Hash.ToLowerInvariant()

    $manifestPath = Join-Path $root 'customer-export.json'
    $manifest = @"
{
  "schemaVersion": "1.0",
  "tenantAlias": "source-lab",
  "customerScope": "Synthetic export",
  "retainedTenantArtifacts": [
    {
      "path": "infra/src/config/tenants/customer-synthetic.json",
      "artifactKind": "TenantManifest",
      "customerScope": "Synthetic target tenant intent"
    }
  ],
  "replacements": [
    {
      "id": "tenant-alias-json",
      "path": "infra/src/config/tenants/customer-synthetic.json",
      "format": "Json",
      "selector": "/tenantAlias",
      "expectedOldValue": "source-lab",
      "newValue": "customer-synthetic",
      "requiredCount": 1
    },
    {
      "id": "customer-name-readme",
      "path": "README.md",
      "format": "MarkdownExact",
      "expectedOldText": "Source Reference Organization",
      "newText": "Customer Example Organization",
      "requiredCount": 2
    }
  ],
  "residualMarkers": [
    { "id": "source-alias", "category": "TenantAlias", "value": "source-lab", "comparison": "OrdinalIgnoreCase" },
    { "id": "source-customer-name", "category": "CompanyName", "value": "Source Reference Organization", "comparison": "Ordinal" }
  ],
  "sourceMarkerCatalog": [
    {
      "id": "source-alias",
      "category": "TenantAlias",
      "value": "source-lab",
      "comparison": "OrdinalIgnoreCase",
      "sources": [ { "path": "infra/src/config/tenants/customer-synthetic.json", "blobSha256": "$tenantDigest", "occurrenceCount": 1 } ]
    },
    {
      "id": "source-customer-name",
      "category": "CompanyName",
      "value": "Source Reference Organization",
      "comparison": "Ordinal",
      "sources": [ { "path": "README.md", "blobSha256": "$readmeDigest", "occurrenceCount": 2 } ]
    }
  ],
  "residualDispositions": [],
  "syntheticDataPolicy": {
    "reservedNames": [ "Customer Example Organization", "Synthetic Reviewer" ],
    "reservedDomains": [ "example.com", "example.org", "example.net", "example.invalid" ],
    "reservedIdPrefixes": [ "synthetic-" ]
  },
  "fileClassifications": [
    {
      "path": "README.md",
      "sourceBlobSha256": "$readmeDigest",
      "expectedOutputSha256": "$readmeExpectedDigest",
      "classification": "ReviewedNonPersonal",
      "reason": "Repository introduction contains organization names only."
    }
  ],
  "inspectableBinaries": [],
  "validationSuites": [ "Pester", "RepositorySafety", "BicepBuild" ]
}
"@
    [IO.File]::WriteAllText($manifestPath, $manifest, [Text.UTF8Encoding]::new($false))

    $gitCommit = ('a' * 40)
    $tracked = [ordered]@{
        'README.md' = $readmeBytes
        'infra/src/config/tenants/customer-synthetic.json' = $tenantBytes
        '.github/workflows/sentinel.yml' = [Text.UTF8Encoding]::new($false).GetBytes('name: sentinel')
    }
    $runner = {
        param($file, $arguments)
        $argsText = (@($arguments) | ForEach-Object { [string]$_ }) -join ' '
        if ($argsText -match 'status --porcelain=v1 --untracked-files=all') { return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' } }
        if ($argsText -match 'rev-parse HEAD') { return [pscustomobject]@{ exitCode = 0; stdout = $gitCommit; stderr = '' } }
        if ($argsText -match 'rev-parse --show-toplevel') { return [pscustomobject]@{ exitCode = 0; stdout = $source; stderr = '' } }
        if ($argsText -match 'sparse-checkout list') { return [pscustomobject]@{ exitCode = 1; stdout = ''; stderr = '' } }
        if ($argsText -match 'ls-tree -r -z --full-tree HEAD') {
            $entries = @(
                "100644 blob $('1' * 40)`t.github/workflows/sentinel.yml",
                "100644 blob $('2' * 40)`tinfra/src/config/tenants/customer-synthetic.json",
                "100644 blob $('3' * 40)`tREADME.md"
            ) -join [char]0
            return [pscustomobject]@{ exitCode = 0; stdout = $entries + [char]0; stderr = '' }
        }
        if ($argsText -match 'for-each-ref') { return [pscustomobject]@{ exitCode = 0; stdout = "refs/heads/main$([char]0)$gitCommit"; stderr = '' } }
        if ($argsText -match 'remote -v') { return [pscustomobject]@{ exitCode = 0; stdout = "origin https://example.invalid/repo (fetch)`norigin https://example.invalid/repo (push)"; stderr = '' } }
        if ($argsText -match 'config --local --list --null') { return [pscustomobject]@{ exitCode = 0; stdout = "core.repositoryformatversion=0$([char]0)"; stderr = '' } }
        if ($argsText -match '--version') { return [pscustomobject]@{ exitCode = 0; stdout = 'tool version'; stderr = '' } }
        if ($argsText -match '\$PSVersionTable\.PSVersion') { return [pscustomobject]@{ exitCode = 0; stdout = '5.1.26100.6584'; stderr = '' } }
        return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
    }.GetNewClosure()
    $gitReader = {
        param($gitPath, $repositoryRoot, $commit, $path)
        [byte[]]$tracked[$path]
    }.GetNewClosure()
    $resolver = {
        param($name)
        switch ($name) {
            'git.exe' { @('C:\Approved\git.exe') }
            'powershell.exe' { @('C:\Approved\powershell.exe') }
            'az.cmd' { @('C:\Approved\az.cmd') }
            default { @() }
        }
    }
    $identityProvider = {
        param($path)
        [pscustomobject]@{
            path = $path
            sha256 = if ($path -like '*git.exe') { ('a' * 64) } elseif ($path -like '*powershell.exe') { ('b' * 64) } else { ('c' * 64) }
        }
    }
    [pscustomobject]@{
        Source = $source
        Destination = $destination
        Report = $report
        ManifestPath = $manifestPath
        ExpectedSourceCommit = $gitCommit
        NativeCommandRunner = $runner
        GitBlobReader = $gitReader
        CommandResolver = $resolver
        FileIdentityProvider = $identityProvider
        InteractiveHostProbe = { [pscustomobject]@{ isInteractive = $true; reason = 'InteractiveWindows11PowerShell' } }
        PlatformProbe = { [pscustomobject]@{ productName = 'Windows 11'; build = 26100 } }
        OperatorIdProvider = { 'SYNTHETIC\operator' }
        ValidationRunner = { param($id,$file,$arguments,$root) [pscustomobject]@{ suite = $id; executablePath = $file; exitCode = 0 } }
    }
}

Describe 'New-CustomerRepositoryExport gates' {
    It 'plans without creating destination' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider

        Test-Path $fixture.Destination | Should -BeFalse
        Test-Path (Join-Path $fixture.Report 'customer-export-assessment.json') | Should -BeTrue
        Test-Path (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | Should -BeTrue
        $evidence = Get-Content -Raw (Join-Path $fixture.Report 'customer-export-evidence.json') | ConvertFrom-Json
        @($evidence.PSObject.Properties.Name) | Should -Contain 'generatedAtUtc'
        $evidence.sourceCommit | Should -Match '^[0-9a-f]{40}$'
        $evidence.assessmentDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.planDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.manifestDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.operatorId | Should -Be 'SYNTHETIC\operator'
        $evidence.shouldProcessDecision | Should -Be 'NotApplicable'
    }

    It 'does not create staging under WhatIf' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest ((Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest) -Apply -WhatIf -Confirm:$false `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider
        Test-Path $fixture.Destination | Should -BeFalse
        @(Get-ChildItem (Split-Path $fixture.Destination) -Filter '.customer-export-*' -ErrorAction SilentlyContinue).Count | Should -Be 0
    }

    It 'refuses an approval mismatch before writing staging' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        {
            & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
                -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
                -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
                -ApprovedDigest ('f' * 64) -Apply -Confirm:$false `
                -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
                -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
                -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
                -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider
        } | Should -Throw '*approved digest*'
        Test-Path $fixture.Destination | Should -BeFalse
    }

    It 'refuses executable identity drift before the first staging write' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        $identityCalls = [Collections.Generic.List[string]]::new()
        $identityProvider = {
            param($path)
            [void]$identityCalls.Add($path)
            [pscustomobject]@{
                path = $path
                sha256 = if ($identityCalls.Count -le 3) { ('a' * 64) } else { ('b' * 64) }
            }
        }.GetNewClosure()

        {
            & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
                -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
                -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
                -ApprovedDigest ((Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest) `
                -Apply -Confirm:$false -NativeCommandRunner $fixture.NativeCommandRunner `
                -CommandResolver { param($name) @("C:\Approved\$name") } -FileIdentityProvider $identityProvider `
                -GitBlobReader $fixture.GitBlobReader -ValidationRunner $fixture.ValidationRunner `
                -InteractiveHostProbe $fixture.InteractiveHostProbe -PlatformProbe $fixture.PlatformProbe `
                -OperatorIdProvider $fixture.OperatorIdProvider
        } | Should -Throw '*executable identity changed*'
        Test-Path $fixture.Destination | Should -BeFalse
    }
}

Describe 'Test-CustomerRepositoryExport validator' {
    It 'returns publishReady only for a clean export and unchanged source' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        $approvedDigest = (Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -Apply -Confirm:$false `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        $validationReport = Join-Path (Split-Path $fixture.Report -Parent) 'validation'
        $result = & $global:CustomerExportValidatorPath -SourceRoot $fixture.Source -DestinationRoot $fixture.Destination `
            -ExpectedSourceCommit $fixture.ExpectedSourceCommit -ManifestPath $fixture.ManifestPath `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -ReportPath $validationReport `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider
        $result.status | Should -Be 'Passed'
        $result.publishReady | Should -BeTrue
        Test-Path (Join-Path $validationReport 'customer-export-validation.json') | Should -BeTrue
        $evidence = Get-Content -Raw (Join-Path $validationReport 'customer-export-validation-evidence.json') | ConvertFrom-Json
        $evidence.sourceCommit | Should -Match '^[0-9a-f]{40}$'
        $evidence.assessmentDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.planDigest | Should -Be $approvedDigest
        $evidence.manifestDigest | Should -Match '^[0-9a-f]{64}$'
        $evidence.operatorId | Should -Be 'SYNTHETIC\operator'
        $evidence.shouldProcessDecision | Should -Be 'NotApplicable'
    }

    It 'derives replacement proof from original commit bytes and compares the whole staged file' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        $approvedDigest = (Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -Apply -Confirm:$false `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        $original = [Text.UTF8Encoding]::new($false).GetBytes(
            "Owner: Source Reference Organization`r`nContact Source Reference Organization`r`n")
        $expected = [Text.UTF8Encoding]::new($false).GetBytes(
            "Owner: Customer Example Organization`r`nContact Customer Example Organization`r`n")
        $reader = {
            param($gitPath, $root, $commit, $path)
            if ($path -ceq 'README.md') { return $original }
            return & $fixture.GitBlobReader $gitPath $root $commit $path
        }.GetNewClosure()

        $result = & $global:CustomerExportValidatorPath -SourceRoot $fixture.Source -DestinationRoot $fixture.Destination `
            -ExpectedSourceCommit $fixture.ExpectedSourceCommit -ManifestPath $fixture.ManifestPath `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -ReportPath (Join-Path (Split-Path $fixture.Report -Parent) 'validation-2') `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $reader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider

        $result.publishReady | Should -BeTrue
        @($result.replacementLog | Select-Object -ExpandProperty replacementCount) | Should -Contain 2
        [IO.File]::ReadAllBytes((Join-Path $fixture.Destination 'README.md')) | Should -Be $expected
    }

    It 'fails when staged bytes differ outside the reviewed replacement' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        $approvedDigest = (Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -Apply -Confirm:$false `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        [IO.File]::AppendAllText((Join-Path $fixture.Destination 'README.md'), "Unreviewed line`r`n", [Text.UTF8Encoding]::new($false))

        $result = & $global:CustomerExportValidatorPath -SourceRoot $fixture.Source -DestinationRoot $fixture.Destination `
            -ExpectedSourceCommit $fixture.ExpectedSourceCommit -ManifestPath $fixture.ManifestPath `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -ReportPath (Join-Path (Split-Path $fixture.Report -Parent) 'validation-3') `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider
        $result.publishReady | Should -BeFalse
        @($result.failures | Where-Object category -eq 'ExpectedOutputMismatch').Count | Should -Be 1
    }

    It 'fails when the original committed blob does not satisfy the reviewed count' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        $approvedDigest = (Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -Apply -Confirm:$false `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        $wrongOriginal = [Text.UTF8Encoding]::new($false).GetBytes("Owner: Source Reference Organization`r`n")
        $reader = {
            param($gitPath, $root, $commit, $path)
            if ($path -ceq 'README.md') { return $wrongOriginal }
            return & $fixture.GitBlobReader $gitPath $root $commit $path
        }.GetNewClosure()
        {
            & $global:CustomerExportValidatorPath -SourceRoot $fixture.Source -DestinationRoot $fixture.Destination `
                -ExpectedSourceCommit $fixture.ExpectedSourceCommit -ManifestPath $fixture.ManifestPath `
                -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
                -ApprovedDigest $approvedDigest -ReportPath (Join-Path (Split-Path $fixture.Report -Parent) 'validation-4') `
                -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
                -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $reader `
                -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
                -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider
        } | Should -Throw
    }
}
