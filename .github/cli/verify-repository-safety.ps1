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
$prohibitedPattern = 'az\s+deployment\s+sub\s+create|New-AzSubscriptionDeployment|client[_-]?secret|AZURE_CLIENT_SECRET|--password|Set-ExecutionPolicy\s+(?:Unrestricted|Bypass)|Set-MpPreference\s+-DisableRealtimeMonitoring|Start-Process[^\r\n]+-Verb\s+RunAs'
$failures = [Collections.Generic.List[string]]::new()
$paths = [Collections.Generic.List[string]]::new()
$scriptRoot = Join-Path $repositoryRootPath 'infra\src\scripts'
$workflowRoot = Join-Path $repositoryRootPath '.github\workflows'
$manifestPath = Join-Path $repositoryRootPath 'infra\src\config\github\action-pins.json'
$reviewedActions = [ordered]@{}
$usedActions = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$protectedTenant1Fingerprints = @(
    '8f2981547cbd58fe5dafb3a153d1b0818ecab96f913d00106a7e29ef6d6066b7'
    '62dcc1603e24a9c5c897049117e5f3e800e0869f391b400f1229e7ce97eb8fb9'
    '55cb0d6583fc3ac19a4427d7b332ee58cc4a2da6ff3d4057fc0a72bc179eeed7'
    'd95d5a7f8ee595271653f532f7e437358f54b9db94e2f480d88f360cc1e67833'
    '87fcc58683715557463b1682f1e635f91a86d250a64efed30274e2a37750edca'
    '311198821c5a5e1e5d67c715b87bdadd360cf3eb9921c0438db416899a7f24c1'
    '35d8bfbfa26b5d687b550ae3f55f64504f0d17a7025e57cb239b29b3edbfecdc'
    '42971cdb16282457f6101a8c3a37d95aa9fec4e85b76b145b7b4ff8e27615d95'
    '9c5551976f8bbf3cf2d4724644140ba88cbf5d38ec68a446152c4eb12a11d4fa'
    '5f9e36a954fdb7602baaa1054ec660c357e54f3629045393c88816f1a02a3fab'
    'bdf5005ce7a7a71aae2918683cfede67ba2b2c3177e8af5af1deb1a1d33e634c'
    'cc4317024ee5e1283fb35923093c795fa0a614a690af4911e775d39868b2c0cc'
    '95ae0288be8ecf4033a1b971ddb4a314bf00e1871de7d2cf4a04102c10bf1461'
    '7d25b460a751216a22b3fe5def0152f536422b92bb0a38215939ee508372b2f4'
    '081abe64cf7b0f154e8dc645aea836838caa1bf828124da8c17eb619b5bb6632'
)
$protectedTenant1FingerprintSet = [Collections.Generic.HashSet[string]]::new(
    [string[]]$protectedTenant1Fingerprints,
    [StringComparer]::Ordinal
)

function Get-NormalizedContentFingerprint {
    param([Parameter(Mandatory)][string]$Value)

    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value.Trim().ToLowerInvariant())
        ([BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-ContentFingerprintCandidates {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Extension
    )

    $candidates = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $patterns = @(
        '[''"](?<value>[^''"\r\n]{1,512})[''"]'
        '(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b'
        '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b'
        '(?i)https?://[^\s''"<>]+'
        '\b[0-9]{6,}\b'
        '\b[A-Za-z][A-Za-z0-9-]{5,}\b'
    )
    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches(
            $Content,
            $pattern,
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
            $value = if ($match.Groups['value'].Success) {
                $match.Groups['value'].Value
            }
            else {
                $match.Value
            }
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void]$candidates.Add($value.Trim())
            }
        }
    }
    foreach ($candidate in @($candidates)) {
        $decoded = [Uri]::UnescapeDataString($candidate)
        if (-not [string]::IsNullOrWhiteSpace($decoded)) {
            [void]$candidates.Add($decoded.Trim())
            foreach ($segment in @($decoded -split '[/\\]')) {
                if (-not [string]::IsNullOrWhiteSpace($segment)) {
                    [void]$candidates.Add($segment.Trim())
                }
            }
        }
    }

    if ($Extension -in @('.ps1', '.psm1', '.psd1')) {
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseInput(
            $Content,
            [ref]$tokens,
            [ref]$parseErrors
        )
        foreach ($expression in @($ast.FindAll({
            param($node)
            $node -is [Management.Automation.Language.BinaryExpressionAst]
        }, $true))) {
            try {
                $value = $expression.SafeGetValue()
                if ($value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) {
                    [void]$candidates.Add($value.Trim())
                }
            }
            catch {
            }
        }
    }

    @($candidates)
}

try {
    $gitPath = (Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $trackedTenantFiles = @(
        & $gitPath -C $repositoryRootPath ls-files -- `
            'infra/src/config/tenants/*.psd1' `
            'infra/evidence/discovery/*.json'
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'git ls-files failed.'
    }

    $allowedTenantFiles = @(
        'infra/evidence/discovery/caldova25668747.json'
        'infra/src/config/tenants/_template.psd1'
        'infra/src/config/tenants/caldova25668747.psd1'
    )
    if (($trackedTenantFiles -join "`n") -cne ($allowedTenantFiles -join "`n")) {
        [void]$failures.Add('Tracked tenant configuration/evidence inventory is not the reviewed lean boundary.')
    }

    $expectedTenant2Blobs = @{
        'infra/src/config/tenants/caldova25668747.psd1' = 'f4b2dfed2f42d1d9d95d51dddaeaaedf4d8b6dce'
        'infra/evidence/discovery/caldova25668747.json' = 'c2d4d66f4f812fc449752c275845fac5a713915e'
    }
    foreach ($entry in $expectedTenant2Blobs.GetEnumerator()) {
        $actualBlob = (& $gitPath -C $repositoryRootPath hash-object -- $entry.Key).Trim()
        if ($LASTEXITCODE -ne 0 -or $actualBlob -cne $entry.Value) {
            [void]$failures.Add("Protected Tenant 2 blob changed: $($entry.Key)")
        }
    }

    $activePayloadPaths = @(
        & $gitPath -C $repositoryRootPath ls-files -- `
            '.github/cli/**' `
            '.github/ISSUE_TEMPLATE/**' `
            '.github/workflows/**' `
            'infra/src/**' `
            'infra/tests/**'
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'git ls-files failed for active payload isolation.'
    }
    $protectedTransitionPaths = @(
        'infra/src/config/tenants/caldova25668747.psd1'
        'infra/evidence/discovery/caldova25668747.json'
    )
    $scannableExtensions = @(
        '.ps1', '.psm1', '.psd1', '.json', '.bicep', '.bicepparam',
        '.yml', '.yaml', '.xml', '.txt', '.csv'
    )
    foreach ($relativePath in $activePayloadPaths) {
        if ($relativePath -in $protectedTransitionPaths) {
            continue
        }
        $extension = [IO.Path]::GetExtension($relativePath).ToLowerInvariant()
        if ($extension -notin $scannableExtensions) {
            continue
        }

        $absolutePath = Join-Path $repositoryRootPath $relativePath
        if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
            continue
        }
        $content = [IO.File]::ReadAllText($absolutePath)
        foreach ($candidate in @(Get-ContentFingerprintCandidates -Content $content -Extension $extension)) {
            $fingerprint = Get-NormalizedContentFingerprint -Value $candidate
            if ($protectedTenant1FingerprintSet.Contains($fingerprint)) {
                [void]$failures.Add("Protected Tenant 1 payload fingerprint found: $relativePath")
                break
            }
        }
    }
}
catch {
    [void]$failures.Add("Cannot validate tracked tenant boundary: $($_.Exception.Message)")
}

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