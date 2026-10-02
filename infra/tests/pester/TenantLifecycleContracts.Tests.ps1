Set-StrictMode -Version Latest

$contractCases = @(
    @{ Name = 'assessment'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; DigestPath = 'digest' }
    @{ Name = 'execution manifest'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; DigestPath = 'digest' }
    @{ Name = 'approval'; Kind = 'Approval'; FixtureProperty = 'approval'; SchemaFile = 'tenant-lifecycle-approval.schema.json'; DigestPath = 'executionManifestDigest' }
    @{ Name = 'action evidence'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; DigestPath = 'preReadDigest' }
    @{ Name = 'state'; Kind = 'State'; FixtureProperty = 'state'; SchemaFile = 'tenant-lifecycle-state.schema.json'; DigestPath = 'resources.ownedPropertiesDigest' }
    @{ Name = 'read-back'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; DigestPath = 'digest' }
    @{ Name = 'summary'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; DigestPath = 'manifestDigest' }
)
$statusCases = @(
    @{ Name = 'assessment provider context'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'providerContexts.0.status' }
    @{ Name = 'assessment component'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'components.0.status' }
    @{ Name = 'assessment prerequisite'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'prerequisites.0.status' }
    @{ Name = 'execution manifest provider context'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'providerContexts.0.status' }
    @{ Name = 'execution manifest prerequisite'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'prerequisites.0.status' }
    @{ Name = 'action evidence'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; FieldPath = 'status' }
    @{ Name = 'read-back component'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; FieldPath = 'components.0.status' }
    @{ Name = 'read-back root'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; FieldPath = 'status' }
    @{ Name = 'summary prerequisite'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'prerequisites.0.status' }
    @{ Name = 'summary action'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'actions.0.status' }
    @{ Name = 'summary root'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'status' }
)
$dateTimeCases = @(
    @{ Name = 'assessment generatedAtUtc'; Kind = 'Assessment'; FixtureProperty = 'assessment'; SchemaFile = 'tenant-lifecycle-assessment.schema.json'; FieldPath = 'generatedAtUtc'; LowercaseValue = '2026-10-02T12:00:00z' }
    @{ Name = 'execution manifest generatedAtUtc'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'generatedAtUtc'; LowercaseValue = '2026-10-02T12:05:00z' }
    @{ Name = 'execution manifest expiresAtUtc'; Kind = 'ExecutionManifest'; FixtureProperty = 'executionManifest'; SchemaFile = 'tenant-lifecycle-execution-manifest.schema.json'; FieldPath = 'expiresAtUtc'; LowercaseValue = '2026-10-02T12:35:00z' }
    @{ Name = 'approval approvedAtUtc'; Kind = 'Approval'; FixtureProperty = 'approval'; SchemaFile = 'tenant-lifecycle-approval.schema.json'; FieldPath = 'approvedAtUtc'; LowercaseValue = '2026-10-02T12:06:00z' }
    @{ Name = 'approval expiresAtUtc'; Kind = 'Approval'; FixtureProperty = 'approval'; SchemaFile = 'tenant-lifecycle-approval.schema.json'; FieldPath = 'expiresAtUtc'; LowercaseValue = '2026-10-02T12:35:00z' }
    @{ Name = 'action evidence startedAtUtc'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; FieldPath = 'startedAtUtc'; LowercaseValue = '2026-10-02T12:07:00z' }
    @{ Name = 'action evidence completedAtUtc'; Kind = 'ActionEvidence'; FixtureProperty = 'actionEvidence'; SchemaFile = 'tenant-lifecycle-action-evidence.schema.json'; FieldPath = 'completedAtUtc'; LowercaseValue = '2026-10-02T12:08:00z' }
    @{ Name = 'state resource lastVerifiedAtUtc'; Kind = 'State'; FixtureProperty = 'state'; SchemaFile = 'tenant-lifecycle-state.schema.json'; FieldPath = 'resources.0.lastVerifiedAtUtc'; LowercaseValue = '2026-10-02T12:09:00z' }
    @{ Name = 'read-back generatedAtUtc'; Kind = 'ReadBack'; FixtureProperty = 'readBack'; SchemaFile = 'tenant-lifecycle-read-back.schema.json'; FieldPath = 'generatedAtUtc'; LowercaseValue = '2026-10-02T12:10:00z' }
    @{ Name = 'summary startedAtUtc'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'startedAtUtc'; LowercaseValue = '2026-10-02T12:00:00z' }
    @{ Name = 'summary completedAtUtc'; Kind = 'Summary'; FixtureProperty = 'summary'; SchemaFile = 'tenant-lifecycle-summary.schema.json'; FieldPath = 'completedAtUtc'; LowercaseValue = '2026-10-02T12:11:00z' }
)
$pythonResult = & python -c 'import jsonschema' 2>&1
$hasJsonSchema = $LASTEXITCODE -eq 0
foreach ($testCase in @($statusCases) + @($dateTimeCases)) {
    $testCase.HasJsonSchema = $hasJsonSchema
}

Describe 'Tenant lifecycle contracts' {
    BeforeAll {
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:ModulePath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:SchemaRoot = Join-Path $script:RepositoryRoot 'infra\src\config\schemas'
        $fixturePath = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:Fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        & python -c 'import jsonschema' 2>&1 | Out-Null
        $script:HasJsonSchema = $LASTEXITCODE -eq 0
        Import-Module $script:ModulePath -Force

        function Copy-ContractObject {
            param([Parameter(Mandatory)][object]$InputObject)
            $InputObject | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        }

        function Invoke-JsonSchemaValidation {
            param(
                [Parameter(Mandatory)][string]$SchemaPath,
                [Parameter(Mandatory)][object]$InputObject
            )
            $json = $InputObject | ConvertTo-Json -Depth 30 -Compress
            $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))
            $program = "import base64,json,jsonschema,sys; schema=json.load(open(sys.argv[1],encoding='utf-8')); instance=json.loads(base64.b64decode(sys.argv[2]).decode('utf-8')); jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker()).validate(instance)"
            $previousErrorActionPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $output = & python -c $program $SchemaPath $encoded 2>&1
                $exitCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }
            [pscustomobject]@{
                ExitCode = $exitCode
                Output = ($output -join [Environment]::NewLine)
            }
        }

        function Set-ContractPropertyValue {
            param(
                [Parameter(Mandatory)][object]$InputObject,
                [Parameter(Mandatory)][string]$PropertyPath,
                [Parameter(Mandatory)][AllowNull()][object]$Value
            )
            $segments = @($PropertyPath -split '\.')
            $current = $InputObject
            for ($index = 0; $index -lt ($segments.Count - 1); $index++) {
                $segment = $segments[$index]
                if ($segment -match '^\d+$') {
                    $current = @($current)[[int]$segment]
                }
                else {
                    $current = $current.PSObject.Properties[$segment].Value
                }
            }
            $current.PSObject.Properties[$segments[-1]].Value = $Value
        }

        function Set-ContractDigestUppercase {
            param(
                [Parameter(Mandatory)][object]$InputObject,
                [Parameter(Mandatory)][string]$DigestPath
            )
            if ($DigestPath -eq 'resources.ownedPropertiesDigest') {
                $InputObject.resources[0].ownedPropertiesDigest = 'A' * 64
            }
            else {
                $InputObject.$DigestPath = 'A' * 64
            }
        }
    }

    It 'exports Test-TenantLifecycleContract from the module manifest' {
        Get-Command -Name Test-TenantLifecycleContract -Module Caldova.HrFrontier.Bootstrap -ErrorAction SilentlyContinue |
            Should -Not -BeNullOrEmpty
    }

    It 'accepts a complete synthetic <Name> contract at runtime' -TestCases $contractCases {
        param($Kind, $FixtureProperty)
        $value = $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Test-TenantLifecycleContract -Kind $Kind -InputObject $value | Should -BeTrue
    }

    It 'mirrors the complete synthetic <Name> contract in JSON Schema' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Be 0 -Because $result.Output
    }

    It 'rejects an unknown property in <Name> without disclosing its value' -TestCases $contractCases {
        param($Kind, $FixtureProperty)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value | Add-Member -NotePropertyName unexpectedProperty -NotePropertyValue 'private-marker-do-not-disclose'
        $message = $null
        try {
            Test-TenantLifecycleContract -Kind $Kind -InputObject $value
        }
        catch {
            $message = $_.Exception.Message
        }
        $message | Should -BeExactly "TenantLifecycle.Contract.$Kind"
        $message | Should -Not -Match 'private-marker'
    }

    It 'rejects a missing required property in <Name>' -TestCases $contractCases {
        param($Kind, $FixtureProperty)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value.PSObject.Properties.Remove('schemaVersion')
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"
    }

    It 'rejects null input with the stable <Kind> contract error' -TestCases $contractCases {
        param($Kind)
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $null } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"
    }

    It 'rejects a non-lowercase digest in <Name>' -TestCases $contractCases {
        param($Kind, $FixtureProperty, $DigestPath)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractDigestUppercase -InputObject $value -DigestPath $DigestPath
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"
    }

    It 'rejects punctuation in the <Name> status at runtime and in JSON Schema' -TestCases $statusCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value 'Ready-Now'
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'rejects an overlength <Name> status at runtime and in JSON Schema' -TestCases $statusCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value ('A' * 65)
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'rejects lowercase z in the <Name> date-time at runtime and in JSON Schema' -TestCases $dateTimeCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $LowercaseValue, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value $LowercaseValue
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'rejects a calendar-invalid <Name> date-time through format validation' -TestCases $dateTimeCases {
        param($Kind, $FixtureProperty, $SchemaFile, $FieldPath, $HasJsonSchema)
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractPropertyValue -InputObject $value -PropertyPath $FieldPath -Value '2026-02-30T12:00:00Z'
        { Test-TenantLifecycleContract -Kind $Kind -InputObject $value } |
            Should -Throw -ExpectedMessage "TenantLifecycle.Contract.$Kind"

        if ($HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot $SchemaFile) `
                -InputObject $value
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'keeps each <Name> schema closed' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value | Add-Member -NotePropertyName unexpectedProperty -NotePropertyValue 'synthetic'
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Not -Be 0
    }

    It 'requires every root field in the <Name> schema' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        $value.PSObject.Properties.Remove('schemaVersion')
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Not -Be 0
    }

    It 'requires lowercase digests in the <Name> schema' -TestCases $contractCases -Skip:(-not $hasJsonSchema) {
        param($FixtureProperty, $SchemaFile, $DigestPath)
        $schemaPath = Join-Path $script:SchemaRoot $SchemaFile
        Test-Path -LiteralPath $schemaPath -PathType Leaf | Should -BeTrue
        $value = Copy-ContractObject $script:Fixture.PSObject.Properties[$FixtureProperty].Value
        Set-ContractDigestUppercase -InputObject $value -DigestPath $DigestPath
        $result = Invoke-JsonSchemaValidation -SchemaPath $schemaPath -InputObject $value
        $result.ExitCode | Should -Not -Be 0
    }

    It 'rejects duplicate action IDs using ordinal comparison' {
        $manifest = Copy-ContractObject $script:Fixture.executionManifest
        $duplicate = Copy-ContractObject $manifest.actions[0]
        $duplicate.provider = 'AnotherSyntheticProvider'
        $manifest.actions = @($manifest.actions) + @($duplicate)
        { Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $manifest } |
            Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.ExecutionManifest'
    }

    It 'rejects a state resource without stableId' {
        $state = Copy-ContractObject $script:Fixture.state
        $state.resources[0].PSObject.Properties.Remove('stableId')
        { Test-TenantLifecycleContract -Kind State -InputObject $state } |
            Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.State'

        if ($script:HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot 'tenant-lifecycle-state.schema.json') `
                -InputObject $state
            $result.ExitCode | Should -Not -Be 0
        }
    }

    It 'rejects a classification outside the six-value set' {
        $manifest = Copy-ContractObject $script:Fixture.executionManifest
        $manifest.actions[0].classification = 'Reconcile'
        { Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $manifest } |
            Should -Throw -ExpectedMessage 'TenantLifecycle.Contract.ExecutionManifest'

        if ($script:HasJsonSchema) {
            $result = Invoke-JsonSchemaValidation `
                -SchemaPath (Join-Path $script:SchemaRoot 'tenant-lifecycle-execution-manifest.schema.json') `
                -InputObject $manifest
            $result.ExitCode | Should -Not -Be 0
        }
    }
}

Describe 'Tenant lifecycle intent and state separation' {
    BeforeAll {
        $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:ModulePath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $fixturePath = Join-Path $script:RepositoryRoot 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:Fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        Import-Module $script:ModulePath -Force

        $script:SyntheticRepositoryRoot = Join-Path $TestDrive 'repository'
        $script:SyntheticTenantRoot = Join-Path $script:SyntheticRepositoryRoot 'infra\src\config\tenants'
        $script:IntentPath = Join-Path $script:SyntheticTenantRoot 'tenant1.local.psd1'
        $script:StatePath = Join-Path $script:SyntheticTenantRoot 'tenant1.state.local.json'
        [IO.Directory]::CreateDirectory($script:SyntheticTenantRoot) | Out-Null

        function Copy-LifecycleValue {
            param([Parameter(Mandatory)][object]$InputObject)
            $InputObject | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        }

        function New-ReviewedIntentResource {
            param(
                [Parameter(Mandatory)]
                [ValidateSet('Existing', 'Create')]
                [string]$Mode,

                [string]$LogicalName = 'component-001',

                [string]$Id
            )

            $resource = [ordered]@{
                provider = 'Synthetic'
                resourceType = 'SyntheticResource'
                logicalName = $LogicalName
                Mode = $Mode
            }
            if ($PSBoundParameters.ContainsKey('Id')) {
                $resource.Id = $Id
            }
            [pscustomobject]$resource
        }

        function Reset-SyntheticPrivatePair {
            $intent = Get-Content -Raw -LiteralPath (
                Join-Path $script:RepositoryRoot 'infra\src\config\tenants\_template.psd1'
            )
            $intent = $intent.Replace("TenantAlias = 'example123456'", "TenantAlias = 'privatemarker123'")
            $intent = $intent.Replace('bootstrap-example123456', 'bootstrap-privatemarker123')
            $intent = $intent.Replace(
                '    Components = @{}',
                "    Components = @{$([Environment]::NewLine)        SyntheticResource = @{ Mode = 'Existing'; Id = 'stable-synthetic-001' }$([Environment]::NewLine)    }"
            )
            [IO.File]::WriteAllText($script:IntentPath, $intent, [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText(
                $script:StatePath,
                (($script:Fixture.state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
                [Text.UTF8Encoding]::new($false)
            )
        }

        function New-SyntheticGitBoundaryRunner {
            param(
                [Parameter(Mandatory)]
                [AllowEmptyCollection()]
                [Collections.Generic.List[string]]$Calls
            )

            {
                param($FilePath, $ArgumentList)

                $arguments = @($ArgumentList)
                $command = ($arguments | ForEach-Object { [string]$_ }) -join ' '
                [void]$Calls.Add("$FilePath $command")
                $relativeLabel = [string]$arguments[-1]
                if ($command -match ' check-ignore --quiet -- ') {
                    return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
                }
                if ($command -match ' ls-files --error-unmatch -- ') {
                    return [pscustomobject]@{ exitCode = 1; stdout = ''; stderr = '' }
                }
                if ($command -match ' status --porcelain=v1 --ignored --untracked-files=all -- ') {
                    return [pscustomobject]@{
                        exitCode = 0
                        stdout = "!! $relativeLabel"
                        stderr = ''
                    }
                }
                throw "Unexpected synthetic Git command: $command"
            }.GetNewClosure()
        }

        function Invoke-SyntheticPrivateBoundary {
            param([Parameter(Mandatory)][scriptblock]$Runner)

            Test-TenantLifecyclePrivateBoundary `
                -PublicTenantKey tenant1 `
                -IntentPath $script:IntentPath `
                -StatePath $script:StatePath `
                -RepositoryRoot $script:SyntheticRepositoryRoot `
                -NativeCommandRunner $Runner
        }
    }

    BeforeEach {
        Reset-SyntheticPrivatePair
    }

    It 'exports the intent state and private-boundary functions' {
        foreach ($name in @(
            'Test-TenantLifecyclePrivateBoundary',
            'Import-TenantLifecycleState',
            'Update-TenantLifecycleState'
        )) {
            Get-Command -Name $name -Module Caldova.HrFrontier.Bootstrap -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'rejects absent private files before invoking Git without leaking paths' {
        Remove-Item -LiteralPath $script:StatePath -Force
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        $message = try {
            Invoke-SyntheticPrivateBoundary -Runner $runner
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.PrivateBoundary.Files'
        $message | Should -Not -Match ([regex]::Escape($script:SyntheticRepositoryRoot))
        $calls.Count | Should -Be 0
    }

    It 'rejects paths outside the exact tenant boundary and the tracked template before invoking Git' {
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls
        $outsidePath = Join-Path $script:SyntheticRepositoryRoot 'tenant1.local.psd1'
        Copy-Item -LiteralPath $script:IntentPath -Destination $outsidePath

        {
            Test-TenantLifecyclePrivateBoundary `
                -PublicTenantKey tenant1 `
                -IntentPath $outsidePath `
                -StatePath $script:StatePath `
                -RepositoryRoot $script:SyntheticRepositoryRoot `
                -NativeCommandRunner $runner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Path'

        {
            Test-TenantLifecyclePrivateBoundary `
                -PublicTenantKey tenant1 `
                -IntentPath (Join-Path $script:RepositoryRoot 'infra\src\config\tenants\_template.psd1') `
                -StatePath $script:StatePath `
                -RepositoryRoot $script:SyntheticRepositoryRoot `
                -NativeCommandRunner $runner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Path'

        $calls.Count | Should -Be 0
    }

    It 'rejects a wrong public tenant key before invoking Git without leaking private values' {
        $intent = Get-Content -Raw -LiteralPath $script:IntentPath
        $intent = $intent.Replace("PublicTenantKey = 'tenant1'", "PublicTenantKey = 'tenant9'")
        [IO.File]::WriteAllText($script:IntentPath, $intent, [Text.UTF8Encoding]::new($false))
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        $message = try {
            Invoke-SyntheticPrivateBoundary -Runner $runner
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.PrivateBoundary.Intent'
        $message | Should -Not -Match 'privatemarker123|tenant9'
        $calls.Count | Should -Be 0
    }

    It 'rejects state-added desired properties and intent classifications' {
        foreach ($propertyName in @('desiredProperties', 'classification')) {
            $state = Copy-LifecycleValue $script:Fixture.state
            $state.resources[0] | Add-Member -NotePropertyName $propertyName -NotePropertyValue 'private-marker'
            [IO.File]::WriteAllText(
                $script:StatePath,
                (($state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
                [Text.UTF8Encoding]::new($false)
            )

            {
                Import-TenantLifecycleState -Path $script:StatePath -PublicTenantKey tenant1
            } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Invalid'
        }
    }

    It 'rejects a wrong state tenant key and duplicate stable IDs' {
        $wrongKey = Copy-LifecycleValue $script:Fixture.state
        $wrongKey.publicTenantKey = 'tenant9'
        [IO.File]::WriteAllText(
            $script:StatePath,
            (($wrongKey | ConvertTo-Json -Depth 30 -Compress) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
        {
            Import-TenantLifecycleState -Path $script:StatePath -PublicTenantKey tenant1
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.PublicTenantKey'

        $duplicate = Copy-LifecycleValue $script:Fixture.state
        $second = Copy-LifecycleValue $duplicate.resources[0]
        $second.logicalName = 'component-002'
        $duplicate.resources = @($duplicate.resources) + @($second)
        [IO.File]::WriteAllText(
            $script:StatePath,
            (($duplicate | ConvertTo-Json -Depth 30 -Compress) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
        {
            Import-TenantLifecycleState -Path $script:StatePath -PublicTenantKey tenant1
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Invalid'
    }

    It 'rejects state resources not present in reviewed intent before invoking Git' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $state.resources[0].resourceType = 'UnreviewedResource'
        [IO.File]::WriteAllText(
            $script:StatePath,
            (($state | ConvertTo-Json -Depth 30 -Compress) + "`n"),
            [Text.UTF8Encoding]::new($false)
        )
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        {
            Invoke-SyntheticPrivateBoundary -Runner $runner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.State'
        $calls.Count | Should -Be 0
    }

    It 'rejects tracked or inexactly reported private files' {
        $trackedRunner = {
            param($FilePath, $ArgumentList)
            $command = (@($ArgumentList) | ForEach-Object { [string]$_ }) -join ' '
            if ($command -match ' check-ignore --quiet -- ') {
                return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
            }
            if ($command -match ' ls-files --error-unmatch -- ') {
                return [pscustomobject]@{ exitCode = 0; stdout = [string]@($ArgumentList)[-1]; stderr = '' }
            }
            return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
        }
        {
            Invoke-SyntheticPrivateBoundary -Runner $trackedRunner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Git'

        $inexactRunner = {
            param($FilePath, $ArgumentList)
            $command = (@($ArgumentList) | ForEach-Object { [string]$_ }) -join ' '
            if ($command -match ' check-ignore --quiet -- ') {
                return [pscustomobject]@{ exitCode = 0; stdout = ''; stderr = '' }
            }
            if ($command -match ' ls-files --error-unmatch -- ') {
                return [pscustomobject]@{ exitCode = 1; stdout = ''; stderr = '' }
            }
            return [pscustomobject]@{ exitCode = 0; stdout = '!! infra/src/config/tenants/decoy.local.json'; stderr = '' }
        }
        {
            Invoke-SyntheticPrivateBoundary -Runner $inexactRunner
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.PrivateBoundary.Git'
    }

    It 'accepts only the exact ignored and untracked synthetic private pair' {
        $calls = [Collections.Generic.List[string]]::new()
        $runner = New-SyntheticGitBoundaryRunner -Calls $calls

        $result = Invoke-SyntheticPrivateBoundary -Runner $runner

        $result.PSObject.Properties.Name -join ',' |
            Should -BeExactly 'publicTenantKey,intent,state'
        $result.intent.PSObject.Properties.Name -join ',' |
            Should -BeExactly 'label,exists,ignored,tracked,schemaValid,digest'
        $result.state.PSObject.Properties.Name -join ',' |
            Should -BeExactly 'label,exists,ignored,tracked,schemaValid,digest'
        $result.publicTenantKey | Should -BeExactly 'tenant1'
        $result.intent.label | Should -BeExactly 'infra/src/config/tenants/tenant1.local.psd1'
        $result.state.label | Should -BeExactly 'infra/src/config/tenants/tenant1.state.local.json'
        $result.intent.exists | Should -BeTrue
        $result.intent.ignored | Should -BeTrue
        $result.intent.tracked | Should -BeFalse
        $result.intent.schemaValid | Should -BeTrue
        $result.intent.digest | Should -Match '^[0-9a-f]{64}$'
        $result.state.exists | Should -BeTrue
        $result.state.ignored | Should -BeTrue
        $result.state.tracked | Should -BeFalse
        $result.state.schemaValid | Should -BeTrue
        $result.state.digest | Should -Match '^[0-9a-f]{64}$'
        ($result | ConvertTo-Json -Depth 10) |
            Should -Not -Match 'privatemarker123|SyntheticResource|stable-synthetic|repository'

        $calls.Count | Should -Be 6
        @($calls | Where-Object { $_ -match ' check-ignore --quiet -- infra/src/config/tenants/tenant1\.local\.psd1$' }).Count |
            Should -Be 1
        @($calls | Where-Object { $_ -match ' ls-files --error-unmatch -- infra/src/config/tenants/tenant1\.state\.local\.json$' }).Count |
            Should -Be 1
        @($calls | Where-Object { $_ -match ' status --porcelain=v1 --ignored --untracked-files=all -- ' }).Count |
            Should -Be 2
    }

    It 'changes the sanitized intent digest when reviewed intent changes' {
        $firstCalls = [Collections.Generic.List[string]]::new()
        $first = Invoke-SyntheticPrivateBoundary `
            -Runner (New-SyntheticGitBoundaryRunner -Calls $firstCalls)
        $intent = Get-Content -Raw -LiteralPath $script:IntentPath
        $intent = [regex]::Replace(
            $intent,
            "(?m)^\s*DisplayName\s*=\s*'[^']+'\s*$",
            "    DisplayName = 'Reviewed Intent Drift'"
        )
        [IO.File]::WriteAllText(
            $script:IntentPath,
            $intent,
            [Text.UTF8Encoding]::new($false)
        )
        $secondCalls = [Collections.Generic.List[string]]::new()

        $second = Invoke-SyntheticPrivateBoundary `
            -Runner (New-SyntheticGitBoundaryRunner -Calls $secondCalls)

        $second.intent.digest | Should -Not -BeExactly $first.intent.digest
        ($second | ConvertTo-Json -Depth 10) |
            Should -Not -Match 'Reviewed Intent Drift|privatemarker123'
    }

    It 'uses the tracked state ignore rule in the actual repository' {
        $rules = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot '.gitignore')
        $rules | Should -Contain 'infra/src/config/tenants/*.state.local.json'

        & git -C $script:RepositoryRoot check-ignore --quiet -- (
            'infra/src/config/tenants/tenant1.state.local.json'
        )
        $LASTEXITCODE | Should -Be 0
    }

    It 'updates only observed fields for matching Existing reviewed intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $reviewedIntentResource = New-ReviewedIntentResource `
            -Mode Existing `
            -Id 'stable-synthetic-001'
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-001'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }
        $now = [datetime]::SpecifyKind([datetime]'2026-10-02T14:30:00', [DateTimeKind]::Utc)

        $updated = Update-TenantLifecycleState `
            -State $state `
            -ReviewedIntentResource $reviewedIntentResource `
            -VerifiedResource $verifiedResource `
            -NowUtc $now

        $state.resources[0].stableId | Should -BeExactly 'stable-synthetic-001'
        $updated.resources[0].provider | Should -BeExactly 'Synthetic'
        $updated.resources[0].resourceType | Should -BeExactly 'SyntheticResource'
        $updated.resources[0].logicalName | Should -BeExactly 'component-001'
        $updated.resources[0].stableId | Should -BeExactly 'stable-synthetic-001'
        $updated.resources[0].lastVerifiedAtUtc | Should -BeExactly '2026-10-02T14:30:00.0000000Z'
        $updated.resources[0].ownedPropertiesDigest | Should -BeExactly ('f' * 64)
        Test-TenantLifecycleContract -Kind State -InputObject $updated | Should -BeTrue
    }

    It 'rejects a stable ID change for Existing reviewed intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $reviewedIntentResource = New-ReviewedIntentResource `
            -Mode Existing `
            -Id 'stable-synthetic-001'
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentResource $reviewedIntentResource `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Intent'
    }

    It 'requires the reviewed intent resource and rejects an identity mismatch' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-001'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage '*ReviewedIntentResource*'

        $wrongIntentResource = New-ReviewedIntentResource `
            -Mode Existing `
            -LogicalName 'component-999' `
            -Id 'stable-synthetic-001'
        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentResource $wrongIntentResource `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Intent'
    }

    It 'rejects an inexact reviewed intent mode' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $reviewedIntentResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            Mode = 'create'
        }
        $verifiedResource = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentResource $reviewedIntentResource `
                -VerifiedResource $verifiedResource `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Intent'
    }

    It 'adopts a verified stable ID only for matching Create reviewed intent' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $reviewedIntentResource = New-ReviewedIntentResource -Mode Create
        $unverified = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $false
        }
        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentResource $reviewedIntentResource `
                -VerifiedResource $unverified `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.ReadBack'

        $verified = Copy-LifecycleValue $unverified
        $verified.exactReadBack = $true
        $updated = Update-TenantLifecycleState `
            -State $state `
            -ReviewedIntentResource $reviewedIntentResource `
            -VerifiedResource $verified `
            -NowUtc (
                [datetime]::SpecifyKind(
                    [datetime]'2026-10-02T15:30:00',
                    [DateTimeKind]::Utc
                )
            )

        $state.resources[0].stableId | Should -BeExactly 'stable-synthetic-001'
        $updated.resources[0].stableId | Should -BeExactly 'stable-synthetic-002'
        $updated.resources[0].lastVerifiedAtUtc |
            Should -BeExactly '2026-10-02T15:30:00.0000000Z'
        $updated.resources[0].ownedPropertiesDigest | Should -BeExactly ('f' * 64)
    }

    It 'refuses state adoption without a pre-existing state resource' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $unknownIntent = New-ReviewedIntentResource `
            -Mode Create `
            -LogicalName 'component-999'
        $unknown = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-999'
            stableId = 'stable-synthetic-999'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentResource $unknownIntent `
                -VerifiedResource $unknown `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.Resource'
    }

    It 'rejects fields outside the exact read-back contract' {
        $state = Copy-LifecycleValue $script:Fixture.state
        $reviewedIntentResource = New-ReviewedIntentResource -Mode Create
        $classificationChange = [pscustomobject]@{
            provider = 'Synthetic'
            resourceType = 'SyntheticResource'
            logicalName = 'component-001'
            stableId = 'stable-synthetic-002'
            ownedPropertiesDigest = 'f' * 64
            exactReadBack = $true
            classification = 'Manual'
        }

        {
            Update-TenantLifecycleState `
                -State $state `
                -ReviewedIntentResource $reviewedIntentResource `
                -VerifiedResource $classificationChange `
                -NowUtc ([datetime]::UtcNow)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.State.ReadBack'
    }
}

Describe 'Tenant lifecycle evidence manifest and writer' {
    BeforeAll {
        $script:EvidenceRepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
        $script:EvidenceModulePath = Join-Path $script:EvidenceRepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $fixturePath = Join-Path $script:EvidenceRepositoryRoot 'infra\tests\fixtures\runbooks\tenant-lifecycle.synthetic.json'
        $script:EvidenceFixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        Import-Module $script:EvidenceModulePath -Force

        function Copy-EvidenceValue {
            param([Parameter(Mandatory)][object]$InputObject)
            $InputObject | ConvertTo-Json -Depth 30 | ConvertFrom-Json
        }

        function New-EvidenceManifestParameters {
            @{
                RunId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
                SourceCommit = 'a' * 40
                EvidenceRoot = 'C:\evidence-root-synthetic'
                PublicTenantKey = 'tenant1'
                IntentDigest = '1' * 64
                StateDigest = '2' * 64
                Machine = Copy-EvidenceValue $script:EvidenceFixture.executionManifest.machine
                Operator = Copy-EvidenceValue $script:EvidenceFixture.executionManifest.operator
                ToolIdentities = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.toolIdentities)
                ProviderContexts = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.providerContexts)
                Prerequisites = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.prerequisites)
                Actions = @(Copy-EvidenceValue $script:EvidenceFixture.executionManifest.actions)
                GeneratedAtUtc = [datetime]'2026-10-02T12:05:00Z'
                ExpiresAtUtc = [datetime]'2026-10-02T12:35:00Z'
            }
        }
    }

        Describe 'Tenant lifecycle acceptance projection contracts' {
            BeforeAll {
                $script:ProjectionRepositoryRoot = (
                    Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
                ).Path
                $script:ProjectionModulePath = Join-Path $script:ProjectionRepositoryRoot (
                    'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\' +
                    'Caldova.HrFrontier.Bootstrap.psd1'
                )
                Import-Module $script:ProjectionModulePath -Force

                function New-AcceptanceProjectionEvidence {
                    param(
                        [Parameter(Mandatory)][string]$RunDirectory,
                        [string]$ApprovedStableId = 'stable-synthetic-001',
                        [switch]$CaseDriftReadBackComponent,
                        [switch]$CaseDriftSummaryPrerequisite,
                        [switch]$CorruptActionDigest,
                        [switch]$CorruptAssessmentDigest,
                        [switch]$CorruptReadBackDigest,
                        [switch]$IncludeUnreportedManifestAction,
                        [switch]$OmitPrivateReadBackComponent
                    )

                    $runId = [guid]'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'
                    $runIdText = $runId.ToString('D').ToLowerInvariant()
                    $sourceCommit = 'a' * 40
                    $inputDigest = '9' * 64
                    $approvedStableId = $ApprovedStableId
                    $urlStableId = (
                        'https://Portal.Example.Invalid/private/path' +
                        '?token=PROHIBITED-TOKEN#private'
                    )
                    $unapprovedStableId = 'stable-private-PROHIBITED-ID'
                    $state = [pscustomobject][ordered]@{
                        schemaVersion = '1.0'
                        publicTenantKey = 'tenant1'
                        resources = @(
                            [pscustomobject][ordered]@{
                                provider = 'Synthetic'
                                resourceType = 'SyntheticResource'
                                logicalName = 'approved-component'
                                stableId = $approvedStableId
                                lastVerifiedAtUtc = '2026-10-02T12:09:00.0000000Z'
                                ownedPropertiesDigest = 'e' * 64
                            }
                            [pscustomobject][ordered]@{
                                provider = 'Synthetic'
                                resourceType = 'SyntheticResource'
                                logicalName = 'url-component'
                                stableId = $urlStableId
                                lastVerifiedAtUtc = '2026-10-02T12:09:00.0000000Z'
                                ownedPropertiesDigest = 'd' * 64
                            }
                            [pscustomobject][ordered]@{
                                provider = 'Synthetic'
                                resourceType = 'SyntheticResource'
                                logicalName = 'private-component'
                                stableId = $unapprovedStableId
                                lastVerifiedAtUtc = '2026-10-02T12:09:00.0000000Z'
                                ownedPropertiesDigest = 'c' * 64
                            }
                        )
                    }
                    $stateDigest = Get-RunbookContentDigest -InputObject $state
                    $action = [pscustomobject][ordered]@{
                        id = 'Foundation'
                        provider = 'Synthetic'
                        classification = 'NoChange'
                        targetStableId = $approvedStableId
                        absencePredicate = 'NotPresent'
                        desiredPropertiesDigest = $inputDigest
                        preconditionDigest = '8' * 64
                        prerequisiteActionIds = [string[]]@()
                        adapter = 'SyntheticAdapter'
                        shouldProcessTarget = 'SyntheticResource/approved-component'
                        expectedPostcondition = 'MatchesDesiredProperties'
                        recovery = 'Reassess'
                        evidenceProjection = @('classification', 'status')
                    }
                    $manifestActions = @($action)
                    if ($IncludeUnreportedManifestAction) {
                        $manifestActions += [pscustomobject][ordered]@{
                            id = 'ReadBack'
                            provider = 'Synthetic'
                            classification = 'NoChange'
                            targetStableId = $approvedStableId
                            absencePredicate = 'NotPresent'
                            desiredPropertiesDigest = $inputDigest
                            preconditionDigest = '7' * 64
                            prerequisiteActionIds = @('Foundation')
                            adapter = 'SyntheticAdapter'
                            shouldProcessTarget = 'SyntheticResource/approved-component'
                            expectedPostcondition = 'MatchesDesiredProperties'
                            recovery = 'Reassess'
                            evidenceProjection = @('classification', 'status')
                        }
                    }
                    $manifestParameters = New-EvidenceManifestParameters
                    $manifestParameters.RunId = $runId
                    $manifestParameters.SourceCommit = $sourceCommit
                    $manifestParameters.EvidenceRoot = $RunDirectory
                    $manifestParameters.IntentDigest = '1' * 64
                    $manifestParameters.StateDigest = $stateDigest
                    $manifestParameters.Actions = @($manifestActions)
                    $manifest = New-TenantLifecycleExecutionManifest @manifestParameters
                    $approval = [pscustomobject][ordered]@{
                        schemaVersion = '1.0'
                        runId = $runIdText
                        executionManifestDigest = $manifest.digest
                        approverRole = 'TenantLifecycleApprover'
                        approvedAtUtc = '2026-10-02T12:06:00.0000000Z'
                        expiresAtUtc = '2026-10-02T12:35:00.0000000Z'
                        scope = @(
                            $manifestActions |
                                ForEach-Object { [string]$_.id }
                        )
                        status = 'Approved'
                    }
                    $assessment = [pscustomobject][ordered]@{
                        schemaVersion = '1.0'
                        runId = $runIdText
                        kind = 'TenantLifecycle'
                        generatedAtUtc = '2026-10-02T12:00:00.0000000Z'
                        sourceCommit = $sourceCommit
                        machine = [pscustomobject][ordered]@{
                            machineId = 'machine-synthetic-001'
                            platform = 'Windows 11'
                        }
                        publicTenantKey = 'tenant1'
                        intentDigest = $manifest.intentDigest
                        stateDigest = $manifest.stateDigest
                        toolIdentities = @($manifest.toolIdentities)
                        providerContexts = @($manifest.providerContexts)
                        components = @(
                            [pscustomobject][ordered]@{
                                id = 'approved-component'
                                provider = 'Synthetic'
                                resourceType = 'SyntheticResource'
                                classification = 'NoChange'
                                targetStableId = $approvedStableId
                                ownedPropertiesDigest = 'e' * 64
                                status = 'Passed'
                            }
                            [pscustomobject][ordered]@{
                                id = 'url-component'
                                provider = 'Synthetic'
                                resourceType = 'SyntheticResource'
                                classification = 'NoChange'
                                targetStableId = $urlStableId
                                ownedPropertiesDigest = 'd' * 64
                                status = 'Passed'
                            }
                            [pscustomobject][ordered]@{
                                id = 'private-component'
                                provider = 'Synthetic'
                                resourceType = 'SyntheticResource'
                                classification = 'NoChange'
                                targetStableId = $unapprovedStableId
                                ownedPropertiesDigest = 'c' * 64
                                status = 'Passed'
                            }
                        )
                        prerequisites = @($manifest.prerequisites)
                        digest = ''
                    }
                    $assessment.digest = Get-RunbookContentDigest -InputObject (
                        [pscustomobject][ordered]@{
                            runId = $assessment.runId
                            sourceCommit = $assessment.sourceCommit
                            intentDigest = $assessment.intentDigest
                            stateDigest = $assessment.stateDigest
                        }
                    )
                    if ($CorruptAssessmentDigest) {
                        $assessment.digest = '5' * 64
                    }
                    $actionEvidence = [pscustomobject][ordered]@{
                        schemaVersion = '1.0'
                        runId = $runIdText
                        actionId = 'Foundation'
                        classification = 'NoChange'
                        startedAtUtc = '2026-10-02T12:07:00.0000000Z'
                        completedAtUtc = '2026-10-02T12:08:00.0000000Z'
                        preReadDigest = $inputDigest
                        decision = 'NoChange'
                        postReadDigest = $inputDigest
                        status = 'Passed'
                        errorCode = $null
                        recovery = 'NotRequired'
                    }
                    $actionEvidenceDigest = Get-RunbookContentDigest -InputObject $actionEvidence
                    $summaryEvidenceDigest = if ($CorruptActionDigest) {
                        '0' * 64
                    }
                    else {
                        $actionEvidenceDigest
                    }
                    $readBackComponents = @(
                        foreach ($resource in $state.resources) {
                            if ($OmitPrivateReadBackComponent -and
                                [string]$resource.logicalName -ceq
                                    'private-component') {
                                continue
                            }
                            [pscustomobject][ordered]@{
                                id = if ($CaseDriftReadBackComponent -and
                                    [string]$resource.logicalName -ceq
                                        'approved-component') {
                                    'Approved-component'
                                }
                                else {
                                    [string]$resource.logicalName
                                }
                                provider = $resource.provider
                                stableId = $resource.stableId
                                ownedPropertiesDigest = $resource.ownedPropertiesDigest
                                status = 'Passed'
                            }
                        }
                    )
                    $readBackWithoutDigest = [pscustomobject][ordered]@{
                        schemaVersion = '1.0'
                        runId = $runIdText
                        generatedAtUtc = '2026-10-02T12:10:00.0000000Z'
                        components = @($readBackComponents)
                        status = 'Passed'
                    }
                    $readBack = [pscustomobject][ordered]@{
                        schemaVersion = $readBackWithoutDigest.schemaVersion
                        runId = $readBackWithoutDigest.runId
                        generatedAtUtc = $readBackWithoutDigest.generatedAtUtc
                        components = @($readBackWithoutDigest.components)
                        status = $readBackWithoutDigest.status
                        digest = Get-RunbookContentDigest -InputObject $readBackWithoutDigest
                    }
                    if ($CorruptReadBackDigest) {
                        $readBack.digest = '6' * 64
                    }
                    $summary = [pscustomobject][ordered]@{
                        schemaVersion = '1.0'
                        runId = $runIdText
                        sourceCommit = $sourceCommit
                        manifestDigest = $manifest.digest
                        startedAtUtc = '2026-10-02T12:00:00.0000000Z'
                        completedAtUtc = '2026-10-02T12:11:00.0000000Z'
                        status = 'Passed'
                        counts = [pscustomobject][ordered]@{
                            NoChange = 1
                            Create = 0
                            Update = 0
                            Manual = 0
                            Blocked = 0
                            Refused = 0
                        }
                        prerequisites = @([pscustomobject][ordered]@{
                            id = if ($CaseDriftSummaryPrerequisite) {
                                'foundation'
                            }
                            else {
                                'Foundation'
                            }
                            status = 'Passed'
                            inputDigest = $inputDigest
                            evidenceDigest = $summaryEvidenceDigest
                        })
                        actions = @([pscustomobject][ordered]@{
                            id = 'Foundation'
                            classification = 'NoChange'
                            status = 'Passed'
                            evidenceRelativePath = 'actions/Foundation.json'
                        })
                        nonClaims = @(
                            'Subsystem evidence remains independently reviewable.'
                        )
                    }

                    foreach ($record in @(
                        @{ Path = 'assessment.json'; Kind = 'Assessment'; Value = $assessment }
                        @{ Path = 'execution-manifest.json'; Kind = 'ExecutionManifest'; Value = $manifest }
                        @{ Path = 'approvals.json'; Kind = 'Approval'; Value = $approval }
                        @{ Path = 'actions/Foundation.json'; Kind = 'ActionEvidence'; Value = $actionEvidence }
                        @{ Path = 'state.json'; Kind = 'State'; Value = $state }
                        @{ Path = 'read-back.json'; Kind = 'ReadBack'; Value = $readBack }
                        @{ Path = 'summary.json'; Kind = 'Summary'; Value = $summary }
                    )) {
                        Write-TenantLifecycleEvidence `
                            -RunDirectory $RunDirectory `
                            -RelativePath $record.Path `
                            -Kind $record.Kind `
                            -InputObject $record.Value |
                            Out-Null
                    }

                    [IO.File]::WriteAllText(
                        (Join-Path $RunDirectory 'provider-raw.json'),
                        (
                            '{"token":"PROHIBITED-TOKEN","rawCommandOutput":' +
                            '"PROHIBITED-RAW","privateIntent":"PROHIBITED-INTENT",' +
                            '"privatePath":"C:\\private\\tenant"}'
                        ),
                        [Text.UTF8Encoding]::new($false)
                    )

                    [pscustomobject]@{
                        ApprovedStableId = $approvedStableId
                        ActionEvidenceDigest = $actionEvidenceDigest
                        RunId = $runIdText
                        SourceCommit = $sourceCommit
                    }
                }
            }

            BeforeEach {
                $script:ProjectionRunDirectory = Join-Path $TestDrive (
                    "projection-run-$([guid]::NewGuid().ToString('N'))"
                )
                $script:ProjectionOutputPath = Join-Path $TestDrive (
                    "acceptance-$([guid]::NewGuid().ToString('N')).json"
                )
            }

            It 'exports the sanitized acceptance projection command' {
                Get-Command `
                    -Name ConvertTo-TenantLifecycleAcceptanceProjection `
                    -Module Caldova.HrFrontier.Bootstrap `
                    -ErrorAction SilentlyContinue |
                    Should -Not -BeNullOrEmpty
            }

            It 'writes a canonical acceptance projection from allowlisted fields only' {
                $evidence = New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory

                $path = ConvertTo-TenantLifecycleAcceptanceProjection `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -AllowedStableIds @($evidence.ApprovedStableId) `
                    -AllowedUrlHosts @('portal.example.invalid') `
                    -OutputPath $script:ProjectionOutputPath

                $path | Should -BeExactly ([IO.Path]::GetFullPath($script:ProjectionOutputPath))
                $bytes = [IO.File]::ReadAllBytes($path)
                $bytes[0..2] | Should -Not -Be @(0xEF, 0xBB, 0xBF)
                $bytes[-1] | Should -Be 10
                $bytes[-2] | Should -Not -Be 10
                $raw = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
                foreach ($marker in @(
                    'PROHIBITED-TOKEN',
                    'PROHIBITED-RAW',
                    'PROHIBITED-INTENT',
                    'PROHIBITED-ID',
                    'C:\\private',
                    '/private/path',
                    '?token=',
                    '#private'
                )) {
                    $raw | Should -Not -Match ([regex]::Escape($marker))
                }

                $projection = $raw | ConvertFrom-Json
                ($projection.PSObject.Properties.Name -join ',') |
                    Should -BeExactly (
                        'actions,approvedDigests,artifactDigest,counts,' +
                        'disclosedStableIds,disclosedUrlHosts,nonClaims,' +
                        'runId,sourceCommit,statuses'
                    )
                $projection.runId | Should -BeExactly $evidence.RunId
                $projection.sourceCommit | Should -BeExactly $evidence.SourceCommit
                @($projection.disclosedStableIds) |
                    Should -BeExactly @($evidence.ApprovedStableId)
                @($projection.disclosedUrlHosts) |
                    Should -BeExactly @('portal.example.invalid')
                $projection.actions.Count | Should -Be 1
                $projection.actions[0].id | Should -BeExactly 'Foundation'
                $projection.actions[0].classification | Should -BeExactly 'NoChange'
                $projection.actions[0].status | Should -BeExactly 'Passed'
                $projection.actions[0].digest |
                    Should -BeExactly $evidence.ActionEvidenceDigest
                $projection.statuses.approval | Should -BeExactly 'Approved'
                $projection.statuses.readBack | Should -BeExactly 'Passed'
                $projection.statuses.summary | Should -BeExactly 'Passed'
                $projection.nonClaims | Should -Contain (
                    'Provider mutation was not verified by this projection.'
                )
                $projection.nonClaims | Should -Contain (
                    'Pipeline import was not verified by this projection.'
                )
                $projection.nonClaims | Should -Contain (
                    'Artifact bytes were not verified by this projection.'
                )

                $digestInput = [pscustomobject][ordered]@{}
                foreach ($property in $projection.PSObject.Properties) {
                    if ($property.Name -cne 'artifactDigest') {
                        $digestInput | Add-Member `
                            -NotePropertyName $property.Name `
                            -NotePropertyValue $property.Value
                    }
                }
                $projection.artifactDigest |
                    Should -BeExactly (Get-RunbookContentDigest -InputObject $digestInput)

                $artifactPaths = [ordered]@{
                    assessment = 'assessment.json'
                    executionManifest = 'execution-manifest.json'
                    approval = 'approvals.json'
                    state = 'state.json'
                    readBack = 'read-back.json'
                    summary = 'summary.json'
                }
                foreach ($name in $artifactPaths.Keys) {
                    $projection.approvedDigests.$name |
                        Should -BeExactly (
                            (
                                Get-FileHash `
                                    -LiteralPath (
                                        Join-Path `
                                            $script:ProjectionRunDirectory `
                                            $artifactPaths[$name]
                                    ) `
                                    -Algorithm SHA256
                            ).Hash.ToLowerInvariant()
                        )
                }
                $projection.approvedDigests.actions[0].digest |
                    Should -BeExactly (
                        (
                            Get-FileHash `
                                -LiteralPath (
                                    Join-Path `
                                        $script:ProjectionRunDirectory `
                                        'actions\Foundation.json'
                                ) `
                                -Algorithm SHA256
                        ).Hash.ToLowerInvariant()
                    )
            }

            It 'rejects an assessment whose embedded digest does not bind its contract projection' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -CorruptAssessmentDigest |
                    Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('stable-synthetic-001') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage (
                    'TenantLifecycle.Disclosure.Evidence.Invalid'
                )

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'rejects a read-back whose embedded digest does not bind its contract projection' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -CorruptReadBackDigest |
                    Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('stable-synthetic-001') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage (
                    'TenantLifecycle.Disclosure.Evidence.Invalid'
                )

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'rejects a manifest action omitted from summary actions and prerequisites' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -IncludeUnreportedManifestAction |
                    Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('stable-synthetic-001') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage (
                    'TenantLifecycle.Disclosure.ActionEvidence.Correlation'
                )

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'rejects ordinal case drift in the summary prerequisite action set' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -CaseDriftSummaryPrerequisite |
                    Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('stable-synthetic-001') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage (
                    'TenantLifecycle.Disclosure.ActionEvidence.Correlation'
                )

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'rejects a partial read-back component set' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -OmitPrivateReadBackComponent |
                    Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('stable-synthetic-001') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage (
                    'TenantLifecycle.Disclosure.ReadBack.Correlation'
                )

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'rejects ordinal case drift in the read-back component set' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -CaseDriftReadBackComponent |
                    Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('stable-synthetic-001') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage (
                    'TenantLifecycle.Disclosure.ReadBack.Correlation'
                )

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'fails closed on an uncorrelated action evidence digest without leaking evidence' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -CorruptActionDigest |
                    Out-Null

                $message = try {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('stable-synthetic-001') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                    ''
                }
                catch {
                    $_.Exception.Message
                }

                $message | Should -BeExactly 'TenantLifecycle.Disclosure.ActionEvidence.Correlation'
                $message | Should -Not -Match 'PROHIBITED'
                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'does not overwrite an existing acceptance projection' {
                $evidence = New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory
                ConvertTo-TenantLifecycleAcceptanceProjection `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -AllowedStableIds @($evidence.ApprovedStableId) `
                    -AllowedUrlHosts @('portal.example.invalid') `
                    -OutputPath $script:ProjectionOutputPath |
                    Out-Null
                $before = [IO.File]::ReadAllBytes($script:ProjectionOutputPath)

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @($evidence.ApprovedStableId) `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage 'TenantLifecycle.Disclosure.OutputExists'

                [Convert]::ToBase64String([IO.File]::ReadAllBytes($script:ProjectionOutputPath)) |
                    Should -BeExactly ([Convert]::ToBase64String($before))
            }

            It 'rejects a private filesystem path in the stable ID disclosure allowlist' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory |
                    Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @('C:\private\tenant') `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage 'TenantLifecycle.Disclosure.Allowlist'

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'rejects host-independent path-shaped stable ID <StableId>' -ForEach @(
                @{ StableId = 'C:\private\tenant' }
                @{ StableId = 'C:/private/tenant' }
                @{ StableId = '\\server\share\tenant' }
                @{ StableId = '//server/share/tenant' }
                @{ StableId = '/private/tenant' }
                @{ StableId = '~/private/tenant' }
                @{ StableId = '~\private\tenant' }
                @{ StableId = '../private/tenant' }
                @{ StableId = '..\private\tenant' }
                @{ StableId = 'private/tenant' }
                @{ StableId = 'private\tenant' }
            ) {
                [IO.Directory]::CreateDirectory(
                    $script:ProjectionRunDirectory
                ) | Out-Null

                {
                    ConvertTo-TenantLifecycleAcceptanceProjection `
                        -RunDirectory $script:ProjectionRunDirectory `
                        -AllowedStableIds @($StableId) `
                        -AllowedUrlHosts @('portal.example.invalid') `
                        -OutputPath $script:ProjectionOutputPath
                } | Should -Throw -ExpectedMessage (
                    'TenantLifecycle.Disclosure.Allowlist'
                )

                $script:ProjectionOutputPath | Should -Not -Exist
            }

            It 'preserves a legitimate opaque stable ID allowlist value' {
                $stableId = 'opaque:tenant.id_01'
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -ApprovedStableId $stableId |
                    Out-Null

                ConvertTo-TenantLifecycleAcceptanceProjection `
                    -RunDirectory $script:ProjectionRunDirectory `
                    -AllowedStableIds @($stableId) `
                    -AllowedUrlHosts @('portal.example.invalid') `
                    -OutputPath $script:ProjectionOutputPath |
                    Out-Null

                $projection = Get-Content `
                    -Raw `
                    -LiteralPath $script:ProjectionOutputPath |
                    ConvertFrom-Json
                @($projection.disclosedStableIds) |
                    Should -BeExactly @($stableId)
            }

            It 'rejects an acceptance projection output inside a Git worktree' {
                New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory |
                    Out-Null
                $insideGit = Join-Path $script:ProjectionRepositoryRoot (
                    ".superpowers\projection-$([guid]::NewGuid().ToString('N')).json"
                )

                try {
                    {
                        ConvertTo-TenantLifecycleAcceptanceProjection `
                            -RunDirectory $script:ProjectionRunDirectory `
                            -AllowedStableIds @('stable-synthetic-001') `
                            -AllowedUrlHosts @('portal.example.invalid') `
                            -OutputPath $insideGit
                    } | Should -Throw -ExpectedMessage 'TenantLifecycle.Disclosure.OutputGit'
                }
                finally {
                    if (Test-Path -LiteralPath $insideGit) {
                        Remove-Item -LiteralPath $insideGit -Force
                    }
                }
            }

            It 'rejects a real reparse ancestor without creating projection output' {
                $evidence = New-AcceptanceProjectionEvidence `
                    -RunDirectory $script:ProjectionRunDirectory
                $targetDirectory = Join-Path $TestDrive (
                    "projection-target-$([guid]::NewGuid().ToString('N'))"
                )
                $reparseDirectory = Join-Path $TestDrive (
                    "projection-reparse-$([guid]::NewGuid().ToString('N'))"
                )
                [IO.Directory]::CreateDirectory($targetDirectory) | Out-Null
                $fixture = $null
                $fixtureErrors = [Collections.Generic.List[string]]::new()
                foreach ($itemType in @('Junction', 'SymbolicLink')) {
                    try {
                        $fixture = New-Item `
                            -ItemType $itemType `
                            -Path $reparseDirectory `
                            -Target $targetDirectory `
                            -ErrorAction Stop
                        break
                    }
                    catch {
                        $fixtureErrors.Add(
                            "$itemType`: $($_.Exception.Message)"
                        )
                    }
                }
                if ($null -eq $fixture) {
                    Set-ItResult `
                        -Skipped `
                        -Because (
                            'No supported reparse fixture could be created. ' +
                            ($fixtureErrors -join ' | ')
                        )
                    return
                }

                $reparseOutput = Join-Path $reparseDirectory 'acceptance.json'
                $targetOutput = Join-Path $targetDirectory 'acceptance.json'
                try {
                    {
                        ConvertTo-TenantLifecycleAcceptanceProjection `
                            -RunDirectory $script:ProjectionRunDirectory `
                            -AllowedStableIds @($evidence.ApprovedStableId) `
                            -AllowedUrlHosts @('portal.example.invalid') `
                            -OutputPath $reparseOutput
                    } | Should -Throw -ExpectedMessage (
                        'TenantLifecycle.Disclosure.OutputPath'
                    )

                    $reparseOutput | Should -Not -Exist
                    $targetOutput | Should -Not -Exist
                }
                finally {
                    if (Test-Path -LiteralPath $reparseDirectory) {
                        Remove-Item -LiteralPath $reparseDirectory -Force
                    }
                    if (Test-Path -LiteralPath $targetDirectory) {
                        Remove-Item `
                            -LiteralPath $targetDirectory `
                            -Recurse `
                            -Force
                    }
                }
            }
        }

    BeforeEach {
        $script:EvidenceRunDirectory = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'exports the evidence manifest approval and writer commands' {
        foreach ($name in @(
            'New-TenantLifecycleExecutionManifest',
            'Test-TenantLifecycleApproval',
            'Write-TenantLifecycleEvidence'
        )) {
            Get-Command -Name $name -Module Caldova.HrFrontier.Bootstrap -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }

    It 'creates a canonical evidence manifest whose digest binds every accepted input' {
        $parameters = New-EvidenceManifestParameters
        $manifest = New-TenantLifecycleExecutionManifest @parameters
        $repeatParameters = New-EvidenceManifestParameters
        $repeat = New-TenantLifecycleExecutionManifest @repeatParameters

        ($manifest | ConvertTo-Json -Depth 30 -Compress) |
            Should -BeExactly ($repeat | ConvertTo-Json -Depth 30 -Compress)
        Test-TenantLifecycleContract -Kind ExecutionManifest -InputObject $manifest | Should -BeTrue

        $mutations = [ordered]@{
            runId = { param($value) $value.RunId = [guid]'bbbbbbbb-cccc-4ddd-8eee-ffffffffffff' }
            sourceCommit = { param($value) $value.SourceCommit = 'b' * 40 }
            evidenceRoot = { param($value) $value.EvidenceRoot = 'C:\other-evidence-root' }
            intentDigest = { param($value) $value.IntentDigest = '3' * 64 }
            stateDigest = { param($value) $value.StateDigest = '4' * 64 }
            machine = { param($value) $value.Machine.machineId = 'machine-synthetic-002' }
            operator = { param($value) $value.Operator.operatorId = 'operator-synthetic-002' }
            toolIdentities = { param($value) $value.ToolIdentities[0].digest = '5' * 64 }
            providerContexts = { param($value) $value.ProviderContexts[0].digest = '6' * 64 }
            prerequisites = { param($value) $value.Prerequisites[0].evidenceDigest = '8' * 64 }
            actions = { param($value) $value.Actions[0].desiredPropertiesDigest = '7' * 64 }
            generatedAtUtc = { param($value) $value.GeneratedAtUtc = [datetime]'2026-10-02T12:06:00Z' }
            expiresAtUtc = { param($value) $value.ExpiresAtUtc = [datetime]'2026-10-02T12:34:00Z' }
        }

        foreach ($field in $mutations.Keys) {
            $variantParameters = New-EvidenceManifestParameters
            & $mutations[$field] $variantParameters
            $variant = New-TenantLifecycleExecutionManifest @variantParameters
            $variant.digest | Should -Not -BeExactly $manifest.digest -Because "$field must be digest-bound"
        }
    }

    It 'rejects an evidence approval window longer than thirty minutes' {
        $parameters = New-EvidenceManifestParameters
        $parameters.ExpiresAtUtc = [datetime]'2026-10-02T12:35:00.001Z'

        {
            New-TenantLifecycleExecutionManifest @parameters
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Manifest.Expiry'
    }

    It 'writes every evidence kind only to its exact allowlisted filename' {
        $manifestParameters = New-EvidenceManifestParameters
        $executionManifest = New-TenantLifecycleExecutionManifest @manifestParameters
        $cases = @(
            @{ Kind = 'Assessment'; RelativePath = 'assessment.json'; Input = $script:EvidenceFixture.assessment }
            @{ Kind = 'ExecutionManifest'; RelativePath = 'execution-manifest.json'; Input = $executionManifest }
            @{ Kind = 'Approval'; RelativePath = 'approvals.json'; Input = $script:EvidenceFixture.approval }
            @{ Kind = 'ActionEvidence'; RelativePath = 'actions/action-001.json'; Input = $script:EvidenceFixture.actionEvidence }
            @{ Kind = 'State'; RelativePath = 'state.json'; Input = $script:EvidenceFixture.state }
            @{ Kind = 'ReadBack'; RelativePath = 'read-back.json'; Input = $script:EvidenceFixture.readBack }
            @{ Kind = 'Summary'; RelativePath = 'summary.json'; Input = $script:EvidenceFixture.summary }
        )

        foreach ($case in $cases) {
            $path = Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath $case.RelativePath `
                -Kind $case.Kind `
                -InputObject (Copy-EvidenceValue $case.Input)

            $path | Should -BeExactly ([IO.Path]::GetFullPath((Join-Path $script:EvidenceRunDirectory $case.RelativePath.Replace('/', '\'))))
            Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue
        }

        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'other-summary.json' `
                -Kind Summary `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.summary)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Path'
    }

    It 'rejects a digest-stale evidence manifest before writing any bytes' {
        $manifestParameters = New-EvidenceManifestParameters
        $manifest = New-TenantLifecycleExecutionManifest @manifestParameters
        $manifest.sourceCommit = 'b' * 40

        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'execution-manifest.json' `
                -Kind ExecutionManifest `
                -InputObject $manifest
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Invalid'

        Test-Path -LiteralPath (Join-Path $script:EvidenceRunDirectory 'execution-manifest.json') |
            Should -BeFalse
    }

    It 'writes canonical UTF-8 evidence with no BOM one LF and repeatable bytes' {
        $firstRun = Join-Path $TestDrive 'canonical-first'
        $secondRun = Join-Path $TestDrive 'canonical-second'
        $input = Copy-EvidenceValue $script:EvidenceFixture.assessment

        $firstPath = Write-TenantLifecycleEvidence -RunDirectory $firstRun -RelativePath 'assessment.json' -Kind Assessment -InputObject $input
        $secondPath = Write-TenantLifecycleEvidence -RunDirectory $secondRun -RelativePath 'assessment.json' -Kind Assessment -InputObject (Copy-EvidenceValue $input)
        $firstBytes = [IO.File]::ReadAllBytes($firstPath)
        $secondBytes = [IO.File]::ReadAllBytes($secondPath)
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($firstBytes)

        [Convert]::ToBase64String($firstBytes) | Should -BeExactly ([Convert]::ToBase64String($secondBytes))
        ($firstBytes[0..2] -join ',') | Should -Not -BeExactly '239,187,191'
        $firstBytes[-1] | Should -Be 10
        $text.TrimEnd("`n").Contains("`n") | Should -BeFalse
        $text.Contains("`r") | Should -BeFalse
        @(Get-ChildItem -LiteralPath $firstRun -Recurse -Filter '*.tmp').Count | Should -Be 0
        @(Get-ChildItem -LiteralPath $secondRun -Recurse -Filter '*.tmp').Count | Should -Be 0
    }

    It 'leaves no partial evidence or temporary file when validation fails' {
        $invalid = Copy-EvidenceValue $script:EvidenceFixture.assessment
        $invalid | Add-Member -NotePropertyName rawCommandOutput -NotePropertyValue 'private-marker-do-not-disclose'
        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject $invalid
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Invalid'
        $message | Should -Not -Match 'private-marker'
        Test-Path -LiteralPath (Join-Path $script:EvidenceRunDirectory 'assessment.json') | Should -BeFalse
        if (Test-Path -LiteralPath $script:EvidenceRunDirectory) {
            @(Get-ChildItem -LiteralPath $script:EvidenceRunDirectory -Recurse -File).Count | Should -Be 0
        }
    }

    It 'never overwrites a completed action evidence envelope' {
        $path = Write-TenantLifecycleEvidence `
            -RunDirectory $script:EvidenceRunDirectory `
            -RelativePath 'actions/action-001.json' `
            -Kind ActionEvidence `
            -InputObject (Copy-EvidenceValue $script:EvidenceFixture.actionEvidence)
        $before = [IO.File]::ReadAllBytes($path)
        $changed = Copy-EvidenceValue $script:EvidenceFixture.actionEvidence
        $changed.recovery = 'Reassess'

        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'actions/action-001.json' `
                -Kind ActionEvidence `
                -InputObject $changed
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Exists'

        [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
            Should -BeExactly ([Convert]::ToBase64String($before))
        @(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter '*.tmp').Count | Should -Be 0
    }

    It 'rejects evidence path traversal outside the run directory' {
        {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath '..\assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
        } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.Path'

        Test-Path -LiteralPath (Join-Path (Split-Path -Parent $script:EvidenceRunDirectory) 'assessment.json') |
            Should -BeFalse
    }

    It 'normalizes an evidence root that is a file without leaking its path' {
        [IO.File]::WriteAllText($script:EvidenceRunDirectory, 'private-root-marker')

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Root'
        $message | Should -Not -Match 'private-root-marker'
        [IO.File]::ReadAllText($script:EvidenceRunDirectory) | Should -BeExactly 'private-root-marker'
    }

    It 'normalizes inaccessible evidence root metadata without leaking the provider error' {
        [IO.Directory]::CreateDirectory($script:EvidenceRunDirectory) | Out-Null
        Mock -CommandName Get-Item -ModuleName Caldova.HrFrontier.Bootstrap -MockWith {
            throw [UnauthorizedAccessException]::new('private-access-marker')
        }

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Root'
        $message | Should -Not -Match 'private-access-marker'
        Test-Path -LiteralPath (Join-Path $script:EvidenceRunDirectory 'assessment.json') |
            Should -BeFalse
    }

    It 'normalizes a malformed evidence root without leaking its value' {
        $malformedRoot = "$TestDrive\private-malformed-marker$([char]0)"
        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $malformedRoot `
                -RelativePath 'assessment.json' `
                -Kind Assessment `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Root'
        $message | Should -Not -Match 'private-malformed-marker'
    }

    It 'normalizes an action directory creation failure without leaking its path' {
        [IO.Directory]::CreateDirectory($script:EvidenceRunDirectory) | Out-Null
        $actionDirectory = Join-Path $script:EvidenceRunDirectory 'actions'
        [IO.File]::WriteAllText($actionDirectory, 'private-action-marker')

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'actions/action-001.json' `
                -Kind ActionEvidence `
                -InputObject (Copy-EvidenceValue $script:EvidenceFixture.actionEvidence)
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.ActionDirectory'
        $message | Should -Not -Match 'private-action-marker'
        [IO.File]::ReadAllText($actionDirectory) | Should -BeExactly 'private-action-marker'
    }

    It 'rejects hidden evidence properties without evaluating them or disclosing their error' {
        $hidden = Copy-EvidenceValue $script:EvidenceFixture.actionEvidence
        $hidden.PSObject.Properties.Remove('actionId')
        $hidden | Add-Member -MemberType ScriptProperty -Name actionId -Value {
            throw 'hidden getter executed'
        }

        $message = try {
            Write-TenantLifecycleEvidence `
                -RunDirectory $script:EvidenceRunDirectory `
                -RelativePath 'actions/action-001.json' `
                -Kind ActionEvidence `
                -InputObject $hidden
            ''
        }
        catch {
            $_.Exception.Message
        }

        $message | Should -BeExactly 'TenantLifecycle.Evidence.Invalid'
        $message | Should -Not -Match 'hidden getter'
        Test-Path -LiteralPath $script:EvidenceRunDirectory | Should -BeFalse
    }

    It 'rejects a reparse-point evidence root' {
        $realRoot = Join-Path $TestDrive 'real-evidence-root'
        $reparseRoot = Join-Path $TestDrive 'linked-evidence-root'
        $nestedRoot = Join-Path $reparseRoot 'run'
        [IO.Directory]::CreateDirectory($realRoot) | Out-Null
        New-Item -ItemType Junction -Path $reparseRoot -Target $realRoot | Out-Null
        try {
            {
                Write-TenantLifecycleEvidence `
                    -RunDirectory $nestedRoot `
                    -RelativePath 'assessment.json' `
                    -Kind Assessment `
                    -InputObject (Copy-EvidenceValue $script:EvidenceFixture.assessment)
            } | Should -Throw -ExpectedMessage 'TenantLifecycle.Evidence.ReparsePoint'
        }
        finally {
            $unexpectedRun = Join-Path $realRoot 'run'
            if (Test-Path -LiteralPath $unexpectedRun) {
                Remove-Item -LiteralPath $unexpectedRun -Recurse -Force
            }
            if (Test-Path -LiteralPath $reparseRoot) {
                Remove-Item -LiteralPath $reparseRoot -Force
            }
        }

        @(Get-ChildItem -LiteralPath $realRoot -Force).Count | Should -Be 0
    }
}
