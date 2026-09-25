function Connect-HrPowerPlatformEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]+$')]
        [string]$TenantAlias,

        [Parameter(Mandatory)]
        [ValidateSet('Dev', 'Test', 'Prod')]
        [string]$Stage,

        [string]$TenantConfigurationPath,

        [scriptblock]$NativeCommandRunner
    )

    $environmentUrl = Get-HrTenantPowerPlatformUrl -TenantAlias $TenantAlias -Stage $Stage -TenantConfigurationPath $TenantConfigurationPath
    $profileName = "hr-$TenantAlias-$($Stage.ToLowerInvariant())"
    if ($profileName.Length -gt 30) {
        throw "Computed PAC auth profile name '$profileName' exceeds the 30-character limit. Shorten TenantAlias or contact the platform owner before proceeding."
    }

    $listResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('auth', 'list') -NativeCommandRunner $NativeCommandRunner
    if ($listResult.ExitCode -ne 0) {
        throw "pac auth list failed: $($listResult.StdErr)"
    }

    $existingProfileFound = $false
    foreach ($line in ($listResult.StdOut -split "`r?`n")) {
        $match = [regex]::Match($line, '^\[(?<idx>\d+)\]\s*(?<active>\*)?\s*(?<kind>\S+)\s+(?<name>\S+)')
        if ($match.Success -and $match.Groups['name'].Value -ceq $profileName) {
            $existingProfileFound = $true
            break
        }
    }

    if ($existingProfileFound) {
        $selectResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('auth', 'select', '--name', $profileName) -NativeCommandRunner $NativeCommandRunner
        if ($selectResult.ExitCode -ne 0) {
            throw "pac auth select failed for profile '$profileName': $($selectResult.StdErr)"
        }
    }
    else {
        $createResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('auth', 'create', '--name', $profileName, '--environment', $environmentUrl) -NativeCommandRunner $NativeCommandRunner
        if ($createResult.ExitCode -ne 0) {
            throw "pac auth create failed for profile '$profileName': $($createResult.StdErr)"
        }
    }

    $whoResult = Invoke-HrNativeCommand -FilePath 'pac' -ArgumentList @('org', 'who', '--environment', $environmentUrl) -NativeCommandRunner $NativeCommandRunner
    if ($whoResult.ExitCode -ne 0) {
        throw "pac org who failed to verify connectivity for '$environmentUrl': $($whoResult.StdErr)"
    }

    [pscustomobject]@{
        TenantAlias = $TenantAlias
        Stage = $Stage
        EnvironmentUrl = $environmentUrl
        ProfileName = $profileName
    }
}
