Set-StrictMode -Version Latest

BeforeAll {
    $script:root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:docsTheme = Join-Path $script:root 'docs\brand\caldova-fluent-theme.ts'
    $script:tokens = Join-Path $script:root 'docs\brand\caldova-tokens.css'
    $script:mockup = Join-Path $script:root 'docs\brand\hr-control-plane-mockup.html'
    $script:appRoot = Join-Path $script:root 'hr\src\apps\hr-control-plane'
    $script:appTheme = Join-Path $script:appRoot 'src\theme.ts'
    $script:app = Join-Path $script:appRoot 'src\App.tsx'
    $script:header = Join-Path $script:appRoot 'src\components\AppHeader.tsx'
    $script:footer = Join-Path $script:appRoot 'src\components\AppFooter.tsx'
}

Describe 'Caldova product theme contract' {
    It 'uses the two canonical target asset paths' {
        $script:docsTheme | Should -Exist
        $script:tokens | Should -Exist
    }

    It 'preserves the exact Fluent brand ramp in the canonical and app themes' {
        $expected = [ordered]@{
            10 = '#04121E'; 20 = '#08243C'; 30 = '#0C3559'; 40 = '#104776'
            50 = '#145893'; 60 = '#1965A3'; 70 = '#2C76B0'; 80 = '#4488BE'
            90 = '#5F9ACB'; 100 = '#7CACD8'; 110 = '#99BFE4'
            120 = '#B5D1EC'; 130 = '#CFE1F3'; 140 = '#E2EDF8'
            150 = '#EFF5FB'; 160 = '#F7FAFD'
        }
        foreach ($path in @($script:docsTheme, $script:appTheme)) {
            $content = [IO.File]::ReadAllText($path)
            foreach ($entry in $expected.GetEnumerator()) {
                $content | Should -Match (
                    '(?m)^\s*{0}:\s*"{1}",' -f $entry.Key, [regex]::Escape($entry.Value)
                )
            }
            $content | Should -Match '6\.05:1 on white'
            $content | Should -Match '7\.28:1 on #1B1A19'
        }
    }

    It 'exports only the Caldova symbol contract and Dataverse-style prefix' {
        $content = [IO.File]::ReadAllText($script:appTheme)
        foreach ($symbol in @(
            'caldovaBrandRamp', 'caldovaLightTheme', 'caldovaDarkTheme',
            'caldovaSemantic', 'caldovaDataViz', 'caldovaLocales',
            'CaldovaLocale', 'caldovaDefaultLocale',
            'caldovaNonLocalisedPatterns'
        )) {
            $content | Should -Match ('\b{0}\b' -f [regex]::Escape($symbol))
        }
        $content | Should -Match '\^caldova_\[a-z\]\+\$'
    }

    It 'uses the canonical CSS prefixes and interim-palette wording' {
        $tokenContent = [IO.File]::ReadAllText($script:tokens)
        $brandGuide = [IO.File]::ReadAllText(
            (Join-Path $script:root 'docs\brand\README.md')
        )
        $tokenContent | Should -Match '--caldova-brand-60:\s+#1965A3'
        $tokenContent | Should -Match '(?m)^\.caldova-theme-dark\s*\{'
        $tokenContent | Should -Match '(?m)^\.caldova-app\s*\{'
        $brandGuide | Should -Match (
            'interim product palette pending an approved Caldova design standard'
        )
        $brandGuide | Should -Not -Match 'official Caldova corporate'
    }

    It 'uses Caldova in the app and mockup visible labels and imports' {
        [IO.File]::ReadAllText($script:app) |
            Should -Match 'import \{ caldovaLightTheme \} from "\./theme"'
        [IO.File]::ReadAllText($script:app) |
            Should -Match 'theme=\{caldovaLightTheme\}'
        [IO.File]::ReadAllText($script:header) |
            Should -Match '>Caldova<'
        [IO.File]::ReadAllText($script:footer) |
            Should -Match 'Caldova HR Agentic Platform'
        [IO.File]::ReadAllText($script:mockup) |
            Should -Match 'Caldova HR Agentic Platform'
        [IO.File]::ReadAllText($script:mockup) |
            Should -Match '--caldova-brand-60'
    }
}
