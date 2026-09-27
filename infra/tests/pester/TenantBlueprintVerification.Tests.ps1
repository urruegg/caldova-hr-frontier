Set-StrictMode -Version Latest

Describe 'Tenant 1 blueprint verification' {
    BeforeAll {
        $script:ManifestPath = Join-Path $PSScriptRoot '..\..\src\config\tenants\caldova25156897.psd1'
        $script:EvidencePath = Join-Path $PSScriptRoot '..\..\evidence\discovery\caldova25156897.json'

        # A tenant-specific repository copy (Tenant 2, Tenant 3, ...) runs the
        # Repository Clean-Up Runbook, which removes Tenant 1's manifest and
        # discovery evidence. This suite is Tenant-1-specific and must skip
        # gracefully in that case rather than hard-fail.
        $script:BlueprintFilesPresent = (Test-Path -LiteralPath $script:ManifestPath) -and (Test-Path -LiteralPath $script:EvidencePath)
        $script:SkipBecause = "Tenant 1's manifest/evidence are not present in this repository copy"

        function script:Get-EvidenceResources {
            param([Parameter(Mandatory)] [object]$Evidence)

            $resources = [System.Collections.Generic.List[object]]::new()
            foreach ($serviceProperty in $Evidence.Services.PSObject.Properties) {
                $service = $serviceProperty.Value
                if ($null -eq $service.Resources) { continue }
                foreach ($resource in @($service.Resources)) {
                    $resources.Add($resource)
                }
            }
            @($resources)
        }
    }

    It 'has a reviewed manifest and a discovery evidence file at their expected paths' {
        if (-not $script:BlueprintFilesPresent) {
            Set-ItResult -Skipped -Because $script:SkipBecause
            return
        }

        Test-Path -LiteralPath $script:ManifestPath | Should -BeTrue
        Test-Path -LiteralPath $script:EvidencePath | Should -BeTrue
    }

    It 'has every Existing component''s stable ID present in discovery evidence with Status Found' {
        if (-not $script:BlueprintFilesPresent) {
            Set-ItResult -Skipped -Because $script:SkipBecause
            return
        }

        $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
        $evidence = Get-Content -Raw -LiteralPath $script:EvidencePath | ConvertFrom-Json
        $evidenceResources = Get-EvidenceResources -Evidence $evidence

        $existingComponents = @($manifest.Components.Keys | Where-Object {
            $manifest.Components[$_].Mode -ceq 'Existing'
        })

        $existingComponents.Count | Should -BeGreaterThan 0

        foreach ($componentName in $existingComponents) {
            $expectedId = [string]$manifest.Components[$componentName].Id
            $expectedId | Should -Not -BeNullOrEmpty -Because "component '$componentName' claims Mode=Existing and must carry a stable Id"

            $matchingResource = $evidenceResources | Where-Object {
                [string]$_.Type -ceq $componentName -and [string]$_.Id -ceq $expectedId
            } | Select-Object -First 1

            $matchingResource | Should -Not -BeNullOrEmpty -Because "no discovery evidence resource of Type '$componentName' with Id '$expectedId' was found"
            [string]$matchingResource.Status | Should -Be 'Found' -Because "component '$componentName' (Id '$expectedId') is not confirmed Found in discovery evidence"
        }
    }

    It 'has the manifest''s own TenantAlias field match the evidence file''s TenantAlias field' {
        if (-not $script:BlueprintFilesPresent) {
            Set-ItResult -Skipped -Because $script:SkipBecause
            return
        }

        $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
        $evidence = Get-Content -Raw -LiteralPath $script:EvidencePath | ConvertFrom-Json

        [string]$manifest.TenantAlias | Should -Be ([string]$evidence.TenantAlias)
    }
}
