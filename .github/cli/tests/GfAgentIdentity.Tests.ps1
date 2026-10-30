Describe 'GF agent identity intake' {
    It 'validates the actual curated configuration assets bindings and provenance' {
        $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = (Get-Command python -CommandType Application -ErrorAction Stop |
            Select-Object -First 1).Source
        $start.Arguments = '-m unittest discover -s .github\cli\tests -p test_gf_agent_identity.py -v'
        $start.WorkingDirectory = $root
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $start
        try {
            if (-not $process.Start()) {
                throw 'Python identity validation process did not start.'
            }
            # unittest progress uses stderr, which PowerShell 5.1 otherwise treats as errors.
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit()
            $diagnostics = @($stdout.Result, $stderr.Result) -join [Environment]::NewLine
            $process.ExitCode | Should -Be 0 -Because $diagnostics
        }
        finally {
            $process.Dispose()
        }
    }
}
