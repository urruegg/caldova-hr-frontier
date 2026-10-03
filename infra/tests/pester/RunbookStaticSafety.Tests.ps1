Set-StrictMode -Version Latest

Describe 'Runbook static safety' {
    BeforeAll {
        $script:RunbookRoot = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks'
        $script:Initializer = Join-Path $script:RunbookRoot 'Initialize-DeveloperWorkstation.ps1'
        $script:Assessment = Join-Path $script:RunbookRoot 'Test-DeveloperWorkstation.ps1'
        $script:TenantLifecycle = Join-Path $script:RunbookRoot 'Invoke-TenantLifecycle.ps1'
    }

    It 'declares SupportsShouldProcess and an explicit Apply switch' {
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($script:Initializer, [ref]$tokens, [ref]$errors)

        $errors.Count | Should -Be 0
        $ast.ParamBlock.Attributes.Extent.Text | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
        @($ast.ParamBlock.Parameters.Name.VariablePath.UserPath) | Should -Contain 'Apply'
        $ast.Extent.Text | Should -Match '\$PSCmdlet\.ShouldProcess\('
    }

    It 'contains no security weakening persistence self-elevation or authentication command' {
        $content = ((Get-Content -Raw $script:Initializer), (Get-Content -Raw $script:Assessment)) -join "`n"

        $content | Should -Not -Match '(?i)\b(Set-ExecutionPolicy|Set-MpPreference|Invoke-Expression)\b'
        $content | Should -Not -Match '(?i)Start-Process.+-Verb\s+RunAs'
        $content | Should -Not -Match '(?i)SetEnvironmentVariable'
        $content | Should -Not -Match '(?i)\b(az\s+login|gh\s+auth\s+login|azd\s+auth\s+login|pac\s+auth\s+create|copilot\s+login)\b'
        $content | Should -Not -Match '(?i)(Read-Host|\[Console\]::ReadLine|\$input\b)'
    }

    It 'accepts no credential material and contains no OIDC or workflow trigger text' {
        $tokens = $null
        $errors = $null
        $asts = @(
            [Management.Automation.Language.Parser]::ParseFile($script:Initializer, [ref]$tokens, [ref]$errors)
            [Management.Automation.Language.Parser]::ParseFile($script:Assessment, [ref]$tokens, [ref]$errors)
        )
        $parameterNames = @($asts.ParamBlock.Parameters.Name.VariablePath.UserPath)

        ($parameterNames -join '|') | Should -Not -Match '(?i)\b(password|token|secret|credential|certificate|pat)\b'
        (($asts.Extent.Text) -join "`n") | Should -Not -Match '(?i)(ACTIONS_ID_TOKEN_REQUEST_TOKEN|id-token:\s*write|workflow_dispatch|federated.?credential)'
    }

    It 'keeps every native mutator behind ShouldProcess' {
        $content = Get-Content -Raw $script:Initializer

        foreach ($verb in @('WinGetInstallExact', 'Install-Module', "'extension', 'add'", "'bicep', 'install'", '--install-extension')) {
            $content | Should -Match ([regex]::Escape($verb))
        }
        $content | Should -Not -Match '(?i)\b(upgrade|uninstall|remove)\b'
    }

    It 'builds the module installation from the matched policy action' {
        $content = Get-Content -Raw $script:Initializer
        $switchIndex = $content.IndexOf("switch ([string]`$action.action)")
        $startToken = "'InstallPesterExact' {"
        $endToken = "'InstallBicepComponent' {"
        $startIndex = $content.IndexOf($startToken, $switchIndex)
        $endIndex = $content.IndexOf($endToken, $startIndex)

        $switchIndex | Should -BeGreaterThan -1
        $startIndex | Should -BeGreaterThan -1
        $endIndex | Should -BeGreaterThan $startIndex
        $body = $content.Substring($startIndex, $endIndex - $startIndex)
        foreach ($field in @('targetId', 'requiredVersion', 'packageSource', 'scope')) {
            $body | Should -Match ([regex]::Escape("`$policyAction.$field"))
        }
        $body | Should -Not -Match '(?i)(Install-Module\s+Pester|5\.7\.1|PSGallery|CurrentUser)'
    }

    It 'keeps the tenant lifecycle umbrella provider-neutral and sequencing-only' {
        $content = Get-Content -Raw -LiteralPath $script:TenantLifecycle -ErrorAction Stop

        $content | Should -Not -Match (
            '(?i)\b(az|azd|gh|pac|bicep|winget|npm|npx|dotnet)(?:\.exe)?\b'
        )
        $content | Should -Not -Match (
            '(?i)\b(password|token|secret|credential|authorization|providerPayload)\b'
        )
        $content | Should -Not -Match (
            '(?i)(Install-Module|Install-Package|Start-Process|Invoke-Expression)'
        )
        $content | Should -Not -Match (
            '(?i)(Initialize-DeveloperWorkstation|Test-DeveloperWorkstation|' +
            'Get-CloudFoundationPlan|Invoke-CloudFoundation|' +
            'New-CustomerRepositoryExport|Test-CustomerRepositoryExport)\.ps1'
        )
    }

    It 'removes retired umbrella authority from the coordinate-only source' {
        $tokens = $null
        $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile(
            $script:TenantLifecycle,
            [ref]$tokens,
            [ref]$errors
        )

        $errors.Count | Should -Be 0
        $parameterNames = @($ast.ParamBlock.Parameters.Name.VariablePath.UserPath)
        ($parameterNames -join '|') |
            Should -Not -Match (
                '(?i)\b(password|token|secret|credential|certificate|pat)\b'
            )
        $ast.ParamBlock.Attributes.Extent.Text |
            Should -Not -Match 'SupportsShouldProcess'

        $content = Get-Content -Raw -LiteralPath $script:TenantLifecycle
        $content | Should -Not -Match (
            '(?i)\$(Apply|ExecutionManifestPath|ApprovedDigest|' +
            'BindingObserver|CurrentBindingProvider)\b'
        )
        $content | Should -Not -Match (
            '(?i)(approvals[.]json|Test-TenantLifecycleApproval|' +
            'currentBinding|targetStableId|ShouldProcess)'
        )
        $content | Should -Not -Match (
            '(?i)(ManifestAction|[.]actions\b|ActionEvidence|' +
            'correlatedEvidence)'
        )
    }

    It 'uses only named coordinate-only Assess and Plan invoker arguments and discards its return' {
        $content = Get-Content -Raw -LiteralPath $script:TenantLifecycle

        $content | Should -Match (
            '(?s)\$null\s*=\s*&\s*\$SubsystemInvoker\s+' +
            '`\s*-Stage\s+\$stage\s+`\s*-Mode\s+\$Mode\s+`\s*' +
            '-ControlRecord\s+\$freshControlRecord'
        )
        $content | Should -Not -Match (
            '(?i)\$(outcome|result|providerResult|returnValue)\s*=\s*' +
            '&\s*\$SubsystemInvoker'
        )
    }

    It 'defines the exact closed control record allowlist' {
        $helperPath = Join-Path (
            Split-Path -Parent $script:TenantLifecycle
        ) (
            '..\modules\Caldova.HrFrontier.Bootstrap\Private\' +
            'New-TenantLifecycleControlRecord.ps1'
        )
        $helperPath | Should -Exist
        if (-not (Test-Path -LiteralPath $helperPath -PathType Leaf)) {
            return
        }
        $content = Get-Content -Raw -LiteralPath $helperPath
        $fields = @(
            'schemaVersion',
            'runId',
            'sourceCommit',
            'publicTenantKey',
            'intentDigest',
            'stateDigest',
            'selectedStages',
            'prerequisiteResults',
            'evidenceRunRelativePath'
        )

        foreach ($field in $fields) {
            $content | Should -Match (
                '(?m)^\s*' + [regex]::Escape($field) + '\s*='
            )
        }
        $content | Should -Not -Match (
            '(?i)(absolute|TenantConfigurationPath|TenantStatePath|' +
            'credential|token|approval|providerContext|stableId|url|' +
            '\bactions?\b|payload|rawReadBack)'
        )
    }
}
