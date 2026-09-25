function Invoke-HrNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [scriptblock]$NativeCommandRunner
    )

    if ($NativeCommandRunner) {
        $result = & $NativeCommandRunner -FilePath $FilePath -ArgumentList $ArgumentList
        return [pscustomobject]@{
            ExitCode = [int]$result.ExitCode
            StdOut = [string]$result.StdOut
            StdErr = [string]$result.StdErr
        }
    }

    $resolvedCommand = Get-Command $FilePath -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $resolvedCommand) {
        throw "Cannot resolve executable on PATH: $FilePath"
    }

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        & $resolvedCommand.Source @ArgumentList 1> $stdoutPath 2> $stderrPath
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            StdOut = [System.IO.File]::ReadAllText($stdoutPath)
            StdErr = [System.IO.File]::ReadAllText($stderrPath)
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}
