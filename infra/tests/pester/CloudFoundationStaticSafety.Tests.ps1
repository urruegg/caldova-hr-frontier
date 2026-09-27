Set-StrictMode -Version Latest

Describe 'Cloud foundation static safety' {
    BeforeAll {
        function Test-ProhibitedCloudParameterName {
            param([Parameter(Mandatory)][string]$Name)

            if ($Name -match '(?i)(password|token|secret|credential|certificate|authorization|device.?code|client.?id|service.?principal)') {
                return $true
            }
            $segments = @($Name -split '[_-]' | ForEach-Object {
                [regex]::Matches($_, '[A-Z]+(?=[A-Z][a-z]|$)|[A-Z]?[a-z]+|[0-9]+') |
                    ForEach-Object Value
            })
            @($segments | Where-Object { $_ -ceq 'PAT' -or $_ -ieq 'Pat' }).Count -gt 0
        }

        function Resolve-StaticTestGitPath {
            $candidates = @(
                (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
                (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe')
            )
            $resolved = @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
            if ($resolved.Count -eq 0) {
                throw 'Git application was not found at an approved absolute installation path.'
            }
            [IO.Path]::GetFullPath($resolved[0])
        }

        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:CloudFiles = @(
            'infra\src\scripts\runbooks\Get-CloudFoundationPlan.ps1',
            'infra\src\scripts\runbooks\Invoke-CloudFoundation.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Get-CloudServiceSnapshot.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-CloudNativeCommand.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-GitHubFoundationMutation.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-AzureFoundationMutation.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-AzureDevOpsFoundationMutation.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Resolve-CloudNativeTool.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Test-CloudDelegatedContext.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Get-CloudFoundationAssessment.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\New-CloudFoundationActionPlan.ps1',
            'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Invoke-CloudFoundationAction.ps1'
        ) | ForEach-Object { Join-Path $script:RepositoryRoot $_ }
    }

    It 'accepts required Path parameter names without treating path as PAT' {
        foreach ($name in @('TenantConfigurationPath','ReportPath','FilePath')) {
            Test-ProhibitedCloudParameterName -Name $name | Should -BeFalse
        }
    }

    It 'rejects PAT as a semantic parameter-name token' {
        foreach ($name in @('Pat','PAT','PatValue','GitHubPat','github_pat','github-pat')) {
            Test-ProhibitedCloudParameterName -Name $name | Should -BeTrue
        }
    }

    It 'parses every cloud script and exposes no credential-bearing parameter' {
        foreach ($path in $script:CloudFiles) {
            Test-Path -LiteralPath $path | Should -BeTrue
            $tokens=$null;$errors=$null
            $ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
            @($errors).Count | Should -Be 0 -Because $path
            $parameters = $ast.FindAll({
                param($node) $node -is [Management.Automation.Language.ParameterAst]
            },$true)
            @($parameters.Name.VariablePath.UserPath | Where-Object {
                Test-ProhibitedCloudParameterName -Name $_
            }).Count |
                Should -Be 0 -Because $path
        }
    }

    It 'keeps every cloud file outside workflow paths' {
        foreach($path in $script:CloudFiles) {
            $relative=[IO.Path]::GetRelativePath($script:RepositoryRoot,$path).Replace('\','/')
            $relative | Should -Not -Match '^(?i)\.github/workflows/'
        }
        $git=Resolve-StaticTestGitPath
        [IO.Path]::IsPathRooted($git) | Should -BeTrue
        $changed=@(& $git -C $script:RepositoryRoot diff --name-only --diff-filter=ACDMRTUXB HEAD~5..HEAD)
        @($changed | Where-Object { $_ -match '^(?i)\.github/workflows/' }).Count | Should -Be 0
    }

    It 'contains no prohibited executable cloud operation' {
        $prohibited = @(
            'workflow_dispatch','actions/workflows','actions/environments',
            'az devops login','--with-token','--service-principal','--federated-token',
            'devops project update','pipeline run','gh auth token'
        )
        foreach($path in $script:CloudFiles) {
            $content=Get-Content -Raw -LiteralPath $path
            foreach($term in $prohibited) {
                $content | Should -Not -Match ([regex]::Escape($term)) -Because $path
            }
        }
    }

    It 'uses one absolute native-command boundary and never a leaf-name invocation' {
        $boundary = Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-CloudNativeCommand.ps1')
        $boundary | Should -Match '\$Runner \$approvedPath \$ArgumentList'
        $boundary | Should -Match '\[IO\.Path\]::IsPathRooted'
        $boundary | Should -Match 'ToolResolution\.name'
        $resolver = Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Public\Resolve-CloudNativeTool.ps1')
        $resolver | Should -Match 'CommandType Application -All'
        $resolver | Should -Match 'Get-FileHash -LiteralPath'
    }

    It 'binds Apply to current manifest fields and revalidates tools before each mutation' {
        $apply=Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\scripts\runbooks\Invoke-CloudFoundation.ps1')
        $apply | Should -Match 'CurrentSourceCommit'
        $apply | Should -Match 'CurrentAssessmentDigest'
        $apply | Should -Match 'CurrentAuthenticationContext'
        $apply | Should -Not -Match 'Expected(SourceCommit|AssessmentDigest|Authentication)'
        ([regex]::Matches($apply,'Assert-ApprovedCloudToolResolutions')).Count | Should -BeGreaterOrEqual 3
        $apply | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'limits mutations to local gh api, exact Azure deployment, Entra metadata, and project create' {
        $github=Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-GitHubFoundationMutation.ps1')
        $github | Should -Match "'api','--method'"
        $github | Should -Match "'PATCH'"
        $github | Should -Match 'non-Actions'
        $azure=Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-AzureFoundationMutation.ps1')
        $azure | Should -Match "'deployment','sub','create'"
        foreach($required in @("'--name'","'--location'","'--template-file'","'--parameters'","'--output','json'")) {
            $azure | Should -Match ([regex]::Escape($required))
        }
        $azure | Should -Match "'ad','app','list','--display-name'"
        $azure | Should -Match "'ad','sp','list','--filter'"
        $ado=Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Private\Invoke-AzureDevOpsFoundationMutation.ps1')
        $ado | Should -Match "'devops','project','create'"
        $ado | Should -Not -Match "'devops','project','update'"
    }

    It 'keeps planning manual records on the exact closed six-field contract' {
        $fixture=Get-Content -Raw (Join-Path $script:RepositoryRoot 'infra\tests\fixtures\runbooks\cloud-assessment.json') | ConvertFrom-Json
        foreach($item in $fixture.manualItems) {
            @($item.PSObject.Properties.Name) |
                Should -Be @('service','targetId','condition','owner','diagnostic','recovery')
        }
    }
}
