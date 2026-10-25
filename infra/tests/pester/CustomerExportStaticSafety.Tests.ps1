Set-StrictMode -Version Latest

Describe 'Customer export static safety' {
    BeforeAll {
        $script:Entry = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\New-CustomerRepositoryExport.ps1'
        $script:Validator = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Test-CustomerRepositoryExport.ps1'
    }

    It 'keeps forbidden authentication and remote interfaces out of both entry points' {
        $forbiddenParameters = '(?i)token|secret|credential|password|pat|authorization|devicecode|remote|organization'
        $forbiddenText = '(?i)(GH_TOKEN|GITHUB_TOKEN|AZURE_DEVOPS_EXT_PAT|SYSTEM_ACCESSTOKEN|--with-token|az\s+devops\s+login|oidc|workload.identity|workflow_dispatch|api/repos/.+/environments|git\s+(init|remote|push|fetch|pull|checkout|switch|reset|clean|filter-branch)|New-GitHubRepository|Publish-Customer)'
        foreach ($path in @($script:Entry, $script:Validator)) {
            $text = Get-Content -Raw -LiteralPath $path
            $text | Should -Not -Match $forbiddenText
        }
    }

    It 'keeps should-process and mutator boundaries in the reviewed scripts' {
        (Get-Content -Raw -LiteralPath $script:Entry) | Should -Match 'SupportsShouldProcess'
        (Get-Content -Raw -LiteralPath $script:Entry) | Should -Match 'ShouldProcess'
        (Get-Content -Raw -LiteralPath $script:Validator) | Should -Not -Match '\[switch\]\$Apply'
    }

    It 'traces canonical commands into the shared module without a publication or provider escape' {
        $moduleRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap'))
        $functions = @{}
        foreach ($file in Get-ChildItem $moduleRoot -Filter '*.ps1' -Recurse) {
            $ast = [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            foreach ($function in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
                $functions[$function.Name] = $function.Body
            }
        }
        $seen = @{}
        $pending = [Collections.Generic.Queue[object]]::new()
        foreach ($name in @('Test-RepositoryExport.ps1', 'New-RepositoryExportPlan.ps1', 'Invoke-RepositoryExport.ps1')) {
            $path = Join-Path (Split-Path $script:Entry -Parent) $name
            Test-Path $path | Should -BeTrue
            $pending.Enqueue([Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null))
        }
        while ($pending.Count -gt 0) {
            $ast = $pending.Dequeue()
            foreach ($reference in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.VariableExpressionAst] }, $true)) {
                $path = $reference.VariablePath.UserPath
                if ($path.StartsWith('function:', [StringComparison]::OrdinalIgnoreCase)) {
                    $name = $path.Substring('function:'.Length)
                    if ($functions.ContainsKey($name) -and -not $seen.ContainsKey($name)) {
                        $seen[$name] = $true
                        $pending.Enqueue($functions[$name])
                    }
                }
            }
            foreach ($command in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] }, $true)) {
                $name = $command.GetCommandName()
                if ([string]::IsNullOrWhiteSpace($name)) { continue }
                $name | Should -Not -Match '^(Invoke-(RestMethod|WebRequest)|Connect-.+|Publish-.+|New-GitHubRepository|gh|az|pac|curl)(\.exe|\.cmd)?$'
                if ($functions.ContainsKey($name) -and -not $seen.ContainsKey($name)) {
                    $seen[$name] = $true
                    $pending.Enqueue($functions[$name])
                }
            }
        }
        # A wrapper that never reaches the engine cannot satisfy this scope check.
        $seen.Keys | Should -Contain 'Get-RepositoryExportContext'
        $seen.Keys | Should -Contain 'Test-CustomerExportContent'
        $seen.Keys | Should -Contain 'Convert-CustomerExportBlob'
        $seen.Keys | Should -Contain 'Read-CustomerExportCommitBlob'
    }
}
