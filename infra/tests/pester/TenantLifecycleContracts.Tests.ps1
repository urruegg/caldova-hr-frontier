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
            $output = & python -c $program $SchemaPath $encoded 2>&1
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join [Environment]::NewLine) }
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
