function Read-CustomerExportCommitBlob {
    param([string]$GitPath, [string]$RepositoryRoot, [string]$Commit, [string]$Path)

    $arguments = @('-C', [IO.Path]::GetFullPath($RepositoryRoot), 'show', '--no-textconv', ('{0}:{1}' -f $Commit, $Path))
    $quoted = foreach ($value in $arguments) {
        if ($value -notmatch '[\s"]') { $value; continue }
        $builder = [Text.StringBuilder]::new('"')
        $backslashes = 0
        foreach ($character in $value.ToCharArray()) {
            if ($character -eq '\') { $backslashes++; continue }
            if ($character -eq '"') {
                [void]$builder.Append(('\' * (($backslashes * 2) + 1)))
                [void]$builder.Append('"')
                $backslashes = 0
                continue
            }
            if ($backslashes -gt 0) { [void]$builder.Append(('\' * $backslashes)); $backslashes = 0 }
            [void]$builder.Append($character)
        }
        if ($backslashes -gt 0) { [void]$builder.Append(('\' * ($backslashes * 2))) }
        [void]$builder.Append('"')
        $builder.ToString()
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = [Diagnostics.ProcessStartInfo]::new()
    $process.StartInfo.FileName = [IO.Path]::GetFullPath($GitPath)
    $process.StartInfo.Arguments = $quoted -join ' '
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.EnvironmentVariables['GIT_OPTIONAL_LOCKS'] = '0'
    $memory = [IO.MemoryStream]::new()
    try {
        [void]$process.Start()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $process.WaitForExit()
        [void]$stderr.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw 'Git commit blob read failed.' }
        return $memory.ToArray()
    }
    finally { $memory.Dispose(); $process.Dispose() }
}
