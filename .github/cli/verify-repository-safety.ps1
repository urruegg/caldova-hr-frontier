[CmdletBinding()]
param(
    [string]$RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
)

$ErrorActionPreference = 'Stop'
$repositoryRootPath = [IO.Path]::GetFullPath($RepositoryRoot)
$prohibitedPattern = 'az\s+deployment\s+sub\s+create|New-AzSubscriptionDeployment|client[_-]?secret|AZURE_CLIENT_SECRET|--password'
$failures = [Collections.Generic.List[string]]::new()
$paths = [Collections.Generic.List[string]]::new()
$scriptRoot = Join-Path $repositoryRootPath 'infra\src\scripts'
$workflowRoot = Join-Path $repositoryRootPath '.github\workflows'

if (Test-Path -LiteralPath $scriptRoot -PathType Container) {
    foreach ($scriptFile in @(Get-ChildItem -LiteralPath $scriptRoot -File -Recurse -Force | Where-Object {
        $_.Extension -in @('.ps1', '.psm1')
    })) {
        [void]$paths.Add($scriptFile.FullName)
    }
}

if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
    foreach ($workflowFile in @(Get-ChildItem -LiteralPath $workflowRoot -File -Recurse -Force | Where-Object {
        $_.Extension -in @('.yml', '.yaml')
    })) {
        [void]$paths.Add($workflowFile.FullName)
    }
}

foreach ($path in $paths) {
    try {
        $content = [IO.File]::ReadAllText($path)
        if ($content -match $prohibitedPattern) {
            $relativePath = $path.Substring($repositoryRootPath.Length).TrimStart('\').Replace('\', '/')
            [void]$failures.Add("Prohibited bootstrap command or credential pattern found: $relativePath")
        }
    }
    catch {
        [void]$failures.Add("Cannot scan repository safety path: $path")
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "ERROR: $failure" }
    Write-Output "Repository safety validation failed with $($failures.Count) error(s)."
    exit 1
}

Write-Output 'Repository safety validation passed.'