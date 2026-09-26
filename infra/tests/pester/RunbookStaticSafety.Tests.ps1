Set-StrictMode -Version Latest

Describe 'Runbook static safety' {
    BeforeAll {
        $script:RunbookRoot = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks'
        $script:Initializer = Join-Path $script:RunbookRoot 'Initialize-DeveloperWorkstation.ps1'
        $script:Assessment = Join-Path $script:RunbookRoot 'Test-DeveloperWorkstation.ps1'
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
}
