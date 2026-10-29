BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:profilePath = Join-Path $script:repositoryRoot '.github\agents\blueprint-maintainer.agent.md'
    Import-Module (Join-Path $PSScriptRoot '..\modules\DocumentationMetadata.psm1') -Force

    function Read-BlueprintPreviewProfile {
        $script:profilePath | Should -Exist
        $content = Get-Content -LiteralPath $script:profilePath -Raw
        $match = [regex]::Match($content, '(?s)\A---\r?\n(?<Yaml>.*?)\r?\n---(?:\r?\n|$)')
        $match.Success | Should -BeTrue -Because 'the host discovers the profile through YAML frontmatter'

        $fields = @{}
        foreach ($line in ($match.Groups['Yaml'].Value -split '\r?\n')) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $field = [regex]::Match($line, '^(?<Name>[a-z][a-z-]*):\s*(?<Value>.+)$')
            $field.Success | Should -BeTrue -Because 'the preview uses explicit flat frontmatter fields'
            $name = $field.Groups['Name'].Value
            $fields.ContainsKey($name) | Should -BeFalse -Because 'duplicate host settings are ambiguous'
            $fields[$name] = $field.Groups['Value'].Value.Trim()
        }

        [pscustomobject]@{ Content = $content; Fields = $fields }
    }
}

Describe 'Blueprint Maintainer gated preview profile' {
    It 'exists at the workspace agent discovery path' {
        $script:profilePath | Should -Exist
    }

    It 'declares an identifiable blueprint discovery description' {
        $profile = Read-BlueprintPreviewProfile
        $profile.Fields['name'] | Should -BeExactly 'blueprint-maintainer'
        $description = $profile.Fields['description']
        $description | Should -Match '^"[^"]+"$'
        $description | Should -Match '(?i)blueprint'
        $description | Should -Match '(?i)read.only'
    }

    It 'grants only repository reading searching and session task tracking' {
        $profile = Read-BlueprintPreviewProfile
        $profile.Fields.ContainsKey('tools') | Should -BeTrue
        $profile.Fields['tools'] | Should -Match '^\[[^\[\]]+\]$'
        $tools = @(
            ($profile.Fields['tools'].Trim('[', ']') -split ',') |
                ForEach-Object { $_.Trim() } |
                Sort-Object
        )
        $tools | Should -Be @('read', 'search', 'todo')
    }

    It 'allows manual selection but not model initiated invocation' {
        $profile = Read-BlueprintPreviewProfile
        $profile.Fields['user-invocable'] | Should -BeExactly 'true'
        $profile.Fields['disable-model-invocation'] | Should -BeExactly 'true'
    }

    It 'does not declare a delegation or hook execution route' {
        $profile = Read-BlueprintPreviewProfile
        $profile.Fields.Keys | Should -Not -Contain 'agents'
        $profile.Fields.Keys | Should -Not -Contain 'handoffs'
        $profile.Fields.Keys | Should -Not -Contain 'hooks'
    }

    It 'retains valid proposed documentation status rather than claiming activation' {
        $profile = Read-BlueprintPreviewProfile
        @(Test-DocumentationMetadataContent `
            -Content $profile.Content `
            -DocumentRelativePath '.github/agents/blueprint-maintainer.agent.md') |
            Should -BeNullOrEmpty
        $status = [regex]::Match(
            $profile.Content,
            '(?m)^\| \*\*Status\*\* \| (?<Status>[^|]+) \|\r?$'
        )
        $status.Success | Should -BeTrue
        $status.Groups['Status'].Value | Should -BeExactly 'Proposed Baseline'
    }
}
