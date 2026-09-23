Set-StrictMode -Version Latest

Describe 'Task 5 Bicep composition' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:BicepRoot = Join-Path $script:RepositoryRoot 'infra\src\bicep'
        $script:MainBicepPath = Join-Path $script:BicepRoot 'main.bicep'
        $script:BicepConfigPath = Join-Path $script:BicepRoot 'bicepconfig.json'
        $script:ModulePaths = [ordered]@{
            ResourceGroup = Join-Path $script:BicepRoot 'modules\resource-group.bicep'
            LogAnalyticsWorkspace = Join-Path $script:BicepRoot 'modules\log-analytics-workspace.bicep'
            ActivityLogDiagnostics = Join-Path $script:BicepRoot 'modules\activity-log-diagnostics.bicep'
            ValidationRole = Join-Path $script:BicepRoot 'modules\validation-role.bicep'
            SubscriptionPolicyAssignments = Join-Path $script:BicepRoot 'modules\subscription-policy-assignments.bicep'
        }
        $script:GeneratorScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\New-TenantBicepParameters.ps1'
        $script:TenantManifestPath = Join-Path $script:RepositoryRoot 'infra\src\config\tenants\caldova25156897.psd1'
        $script:AllowedResourceTypes = @(
            'Microsoft.Resources/resourceGroups',
            'Microsoft.OperationalInsights/workspaces',
            'Microsoft.Insights/diagnosticSettings',
            'Microsoft.Authorization/roleDefinitions',
            'Microsoft.Authorization/roleAssignments',
            'Microsoft.Authorization/policyAssignments'
        )
        $script:ForbiddenResourceTypePatterns = @(
            'Microsoft.ManagedIdentity/',
            'Microsoft.KeyVault/',
            'Microsoft.Storage/',
            'Microsoft.Web/',
            'Microsoft.Network/'
        )
        $script:ExpectedModuleReferences = @(
            'modules/resource-group.bicep',
            'modules/log-analytics-workspace.bicep',
            'modules/activity-log-diagnostics.bicep',
            'modules/validation-role.bicep',
            'modules/subscription-policy-assignments.bicep'
        )
        $script:ExpectedRoleActions = @(
            '*/read',
            'Microsoft.Resources/deployments/read',
            'Microsoft.Resources/deployments/validate/action',
            'Microsoft.Resources/deployments/whatIf/action'
        )

        function script:Invoke-AzCli {
            param(
                [Parameter(Mandatory)]
                [string[]]$Arguments
            )

            $output = & az @Arguments 2>&1 | Out-String
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = $output.TrimEnd()
            }
        }

        function script:Build-BicepJson {
            param(
                [Parameter(Mandatory)]
                [string]$Path
            )

            $result = Invoke-AzCli -Arguments @('bicep', 'build', '--file', $Path, '--stdout')
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Not -BeNullOrEmpty

            [pscustomobject]@{
                Raw = $result.Output
                Json = $result.Output | ConvertFrom-Json
            }
        }

        function script:Build-BicepParametersJson {
            param(
                [Parameter(Mandatory)]
                [string]$Path
            )

            $result = Invoke-AzCli -Arguments @('bicep', 'build-params', '--file', $Path, '--stdout')
            $result.ExitCode | Should -Be 0
            $result.Output | Should -Not -BeNullOrEmpty

            [pscustomobject]@{
                Raw = $result.Output
                Json = $result.Output | ConvertFrom-Json
            }
        }

        function script:Get-BicepFiles {
            $files = @($script:MainBicepPath, $script:BicepConfigPath, $script:GeneratorScriptPath)
            $files += @($script:ModulePaths.Values)
            $files
        }

        function script:Get-CompiledTemplateResources {
            param(
                [Parameter(Mandatory)]
                [object]$TemplateJson
            )

            $resources = $TemplateJson.resources
            if ($resources -is [System.Array]) {
                return @($resources)
            }

            if ($resources.PSObject.Properties.Name -contains 'type') {
                return @($resources)
            }

            @($resources.PSObject.Properties.Value)
        }

        function script:New-IsolatedTask5Harness {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            [void](New-Item -ItemType Directory -Path $root -Force)

            $copies = @(
                'infra\src\bicep',
                'infra\src\config',
                'infra\src\scripts\New-TenantBicepParameters.ps1',
                'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap'
            )

            foreach ($relativePath in $copies) {
                $sourcePath = Join-Path $script:RepositoryRoot $relativePath
                $destinationPath = Join-Path $root $relativePath
                $destinationParent = Split-Path -Parent $destinationPath
                if (-not [string]::IsNullOrWhiteSpace($destinationParent)) {
                    [void](New-Item -ItemType Directory -Path $destinationParent -Force)
                }

                if (Test-Path -LiteralPath $sourcePath -PathType Container) {
                    Copy-Item -LiteralPath $sourcePath -Destination $destinationParent -Recurse -Force
                }
                else {
                    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
                }
            }

            $root
        }

        function script:Invoke-Task5Generator {
            param(
                [Parameter(Mandatory)]
                [string]$HarnessRoot,

                [Parameter(Mandatory)]
                [string[]]$Arguments
            )

            $scriptPath = Join-Path $HarnessRoot 'infra\src\scripts\New-TenantBicepParameters.ps1'
            $stdoutPath = [System.IO.Path]::GetTempFileName()
            $stderrPath = [System.IO.Path]::GetTempFileName()

            try {
                $processArguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + $Arguments
                $process = Start-Process -FilePath 'powershell.exe' -WorkingDirectory $HarnessRoot -ArgumentList $processArguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -Wait
                $stdout = [System.IO.File]::ReadAllText($stdoutPath)
                $stderr = [System.IO.File]::ReadAllText($stderrPath)

                [pscustomobject]@{
                    ExitCode = $process.ExitCode
                    Output = @($stdout.TrimEnd(), $stderr.TrimEnd() | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine
                }
            }
            finally {
                Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'defines exactly the tracked Task 5 surface before implementation' {
        $expectedPaths = @(
            $script:BicepConfigPath,
            $script:MainBicepPath,
            $script:ModulePaths.ResourceGroup,
            $script:ModulePaths.LogAnalyticsWorkspace,
            $script:ModulePaths.ActivityLogDiagnostics,
            $script:ModulePaths.ValidationRole,
            $script:ModulePaths.SubscriptionPolicyAssignments,
            $script:GeneratorScriptPath
        )

        foreach ($path in $expectedPaths) {
            Test-Path -LiteralPath $path | Should -BeTrue
        }
    }

    It 'uses a closed typed subscription entry point and the five approved modules without explicit names' {
        $content = Get-Content -Raw -LiteralPath $script:MainBicepPath

        $content | Should -Match "targetScope = 'subscription'"
        $content | Should -Match 'type tenantConfiguration = \{'
        $content | Should -Match 'type policyAssignmentConfiguration = \{'
        $content | Should -Match "param tenant tenantConfiguration"

        foreach ($moduleReference in $script:ExpectedModuleReferences) {
            $escapedReference = [regex]::Escape($moduleReference)
            $content | Should -Match ("module\s+\w+\s+'{0}'\s*=\s*\{{" -f $escapedReference)
        }

        $moduleBlocks = [regex]::Matches(
            $content,
            "module\s+\w+\s+'[^']+'\s*=\s*\{(?<body>.*?)\r?\n\}",
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
        $moduleBlocks.Count | Should -Be 5
        foreach ($moduleBlock in $moduleBlocks) {
            $moduleBlock.Groups['body'].Value | Should -Not -Match '(^|\r?\n)\s*name\s*:'
        }
    }

    It 'keeps the policy assignment module typed and empty by default' {
        $content = Get-Content -Raw -LiteralPath $script:ModulePaths.SubscriptionPolicyAssignments
        $content | Should -Match 'param policyAssignments policyAssignmentConfiguration\[\] = \[\]'
    }

    It 'builds the main template and keeps resource types on the approved allowlist' {
        $mainTemplate = Build-BicepJson -Path $script:MainBicepPath
        $mainTemplate.Json.'$schema' | Should -Match 'subscriptionDeploymentTemplate'
        $mainResources = @(Get-CompiledTemplateResources -TemplateJson $mainTemplate.Json)
        $mainResources.Count | Should -Be 5
        foreach ($resource in $mainResources) {
            $resource.type | Should -Be 'Microsoft.Resources/deployments'
        }

        foreach ($modulePath in $script:ModulePaths.Values) {
            $template = Build-BicepJson -Path $modulePath
            foreach ($resource in @(Get-CompiledTemplateResources -TemplateJson $template.Json)) {
                $resource.type | Should -BeIn $script:AllowedResourceTypes
            }
        }
    }

    It 'orders the workspace deployment after the platform resource group' {
        $content = Get-Content -Raw -LiteralPath $script:MainBicepPath
        $workspaceModule = [regex]::Match(
            $content,
            "module\s+logAnalyticsWorkspace\s+'[^']+'\s*=\s*\{(?<body>.*?)\r?\n\}",
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
        $workspaceModule.Success | Should -BeTrue
        $workspaceModule.Groups['body'].Value | Should -Match 'dependsOn\s*:\s*\[\s*platformResourceGroup\s*\]'

        $mainTemplate = Build-BicepJson -Path $script:MainBicepPath
        $workspaceDeployment = $mainTemplate.Json.resources.logAnalyticsWorkspace
        $workspaceDeployment.PSObject.Properties.Name | Should -Contain 'dependsOn'
        @($workspaceDeployment.dependsOn).Count | Should -BeGreaterThan 0
        (@($workspaceDeployment.dependsOn) -join "`n") | Should -Match 'platformResourceGroup'
    }

    It 'does not introduce forbidden resource providers or runtime services' {
        $allContent = (Get-BicepFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_ }) -join "`n"

        foreach ($pattern in $script:ForbiddenResourceTypePatterns) {
            $allContent | Should -Not -Match ([regex]::Escape($pattern))
        }

        foreach ($runtimePattern in @('functionapp', 'appservice', 'keyvault', 'managedidentity', 'storage account')) {
            $allContent.ToLowerInvariant() | Should -Not -Match $runtimePattern
        }
    }

    It 'pins the reviewed workspace and diagnostics shape in compiled JSON' {
        $workspaceTemplate = Build-BicepJson -Path $script:ModulePaths.LogAnalyticsWorkspace
        $workspaceResource = @($workspaceTemplate.Json.resources | Where-Object { $_.type -eq 'Microsoft.OperationalInsights/workspaces' })[0]

        $workspaceResource.apiVersion | Should -Be '2023-09-01'
        $workspaceResource.properties.retentionInDays | Should -Be 30
        $workspaceResource.properties.publicNetworkAccessForIngestion | Should -Be 'Enabled'
        $workspaceResource.properties.publicNetworkAccessForQuery | Should -Be 'Enabled'
        $workspaceResource.properties.sku.name | Should -Be 'PerGB2018'

        $diagnosticsTemplate = Build-BicepJson -Path $script:ModulePaths.ActivityLogDiagnostics
        $diagnosticResource = @($diagnosticsTemplate.Json.resources | Where-Object { $_.type -eq 'Microsoft.Insights/diagnosticSettings' })[0]
        $diagnosticResource.apiVersion | Should -Be '2021-05-01-preview'
        $diagnosticResource.properties.workspaceId | Should -Not -BeNullOrEmpty
        $diagnosticResource.properties.PSObject.Properties.Name | Should -Contain 'logs'
        $diagnosticResource.properties.PSObject.Properties.Name | Should -Not -Contain 'storageAccountId'
        $diagnosticResource.properties.PSObject.Properties.Name | Should -Not -Contain 'eventHubAuthorizationRuleId'
        $diagnosticResource.properties.PSObject.Properties.Name | Should -Not -Contain 'eventHubName'
    }

    It 'pins the reviewed validation role actions without write or delete access' {
        $validationTemplate = Build-BicepJson -Path $script:ModulePaths.ValidationRole
        $roleDefinition = @($validationTemplate.Json.resources | Where-Object { $_.type -eq 'Microsoft.Authorization/roleDefinitions' })[0]
        $roleAssignment = @($validationTemplate.Json.resources | Where-Object { $_.type -eq 'Microsoft.Authorization/roleAssignments' })[0]

        $roleDefinition.apiVersion | Should -Be '2022-04-01'
        $roleAssignment.apiVersion | Should -Be '2022-04-01'
        $roleAssignment.properties.principalType | Should -Be 'ServicePrincipal'

        $permissions = @($roleDefinition.properties.permissions)[0]
        @($permissions.actions) | Should -Be $script:ExpectedRoleActions
        @($permissions.notActions).Count | Should -Be 0
        @($permissions.dataActions).Count | Should -Be 0
        @($permissions.notDataActions).Count | Should -Be 0

        foreach ($action in @($permissions.actions)) {
            $action.ToLowerInvariant() | Should -Not -Match 'write|delete'
        }
    }

    It 'generates a BOM-free parameter file in an isolated harness and builds it locally' {
        $harnessRoot = New-IsolatedTask5Harness
        $outputDirectory = Join-Path $harnessRoot 'infra\src\bicep\params'
        [void](New-Item -ItemType Directory -Path $outputDirectory -Force)

        Push-Location $harnessRoot
        try {
            $result = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-TenantAlias', 'caldova25156897',
                '-ValidationPrincipalId', '11111111-1111-1111-1111-111111111111',
                '-TenantConfigurationPath', (Join-Path $harnessRoot 'infra\src\config\tenants\caldova25156897.psd1'),
                '-OutputPath', $outputDirectory
            )

            $result.ExitCode | Should -Be 0

            $parameterPath = Join-Path $outputDirectory 'caldova25156897.bicepparam'
            Test-Path -LiteralPath $parameterPath | Should -BeTrue

            $bytes = [System.IO.File]::ReadAllBytes($parameterPath)
            ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) | Should -BeFalse

            $content = [System.Text.Encoding]::UTF8.GetString($bytes)
            $content | Should -Match "using '../main.bicep'"
            $content | Should -Match "tenantAlias: 'caldova25156897'"
            $content | Should -Match "namingRoot: 'cal-hr-agentic-bc8rbt'"
            $content | Should -Match "platformResourceGroupName: 'rg-cal-hr-agentic-bc8rbt-platform'"
            $content | Should -Match "logAnalyticsWorkspaceName: 'log-cal-hr-agentic-bc8rbt'"
            $content | Should -Match "validationRoleName: 'cal-hr-agentic-bc8rbt-deployment-validation'"
            $content | Should -Match "validationPrincipalId: '11111111-1111-1111-1111-111111111111'"
            $content | Should -Match 'policyAssignments: \[\]'

            $builtParameters = Build-BicepParametersJson -Path $parameterPath
            $parameterJson = $builtParameters.Json.parametersJson | ConvertFrom-Json
            $parameterJson.parameters.tenant.value.tenantAlias | Should -Be 'caldova25156897'
        }
        finally {
            Pop-Location
        }
    }

    It 'rejects invalid generator inputs and overwrite mismatches while allowing identical output' {
        $harnessRoot = New-IsolatedTask5Harness
        $outputDirectory = Join-Path $harnessRoot 'infra\src\bicep\params'
        [void](New-Item -ItemType Directory -Path $outputDirectory -Force)
        $tenantConfigurationPath = Join-Path $harnessRoot 'infra\src\config\tenants\caldova25156897.psd1'

        Push-Location $harnessRoot
        try {
            $initial = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-TenantAlias', 'caldova25156897',
                '-ValidationPrincipalId', '11111111-1111-1111-1111-111111111111',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $initial.ExitCode | Should -Be 0

            $sameAgain = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-TenantAlias', 'caldova25156897',
                '-ValidationPrincipalId', '11111111-1111-1111-1111-111111111111',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $sameAgain.ExitCode | Should -Be 0

            $invalidGuid = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-TenantAlias', 'caldova25156897',
                '-ValidationPrincipalId', 'not-a-guid',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $invalidGuid.ExitCode | Should -Not -Be 0

            $unknownTenant = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-TenantAlias', 'othertenant',
                '-ValidationPrincipalId', '11111111-1111-1111-1111-111111111111',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $unknownTenant.ExitCode | Should -Not -Be 0

            $differentPrincipal = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-TenantAlias', 'caldova25156897',
                '-ValidationPrincipalId', '22222222-2222-2222-2222-222222222222',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $differentPrincipal.ExitCode | Should -Not -Be 0

            $replacedPrincipal = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-TenantAlias', 'caldova25156897',
                '-ValidationPrincipalId', '22222222-2222-2222-2222-222222222222',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory,
                '-Replace'
            )
            $replacedPrincipal.ExitCode | Should -Be 0
        }
        finally {
            Pop-Location
        }
    }
}