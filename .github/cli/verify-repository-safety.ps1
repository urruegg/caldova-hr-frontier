[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $scriptDirectory = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$MyInvocation.MyCommand.Path)) {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    else {
        throw 'Cannot resolve the repository root from the safety validator path.'
    }
    $RepositoryRoot = Join-Path $scriptDirectory '..\..'
}
$repositoryRootPath = [IO.Path]::GetFullPath($RepositoryRoot)
$prohibitedPattern = 'az\s+deployment\s+sub\s+create|New-AzSubscriptionDeployment|client[_-]?secret|AZURE_CLIENT_SECRET|--password'
$failures = [Collections.Generic.List[string]]::new()
$paths = [Collections.Generic.List[string]]::new()
$scriptRoot = Join-Path $repositoryRootPath 'infra\src\scripts'
$workflowRoot = Join-Path $repositoryRootPath '.github\workflows'
$manifestPath = Join-Path $repositoryRootPath 'infra\src\config\github\action-pins.json'
$reviewedActions = [ordered]@{}
$usedActions = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    [void]$failures.Add('Missing action pin manifest: infra/src/config/github/action-pins.json')
}
else {
    try {
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        if ([string]$manifest.schemaVersion -cne '1.0') {
            [void]$failures.Add('Action pin manifest schemaVersion must be exactly 1.0.')
        }
        $actionProperties = @($manifest.actions.PSObject.Properties)
        if ($actionProperties.Count -eq 0) {
            [void]$failures.Add('Action pin manifest must define at least one action.')
        }
        foreach ($actionProperty in $actionProperties) {
            $actionName = [string]$actionProperty.Name
            $entry = $actionProperty.Value
            if ($actionName -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*$') {
                [void]$failures.Add("Invalid action name in manifest: $actionName")
                continue
            }
            if ([string]$entry.sha -cnotmatch '^[0-9a-f]{40}$') {
                [void]$failures.Add("Manifest SHA must be lowercase 40-character hexadecimal for action: $actionName")
                continue
            }
            if ([string]::IsNullOrWhiteSpace([string]$entry.sourceRef)) {
                [void]$failures.Add("Manifest sourceRef is required for action: $actionName")
                continue
            }
            $reviewedActions[$actionName] = [string]$entry.sha
        }
    }
    catch {
        [void]$failures.Add("Cannot read action pin manifest: $($_.Exception.Message)")
    }
}

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
        $relativePath = $path.Substring($repositoryRootPath.Length).TrimStart('\').Replace('\', '/')
        foreach ($match in [regex]::Matches($content, '(?m)^\s*(?:-\s*)?uses:\s*["'']?([^"''\s#]+)["'']?\s*(?:#.*)?$')) {
            $actionUse = $match.Groups[1].Value
            if ($actionUse.StartsWith('./', [StringComparison]::Ordinal)) {
                continue
            }
            $separatorIndex = $actionUse.LastIndexOf('@')
            if ($separatorIndex -le 0 -or $separatorIndex -eq $actionUse.Length - 1) {
                [void]$failures.Add("External action reference is malformed in ${relativePath}: $actionUse")
                continue
            }
            $actionName = $actionUse.Substring(0, $separatorIndex)
            $revision = $actionUse.Substring($separatorIndex + 1)
            if (-not $reviewedActions.Contains($actionName)) {
                [void]$failures.Add("Unknown external action $actionName in $relativePath")
                continue
            }
            [void]$usedActions.Add($actionName)
            if ($revision -cnotmatch '^[0-9a-f]{40}$') {
                [void]$failures.Add("External action must use a lowercase 40-character SHA in ${relativePath}: $actionUse")
                continue
            }
            if ($revision -cne [string]$reviewedActions[$actionName]) {
                [void]$failures.Add("External action does not match reviewed SHA in ${relativePath}: $actionName")
            }
        }
    }
    catch {
        [void]$failures.Add("Cannot scan repository safety path: $path")
    }
}

foreach ($actionName in @($reviewedActions.Keys)) {
    if (-not $usedActions.Contains([string]$actionName)) {
        [void]$failures.Add("Manifest action is unused: $actionName")
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Output "ERROR: $failure" }
    Write-Output "Repository safety validation failed with $($failures.Count) error(s)."
    exit 1
}

Write-Output 'Repository safety validation passed.'