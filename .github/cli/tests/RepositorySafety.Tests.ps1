BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:validatorPath = Join-Path $script:repositoryRoot '.github\cli\verify-repository-safety.ps1'
    $script:gitPath = @(
        (Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source,
        'C:\Program Files\Git\cmd\git.exe'
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
    if (-not $script:gitPath) {
        throw 'git.exe is required for RepositorySafety.Tests.ps1.'
    }

    function script:New-SafetyFixture {
        param(
            [string]$Content = 'Write-Output ''safe''',
            [string]$WorkflowContent = @'
steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
'@,
            [string]$ManifestContent = @'
{
    "schemaVersion": "1.0",
    "actions": {
        "actions/checkout": {
            "sourceRef": "v7.0.1",
            "sha": "3d3c42e5aac5ba805825da76410c181273ba90b1"
        }
    }
}
'@
        )

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $scriptRoot = Join-Path $root 'infra\src\scripts'
        $workflowRoot = Join-Path $root '.github\workflows'
        $manifestRoot = Join-Path $root 'infra\src\config\github'
        $tenantConfigRoot = Join-Path $root 'infra\src\config\tenants'
        $discoveryRoot = Join-Path $root 'infra\evidence\discovery'
        [void](New-Item -ItemType Directory -Path $scriptRoot -Force)
        [void](New-Item -ItemType Directory -Path $workflowRoot -Force)
        [void](New-Item -ItemType Directory -Path $manifestRoot -Force)
        [void](New-Item -ItemType Directory -Path $tenantConfigRoot -Force)
        [void](New-Item -ItemType Directory -Path $discoveryRoot -Force)
        [IO.File]::WriteAllText((Join-Path $scriptRoot 'Example.ps1'), $Content, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $workflowRoot 'validate.yml'), $WorkflowContent, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $manifestRoot 'action-pins.json'), $ManifestContent, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText(
            (Join-Path $tenantConfigRoot '_template.psd1'),
            "@{ SchemaVersion = '1.0' }",
            [Text.UTF8Encoding]::new($false)
        )
        Copy-Item -LiteralPath (
            Join-Path $script:repositoryRoot 'infra\src\config\tenants\caldova25668747.psd1'
        ) -Destination $tenantConfigRoot
        Copy-Item -LiteralPath (
            Join-Path $script:repositoryRoot 'infra\evidence\discovery\caldova25668747.json'
        ) -Destination $discoveryRoot

        & $script:gitPath -C $root init --quiet
        if ($LASTEXITCODE -ne 0) {
            throw 'Cannot initialize repository safety fixture.'
        }
        & $script:gitPath -C $root add -- `
            '.github/workflows/validate.yml' `
            'infra/src/config/github/action-pins.json' `
            'infra/src/scripts/Example.ps1' `
            'infra/evidence/discovery/caldova25668747.json' `
            'infra/src/config/tenants/_template.psd1' `
            'infra/src/config/tenants/caldova25668747.psd1'
        if ($LASTEXITCODE -ne 0) {
            throw 'Cannot stage reviewed tenant boundary in repository safety fixture.'
        }
        $root
    }

    function script:Get-TestContentFingerprint {
        param([Parameter(Mandatory)][string]$Value)

        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes($Value.Trim().ToLowerInvariant())
            ([BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
        }
        finally {
            $sha256.Dispose()
        }
    }
}

Describe 'Core repository safety validation' {
    It 'treats PDF corpus files as binary on every Git installation' {
        $pdfPath = 'hr/docs/ideas/uc-0001-personal-master-data-completion-agent/gf-aib-fixed-template/documents/a-personalblatt/a01-CAND-2026-0411-brunner.pdf'

        $attributes = @(
            & $script:gitPath -C $script:repositoryRoot check-attr text diff merge -- $pdfPath
        )

        $LASTEXITCODE | Should -Be 0
        $attributes | Should -Contain "$pdfPath`: text: unset"
        $attributes | Should -Contain "$pdfPath`: diff: unset"
        $attributes | Should -Contain "$pdfPath`: merge: unset"
    }

    It 'resolves its own repository root when invoked without -RepositoryRoot' {
        # The CI workflow step runs this script via `-File` with no
        # -RepositoryRoot argument, which exercises the parameter default
        # value in a way that `& $script:validatorPath -RepositoryRoot ...`
        # calls elsewhere in this file do not. Regression test for
        # ParameterArgumentValidationErrorEmptyStringNotAllowed on $PSScriptRoot.
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $script:validatorPath 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 0
        $output | Should -Contain 'Repository safety validation passed.'
    }

    It 'accepts scripts and workflows without deployment execution or credentials' {
        $script:validatorPath | Should -Exist
        $fixtureRoot = New-SafetyFixture

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot)

        $output | Should -Be @('Repository safety validation passed.')
    }

    It 'ignores an active-source path that is tracked for deletion and absent from the worktree' {
        $fixtureRoot = New-SafetyFixture
        Remove-Item -LiteralPath (Join-Path $fixtureRoot 'infra\src\scripts\Example.ps1') -Force

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot)

        $output | Should -Be @('Repository safety validation passed.')
    }

    It 'rejects protected Tenant 1 payload in tracked active source without disclosing it' {
        $protectedValue = 'synthetic-protected-tenant-fixture'
        $protectedFingerprint = Get-TestContentFingerprint -Value $protectedValue
        $fixtureRoot = New-SafetyFixture -Content ("`$tenantId = '{0}'" -f $protectedValue)

        $output = @(
            & $script:validatorPath `
                -RepositoryRoot $fixtureRoot `
                -AdditionalProtectedTenantPayloadFingerprint $protectedFingerprint 2>&1 |
                ForEach-Object { $_.ToString() }
        )

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" |
            Should -Match 'Protected Tenant 1 payload fingerprint found: infra/src/scripts/Example\.ps1'
        $output -join "`n" | Should -Not -Match ([regex]::Escape($protectedValue))
    }

    It 'rejects prohibited bootstrap content' -TestCases @(
        @{ Content = 'az deployment sub create --location switzerlandnorth' }
        @{ Content = 'New-AzSubscriptionDeployment -Location switzerlandnorth' }
        @{ Content = 'AZURE_CLIENT_SECRET=not-a-real-secret' }
        @{ Content = '--password not-a-real-password' }
    ) {
        param([string]$Content)

        $fixtureRoot = New-SafetyFixture -Content $Content
        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match 'Prohibited bootstrap command or credential pattern found'
    }

    It 'rejects workstation security-policy weakening' -TestCases @(
        @{ Content = 'Set-ExecutionPolicy Unrestricted -Force' }
        @{ Content = 'Set-MpPreference -DisableRealtimeMonitoring $true' }
        @{ Content = 'Start-Process powershell.exe -Verb RunAs' }
    ) {
        param([string]$Content)

        $fixtureRoot = New-SafetyFixture -Content $Content
        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object ToString)
        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match 'Prohibited bootstrap command or credential pattern found'
    }

    It 'scans every repository workflow' {
        $fixtureRoot = New-SafetyFixture
        $workflowPath = Join-Path $fixtureRoot '.github\workflows\other.yml'
        [IO.File]::WriteAllText($workflowPath, 'run: command --password not-a-real-password', [Text.UTF8Encoding]::new($false))

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match 'other\.yml'
    }

    It 'accepts exact external pins and ignores repository-local actions' {
        $fixtureRoot = New-SafetyFixture -WorkflowContent @'
steps:
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
  - uses: ./.github/actions/local
'@

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot)

        $output | Should -Be @('Repository safety validation passed.')
    }

    It 'allows only the template and exact preserved Tenant 2 files in tracked tenant boundaries' {
        $tracked = @(& $script:gitPath -C $script:repositoryRoot ls-files -- `
            'infra/src/config/tenants/*.psd1' 'infra/evidence/discovery/*.json')
        $tracked | Should -Be @(
            'infra/evidence/discovery/caldova25668747.json'
            'infra/src/config/tenants/_template.psd1'
            'infra/src/config/tenants/caldova25668747.psd1'
        )
        & $script:gitPath -C $script:repositoryRoot ls-files -- 'infra/src/config/tenants/*.local.psd1' |
            Should -BeNullOrEmpty

        (& $script:gitPath -C $script:repositoryRoot hash-object -- `
            'infra/src/config/tenants/caldova25668747.psd1').Trim() |
            Should -BeExactly 'f4b2dfed2f42d1d9d95d51dddaeaaedf4d8b6dce'
        (& $script:gitPath -C $script:repositoryRoot hash-object -- `
            'infra/evidence/discovery/caldova25668747.json').Trim() |
            Should -BeExactly 'c2d4d66f4f812fc449752c275845fac5a713915e'
    }

    It 'rejects an unreviewed tracked tenant boundary artifact at <RelativePath>' -TestCases @(
        @{
            RelativePath = 'infra/src/config/tenants/tenant1.local.psd1'
            Expected = 'Tracked tenant configuration/evidence inventory is not the reviewed lean boundary.'
        }
        @{
            RelativePath = 'infra/src/config/tenants/another.psd1'
            Expected = 'Tracked tenant configuration/evidence inventory is not the reviewed lean boundary.'
        }
        @{
            RelativePath = 'infra/evidence/discovery/another.json'
            Expected = 'Tracked tenant configuration/evidence inventory is not the reviewed lean boundary.'
        }
    ) {
        param([string]$RelativePath, [string]$Expected)

        $fixtureRoot = New-SafetyFixture
        $path = Join-Path $fixtureRoot $RelativePath.Replace('/', '\')
        [IO.File]::WriteAllText($path, 'unreviewed', [Text.UTF8Encoding]::new($false))
        & $script:gitPath -C $fixtureRoot add -- $RelativePath
        $LASTEXITCODE | Should -Be 0

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match ([regex]::Escape($Expected))
    }

    It 'rejects a changed protected Tenant 2 blob at <RelativePath>' -TestCases @(
        @{ RelativePath = 'infra/src/config/tenants/caldova25668747.psd1' }
        @{ RelativePath = 'infra/evidence/discovery/caldova25668747.json' }
    ) {
        param([string]$RelativePath)

        $fixtureRoot = New-SafetyFixture
        $path = Join-Path $fixtureRoot $RelativePath.Replace('/', '\')
        [IO.File]::WriteAllText($path, 'changed', [Text.UTF8Encoding]::new($false))
        & $script:gitPath -C $fixtureRoot add -- $RelativePath
        $LASTEXITCODE | Should -Be 0

        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" |
            Should -Match ([regex]::Escape("Protected Tenant 2 blob changed: $RelativePath"))
    }

    It 'rejects <Reason>' -TestCases @(
        @{
            Reason = 'an unknown external action'
            WorkflowContent = 'steps:
  - uses: owner/unknown@1111111111111111111111111111111111111111'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"},"owner/known":{"sourceRef":"v1.0.0","sha":"2222222222222222222222222222222222222222"}}}'
            Expected = 'Unknown external action owner/unknown'
        }
        @{
            Reason = 'a mutable action reference'
            WorkflowContent = 'steps:
  - uses: actions/checkout@v7'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"}}}'
            Expected = 'must use a lowercase 40-character SHA'
        }
        @{
            Reason = 'a mismatched action SHA'
            WorkflowContent = 'steps:
  - uses: actions/checkout@1111111111111111111111111111111111111111'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"}}}'
            Expected = 'does not match reviewed SHA'
        }
        @{
            Reason = 'an unused manifest entry'
            WorkflowContent = 'steps:
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'
            ManifestContent = '{"schemaVersion":"1.0","actions":{"actions/checkout":{"sourceRef":"v7.0.1","sha":"3d3c42e5aac5ba805825da76410c181273ba90b1"},"owner/unused":{"sourceRef":"v1.0.0","sha":"2222222222222222222222222222222222222222"}}}'
            Expected = 'Manifest action is unused: owner/unused'
        }
    ) {
        param([string]$WorkflowContent, [string]$ManifestContent, [string]$Expected)

        $fixtureRoot = New-SafetyFixture -WorkflowContent $WorkflowContent -ManifestContent $ManifestContent
        $output = @(& $script:validatorPath -RepositoryRoot $fixtureRoot 2>&1 | ForEach-Object { $_.ToString() })

        $LASTEXITCODE | Should -Be 1
        $output -join "`n" | Should -Match ([regex]::Escape($Expected))
    }

    It 'resolves its repository root when invoked without parameters' {
        $powershell = Get-Command powershell.exe -CommandType Application | Select-Object -First 1
        $process = Start-Process -FilePath $powershell.Source -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $script:validatorPath)
        ) -WorkingDirectory $TestDrive -Wait -PassThru -NoNewWindow

        $process.ExitCode | Should -Be 0
    }
}