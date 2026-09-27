function Invoke-CloudNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$ToolResolution,
        [Parameter(Mandatory)] [string[]]$ArgumentList,
        [Parameter(Mandatory)] [scriptblock]$Runner,
        [switch]$Json
    )

    $logicalName = [string]$ToolResolution.name
    if ($logicalName -cnotin @('az','gh','pac','git')) {
        throw "Cloud command is not allowlisted: $logicalName"
    }
    $approvedPath = [string]$ToolResolution.path
    if (-not [IO.Path]::IsPathRooted($approvedPath)) {
        throw 'The approved cloud executable path is not absolute.'
    }
    $approvedPath = [IO.Path]::GetFullPath($approvedPath)
    if ([string]$ToolResolution.version -eq '' -or
        [string]$ToolResolution.sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw "Approved cloud executable identity is incomplete: $logicalName"
    }
    $prohibited = @(
        'GH_TOKEN','GITHUB_TOKEN','AZURE_DEVOPS_EXT_PAT','SYSTEM_ACCESSTOKEN',
        'AZURE_CLIENT_ID',('AZURE_CLIENT' + '_SECRET'),('AZURE_FEDERATED' + '_TOKEN_FILE'),
        'ARM_CLIENT_ID',('ARM_CLIENT' + '_SECRET'),'ARM_OIDC_TOKEN',('POWERPLATFORMCLIENT' + 'SECRET')
    )
    foreach ($name in $prohibited) {
        if (-not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            throw "A prohibited authentication environment variable is set: $name"
        }
    }

    $nativeResult = & $Runner $approvedPath $ArgumentList
    if ($null -eq $nativeResult -or [int]$nativeResult.exitCode -ne 0) {
        $exitCode = if ($null -eq $nativeResult) { -1 } else { [int]$nativeResult.exitCode }
        throw "Cloud command failed for $logicalName with exit code $exitCode."
    }
    if (-not $Json) { return [string]$nativeResult.stdout }
    if ([string]::IsNullOrWhiteSpace([string]$nativeResult.stdout)) {
        throw "Cloud command returned empty JSON for $logicalName."
    }
    try {
        return ([string]$nativeResult.stdout | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        throw "Cloud command returned invalid JSON for $logicalName."
    }
}
