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
    [IO.Directory]::CreateDirectory((Join-Path $source '.git\logs\refs\heads')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $source '.github\workflows')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $source '.git\index'), 'synthetic-index', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $source '.git\logs\HEAD'), 'synthetic-head-log', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $source '.git\logs\refs\heads\main'), 'synthetic-main-log', [Text.UTF8Encoding]::new($false))

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
        if ($argsText -match 'rev-parse --git-common-dir') { return [pscustomobject]@{ exitCode = 0; stdout = (Join-Path $source '.git'); stderr = '' } }
        if ($argsText -match 'rev-parse --git-path index') { return [pscustomobject]@{ exitCode = 0; stdout = (Join-Path $source '.git\index'); stderr = '' } }
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
        if ($argsText -match 'cat-file --batch-all-objects') {
            return [pscustomobject]@{
                exitCode = 0
                stdout = @(
                    "$('1' * 40) blob 13",
                    "$('2' * 40) blob 29",
                    "$('3' * 40) blob 77"
                ) -join [Environment]::NewLine
                stderr = ''
            }
        }
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

function script:Get-ApprovedGitPath {
    foreach ($candidate in @(
        'C:\Program Files\Git\cmd\git.exe',
        (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
    )) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }

    throw 'git.exe is required for production-default customer export tests.'
}

function script:New-RealGitCustomerExportFixture {
    $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    $source = Join-Path $root 'source'
    $report = Join-Path $root 'report'
    $destination = Join-Path $root 'export'
    [IO.Directory]::CreateDirectory($source) | Out-Null
    $git = Get-ApprovedGitPath

    $tenantPath = Join-Path $source 'infra\src\config\tenants\customer-synthetic.json'
    $readmePath = Join-Path $source 'README.md'
    [IO.Directory]::CreateDirectory((Split-Path $tenantPath -Parent)) | Out-Null
    [IO.File]::WriteAllText($tenantPath, '{"tenantAlias":"source-lab"}', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($readmePath,
        "Owner: Source Reference Organization`r`nContact Source Reference Organization`r`n",
        [Text.UTF8Encoding]::new($false))

    & $git -C $source init --quiet | Out-Null
    & $git -C $source config user.name 'Synthetic Tester' | Out-Null
    & $git -C $source config user.email 'synthetic.tester@example.invalid' | Out-Null
    & $git -C $source config core.autocrlf false | Out-Null
    & $git -C $source add . | Out-Null
    & $git -C $source commit --quiet -m 'Synthetic export fixture' | Out-Null
    $gitCommit = (& $git -C $source rev-parse HEAD).Trim().ToLowerInvariant()
    $powershellPath = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Source)
    $azureCliPath = @(
        Get-Command az.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
        Get-Command az.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($azureCliPath)) {
        $azureCliPath = $powershellPath
    }

    $tenantDigest = (Get-FileHash -LiteralPath $tenantPath -Algorithm SHA256).Hash.ToLowerInvariant()
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

    [pscustomobject]@{
        Source = $source
        Destination = $destination
        Report = $report
        ManifestPath = $manifestPath
        ExpectedSourceCommit = $gitCommit
        CommandResolver = {
            param($name)
            switch ($name) {
                'git.exe' { @($git) }
                'powershell.exe' { @($powershellPath) }
                'az.cmd' { @($azureCliPath) }
                default { @() }
            }
        }.GetNewClosure()
        FileIdentityProvider = {
            param($path)
            [pscustomobject]@{
                path = [IO.Path]::GetFullPath($path)
                sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
        InteractiveHostProbe = { [pscustomobject]@{ isInteractive = $true; reason = 'InteractiveWindows11PowerShell' } }
        PlatformProbe = { [pscustomobject]@{ productName = 'Windows 11'; build = 26100 } }
        OperatorIdProvider = { 'SYNTHETIC\operator' }
        ValidationRunner = { param($id,$file,$arguments,$root) [pscustomobject]@{ suite = $id; executablePath = $file; exitCode = 0; status = 'Passed' } }
    }
}

function script:Invoke-CustomerExportIdentityGateHostCase {
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$HostPath,
        [Parameter(Mandatory)][object]$Fixture,
        [Parameter(Mandatory)][ValidateSet('CanonicalPathMismatch','Sha256Mismatch','AmbiguousResolution','InvalidStructure','InvalidDigest')]
        [string]$Scenario
    )

    $sourceManifestPath = Join-Path $Fixture.Report 'customer-export-execution-manifest.json'
    $executionManifest = Get-Content -Raw -LiteralPath $sourceManifestPath | ConvertFrom-Json
    $approvedDigest = [string]$executionManifest.digest
    $caseManifestPath = Join-Path $TestDrive "$ScriptName-$Scenario-execution-manifest.json"
    if ($Scenario -eq 'InvalidStructure') {
        $executionManifest.PSObject.Properties.Remove('toolVersions')
        $unsignedManifest = [ordered]@{}
        foreach ($property in $executionManifest.PSObject.Properties) {
            if ($property.Name -cne 'digest') {
                $unsignedManifest[$property.Name] = $property.Value
            }
        }
        $executionManifest.digest = Get-RunbookContentDigest -InputObject $unsignedManifest
        $approvedDigest = [string]$executionManifest.digest
    }
    elseif ($Scenario -eq 'InvalidDigest') {
        $executionManifest.digest = 'f' * 64
        $approvedDigest = [string]$executionManifest.digest
    }
    [IO.File]::WriteAllText(
        $caseManifestPath,
        ($executionManifest | ConvertTo-Json -Depth 30),
        [Text.UTF8Encoding]::new($false)
    )

    $harnessPath = Join-Path $TestDrive "$ScriptName-$Scenario-$([IO.Path]::GetFileNameWithoutExtension($HostPath))-identity-gate.ps1"
    @'
param(
    [Parameter(Mandatory)][string]$ScriptName,
    [Parameter(Mandatory)][string]$ScriptPath,
    [Parameter(Mandatory)][string]$Scenario,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$DestinationRoot,
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$ExecutionManifestPath,
    [Parameter(Mandatory)][string]$ApprovedDigest,
    [Parameter(Mandatory)][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$executionManifest = Get-Content -Raw -LiteralPath $ExecutionManifestPath | ConvertFrom-Json
$approvedTools = if ($executionManifest.PSObject.Properties.Name -contains 'toolVersions') {
    $executionManifest.toolVersions
}
else {
    [pscustomobject]@{
        Git = [pscustomobject]@{ path = 'C:\Approved\git.exe'; sha256 = 'a' * 64 }
        WindowsPowerShell = [pscustomobject]@{ path = 'C:\Approved\powershell.exe'; sha256 = 'b' * 64 }
        AzureCli = [pscustomobject]@{ path = 'C:\Approved\az.cmd'; sha256 = 'c' * 64 }
    }
}
$script:nativeRunnerInvocations = 0
$nativeRunner = {
    param($file, $arguments)
    $script:nativeRunnerInvocations++
    [pscustomobject]@{ exitCode = 0; stdout = 'unexpected invocation'; stderr = '' }
}
$commandResolver = {
    param($name)
    $key = switch ($name) {
        'git.exe' { 'Git' }
        'powershell.exe' { 'WindowsPowerShell' }
        'az.cmd' { 'AzureCli' }
    }
    if ($Scenario -eq 'CanonicalPathMismatch' -and $name -ceq 'git.exe') {
        return @('C:\Unapproved\git.exe')
    }
    if ($Scenario -eq 'AmbiguousResolution' -and $name -ceq 'git.exe') {
        return @([string]$approvedTools.$key.path, 'C:\Second\git.exe')
    }
    @([string]$approvedTools.$key.path)
}.GetNewClosure()
$identityProvider = {
    param($path)
    $key = if ([IO.Path]::GetFileName($path) -ceq 'powershell.exe') {
        'WindowsPowerShell'
    }
    elseif ([IO.Path]::GetFileName($path) -ceq 'az.cmd') {
        'AzureCli'
    }
    else {
        'Git'
    }
    $sha256 = [string]$approvedTools.$key.sha256
    if ($Scenario -eq 'Sha256Mismatch' -and $key -ceq 'Git') {
        $sha256 = if ($sha256 -ceq ('0' * 64)) { '1' * 64 } else { '0' * 64 }
    }
    [pscustomobject]@{ path = [IO.Path]::GetFullPath($path); sha256 = $sha256 }
}.GetNewClosure()
$common = @{
    SourceRoot = $SourceRoot
    DestinationRoot = $DestinationRoot
    ExpectedSourceCommit = $ExpectedSourceCommit
    ManifestPath = $ManifestPath
    ExecutionManifestPath = $ExecutionManifestPath
    ApprovedDigest = $ApprovedDigest
    ReportPath = $ReportPath
    NativeCommandRunner = $nativeRunner
    CommandResolver = $commandResolver
    FileIdentityProvider = $identityProvider
    GitBlobReader = { throw 'Git blob reader must not be reached by the identity gate.' }
    ValidationRunner = { throw 'Validation runner must not be reached by the identity gate.' }
    InteractiveHostProbe = { [pscustomobject]@{ isInteractive = $true; reason = 'InteractiveWindows11PowerShell' } }
    PlatformProbe = { [pscustomobject]@{ productName = 'Windows 11'; build = 26100 } }
    OperatorIdProvider = { 'SYNTHETIC\operator' }
}
$threw = $false
$message = ''
try {
    if ($ScriptName -ceq 'New-CustomerRepositoryExport') {
        & $ScriptPath @common -Apply -Confirm:$false | Out-Null
    }
    else {
        & $ScriptPath @common | Out-Null
    }
}
catch {
    $threw = $true
    $message = $_.Exception.Message
}
[pscustomobject]@{
    threw = $threw
    message = $message
    nativeRunnerInvocations = $script:nativeRunnerInvocations
} | ConvertTo-Json -Compress
'@ | Set-Content -LiteralPath $harnessPath -Encoding UTF8

    $output = @(
        & $HostPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $harnessPath `
            -ScriptName $ScriptName -ScriptPath $ScriptPath -Scenario $Scenario `
            -SourceRoot $Fixture.Source -DestinationRoot $Fixture.Destination `
            -ManifestPath $Fixture.ManifestPath -ExecutionManifestPath $caseManifestPath `
            -ApprovedDigest $approvedDigest -ExpectedSourceCommit $Fixture.ExpectedSourceCommit `
            -ReportPath (Join-Path (Split-Path $Fixture.Report -Parent) "$ScriptName-$Scenario-validation") 2>&1
    )
    $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    ($output -join [Environment]::NewLine) | ConvertFrom-Json
}

Describe 'Customer export pre-execution identity gates across PowerShell hosts' {
    $powerShellHosts = @(
        @{
            HostName = 'Windows PowerShell 5.1'
            HostPath = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop).Source
        }
    )
    $pwsh = Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $pwsh) {
        $powerShellHosts += @{
            HostName = 'PowerShell 7'
            HostPath = $pwsh.Source
        }
    }
    $testCases = foreach ($powerShellHost in $powerShellHosts) {
        foreach ($scriptUnderTest in @(
            @{ ScriptName = 'New-CustomerRepositoryExport'; ScriptPath = $global:CustomerExportEntryPath }
            @{ ScriptName = 'Test-CustomerRepositoryExport'; ScriptPath = $global:CustomerExportValidatorPath }
        )) {
            foreach ($scenario in @('CanonicalPathMismatch','Sha256Mismatch','AmbiguousResolution','InvalidStructure','InvalidDigest')) {
                @{
                    ScriptName = $scriptUnderTest.ScriptName
                    ScriptPath = $scriptUnderTest.ScriptPath
                    HostName = $powerShellHost.HostName
                    HostPath = $powerShellHost.HostPath
                    Scenario = $scenario
                }
            }
        }
    }

    BeforeAll {
        $script:identityGateFixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $script:identityGateFixture.Source `
            -ExpectedSourceCommit $script:identityGateFixture.ExpectedSourceCommit `
            -DestinationRoot $script:identityGateFixture.Destination -ManifestPath $script:identityGateFixture.ManifestPath `
            -ReportPath $script:identityGateFixture.Report -NativeCommandRunner $script:identityGateFixture.NativeCommandRunner `
            -CommandResolver $script:identityGateFixture.CommandResolver `
            -FileIdentityProvider $script:identityGateFixture.FileIdentityProvider `
            -GitBlobReader $script:identityGateFixture.GitBlobReader `
            -ValidationRunner $script:identityGateFixture.ValidationRunner `
            -InteractiveHostProbe $script:identityGateFixture.InteractiveHostProbe `
            -PlatformProbe $script:identityGateFixture.PlatformProbe `
            -OperatorIdProvider $script:identityGateFixture.OperatorIdProvider | Out-Null
    }

    It '<ScriptName> rejects <Scenario> before native execution in <HostName>' -TestCases $testCases {
        param($ScriptName, $ScriptPath, $HostName, $HostPath, $Scenario)

        $result = Invoke-CustomerExportIdentityGateHostCase -ScriptName $ScriptName -ScriptPath $ScriptPath `
            -HostPath $HostPath -Fixture $script:identityGateFixture -Scenario $Scenario
        $result.threw | Should -BeTrue -Because "$ScriptName must reject $Scenario in $HostName"
        $result.nativeRunnerInvocations | Should -Be 0 -Because "$ScriptName must reject $Scenario before native execution in $HostName"
    }
}

Describe 'Customer export production default native command runners' {
    $powerShellHosts = @(
        @{
            HostName = 'Windows PowerShell 5.1'
            HostPath = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop).Source
            EnableNativeErrorPreference = $false
        }
    )
    $pwsh = Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $pwsh) {
        $powerShellHosts += @{
            HostName = 'PowerShell 7'
            HostPath = $pwsh.Source
            EnableNativeErrorPreference = $true
        }
    }
    $testCases = foreach ($powerShellHost in $powerShellHosts) {
        foreach ($scriptUnderTest in @(
            @{ ScriptName = 'New-CustomerRepositoryExport'; ScriptPath = $global:CustomerExportEntryPath }
            @{ ScriptName = 'Test-CustomerRepositoryExport'; ScriptPath = $global:CustomerExportValidatorPath }
        )) {
            @{
                ScriptName = $scriptUnderTest.ScriptName
                ScriptPath = $scriptUnderTest.ScriptPath
                HostName = $powerShellHost.HostName
                HostPath = $powerShellHost.HostPath
                EnableNativeErrorPreference = $powerShellHost.EnableNativeErrorPreference
            }
        }
    }

    It '<ScriptName> returns exact nonzero Git stderr in <HostName> without terminating' -TestCases $testCases {
        param($ScriptName, $ScriptPath, $HostPath, $EnableNativeErrorPreference)

        $fixture = New-RealGitCustomerExportFixture
        $harnessPath = Join-Path $TestDrive "$ScriptName-$([IO.Path]::GetFileNameWithoutExtension($HostPath))-default-runner.ps1"
        @'
param(
    [Parameter(Mandatory)][string]$ProductionScriptPath,
    [Parameter(Mandatory)][string]$GitPath,
    [Parameter(Mandatory)][string]$RepositoryRoot,
    [switch]$EnableNativeErrorPreference
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($EnableNativeErrorPreference) {
    $PSNativeCommandUseErrorActionPreference = $true
}
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $ProductionScriptPath,
    [ref]$tokens,
    [ref]$errors
)
if ($errors.Count -ne 0) { throw "Could not parse production script '$ProductionScriptPath'." }
$functionAst = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'New-DefaultNativeCommandRunner'
}, $true))[0]
. ([scriptblock]::Create($functionAst.Extent.Text))
$runner = New-DefaultNativeCommandRunner
$result = & $runner $GitPath @('-C', $RepositoryRoot, 'sparse-checkout', 'list')
[pscustomobject]@{
    result = $result
    nativeErrorPreference = if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {
        $PSNativeCommandUseErrorActionPreference
    } else {
        $null
    }
} | ConvertTo-Json -Compress
'@ | Set-Content -LiteralPath $harnessPath -Encoding UTF8

        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $arguments = @(
                '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $harnessPath,
                '-ProductionScriptPath', $ScriptPath, '-GitPath', (Get-ApprovedGitPath),
                '-RepositoryRoot', $fixture.Source
            )
            if ($EnableNativeErrorPreference) { $arguments += '-EnableNativeErrorPreference' }
            $output = @(& $HostPath @arguments 2>&1)
            $processExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $processExitCode | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        $harnessResult = ($output -join [Environment]::NewLine) | ConvertFrom-Json
        $result = $harnessResult.result
        $result.exitCode | Should -Not -Be 0
        $result.stdout | Should -Be 'fatal: this worktree is not sparse'
        $result.stderr | Should -Be ''
        if ($EnableNativeErrorPreference) {
            $harnessResult.nativeErrorPreference | Should -BeTrue
        }
    }
}

Describe 'New-CustomerRepositoryExport gates' {
    It 'never executes a manifest-supplied Git path before approval validation' {
        foreach ($scriptName in @('New-CustomerRepositoryExport', 'Test-CustomerRepositoryExport')) {
            $fixture = New-CustomerExportFixture
            & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
                -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
                -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
                -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
                -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
                -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

            $executionManifestPath = Join-Path $fixture.Report 'customer-export-execution-manifest.json'
            $executionManifest = Get-Content -Raw -LiteralPath $executionManifestPath | ConvertFrom-Json
            $executionManifest.toolVersions.Git.path = 'C:\Malicious\payload.exe'
            $unsignedManifest = [ordered]@{}
            foreach ($property in $executionManifest.PSObject.Properties) {
                if ($property.Name -cne 'digest') {
                    $unsignedManifest[$property.Name] = $property.Value
                }
            }
            $executionManifest.digest = Get-RunbookContentDigest -InputObject $unsignedManifest
            $approvedDigest = [string]$executionManifest.digest
            [IO.File]::WriteAllText(
                $executionManifestPath,
                ($executionManifest | ConvertTo-Json -Depth 30),
                [Text.UTF8Encoding]::new($false)
            )
            $calls = [Collections.Generic.List[string]]::new()
            $fixtureRunner = $fixture.NativeCommandRunner
            $recordingRunner = {
                param($file, $arguments)
                [void]$calls.Add([string]$file)
                & $fixtureRunner $file $arguments
            }.GetNewClosure()

            $common = @{
                SourceRoot = $fixture.Source
                ExpectedSourceCommit = $fixture.ExpectedSourceCommit
                DestinationRoot = $fixture.Destination
                ManifestPath = $fixture.ManifestPath
                ExecutionManifestPath = $executionManifestPath
                ApprovedDigest = $approvedDigest
                NativeCommandRunner = $recordingRunner
                CommandResolver = $fixture.CommandResolver
                FileIdentityProvider = $fixture.FileIdentityProvider
                GitBlobReader = $fixture.GitBlobReader
                ValidationRunner = $fixture.ValidationRunner
                InteractiveHostProbe = $fixture.InteractiveHostProbe
                PlatformProbe = $fixture.PlatformProbe
                OperatorIdProvider = $fixture.OperatorIdProvider
            }
            if ($scriptName -eq 'New-CustomerRepositoryExport') {
                $common.ReportPath = $fixture.Report
                { & $global:CustomerExportEntryPath @common -Apply -Confirm:$false } |
                    Should -Throw '*executable identity changed*'
            }
            else {
                $common.ReportPath = Join-Path (Split-Path $fixture.Report -Parent) 'validation'
                { & $global:CustomerExportValidatorPath @common } |
                    Should -Throw '*executable identity changed*'
            }
            $calls.Count | Should -Be 0
        }
    }

    It 'plans with the production default Git blob reader' {
        $fixture = New-RealGitCustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -CommandResolver $fixture.CommandResolver -FileIdentityProvider $fixture.FileIdentityProvider `
            -InteractiveHostProbe $fixture.InteractiveHostProbe -PlatformProbe $fixture.PlatformProbe `
            -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        Test-Path (Join-Path $fixture.Report 'customer-export-assessment.json') | Should -BeTrue
    }

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

    It 'applies with the production default validation runner' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -InteractiveHostProbe $fixture.InteractiveHostProbe -PlatformProbe $fixture.PlatformProbe `
            -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        $approvedDigest = (Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest

        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -Apply -Confirm:$false `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -InteractiveHostProbe $fixture.InteractiveHostProbe -PlatformProbe $fixture.PlatformProbe `
            -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        Test-Path (Join-Path $fixture.Destination 'README.md') | Should -BeTrue
    }
}

Describe 'Test-CustomerRepositoryExport validator' {
    It 'uses the production default validation suite mapping' {
        $fixture = New-CustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -InteractiveHostProbe $fixture.InteractiveHostProbe -PlatformProbe $fixture.PlatformProbe `
            -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        $approvedDigest = (Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -Apply -Confirm:$false `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -InteractiveHostProbe $fixture.InteractiveHostProbe -PlatformProbe $fixture.PlatformProbe `
            -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        $result = & $global:CustomerExportValidatorPath -SourceRoot $fixture.Source -DestinationRoot $fixture.Destination `
            -ExpectedSourceCommit $fixture.ExpectedSourceCommit -ManifestPath $fixture.ManifestPath `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -ReportPath (Join-Path (Split-Path $fixture.Report -Parent) 'validation-suite-map') `
            -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
            -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
            -InteractiveHostProbe $fixture.InteractiveHostProbe -PlatformProbe $fixture.PlatformProbe `
            -OperatorIdProvider $fixture.OperatorIdProvider

        (@($result.suiteResults | Where-Object suite -eq 'Pester')[0]).executablePath | Should -Be 'C:\Approved\powershell.exe'
        (@($result.suiteResults | Where-Object suite -eq 'RepositorySafety')[0]).executablePath | Should -Be 'C:\Approved\powershell.exe'
        (@($result.suiteResults | Where-Object suite -eq 'BicepBuild')[0]).executablePath | Should -Be 'C:\Approved\az.cmd'
    }

    It 'uses the production default Git blob reader' {
        $fixture = New-RealGitCustomerExportFixture
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -CommandResolver $fixture.CommandResolver -FileIdentityProvider $fixture.FileIdentityProvider `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null
        $approvedDigest = (Get-Content -Raw (Join-Path $fixture.Report 'customer-export-execution-manifest.json') | ConvertFrom-Json).digest
        & $global:CustomerExportEntryPath -SourceRoot $fixture.Source -ExpectedSourceCommit $fixture.ExpectedSourceCommit `
            -DestinationRoot $fixture.Destination -ManifestPath $fixture.ManifestPath -ReportPath $fixture.Report `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -Apply -Confirm:$false `
            -CommandResolver $fixture.CommandResolver -FileIdentityProvider $fixture.FileIdentityProvider `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider | Out-Null

        $result = & $global:CustomerExportValidatorPath -SourceRoot $fixture.Source -DestinationRoot $fixture.Destination `
            -ExpectedSourceCommit $fixture.ExpectedSourceCommit -ManifestPath $fixture.ManifestPath `
            -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
            -ApprovedDigest $approvedDigest -ReportPath (Join-Path (Split-Path $fixture.Report -Parent) 'validation-default-git') `
            -CommandResolver $fixture.CommandResolver -FileIdentityProvider $fixture.FileIdentityProvider `
            -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
            -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider

        $result.publishReady | Should -BeTrue
    }

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

        $validationReport = Join-Path (Split-Path $fixture.Report -Parent) 'validation-3'
        {
            & $global:CustomerExportValidatorPath -SourceRoot $fixture.Source -DestinationRoot $fixture.Destination `
                -ExpectedSourceCommit $fixture.ExpectedSourceCommit -ManifestPath $fixture.ManifestPath `
                -ExecutionManifestPath (Join-Path $fixture.Report 'customer-export-execution-manifest.json') `
                -ApprovedDigest $approvedDigest -ReportPath $validationReport `
                -NativeCommandRunner $fixture.NativeCommandRunner -CommandResolver $fixture.CommandResolver `
                -FileIdentityProvider $fixture.FileIdentityProvider -GitBlobReader $fixture.GitBlobReader `
                -ValidationRunner $fixture.ValidationRunner -InteractiveHostProbe $fixture.InteractiveHostProbe `
                -PlatformProbe $fixture.PlatformProbe -OperatorIdProvider $fixture.OperatorIdProvider
        } | Should -Throw '*publish-ready*'
        $result = Get-Content -Raw (Join-Path $validationReport 'customer-export-validation.json') | ConvertFrom-Json
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

    It 'documents the attended handover runbook and script links' {
        $path = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))) 'infra\docs\runbooks\03-customer-handover.md'
        $path | Should -Exist
        $content = Get-Content -Raw -LiteralPath $path
        foreach ($heading in @(
            'Purpose','Roles and prerequisites','Assessment and shared execution manifest','Approve the digest',
            'Apply with ShouldProcess','Independent validation','Human review','Publication boundary',
            'Evidence','Failure and recovery','Definition of Done'
        )) {
            $content | Should -Match ("(?m)^## {0}\r?$" -f [regex]::Escape($heading))
        }
        foreach ($literal in @(
            'New-CustomerRepositoryExport.ps1','Test-CustomerRepositoryExport.ps1',
            'customer-export-assessment.json','customer-export-execution-manifest.json',
            'customer-export-evidence.json','customer-export-validation.json',
            'customer-export-validation-evidence.json'
        )) {
            $content | Should -Match ([regex]::Escape($literal))
        }
    }
}
