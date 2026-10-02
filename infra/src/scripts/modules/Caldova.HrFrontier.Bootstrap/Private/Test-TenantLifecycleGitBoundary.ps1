function Test-TenantLifecycleGitBoundary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory)]
        [string]$RelativeLabel,

        [Parameter(Mandatory)]
        [scriptblock]$NativeCommandRunner
    )

    function Invoke-GitBoundaryProbe {
        param([Parameter(Mandatory)][string[]]$ArgumentList)

        try {
            $result = & $NativeCommandRunner 'git' $ArgumentList
        }
        catch {
            throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Git')
        }

        if ($null -eq $result -or
            $null -eq $result.PSObject.Properties['exitCode'] -or
            $null -eq $result.PSObject.Properties['stdout']) {
            throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Git')
        }
        $result
    }

    $commonArguments = @('-C', $RepositoryRoot)
    $ignoreResult = Invoke-GitBoundaryProbe -ArgumentList (
        $commonArguments + @('check-ignore', '--quiet', '--', $RelativeLabel)
    )
    $trackedResult = Invoke-GitBoundaryProbe -ArgumentList (
        $commonArguments + @('ls-files', '--error-unmatch', '--', $RelativeLabel)
    )
    $statusResult = Invoke-GitBoundaryProbe -ArgumentList (
        $commonArguments + @(
            'status',
            '--porcelain=v1',
            '--ignored',
            '--untracked-files=all',
            '--',
            $RelativeLabel
        )
    )

    $ignored = [int]$ignoreResult.exitCode -eq 0
    $tracked = [int]$trackedResult.exitCode -eq 0
    $validTrackedExit = [int]$trackedResult.exitCode -in @(0, 1)
    $statusLine = ([string]$statusResult.stdout).TrimEnd("`r", "`n")
    $exactStatus = [int]$statusResult.exitCode -eq 0 -and
        $statusLine -ceq "!! $RelativeLabel"

    if (-not $ignored -or -not $validTrackedExit -or $tracked -or -not $exactStatus) {
        throw [IO.InvalidDataException]::new('TenantLifecycle.PrivateBoundary.Git')
    }

    [pscustomobject][ordered]@{
        ignored = $true
        tracked = $false
    }
}
