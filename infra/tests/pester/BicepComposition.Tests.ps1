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
            SubscriptionPolicyAssignments = Join-Path $script:BicepRoot 'modules\subscription-policy-assignments.bicep'
        }
        $script:GeneratorScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\New-TenantBicepParameters.ps1'
        $script:AllowedResourceTypes = @(
            'Microsoft.Resources/resourceGroups',
            'Microsoft.OperationalInsights/workspaces',
            'Microsoft.Insights/diagnosticSettings',
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
            'modules/subscription-policy-assignments.bicep'
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
                'infra\src\config\schemas\tenant.schema.json',
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

            [System.IO.File]::WriteAllText(
                (Join-Path $root '.gitignore'),
                "infra/src/config/tenants/*.local.psd1$([Environment]::NewLine)",
                [System.Text.UTF8Encoding]::new($false)
            )
            & git -C $root init --quiet
            if ($LASTEXITCODE -ne 0) {
                throw 'Could not initialize the isolated Bicep repository.'
            }

            $tenantConfigurationPath = Join-Path $root 'infra\src\config\tenants\tenant1.local.psd1'
            [void](New-Item -ItemType Directory -Path (Split-Path -Parent $tenantConfigurationPath) -Force)
            $tenantConfigurationContent = @'
@{
    SchemaVersion = '1.0'
    PublicTenantKey = 'tenant1'
    TenantAlias = 'fixturetenant42'
    DisplayName = 'Fixture Tenant 42'
    TenantId = '22222222-2222-2222-2222-222222222222'
    AdminUpn = 'operator@fixture.example'
    SubscriptionId = '11111111-1111-1111-1111-111111111111'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'syn'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'abc123'
    NamingRoot = 'syn-hr-agentic-abc123'
    LifecycleState = 'IntentReviewed'
    GitHub = @{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = 'bootstrap-fixturetenant42'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://dev.azure.com/synthetic/'
        ProjectName = 'Synthetic HR Frontier'
    }
    PowerPlatform = @{
        DevUrl = 'https://fixture-dev.example.test/'
        TestUrl = 'https://fixture-test.example.test/'
        ProdUrl = 'https://fixture-prod.example.test/'
    }
    Components = @{
        AzureSubscription = @{ Mode = 'Existing'; Id = '11111111-1111-1111-1111-111111111111' }
    }
}
'@
            [System.IO.File]::WriteAllText($tenantConfigurationPath, $tenantConfigurationContent, [System.Text.UTF8Encoding]::new($false))

            $root
        }

        function script:Get-IsolatedTenantConfigurationPath {
            param([Parameter(Mandatory)][string]$HarnessRoot)

            Join-Path $HarnessRoot 'infra\src\config\tenants\tenant1.local.psd1'
        }

        function script:New-IsolatedOutputDirectory {
            param([Parameter(Mandatory)][string]$HarnessRoot)

            $path = Join-Path (Split-Path -Parent $HarnessRoot) ((Split-Path -Leaf $HarnessRoot) + '-output')
            [void](New-Item -ItemType Directory -Path $path -Force)
            $path
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
            $script:ModulePaths.SubscriptionPolicyAssignments,
            $script:GeneratorScriptPath
        )

        foreach ($path in $expectedPaths) {
            Test-Path -LiteralPath $path | Should -BeTrue
        }
    }

    It 'uses a closed typed subscription entry point and the four approved modules without explicit names' {
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
        $moduleBlocks.Count | Should -Be 4
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
        $mainResources.Count | Should -Be 4
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

    It 'excludes role definition and assignment management from the lean composition' {
        $mainTemplate = Build-BicepJson -Path $script:MainBicepPath
        $mainTemplate.Raw | Should -Not -Match 'Microsoft\.Authorization/role(?:Definitions|Assignments)'
        $mainTemplate.Json.parameters.tenant.metadata.description | Should -Not -BeNullOrEmpty

        $mainContent = Get-Content -Raw -LiteralPath $script:MainBicepPath
        $mainContent | Should -Not -Match 'validationRoleName|validationPrincipalId|validationRole'
        $mainContent | Should -Not -Match 'validationRoleDefinitionId|validationRoleAssignmentId'

        Test-Path -LiteralPath (Join-Path $script:BicepRoot 'modules\validation-role.bicep') |
            Should -BeFalse
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

    It 'generates a BOM-free parameter file in an isolated harness and builds it locally' {
        $harnessRoot = New-IsolatedTask5Harness
        $outputDirectory = New-IsolatedOutputDirectory -HarnessRoot $harnessRoot

        Push-Location $harnessRoot
        try {
            $result = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-PublicTenantKey', 'tenant1',
                '-TenantConfigurationPath', (Get-IsolatedTenantConfigurationPath -HarnessRoot $harnessRoot),
                '-OutputPath', $outputDirectory
            )

            $result.ExitCode | Should -Be 0

            $parameterPath = Join-Path $outputDirectory 'fixturetenant42.bicepparam'
            Test-Path -LiteralPath $parameterPath | Should -BeTrue

            $bytes = [System.IO.File]::ReadAllBytes($parameterPath)
            ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) | Should -BeFalse

            $content = [System.Text.Encoding]::UTF8.GetString($bytes)
            $content | Should -Match "^using '.+main\.bicep'"
            $content | Should -Match "tenantAlias: 'fixturetenant42'"
            $content | Should -Match "namingRoot: 'syn-hr-agentic-abc123'"
            $content | Should -Match "platformResourceGroupName: 'rg-syn-hr-agentic-abc123-platform'"
            $content | Should -Match "logAnalyticsWorkspaceName: 'log-syn-hr-agentic-abc123'"
            $content | Should -Not -Match 'validationRoleName|validationPrincipalId'
            $content | Should -Match 'policyAssignments: \[\]'

            $builtParameters = Build-BicepParametersJson -Path $parameterPath
            $parameterJson = $builtParameters.Json.parametersJson | ConvertFrom-Json
            $parameterJson.parameters.tenant.value.tenantAlias | Should -Be 'fixturetenant42'
        }
        finally {
            Pop-Location
        }
    }

    It 'allows identical output and rejects a mismatched public tenant key' {
        $harnessRoot = New-IsolatedTask5Harness
        $outputDirectory = New-IsolatedOutputDirectory -HarnessRoot $harnessRoot
        $tenantConfigurationPath = Get-IsolatedTenantConfigurationPath -HarnessRoot $harnessRoot

        Push-Location $harnessRoot
        try {
            $initial = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-PublicTenantKey', 'tenant1',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $initial.ExitCode | Should -Be 0

            $sameAgain = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-PublicTenantKey', 'tenant1',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $sameAgain.ExitCode | Should -Be 0

            $unknownTenant = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
                '-PublicTenantKey', 'tenant2',
                '-TenantConfigurationPath', $tenantConfigurationPath,
                '-OutputPath', $outputDirectory
            )
            $unknownTenant.ExitCode | Should -Not -Be 0
        }
        finally {
            Pop-Location
        }
    }

    It 'requires explicit local configuration and rejects repository output' {
        $tokens = $null
        $parseErrors = $null
        $entryPointAst = [System.Management.Automation.Language.Parser]::ParseFile($script:GeneratorScriptPath, [ref]$tokens, [ref]$parseErrors)
        $parseErrors.Count | Should -Be 0
        $parameters = @{}
        foreach ($parameter in $entryPointAst.ParamBlock.Parameters) {
            $parameters[$parameter.Name.VariablePath.UserPath] = $parameter
        }

        foreach ($name in @('PublicTenantKey', 'TenantConfigurationPath', 'OutputPath')) {
            $parameters.ContainsKey($name) | Should -BeTrue
            @($parameters[$name].Attributes | Where-Object {
                $_ -is [System.Management.Automation.Language.AttributeAst] -and
                $_.TypeName.FullName -ceq 'Parameter' -and
                $_.NamedArguments.ArgumentName -contains 'Mandatory'
            }).Count | Should -Be 1
        }
        $parameters.ContainsKey('TenantAlias') | Should -BeFalse
        $parameters.ContainsKey('ValidationPrincipalId') | Should -BeFalse

        $harnessRoot = New-IsolatedTask5Harness
        $insideOutput = Join-Path $harnessRoot 'generated'
        $result = Invoke-Task5Generator -HarnessRoot $harnessRoot -Arguments @(
            '-PublicTenantKey', 'tenant1',
            '-TenantConfigurationPath', (Get-IsolatedTenantConfigurationPath -HarnessRoot $harnessRoot),
            '-OutputPath', $insideOutput
        )
        $result.ExitCode | Should -Not -Be 0
        $result.Output | Should -Match 'outside the repository'
    }
}