Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$workflowCases = @(
    @{
        Name = 'discovery'
        Path = Join-Path $repositoryRoot '.github\workflows\discover-tenant.yml'
    },
    @{
        Name = 'bootstrap'
        Path = Join-Path $repositoryRoot '.github\workflows\bootstrap-tenant.yml'
    }
)
$workflowFilesPresent = @($workflowCases | Where-Object { Test-Path -LiteralPath $_.Path }).Count -eq $workflowCases.Count

Describe 'Task 7 tenant workflow contracts' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ActionPins = Get-Content -Raw -LiteralPath (Join-Path $script:RepositoryRoot 'infra\src\config\github\action-pins.json') | ConvertFrom-Json
        $script:WorkflowCases = @(
            @{
                Name = 'discovery'
                Path = Join-Path $script:RepositoryRoot '.github\workflows\discover-tenant.yml'
            },
            @{
                Name = 'bootstrap'
                Path = Join-Path $script:RepositoryRoot '.github\workflows\bootstrap-tenant.yml'
            }
        )

        function script:Get-ReviewedActionUse {
            param([Parameter(Mandatory)][string]$Name)

            $entry = $script:ActionPins.actions.PSObject.Properties[$Name].Value
            '{0}@{1}' -f $Name, $entry.sha
        }

        function script:Get-YamlBlock {
            param(
                [Parameter(Mandatory)]
                [string]$Content,

                [Parameter(Mandatory)]
                [string]$Header,

                [Parameter(Mandatory)]
                [int]$Indent
            )

            $lines = @($Content -split "`r?`n")
            $expectedHeader = ((' ' * $Indent) + $Header)
            $matches = @(
                for ($index = 0; $index -lt $lines.Count; $index++) {
                    if ($lines[$index] -ceq $expectedHeader) {
                        $index
                    }
                }
            )
            if ($matches.Count -ne 1) {
                throw "Expected exactly one YAML block '$Header' at indent $Indent; found $($matches.Count)."
            }

            $start = $matches[0]
            $end = $lines.Count
            for ($index = $start + 1; $index -lt $lines.Count; $index++) {
                if ([string]::IsNullOrWhiteSpace($lines[$index])) {
                    continue
                }

                $lineIndent = $lines[$index].Length - $lines[$index].TrimStart().Length
                if ($lineIndent -le $Indent) {
                    $end = $index
                    break
                }
            }

            ($lines[$start..($end - 1)] -join "`n")
        }

        function script:Get-YamlMappingKeys {
            param(
                [Parameter(Mandatory)]
                [string]$Content,

                [Parameter(Mandatory)]
                [int]$Indent
            )

            $prefix = [regex]::Escape(' ' * $Indent)
            @([regex]::Matches($Content, "(?m)^${prefix}([A-Za-z0-9_-]+):(?:\s.*)?$") | ForEach-Object { $_.Groups[1].Value })
        }

        function script:Get-YamlScalarValue {
            param(
                [Parameter(Mandatory)]
                [string]$Content,

                [Parameter(Mandatory)]
                [string]$Name,

                [Parameter(Mandatory)]
                [int]$Indent
            )

            $prefix = [regex]::Escape(' ' * $Indent)
            $namePattern = [regex]::Escape($Name)
            $matches = @([regex]::Matches($Content, "(?m)^${prefix}${namePattern}:\s*(.+?)\s*$"))
            if ($matches.Count -ne 1) {
                throw "Expected exactly one YAML scalar '$Name' at indent $Indent; found $($matches.Count)."
            }

            $matches[0].Groups[1].Value
        }

        function script:Get-YamlListValues {
            param(
                [Parameter(Mandatory)]
                [string]$Content,

                [Parameter(Mandatory)]
                [int]$Indent
            )

            $prefix = [regex]::Escape(' ' * $Indent)
            @([regex]::Matches($Content, "(?m)^${prefix}-\s+(.+?)\s*$") | ForEach-Object { $_.Groups[1].Value })
        }

        function script:Get-OnlyJobBlock {
            param(
                [Parameter(Mandatory)]
                [string]$Content
            )

            $jobsBlock = Get-YamlBlock -Content $Content -Header 'jobs:' -Indent 0
            $jobNames = @(Get-YamlMappingKeys -Content $jobsBlock -Indent 2)
            if ($jobNames.Count -ne 1) {
                throw "Tenant workflows must define exactly one job; found $($jobNames.Count)."
            }

            Get-YamlBlock -Content $jobsBlock -Header "$($jobNames[0]):" -Indent 2
        }

        function script:Get-StepBlock {
            param(
                [Parameter(Mandatory)]
                [string]$Job,

                [Parameter(Mandatory)]
                [string]$Name
            )

            $lines = @($Job -split "`r?`n")
            $stepHeader = "      - name: $Name"
            $matches = @(
                for ($index = 0; $index -lt $lines.Count; $index++) {
                    if ($lines[$index] -ceq $stepHeader) {
                        $index
                    }
                }
            )
            if ($matches.Count -ne 1) {
                throw "Expected exactly one step named '$Name'; found $($matches.Count)."
            }

            $start = $matches[0]
            $end = $lines.Count
            for ($index = $start + 1; $index -lt $lines.Count; $index++) {
                if ($lines[$index] -match '^      - ') {
                    $end = $index
                    break
                }
            }

            ($lines[$start..($end - 1)] -join "`n")
        }

        function script:Get-StepNames {
            param(
                [Parameter(Mandatory)]
                [string]$Job
            )

            @([regex]::Matches($Job, '(?m)^      - name:\s*(.+?)\s*$') | ForEach-Object { $_.Groups[1].Value })
        }

        function script:Get-StepIndex {
            param(
                [Parameter(Mandatory)]
                [string]$Job,

                [Parameter(Mandatory)]
                [string]$Name
            )

            $stepNames = @(Get-StepNames -Job $Job)
            for ($index = 0; $index -lt $stepNames.Count; $index++) {
                if ($stepNames[$index] -ceq $Name) {
                    return $index
                }
            }

            -1
        }

        function script:Get-PowerShellAst {
            param(
                [Parameter(Mandatory)]
                [string]$Script
            )

            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($Script, [ref]$tokens, [ref]$errors)
            if (@($errors).Count -gt 0) {
                throw "Embedded workflow PowerShell is not parseable: $($errors[0].Message)"
            }

            $ast
        }

        function script:Get-PowerShellCommands {
            param(
                [Parameter(Mandatory)]
                [string]$Script
            )

            $ast = Get-PowerShellAst -Script $Script
            @($ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst]
            }, $true))
        }

        function script:Get-CommandByLeafName {
            param(
                [Parameter(Mandatory)]
                [string]$Script,

                [Parameter(Mandatory)]
                [string]$LeafName
            )

            $matches = @(Get-PowerShellCommands -Script $Script | Where-Object {
                $name = [string]$_.GetCommandName()
                -not [string]::IsNullOrWhiteSpace($name) -and [System.IO.Path]::GetFileName($name) -ceq $LeafName
            })
            if ($matches.Count -ne 1) {
                throw "Expected exactly one '$LeafName' command; found $($matches.Count)."
            }

            $matches[0]
        }

        function script:Get-StepRun {
            param(
                [Parameter(Mandatory)]
                [string]$Step
            )

            $lines = @($Step -split "`r?`n")
            $runLines = @(
                for ($index = 0; $index -lt $lines.Count; $index++) {
                    if ($lines[$index] -match '^        run:\s*(.*)$') {
                        [pscustomobject]@{
                            Index = $index
                            Value = $Matches[1]
                        }
                    }
                }
            )
            if ($runLines.Count -ne 1) {
                throw "Expected exactly one run entry in workflow step; found $($runLines.Count)."
            }

            if ($runLines[0].Value -ceq '|') {
                $scriptLines = @(
                    for ($index = $runLines[0].Index + 1; $index -lt $lines.Count; $index++) {
                        if ([string]::IsNullOrEmpty($lines[$index])) {
                            ''
                            continue
                        }
                        if (-not $lines[$index].StartsWith('          ')) {
                            throw "Run block contains a line outside the expected indentation: $($lines[$index])"
                        }

                        $lines[$index].Substring(10)
                    }
                )
                $scriptText = $scriptLines -join "`n"
            }
            else {
                $scriptText = $runLines[0].Value
            }

            Get-PowerShellAst -Script $scriptText | Out-Null
            $scriptText
        }

        function script:Get-StepUses {
            param(
                [Parameter(Mandatory)]
                [string]$Step
            )

            Get-YamlScalarValue -Content $Step -Name 'uses' -Indent 8
        }

        function script:Get-RunContent {
            param(
                [Parameter(Mandatory)]
                [string]$Job
            )

            $scripts = @(
                foreach ($stepName in @(Get-StepNames -Job $Job)) {
                    $step = Get-StepBlock -Job $Job -Name $stepName
                    if ($step -match '(?m)^        run:') {
                        Get-StepRun -Step $step
                    }
                }
            )
            $scripts -join "`n"
        }
    }

    It 'provides the <Name> workflow before evaluating its behavior contract' -ForEach $workflowCases {
        param($Name, $Path)

        Test-Path -LiteralPath $Path -PathType Leaf | Should -BeTrue -Because "$Name workflow behavior cannot be evaluated when the workflow is missing"
    }

    Context 'when both workflow files exist' -Skip:(-not $workflowFilesPresent) {
        BeforeAll {
            $script:WorkflowContent = @{}
            foreach ($workflowCase in $script:WorkflowCases) {
                $script:WorkflowContent[$workflowCase.Name] = Get-Content -Raw -LiteralPath $workflowCase.Path
            }
        }

        It '<Name> exposes only the attended Tenant 1 dispatch choice' -ForEach $workflowCases {
            param($Name)

            $content = $script:WorkflowContent[$Name]
            $triggers = Get-YamlBlock -Content $content -Header 'on:' -Indent 0
            ((Get-YamlMappingKeys -Content $triggers -Indent 2 | Sort-Object) -join ',') | Should -Be 'workflow_dispatch'

            $dispatch = Get-YamlBlock -Content $triggers -Header 'workflow_dispatch:' -Indent 2
            $inputs = Get-YamlBlock -Content $dispatch -Header 'inputs:' -Indent 4
            $tenantAlias = Get-YamlBlock -Content $inputs -Header 'tenantAlias:' -Indent 6
            (Get-YamlScalarValue -Content $tenantAlias -Name 'required' -Indent 8) | Should -Be 'true'
            (Get-YamlScalarValue -Content $tenantAlias -Name 'type' -Indent 8) | Should -Be 'choice'
            $options = Get-YamlBlock -Content $tenantAlias -Header 'options:' -Indent 8
            $optionValues = @(Get-YamlListValues -Content $options -Indent 10)
            $optionValues.Count | Should -Be 1
            $optionValues[0] | Should -Be 'caldova25156897'
        }

        It '<Name> serializes one tenant on its reviewed GitHub Environment' -ForEach $workflowCases {
            param($Name)

            $content = $script:WorkflowContent[$Name]
            $concurrency = Get-YamlBlock -Content $content -Header 'concurrency:' -Indent 0
            (Get-YamlScalarValue -Content $concurrency -Name 'group' -Indent 2) | Should -Be 'bootstrap-${{ inputs.tenantAlias }}'
            (Get-YamlScalarValue -Content $concurrency -Name 'cancel-in-progress' -Indent 2) | Should -Be 'false'

            $job = Get-OnlyJobBlock -Content $content
            (Get-YamlScalarValue -Content $job -Name 'environment' -Indent 4) | Should -Be 'bootstrap-${{ inputs.tenantAlias }}'
            (Get-YamlScalarValue -Content $job -Name 'runs-on' -Indent 4) | Should -Be 'windows-2025'
        }

        It '<Name> grants only OIDC and checkout permissions' -ForEach $workflowCases {
            param($Name)

            $permissions = Get-YamlBlock -Content $script:WorkflowContent[$Name] -Header 'permissions:' -Indent 0
            ((Get-YamlMappingKeys -Content $permissions -Indent 2 | Sort-Object) -join ',') | Should -Be 'contents,id-token'
            (Get-YamlScalarValue -Content $permissions -Name 'contents' -Indent 2) | Should -Be 'read'
            (Get-YamlScalarValue -Content $permissions -Name 'id-token' -Indent 2) | Should -Be 'write'
        }

        It '<Name> binds pinned checkout and Azure OIDC login to Environment variables' -ForEach $workflowCases {
            param($Name)

            $job = Get-OnlyJobBlock -Content $script:WorkflowContent[$Name]
            $environment = Get-YamlBlock -Content $job -Header 'env:' -Indent 4
            (Get-YamlScalarValue -Content $environment -Name 'AZURE_CLIENT_ID' -Indent 6) | Should -Be '${{ vars.AZURE_CLIENT_ID }}'
            (Get-YamlScalarValue -Content $environment -Name 'AZURE_TENANT_ID' -Indent 6) | Should -Be '${{ vars.AZURE_TENANT_ID }}'
            (Get-YamlScalarValue -Content $environment -Name 'AZURE_SUBSCRIPTION_ID' -Indent 6) | Should -Be '${{ vars.AZURE_SUBSCRIPTION_ID }}'

            $checkout = Get-StepBlock -Job $job -Name 'Check out repository'
            $checkoutUse = Get-ReviewedActionUse -Name 'actions/checkout'
            (Get-StepUses -Step $checkout) | Should -Be $checkoutUse

            $login = Get-StepBlock -Job $job -Name 'Azure OIDC login'
            $loginUse = Get-ReviewedActionUse -Name 'azure/login'
            (Get-StepUses -Step $login) | Should -Be $loginUse
            $loginInputs = Get-YamlBlock -Content $login -Header 'with:' -Indent 8
            (Get-YamlScalarValue -Content $loginInputs -Name 'client-id' -Indent 10) | Should -Be '${{ env.AZURE_CLIENT_ID }}'
            (Get-YamlScalarValue -Content $loginInputs -Name 'tenant-id' -Indent 10) | Should -Be '${{ env.AZURE_TENANT_ID }}'
            (Get-YamlScalarValue -Content $loginInputs -Name 'subscription-id' -Indent 10) | Should -Be '${{ env.AZURE_SUBSCRIPTION_ID }}'

            $actionUses = @([regex]::Matches($job, '(?m)^        uses:\s*(\S+)\s*$') | ForEach-Object { $_.Groups[1].Value })
            @($actionUses | Where-Object { $_ -ceq $checkoutUse }).Count | Should -Be 1
            @($actionUses | Where-Object { $_ -ceq $loginUse }).Count | Should -Be 1
            foreach ($actionUse in $actionUses) {
                $actionUse | Should -Match '@[0-9a-f]{40}$'
            }
        }

        It '<Name> excludes broad credentials, deployment, publication, and error suppression paths' -ForEach $workflowCases {
            param($Name)

            $document = $script:WorkflowContent[$Name]
            $job = Get-OnlyJobBlock -Content $document
            $runContent = Get-RunContent -Job $job

            $document | Should -Not -Match '(?i)client[_-]?secret|AZURE_CLIENT_SECRET|personal[ -]?access[ -]?token|\bPAT\b|GH_TOKEN|secrets\.'
            $runContent | Should -Not -Match '(?im)\baz(?:\.exe)?\s+deployment\s+sub\s+create\b|\bNew-AzSubscriptionDeployment\b'
            $runContent | Should -Not -Match '(?im)^\s*git\s+(?:commit|push)\b|^\s*gh\s+pr\s+create\b'
            $job | Should -Not -Match '(?m)^        continue-on-error:'
        }

        It 'discovers all three reviewed Power Platform environments before producing only redacted evidence' {
            $job = Get-OnlyJobBlock -Content $script:WorkflowContent.discovery
            $manifestStep = Get-StepBlock -Job $job -Name 'Validate tenant manifest'
            $manifestRun = Get-StepRun -Step $manifestStep
            $manifestRun | Should -Match 'Import-PowerShellDataFile'
            $manifestRun | Should -Match '\$configuration\.PowerPlatform\.DevUrl'
            $manifestRun | Should -Match '\$configuration\.PowerPlatform\.TestUrl'
            $manifestRun | Should -Match '\$configuration\.PowerPlatform\.ProdUrl'

            $whoAmIRevision = Get-ReviewedActionUse -Name 'microsoft/powerplatform-actions/who-am-i'
            $expectedProbes = @(
                @{ Name = 'Verify Power Platform DEV'; Stage = 'DEV'; Url = '${{ steps.manifest.outputs.dev-url }}' },
                @{ Name = 'Verify Power Platform TEST'; Stage = 'TEST'; Url = '${{ steps.manifest.outputs.test-url }}' },
                @{ Name = 'Verify Power Platform PROD'; Stage = 'PROD'; Url = '${{ steps.manifest.outputs.prod-url }}' }
            )
            @([regex]::Matches($job, "(?m)^        uses:\s*$([regex]::Escape($whoAmIRevision))\s*$" )).Count | Should -Be 3
            for ($index = 0; $index -lt $expectedProbes.Count; $index++) {
                $step = Get-StepBlock -Job $job -Name $expectedProbes[$index].Name
                (Get-StepUses -Step $step) | Should -Be $whoAmIRevision
                $inputs = Get-YamlBlock -Content $step -Header 'with:' -Indent 8
                (Get-YamlScalarValue -Content $inputs -Name 'environment-url' -Indent 10) | Should -Be $expectedProbes[$index].Url
                (Get-YamlScalarValue -Content $inputs -Name 'app-id' -Indent 10) | Should -Be '${{ env.AZURE_CLIENT_ID }}'
                (Get-YamlScalarValue -Content $inputs -Name 'tenant-id' -Indent 10) | Should -Be '${{ env.AZURE_TENANT_ID }}'
                ((Get-YamlMappingKeys -Content $inputs -Indent 10 | Sort-Object) -join ',') | Should -Be 'app-id,environment-url,tenant-id'
            }

            $probeStep = Get-StepBlock -Job $job -Name 'Write redacted Power Platform probe evidence'
            $probeRun = Get-StepRun -Step $probeStep
            $probeAst = Get-PowerShellAst -Script $probeRun
            $probeRecordTables = @($probeAst.FindAll({
                param($node)
                if ($node -isnot [System.Management.Automation.Language.HashtableAst]) {
                    return $false
                }

                $keys = @($node.KeyValuePairs | ForEach-Object { $_.Item1.Extent.Text.Trim("'`"") })
                $keys -contains 'Stage'
            }, $true))
            $probeRecordTables.Count | Should -Be 3
            foreach ($probeRecordTable in $probeRecordTables) {
                $keys = @($probeRecordTable.KeyValuePairs | ForEach-Object { $_.Item1.Extent.Text.Trim("'`"") } | Sort-Object)
                ($keys -join ',') | Should -Be 'ActionRevision,CollectedUtc,Stage,Status,Url'
            }
            $probeRun | Should -Match '\$env:RUNNER_TEMP\\power-platform-probes\.json'
            $probeRun | Should -Match 'infra[/\\]src[/\\]config[/\\]github[/\\]action-pins\.json'
            $probeRun | Should -Match "actions\.'microsoft/powerplatform-actions/who-am-i'\.sha"

            $discoveryStep = Get-StepBlock -Job $job -Name 'Run tenant discovery'
            $discoveryRun = Get-StepRun -Step $discoveryStep
            $discoveryCommand = Get-CommandByLeafName -Script $discoveryRun -LeafName 'Invoke-TenantDiscovery.ps1'
            $invocation = $discoveryCommand.Extent.Text
            $invocation | Should -Match "-TenantAlias\s+'\$\{\{ inputs\.tenantAlias \}\}'"
            $invocation | Should -Match '-AuthenticationMode\s+ExistingContext'
            $invocation | Should -Match '-PowerPlatformProbePath\s+"\$env:RUNNER_TEMP\\power-platform-probes\.json"'
            $invocation | Should -Match '-OutputPath\s+"\$env:RUNNER_TEMP\\discovery\.json"'

            $validationStep = Get-StepBlock -Job $job -Name 'Validate normalized discovery'
            $validationRun = Get-StepRun -Step $validationStep
            @((Get-PowerShellCommands -Script $validationRun) | Where-Object { $_.GetCommandName() -ceq 'Invoke-Pester' }).Count | Should -Be 1
            $validationRun | Should -Match 'infra[/\\]tests[/\\]pester[/\\]DiscoveryNormalization\.Tests\.ps1'

            $uploadRevision = Get-ReviewedActionUse -Name 'actions/upload-artifact'
            $uploadStep = Get-StepBlock -Job $job -Name 'Upload redacted tenant discovery'
            (Get-StepUses -Step $uploadStep) | Should -Be $uploadRevision
            @([regex]::Matches($job, "(?m)^        uses:\s*$([regex]::Escape($uploadRevision))\s*$" )).Count | Should -Be 1
            $uploadInputs = Get-YamlBlock -Content $uploadStep -Header 'with:' -Indent 8
            (Get-YamlScalarValue -Content $uploadInputs -Name 'path' -Indent 10) | Should -Be '${{ runner.temp }}\discovery.json'
            (Get-YamlScalarValue -Content $uploadInputs -Name 'if-no-files-found' -Indent 10) | Should -Be 'error'

            (Get-StepIndex -Job $job -Name 'Azure OIDC login') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Verify Power Platform DEV')
            (Get-StepIndex -Job $job -Name 'Verify Power Platform PROD') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Write redacted Power Platform probe evidence')
            (Get-StepIndex -Job $job -Name 'Write redacted Power Platform probe evidence') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Run tenant discovery')
            (Get-StepIndex -Job $job -Name 'Run tenant discovery') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Validate normalized discovery')
            (Get-StepIndex -Job $job -Name 'Validate normalized discovery') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Upload redacted tenant discovery')

            $runContent = Get-RunContent -Job $job
            @((Get-PowerShellCommands -Script $runContent) | Where-Object {
                [System.IO.Path]::GetFileName([string]$_.GetCommandName()) -ceq 'Invoke-TenantDiscovery.ps1'
            }).Count | Should -Be 1
            $runContent | Should -Not -Match 'Invoke-TenantBootstrap|Grant-TemporaryBootstrapRoles|Get-TemporaryBootstrapRoleState|Test-WhatIfBoundary|Remove-TemporaryRoleAssignments'
        }

        It 'pins Pester before validating normalized discovery' {
            $job = Get-OnlyJobBlock -Content $script:WorkflowContent.discovery
            $installStep = Get-StepBlock -Job $job -Name 'Install pinned Pester'
            $installRun = Get-StepRun -Step $installStep
            $installCommand = @((Get-PowerShellCommands -Script $installRun) | Where-Object { $_.GetCommandName() -ceq 'Install-Module' })
            $installCommand.Count | Should -Be 1
            $installCommand[0].Extent.Text | Should -Match 'Pester\s+-RequiredVersion\s+5\.7\.1'
            (Get-StepIndex -Job $job -Name 'Install pinned Pester') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Validate normalized discovery')
        }

        It 'fails false cleanup approval before checkout or authentication' {
            $content = $script:WorkflowContent.bootstrap
            $dispatch = Get-YamlBlock -Content (Get-YamlBlock -Content $content -Header 'on:' -Indent 0) -Header 'workflow_dispatch:' -Indent 2
            $inputs = Get-YamlBlock -Content $dispatch -Header 'inputs:' -Indent 4
            $confirmation = Get-YamlBlock -Content $inputs -Header 'confirmRoleCleanup:' -Indent 6
            (Get-YamlScalarValue -Content $confirmation -Name 'required' -Indent 8) | Should -Be 'true'
            (Get-YamlScalarValue -Content $confirmation -Name 'type' -Indent 8) | Should -Be 'boolean'
            (Get-YamlScalarValue -Content $confirmation -Name 'default' -Indent 8) | Should -Be 'false'

            $job = Get-OnlyJobBlock -Content $content
            @(Get-StepNames -Job $job)[0] | Should -Be 'Require cleanup confirmation'
            $guard = Get-StepBlock -Job $job -Name 'Require cleanup confirmation'
            $guard | Should -Not -Match '(?m)^        uses:'
            $guardRun = Get-StepRun -Step $guard
            $guardScriptFalse = $guardRun.Replace('${{ inputs.confirmRoleCleanup }}', 'false')
            $guardScriptTrue = $guardRun.Replace('${{ inputs.confirmRoleCleanup }}', 'true')
            { & ([scriptblock]::Create($guardScriptFalse)) } | Should -Throw '*confirmRoleCleanup must be true*'
            { & ([scriptblock]::Create($guardScriptTrue)) } | Should -Not -Throw

            (Get-StepIndex -Job $job -Name 'Require cleanup confirmation') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Check out repository')
            (Get-StepIndex -Job $job -Name 'Require cleanup confirmation') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Azure OIDC login')
        }

        It 'requires reviewed inputs and captures exactly two post-login role assignments' {
            $job = Get-OnlyJobBlock -Content $script:WorkflowContent.bootstrap
            $environment = Get-YamlBlock -Content $job -Header 'env:' -Indent 4
            (Get-YamlScalarValue -Content $environment -Name 'DISCOVERY_EVIDENCE_PATH' -Indent 6) | Should -Be 'infra\evidence\discovery\${{ inputs.tenantAlias }}.json'
            (Get-YamlScalarValue -Content $environment -Name 'BICEP_PARAMETER_PATH' -Indent 6) | Should -Be 'infra\src\bicep\params\${{ inputs.tenantAlias }}.bicepparam'
            $environment | Should -Not -Match '(?m)^      ROLE_STATE_PATH:'

            foreach ($stepName in @('Discover exact temporary role assignments', 'Run Bicep build and validated what-if', 'Ensure exact temporary role cleanup')) {
                $step = Get-StepBlock -Job $job -Name $stepName
                $stepEnvironment = Get-YamlBlock -Content $step -Header 'env:' -Indent 8
                (Get-YamlScalarValue -Content $stepEnvironment -Name 'ROLE_STATE_PATH' -Indent 10) | Should -Be '${{ runner.temp }}\bootstrap-role-state.json'
            }

            $requiredInputs = Get-StepBlock -Job $job -Name 'Require reviewed evidence and parameters'
            $requiredInputsRun = Get-StepRun -Step $requiredInputs
            $requiredInputsRun | Should -Match 'foreach\s*\(\$path\s+in\s+@\(\$env:DISCOVERY_EVIDENCE_PATH,\s*\$env:BICEP_PARAMETER_PATH\)\)'
            $requiredInputsRun | Should -Match 'Test-Path\s+-LiteralPath\s+\$path\s+-PathType\s+Leaf'
            $requiredInputsRun | Should -Match 'git\s+ls-files\s+--error-unmatch\s+--\s+\$path'

            $roleState = Get-StepBlock -Job $job -Name 'Discover exact temporary role assignments'
            $roleStateRun = Get-StepRun -Step $roleState
            $roleCommand = Get-CommandByLeafName -Script $roleStateRun -LeafName 'Get-TemporaryBootstrapRoleState.ps1'
            $roleCommand.Extent.Text | Should -Match "-TenantAlias\s+'\$\{\{ inputs\.tenantAlias \}\}'"
            $roleCommand.Extent.Text | Should -Match '-OutputPath\s+\$env:ROLE_STATE_PATH'
            $roleStateRun | Should -Match '@\(\$state\.Assignments\)\.Count\s+-ne\s+2'
            $roleStateRun | Should -Match "RoleName\s+-ceq\s+'Contributor'"
            $roleStateRun | Should -Match "RoleName\s+-ceq\s+'Role Based Access Control Administrator'"
            $roleStateRun | Should -Not -Match 'GITHUB_OUTPUT|run-id=|principal-object-id=|scope=|contributor-assignment-id=|rbac-admin-assignment-id='

            (Get-StepIndex -Job $job -Name 'Azure OIDC login') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Discover exact temporary role assignments')
            (Get-StepIndex -Job $job -Name 'Require reviewed evidence and parameters') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Run Bicep build and validated what-if')
        }

        It 'delegates only validated what-if orchestration with the reviewed cleanup tuple' {
            $job = Get-OnlyJobBlock -Content $script:WorkflowContent.bootstrap
            $orchestration = Get-StepBlock -Job $job -Name 'Run Bicep build and validated what-if'
            $orchestrationRun = Get-StepRun -Step $orchestration
            $command = Get-CommandByLeafName -Script $orchestrationRun -LeafName 'Invoke-TenantBootstrap.ps1'
            $invocation = $command.Extent.Text

            $orchestrationRun | Should -Match 'Get-Content\s+-Raw\s+-LiteralPath\s+\$env:ROLE_STATE_PATH\s+\|\s+ConvertFrom-Json'
            $orchestrationRun | Should -Match '@\(\$roleState\.Assignments\)\.Count\s+-ne\s+2'
            $orchestrationRun | Should -Match "RoleName\s+-ceq\s+'Contributor'"
            $orchestrationRun | Should -Match "RoleName\s+-ceq\s+'Role Based Access Control Administrator'"
            $orchestrationRun | Should -Match '\$expectedRunId\s*=\s*\[string\]\$roleState\.RunId'
            $orchestrationRun | Should -Match '\$expectedPrincipalObjectId\s*=\s*\[string\]\$roleState\.PrincipalObjectId'
            $orchestrationRun | Should -Match '\$expectedScope\s*=\s*\[string\]\$roleState\.Scope'
            $orchestrationRun | Should -Not -Match '\$\{\{\s*steps\.role-state\.outputs\.'
            $invocation | Should -Match '-EvidencePath\s+\$env:DISCOVERY_EVIDENCE_PATH'
            $invocation | Should -Match '-ParameterFile\s+\$env:BICEP_PARAMETER_PATH'
            $invocation | Should -Match '-TemporaryRoleStatePath\s+\$env:ROLE_STATE_PATH'
            $invocation | Should -Match '-ConfirmRoleCleanup\s+\$true'
            $invocation | Should -Match '-BootstrapRunId\s+\$expectedRunId'
            $invocation | Should -Match '-ApprovedRoleAssignmentIds\s+\$approvedRoleAssignmentIds'
            $invocation | Should -Match '-WhatIfOnly(?:\s|$)'
            $orchestrationRun | Should -Match '\[string\]\$contributor\[0\]\.Id'
            $orchestrationRun | Should -Match '\[string\]\$rbacAdministrator\[0\]\.Id'
        }

        It 'always retries idempotent cleanup with the same exact run principal scope and IDs' {
            $job = Get-OnlyJobBlock -Content $script:WorkflowContent.bootstrap
            $cleanup = Get-StepBlock -Job $job -Name 'Ensure exact temporary role cleanup'
            (Get-YamlScalarValue -Content $cleanup -Name 'if' -Indent 8) | Should -Be '${{ always() }}'
            $cleanup | Should -Not -Match '(?m)^        continue-on-error:'

            $cleanupRun = Get-StepRun -Step $cleanup
            $cleanupRun | Should -Match 'Get-Content\s+-Raw\s+-LiteralPath\s+\$env:ROLE_STATE_PATH\s+\|\s+ConvertFrom-Json'
            $cleanupRun | Should -Match '@\(\$roleState\.Assignments\)\.Count\s+-ne\s+2'
            $cleanupRun | Should -Match "RoleName\s+-ceq\s+'Contributor'"
            $cleanupRun | Should -Match "RoleName\s+-ceq\s+'Role Based Access Control Administrator'"
            $cleanupRun | Should -Match '\$expectedRunId\s*=\s*\[string\]\$roleState\.RunId'
            $cleanupRun | Should -Match '\$expectedPrincipalObjectId\s*=\s*\[string\]\$roleState\.PrincipalObjectId'
            $cleanupRun | Should -Match '\$expectedScope\s*=\s*\[string\]\$roleState\.Scope'
            $cleanupRun | Should -Not -Match '\$\{\{\s*steps\.role-state\.outputs\.'
            $command = @((Get-PowerShellCommands -Script $cleanupRun) | Where-Object { $_.GetCommandName() -ceq 'Remove-TemporaryRoleAssignments' })
            $command.Count | Should -Be 1
            $invocation = $command[0].Extent.Text
            $invocation | Should -Match '-BootstrapResult\s+\$roleState'
            $invocation | Should -Match '-ExpectedRunId\s+\$expectedRunId'
            $invocation | Should -Match '-ExpectedPrincipalObjectId\s+\$expectedPrincipalObjectId'
            $invocation | Should -Match '-ExpectedScope\s+\$expectedScope'
            $invocation | Should -Match '-ApprovedRoleAssignmentIds\s+\$approvedRoleAssignmentIds'
            $cleanupRun | Should -Match '\[string\]\$contributor\[0\]\.Id'
            $cleanupRun | Should -Match '\[string\]\$rbacAdministrator\[0\]\.Id'
            $cleanupRun | Should -Not -Match '(?i)az\s+role\s+assignment\s+delete|Remove-AzRoleAssignment'

            (Get-StepIndex -Job $job -Name 'Run Bicep build and validated what-if') | Should -BeLessThan (Get-StepIndex -Job $job -Name 'Ensure exact temporary role cleanup')
        }
    }
}