Describe 'GF agent identity intake' {
    It 'validates the actual curated configuration assets bindings and provenance' {
        $root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        Push-Location $root
        try {
            $output = @(
                & python -m unittest discover -s '.github\cli\tests' `
                    -p 'test_gf_agent_identity.py' -v 2>&1
            )
            $exitCode = $LASTEXITCODE
            $exitCode | Should -Be 0 -Because ($output -join [Environment]::NewLine)
        }
        finally {
            Pop-Location
        }
    }
}
