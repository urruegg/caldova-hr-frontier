Set-StrictMode -Version Latest

Describe 'Tenant 1 blueprint verification' {
    BeforeAll {
        $script:ManifestPath = Join-Path $PSScriptRoot '..\..\src\config\tenants\caldova25156897.psd1'
        $script:EvidencePath = Join-Path $PSScriptRoot '..\..\evidence\discovery\caldova25156897.json'

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
        Test-Path -LiteralPath $script:ManifestPath | Should -BeTrue
        Test-Path -LiteralPath $script:EvidencePath | Should -BeTrue
    }

    It 'has every Existing component''s stable ID present in discovery evidence with Status Found' {
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
        $manifest = Import-PowerShellDataFile -LiteralPath $script:ManifestPath
        $evidence = Get-Content -Raw -LiteralPath $script:EvidencePath | ConvertFrom-Json

        [string]$manifest.TenantAlias | Should -Be ([string]$evidence.TenantAlias)
    }
}
