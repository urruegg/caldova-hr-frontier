. ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..\.github\cli\Get-HistoryFreeRepositoryInventory.ps1')))

function New-RepositoryExportCommandResolver {
    {
        param($name)
        switch -CaseSensitive ($name) {
            'git.exe' { Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Git\cmd\git.exe' }
            'powershell.exe' { Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe' }
            'bicep.exe' {
                @(
                    (Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'Bicep CLI\bicep.exe')
                    (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\Bicep CLI\bicep.exe')
                    (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.azure\bin\bicep.exe')
                ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
            }
            default { throw 'Unsupported offline executable.' }
        }
    }
}

function Get-RepositoryExportValidationCommand {
    param(
        [Parameter(Mandatory)][ValidateSet('Pester', 'RepositorySafety', 'BicepBuild')][string]$Suite,
        [Parameter(Mandatory)][object]$ToolIdentities,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][ValidateSet('TenantReplica', 'CustomerHandover')][string]$Profile
    )
    switch -CaseSensitive ($Suite) {
        'Pester' {
            # Literal dispatch only. Neither manifest values nor candidate text enter the command.
            $code = @'
$ErrorActionPreference = 'Stop'
try {
    Import-Module Pester -RequiredVersion 5.7.1 -Force
    $paths = @('infra\tests\pester', 'hr\tests\pester', '.github\cli\tests') | Where-Object { Test-Path -LiteralPath $_ -PathType Container }
    $files = @($paths | ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter '*.Tests.ps1' -File -Recurse -Force })
    if ($files.Count -eq 0) { exit 1 }
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = @($files.FullName)
    $configuration.Run.PassThru = $true
    $configuration.Run.Exit = $false
    $configuration.TestResult.Enabled = $false
    $configuration.CodeCoverage.Enabled = $false
    $configuration.Output.Verbosity = 'None'
    $result = Invoke-Pester -Configuration $configuration
    if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0 -or $result.PassedCount -eq 0 -or
        @($result.Containers).Count -ne $files.Count -or
        @($result.Containers | Where-Object { $_.PassedCount -eq 0 -or $_.Result -cne 'Passed' }).Count -gt 0) { exit 1 }
    exit 0
} catch { exit 1 }
'@
            return [pscustomobject]@{
                filePath = $ToolIdentities.WindowsPowerShell.path
                arguments = @('-NoProfile', '-NonInteractive', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code)))
            }
        }
        'RepositorySafety' {
            $validator = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\..\..\.github\cli\verify-repository-safety.ps1'))
            return [pscustomobject]@{
                filePath = $ToolIdentities.WindowsPowerShell.path
                arguments = @('-NoProfile', '-NonInteractive', '-File', $validator, '-RepositoryRoot', $Root, '-HistoryFree', '-ExportProfile', $Profile)
            }
        }
        'BicepBuild' {
            return [pscustomobject]@{
                filePath = $ToolIdentities.Bicep.path
                arguments = @('build', (Join-Path $Root 'infra\src\bicep\main.bicep'), '--no-restore', '--stdout')
            }
        }
    }
}

function Get-RepositoryExportSuitePrerequisites {
    param([object]$Manifest, [string[]]$Paths, [string]$Profile)
    foreach ($suite in @($Manifest.validationSuites)) {
        $category = $null
        switch -CaseSensitive ($suite) {
            'BicepBuild' {
                if ($Paths -cnotcontains 'infra/src/bicep/main.bicep') { $category = 'SuiteAssetsMissing' }
            }
            'RepositorySafety' {
                if ($Profile -ceq 'TenantReplica' -and
                    ($Paths -cnotcontains '.github/cli/verify-repository-safety.ps1' -or
                     $Paths -cnotcontains '.github/cli/Get-HistoryFreeRepositoryInventory.ps1' -or
                     $Paths -cnotcontains '.github/workflows/validate-repository.yml' -or
                     $Paths -cnotcontains 'infra/src/config/github/action-pins.json')) { $category = 'SuiteAssetsMissing' }
            }
            'Pester' {
                if (@($Paths | Where-Object { $_ -cmatch '^(infra/tests/pester|hr/tests/pester|\.github/cli/tests)/.+\.Tests\.ps1$' }).Count -eq 0) { $category = 'SuiteAssetsMissing' }
                if ($Profile -ceq 'TenantReplica') {
                    foreach ($required in @(
                        '^infra/tests/pester/.+\.Tests\.ps1$',
                        '^hr/tests/pester/.+\.Tests\.ps1$',
                        '^infra/tests/pester/RunbookContracts\.Tests\.ps1$',
                        '^infra/tests/pester/RunbookStaticSafety\.Tests\.ps1$',
                        '^\.github/cli/tests/WorkflowContract\.Tests\.ps1$'
                    )) {
                        if (@($Paths | Where-Object { $_ -cmatch $required }).Count -eq 0) { $category = 'SuiteAssetsMissing' }
                    }
                    if ($Paths -cnotcontains 'azure-pipelines.yml' -or
                        @($Paths | Where-Object { $_.StartsWith('infra/src/pipelines/templates/', [StringComparison]::Ordinal) }).Count -eq 0) {
                        $category = 'PipelineAssetsMissing'
                    }
                    elseif (@($Paths | Where-Object { $_ -cmatch '(^|/)[^/]*Pipeline[^/]*\.Tests\.ps1$' }).Count -eq 0) { $category = 'SuiteAssetsMissing' }
                }
            }
        }
        if ($category) { [pscustomobject]@{ suite = $suite; status = 'Blocked'; exitCode = 1; category = $category } }
    }
}
