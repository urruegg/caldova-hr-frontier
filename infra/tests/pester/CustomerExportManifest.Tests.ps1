Set-StrictMode -Version Latest

Describe 'Customer export manifest contract' {
    BeforeAll {
        $script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:Module = Join-Path $script:Root 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        $script:Sample = Join-Path $script:Root 'infra\src\config\runbooks\customer-export.sample.json'
        Import-Module $script:Module -Force
    }

    It 'imports the synthetic closed sample' {
        $manifest = Import-CustomerExportManifest -Path $script:Sample
        $manifest.schemaVersion | Should -Be '1.0'
        $manifest.tenantAlias | Should -Be 'source-lab'
        @($manifest.replacements | Where-Object format -eq 'MarkdownExact').Count | Should -Be 1
        ($manifest.replacements | Where-Object format -eq 'MarkdownExact').requiredCount | Should -Be 2
        @($manifest.sourceMarkerCatalog).Count | Should -Be @($manifest.residualMarkers).Count
        @($manifest.fileClassifications | Where-Object classification -eq 'SyntheticFixture').Count | Should -Be 1
        @($manifest.validationSuites) | Should -Be @('Pester', 'RepositorySafety', 'BicepBuild')
    }

    It 'rejects wildcard dispositions and unknown validation commands' {
        {
            Import-CustomerExportManifest -Path (Join-Path $PSScriptRoot '..\fixtures\runbooks\customer-export.invalid.json')
        } | Should -Throw '*exact path*'
    }

    It 'rejects Markdown wildcard regex and prohibited-path options' {
        $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
        $rule = $value.replacements | Where-Object format -eq 'MarkdownExact'
        $rule.path = 'docs/**/*.md'
        $rule | Add-Member NoteProperty regex $true
        $path = Join-Path $TestDrive 'invalid-markdown-replacement.json'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        { Import-CustomerExportManifest -Path $path } | Should -Throw
    }

    It 'rejects exact Markdown paths in vendored skills workflows and evidence' {
        foreach ($prohibited in @(
            '.github/skills/vendor/README.md',
            '.github/workflows/customer.md',
            'infra/evidence/customer.md'
        )) {
            $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
            ($value.replacements | Where-Object format -eq 'MarkdownExact').path = $prohibited
            $path = Join-Path $TestDrive (([guid]::NewGuid().ToString('N')) + '.json')
            [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
            { Import-CustomerExportManifest -Path $path } | Should -Throw '*prohibited replacement path*'
        }
    }

    It 'rejects evidence retention and marker-set drift' {
        $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
        $value.retainedTenantArtifacts[0].path = 'infra/evidence/discovery/source.json'
        $path = Join-Path $TestDrive 'evidence-retention.json'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        { Import-CustomerExportManifest -Path $path } | Should -Throw '*evidence*'

        $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
        $value.residualMarkers = @($value.residualMarkers | Select-Object -First 1)
        $path = Join-Path $TestDrive 'missing-residual-marker.json'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        { Import-CustomerExportManifest -Path $path } | Should -Throw '*exactly match*'

        $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
        $value.residualMarkers += [pscustomobject]@{
            id = 'additional-marker'
            category = 'OtherTenantIdentifier'
            value = 'synthetic-additional-marker'
            comparison = 'Ordinal'
        }
        $path = Join-Path $TestDrive 'additional-residual-marker.json'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        { Import-CustomerExportManifest -Path $path } | Should -Throw '*exactly match*'
    }

    It 'rejects broad or digest-free data classifications' {
        $value = Get-Content -Raw $script:Sample | ConvertFrom-Json
        $value.fileClassifications[0].path = 'infra/tests/fixtures/**'
        $value.fileClassifications[0].PSObject.Properties.Remove('expectedOutputSha256')
        $path = Join-Path $TestDrive 'invalid-classification.json'
        [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 30), [Text.UTF8Encoding]::new($false))
        { Import-CustomerExportManifest -Path $path } | Should -Throw
    }

    It 'exports the importer from both module declarations' {
        (Test-ModuleManifest $script:Module).ExportedFunctions.Keys | Should -Contain 'Import-CustomerExportManifest'
        Get-Command Import-CustomerExportManifest -Module Caldova.HrFrontier.Bootstrap | Should -Not -BeNullOrEmpty
    }
}
