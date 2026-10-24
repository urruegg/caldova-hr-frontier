Set-StrictMode -Version Latest

Describe 'Explicit repository export profile contract' {
    BeforeAll {
        $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Module = Join-Path $script:Root 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:CustomerSample = Join-Path $script:Root 'infra\src\config\runbooks\customer-export.sample.json'
        $script:ReplicaSample = Join-Path $script:Root 'infra\src\config\runbooks\tenant-replica.sample.json'
        $script:LegacyPath = Join-Path $PSScriptRoot '..\fixtures\runbooks\customer-export.v1.valid.json'
        Import-Module $script:Module -Force

        function New-ProfileValue {
            param([string]$Profile = 'CustomerHandover')
            $value = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
            $value | Add-Member NoteProperty profile $Profile
            $value | Add-Member NoteProperty profilePolicy ([pscustomobject][ordered]@{
                denyWorkflows = ($Profile -ceq 'CustomerHandover')
                denyEvidence = $true
                denyTenantTransitions = $true
                denyPrivateState = $true
                denySourceHistory = $true
                denyUntrackedFiles = $true
            })
            $value | Add-Member NoteProperty deniedPaths @()
            return $value
        }

        function Write-ProfileValue {
            param([object]$Value)
            $path = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.json')
            [IO.File]::WriteAllText($path, ($Value | ConvertTo-Json -Depth 50), [Text.UTF8Encoding]::new($false))
            return $path
        }

        function Write-ManifestRoot {
            param([string]$ObjectJson, [string]$Shape)
            $json = switch ($Shape) {
                'empty array' { '[]' }
                'singleton array' { '[' + $ObjectJson + ']' }
                'multiple array' { '[' + $ObjectJson + ',' + $ObjectJson + ']' }
                'string' { '"synthetic-value"' }
                'number' { '1' }
                'true' { 'true' }
                'false' { 'false' }
                'null' { 'null' }
            }
            $path = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.json')
            [IO.File]::WriteAllText($path, (" `t`r`n" + $json + "`r`n"), [Text.UTF8Encoding]::new($false))
            return $path
        }
    }

    It 'rejects a <Shape> root through the canonical file importer for <Profile>' -ForEach @(
        foreach ($profile in @('CustomerHandover', 'TenantReplica')) {
            foreach ($shape in @('empty array', 'singleton array', 'multiple array', 'string', 'number', 'true', 'false', 'null')) {
                @{ Profile = $profile; Shape = $shape }
            }
        }
    ) {
        $json = ConvertTo-Json -InputObject (New-ProfileValue -Profile $Profile) -Depth 50
        $path = Write-ManifestRoot -ObjectJson $json -Shape $Shape
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile $Profile } | Should -Throw
    }

    It 'rejects a <Shape> root through the customer compatibility file importer for <Format>' -ForEach @(
        foreach ($format in @('legacy', 'canonical')) {
            foreach ($shape in @('empty array', 'singleton array', 'multiple array', 'string', 'number', 'true', 'false', 'null')) {
                @{ Format = $format; Shape = $shape }
            }
        }
    ) {
        $source = if ($Format -eq 'legacy') { $script:LegacyPath } else { $script:CustomerSample }
        $path = Write-ManifestRoot -ObjectJson ([IO.File]::ReadAllText($source)) -Shape $Shape
        { Import-CustomerExportManifest -Path $path } | Should -Throw
    }

    It 'rejects a <Shape> root before the legacy adapter can normalize it' -ForEach @(
        @{ Shape = 'empty array' }, @{ Shape = 'singleton array' }, @{ Shape = 'multiple array' }
        @{ Shape = 'string' }, @{ Shape = 'number' }, @{ Shape = 'true' }, @{ Shape = 'false' }, @{ Shape = 'null' }
    ) {
        $legacy = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $inputValue = $null
        switch ($Shape) {
            'empty array' { $inputValue = [object[]]@() }
            'singleton array' { $inputValue = [object[]]@($legacy) }
            'multiple array' { $inputValue = [object[]]@($legacy, $legacy) }
            'string' { $inputValue = 'synthetic-value' }
            'number' { $inputValue = 1 }
            'true' { $inputValue = $true }
            'false' { $inputValue = $false }
            'null' { $inputValue = $null }
        }
        { ConvertTo-CustomerHandoverManifest -LegacyManifest $inputValue } | Should -Throw
    }

    It 'preserves literal replacement arrays in a plain object through <EntryPoint>' -ForEach @(
        @{ EntryPoint = 'adapter object' }, @{ EntryPoint = 'adapter dictionary' }
        @{ EntryPoint = 'legacy file' }, @{ EntryPoint = 'canonical file' }
    ) {
        $value = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $value.replacements[0].expectedOldValue = ('{"items":[null,["synthetic-value"],[],false,1]}' | ConvertFrom-Json).items
        $value.replacements[0].newValue = '{"items":[null,"synthetic-new-value"]}' | ConvertFrom-Json
        switch ($EntryPoint) {
            'adapter object' { $manifest = ConvertTo-CustomerHandoverManifest -LegacyManifest $value }
            'adapter dictionary' {
                $dictionary = @{}
                foreach ($property in $value.PSObject.Properties) {
                    $dictionary[$property.Name] = $property.Value
                }
                $manifest = ConvertTo-CustomerHandoverManifest -LegacyManifest $dictionary
            }
            'legacy file' { $manifest = Import-CustomerExportManifest -Path (Write-ProfileValue $value) }
            'canonical file' {
                $value | Add-Member NoteProperty profile 'CustomerHandover'
                $value | Add-Member NoteProperty profilePolicy (New-ProfileValue).profilePolicy
                $value | Add-Member NoteProperty deniedPaths @()
                $manifest = Import-CustomerExportManifest -Path (Write-ProfileValue $value)
            }
        }
        $manifest.profile | Should -BeExactly 'CustomerHandover'
        (ConvertTo-Json -InputObject $manifest.replacements[0].expectedOldValue -Depth 20 -Compress) | Should -BeExactly '[null,["synthetic-value"],[],false,1]'
        (ConvertTo-Json -InputObject $manifest.replacements[0].newValue -Depth 20 -Compress) | Should -BeExactly '{"items":[null,"synthetic-new-value"]}'
    }

    It 'accepts explicit <Profile> without reading referenced source files' -ForEach @(
        @{ Profile = 'TenantReplica' }, @{ Profile = 'CustomerHandover' }
    ) {
        $path = Write-ProfileValue (New-ProfileValue -Profile $Profile)
        $beforeFiles = @(Get-ChildItem -LiteralPath $TestDrive -Recurse -File | ForEach-Object FullName)
        $manifest = Import-RepositoryExportManifest -Path $path -ExpectedProfile $Profile
        $manifest.schemaVersion | Should -BeExactly '1.0'
        $manifest.profile | Should -BeExactly $Profile
        @($manifest.replacements).Count | Should -Be 2
        @(Get-ChildItem -LiteralPath $TestDrive -Recurse -File | ForEach-Object FullName) | Should -Be $beforeFiles
    }

    It 'requires explicit ExpectedProfile at the canonical command boundary' {
        (Get-Command Import-RepositoryExportManifest).Parameters['ExpectedProfile'].Attributes.Mandatory | Should -Contain $true
    }

    It 'rejects an absent profile instead of inferring from ExpectedProfile' {
        { Import-RepositoryExportManifest -Path $script:LegacyPath -ExpectedProfile CustomerHandover } | Should -Throw '*profile*'
    }

    It 'rejects unknown or non-exact profile <Profile>' -ForEach @(
        @{ Profile = 'Other' }, @{ Profile = 'tenantreplica' }, @{ Profile = '' }
    ) {
        $path = Write-ProfileValue (New-ProfileValue -Profile $Profile)
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*profile*'
    }

    It 'rejects ExpectedProfile mismatch for <Profile>' -ForEach @(
        @{ Profile = 'TenantReplica'; Expected = 'CustomerHandover' }
        @{ Profile = 'CustomerHandover'; Expected = 'TenantReplica' }
    ) {
        $path = Write-ProfileValue (New-ProfileValue -Profile $Profile)
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile $Expected } | Should -Throw '*profile*'
    }

    It 'rejects unknown properties at <Location>' -ForEach @(
        @{ Location = 'root' }, @{ Location = 'policy' }, @{ Location = 'replacement' }
    ) {
        $value = New-ProfileValue
        switch ($Location) {
            root { $value | Add-Member NoteProperty skipValidation $true }
            policy { $value.profilePolicy | Add-Member NoteProperty force $true }
            replacement { $value.replacements[0] | Add-Member NoteProperty regex $true }
        }
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects duplicate JSON properties including escaped and nested names' -ForEach @(
        @{ Json = '{"profile":"CustomerHandover","profile":"CustomerHandover"}' }
        @{ Json = '{"profile":"CustomerHandover","profi\u006ce":"CustomerHandover"}' }
        @{ Json = '{"profilePolicy":{"denyEvidence":true,"denyEvidence":true}}' }
    ) {
        $path = Join-Path $TestDrive 'duplicate.json'
        [IO.File]::WriteAllText($path, $Json, [Text.UTF8Encoding]::new($false))
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*duplicate JSON property*'
    }

    It 'rejects duplicate IDs in <Collection>' -ForEach @(
        @{ Collection = 'replacements' }, @{ Collection = 'residualMarkers' }, @{ Collection = 'sourceMarkerCatalog' }
    ) {
        $value = New-ProfileValue
        $value.$Collection[1].id = $value.$Collection[0].id
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects weakening <Policy> for <Profile>' -ForEach @(
        @{ Profile = 'CustomerHandover'; Policy = 'denyWorkflows' }
        @{ Profile = 'TenantReplica'; Policy = 'denyWorkflows' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyEvidence' }
        @{ Profile = 'TenantReplica'; Policy = 'denyEvidence' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyTenantTransitions' }
        @{ Profile = 'TenantReplica'; Policy = 'denyTenantTransitions' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyPrivateState' }
        @{ Profile = 'TenantReplica'; Policy = 'denyPrivateState' }
        @{ Profile = 'CustomerHandover'; Policy = 'denySourceHistory' }
        @{ Profile = 'TenantReplica'; Policy = 'denySourceHistory' }
        @{ Profile = 'CustomerHandover'; Policy = 'denyUntrackedFiles' }
        @{ Profile = 'TenantReplica'; Policy = 'denyUntrackedFiles' }
    ) {
        $value = New-ProfileValue -Profile $Profile
        $value.profilePolicy.$Policy = -not $value.profilePolicy.$Policy
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile $Profile } | Should -Throw '*policy*'
    }

    It 'rejects truthy strings instead of policy booleans' {
        $value = New-ProfileValue
        $value.profilePolicy.denyEvidence = 'true'
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*policy*'
    }

    It 'rejects a missing policy field' {
        $value = New-ProfileValue
        $value.profilePolicy.PSObject.Properties.Remove('denyEvidence')
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*policy*'
    }

    It 'rejects non-exact <Path> in <Location>' -ForEach @(
        @{ Path = 'docs/**'; Location = 'deny' }
        @{ Path = 'docs/?'; Location = 'deny' }
        @{ Path = 'docs/[abc]'; Location = 'deny' }
        @{ Path = '../README.md'; Location = 'deny' }
        @{ Path = 'C:/README.md'; Location = 'deny' }
        @{ Path = '/README.md'; Location = 'deny' }
        @{ Path = 'docs\README.md'; Location = 'deny' }
        @{ Path = 'docs//README.md'; Location = 'deny' }
        @{ Path = 'docs/README.md.'; Location = 'deny' }
        @{ Path = 'docs/README.md '; Location = 'deny' }
        @{ Path = 'docs/CON.json'; Location = 'deny' }
        @{ Path = 'docs/**.md'; Location = 'replacement' }
        @{ Path = 'infra/src/config/tenants/*.json'; Location = 'retain' }
    ) {
        $value = New-ProfileValue
        switch ($Location) {
            deny { $value.deniedPaths = @($Path) }
            replacement { $value.replacements[1].path = $Path }
            retain { $value.retainedTenantArtifacts[0].path = $Path }
        }
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*exact path*'
    }

    It 'rejects wildcard JSON selectors <Selector>' -ForEach @(
        @{ Selector = '/tenant*Alias' }, @{ Selector = '/tenant?' }, @{ Selector = '/[tenant]' }, @{ Selector = '/bad~2escape' }
    ) {
        $value = New-ProfileValue
        $value.replacements[0].selector = $Selector
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*Pointer*'
    }

    It 'rejects contradictory retained artifact and denied path <Denied>' -ForEach @(
        @{ Denied = 'infra/src/config/tenants/customer-synthetic.json' }
        @{ Denied = 'infra/src/config/tenants' }
        @{ Denied = 'INFRA/SRC/CONFIG/TENANTS' }
    ) {
        $value = New-ProfileValue
        $value.deniedPaths = @($Denied)
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*contradict*'
    }

    It 'does not confuse sibling path prefixes with contradictory rules' {
        $value = New-ProfileValue
        $value.deniedPaths = @('infra/src/config/tenants-sibling')
        $path = Write-ProfileValue $value
        (Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover).deniedPaths | Should -Be @('infra/src/config/tenants-sibling')
    }

    It 'rejects case-colliding retained paths' {
        $value = New-ProfileValue
        $entry = $value.retainedTenantArtifacts[0] | ConvertTo-Json | ConvertFrom-Json
        $entry.path = $entry.path.ToUpperInvariant()
        $value.retainedTenantArtifacts += $entry
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects case-colliding deny rules' {
        $value = New-ProfileValue
        $value.deniedPaths = @('docs/private', 'DOCS/PRIVATE')
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*unique*'
    }

    It 'rejects denied paths used by <Location>' -ForEach @(
        @{ Location = 'replacement' }, @{ Location = 'disposition' }, @{ Location = 'classification' }, @{ Location = 'binary' }
    ) {
        $value = New-ProfileValue
        switch ($Location) {
            replacement { $value.deniedPaths = @('README.md') }
            disposition { $value.deniedPaths = @('docs/specs') }
            classification { $value.deniedPaths = @('infra/tests/fixtures') }
            binary {
                $value.deniedPaths = @('assets')
                $value.inspectableBinaries = @([pscustomobject]@{ path = 'assets/synthetic.png'; sha256 = ('a' * 64); reason = 'Synthetic image.' })
            }
        }
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*contradict*'
    }

    It 'rejects ambiguous JSON shapes and coercible primitive types' -ForEach @(
        @{ Field = 'retainedTenantArtifacts'; InvalidValue = $null }
        @{ Field = 'replacements'; InvalidValue = @{} }
        @{ Field = 'tenantAlias'; InvalidValue = 123 }
        @{ Field = 'schemaVersion'; InvalidValue = 1.0 }
        @{ Field = 'deniedPaths'; InvalidValue = 'docs/private' }
    ) {
        $value = New-ProfileValue
        $value.$Field = $InvalidValue
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects noninteger occurrence counts' {
        $value = New-ProfileValue
        $value.replacements[1].requiredCount = '2'
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw
    }

    It 'rejects a UTF-8 BOM' {
        $path = Join-Path $TestDrive 'bom.json'
        [IO.File]::WriteAllText($path, ((New-ProfileValue) | ConvertTo-Json -Depth 50), [Text.UTF8Encoding]::new($true))
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*UTF-8 without BOM*'
    }

    It 'rejects malformed UTF-8 bytes' {
        $path = Join-Path $TestDrive 'invalid-utf8.json'
        [IO.File]::WriteAllBytes($path, [byte[]]@(0x7B, 0xC3, 0x28, 0x7D))
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*Unable to translate bytes*'
    }

    It 'preserves valid non-ASCII UTF-8 text' {
        $value = New-ProfileValue
        $value.customerScope = 'Synthetic ' + [char]0x00E9 + ' scope'
        $path = Write-ProfileValue $value
        (Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover).customerScope | Should -BeExactly $value.customerScope
    }

    It 'preserves timestamp-shaped JSON replacement values as literal strings across hosts' {
        $value = New-ProfileValue
        $value.replacements[0].expectedOldValue = '2026-01-01T00:00:00Z'
        $value.replacements[0].newValue = '2026-01-02T00:00:00Z'
        $path = Write-ProfileValue $value
        $manifest = Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover
        ($manifest.replacements[0].expectedOldValue -is [string]) | Should -BeTrue
        $manifest.replacements[0].expectedOldValue | Should -BeExactly '2026-01-01T00:00:00Z'
        $manifest.replacements[0].newValue | Should -BeExactly '2026-01-02T00:00:00Z'
    }

    It 'preserves nested JSON arrays and null replacement elements without rewriting their meaning' {
        $value = New-ProfileValue
        $value.replacements[0].expectedOldValue = ('{"items":[null,["synthetic-value"],[],false,1]}' | ConvertFrom-Json).items
        $value.replacements[0].newValue = '{"items":[null,"synthetic-new-value"]}' | ConvertFrom-Json
        $path = Write-ProfileValue $value
        $manifest = Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover
        (ConvertTo-Json -InputObject $manifest.replacements[0].expectedOldValue -Depth 20 -Compress) | Should -BeExactly '[null,["synthetic-value"],[],false,1]'
        ($manifest.replacements[0].newValue | ConvertTo-Json -Depth 20 -Compress) | Should -BeExactly '{"items":[null,"synthetic-new-value"]}'
    }

    It 'keeps unknown validation suite IDs blocking' {
        $value = New-ProfileValue
        $value.validationSuites = @('Invoke-CustomerCommand')
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*fixed local suite IDs*'
    }

    It 'rejects relative manifest locations before reading them' {
        { Import-RepositoryExportManifest -Path 'relative.json' -ExpectedProfile CustomerHandover } | Should -Throw '*absolute*'
    }

    It 'imports both required synthetic samples as explicitly profiled contracts' {
        (Import-RepositoryExportManifest -Path $script:CustomerSample -ExpectedProfile CustomerHandover).profile | Should -BeExactly 'CustomerHandover'
        (Import-RepositoryExportManifest -Path $script:ReplicaSample -ExpectedProfile TenantReplica).profile | Should -BeExactly 'TenantReplica'
    }

    It 'preserves empty and singleton arrays in canonical output' {
        $manifest = Import-RepositoryExportManifest -Path $script:CustomerSample -ExpectedProfile CustomerHandover
        ($manifest.inspectableBinaries -is [array]) | Should -BeTrue
        $manifest.inspectableBinaries.Count | Should -Be 0
        ($manifest.retainedTenantArtifacts -is [array]) | Should -BeTrue
        $manifest.retainedTenantArtifacts.Count | Should -Be 1
        ($manifest.sourceMarkerCatalog[0].sources -is [array]) | Should -BeTrue
        $manifest.sourceMarkerCatalog[0].sources.Count | Should -Be 1
    }

    It 'maps historical v1 input to the exact canonical customer sample without mutating input' {
        $legacy = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $before = ConvertTo-TenantLifecycleCanonicalJson -InputObject $legacy
        $expected = ConvertTo-TenantLifecycleCanonicalJson -InputObject ([IO.File]::ReadAllText($script:CustomerSample) | ConvertFrom-Json)
        $first = ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy
        $second = Import-CustomerExportManifest -Path $script:LegacyPath
        $first.profile | Should -BeExactly 'CustomerHandover'
        $first.profilePolicy.denyWorkflows | Should -BeTrue
        $actualBytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-TenantLifecycleCanonicalJson -InputObject $first))
        [Convert]::ToBase64String($actualBytes) | Should -BeExactly ([Convert]::ToBase64String([Text.UTF8Encoding]::new($false).GetBytes($expected)))
        (ConvertTo-TenantLifecycleCanonicalJson -InputObject $second) | Should -BeExactly $expected
        (ConvertTo-TenantLifecycleCanonicalJson -InputObject (ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy)) | Should -BeExactly $expected
        (ConvertTo-TenantLifecycleCanonicalJson -InputObject $legacy) | Should -BeExactly $before
    }

    It 'does not allow the legacy adapter to reinterpret a profiled manifest' {
        { ConvertTo-CustomerHandoverManifest -LegacyManifest (New-ProfileValue -Profile TenantReplica) } | Should -Throw
        { Import-CustomerExportManifest -Path $script:ReplicaSample } | Should -Throw '*profile*'
    }

    It 'does not silently drop unknown legacy fields' {
        $legacy = [IO.File]::ReadAllText($script:LegacyPath) | ConvertFrom-Json
        $legacy | Add-Member NoteProperty force $true
        { ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy } | Should -Throw '*closed*'
    }

    It 'keeps the historical invalid fixture invalid through both legacy interfaces' {
        $path = Join-Path $PSScriptRoot '..\fixtures\runbooks\customer-export.invalid.json'
        { Import-CustomerExportManifest -Path $path } | Should -Throw '*exact path*'
        $legacy = [IO.File]::ReadAllText($path) | ConvertFrom-Json
        { ConvertTo-CustomerHandoverManifest -LegacyManifest $legacy } | Should -Throw '*exact path*'
    }

    It 'keeps customer workflow evidence and vendored replacement denials' -ForEach @(
        @{ Prohibited = '.github/workflows/customer.md' }
        @{ Prohibited = 'infra/evidence/customer.md' }
        @{ Prohibited = '.github/skills/vendor/README.md' }
    ) {
        $value = New-ProfileValue
        $value.replacements[1].path = $Prohibited
        $path = Write-ProfileValue $value
        { Import-RepositoryExportManifest -Path $path -ExpectedProfile CustomerHandover } | Should -Throw '*prohibited replacement path*'
    }

    It 'does not let legacy consumers silently ignore new deny rules' {
        $value = New-ProfileValue
        $value.deniedPaths = @('docs/private')
        $path = Write-ProfileValue $value
        { Import-CustomerExportManifest -Path $path } | Should -Throw '*deniedPaths*'
    }

    It 'exports both new operations from both module declarations' {
        $exports = (Test-ModuleManifest $script:Module).ExportedFunctions.Keys
        foreach ($name in @('Import-RepositoryExportManifest', 'ConvertTo-CustomerHandoverManifest')) {
            $exports | Should -Contain $name
            Get-Command $name -Module Caldova.HrFrontier.Bootstrap | Should -Not -BeNullOrEmpty
        }
    }
}
