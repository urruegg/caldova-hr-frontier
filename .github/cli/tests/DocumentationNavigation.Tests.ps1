Set-StrictMode -Version Latest

$catalogueRoots = @(
    'docs/ideas'
    'docs/specs'
    'docs/plans'
    'docs/reviews'
    'docs/adr'
    'docs/brand'
    'docs/archive'
    'docs/archive/phase-2-operating-model'
    'hr/docs/use-cases'
    'infra/docs'
)

BeforeAll {
    function Get-MetadataStatus {
        param([Parameter(Mandatory)][string]$Path)

        $content = Get-Content -LiteralPath $Path -Raw
        $match = [regex]::Match(
            $content,
            '(?m)^\| \*\*Status\*\* \| (?<Status>.*?) \|\r?$'
        )
        if (-not $match.Success) { throw "Missing Status metadata: $Path" }
        return $match.Groups['Status'].Value.Trim()
    }

    function Get-DirectMarkdownChildren {
        param([Parameter(Mandatory)][string]$Directory)

        return @(
            Get-ChildItem -LiteralPath $Directory -Filter '*.md' -File |
                Where-Object Name -ne 'README.md' |
                Sort-Object Name
        )
    }

    function Get-ExpectedDirectCatalogueTargets {
        param([Parameter(Mandatory)][string]$Directory)

        $files = @(
            Get-DirectMarkdownChildren -Directory $Directory |
                ForEach-Object FullName
        )
        $childReadmes = @(
            Get-ChildItem -LiteralPath $Directory -Directory |
                ForEach-Object { Join-Path $_.FullName 'README.md' } |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
        )
        return @(($files + $childReadmes) | Sort-Object -Unique)
    }

    function Get-CatalogueRows {
        param([Parameter(Mandatory)][string]$ReadmePath)

        $content = Get-Content -LiteralPath $ReadmePath -Raw
        $directory = Split-Path -Parent $ReadmePath
        $catalogueHeading = [regex]::Match(
            $content,
            '(?m)^## Catalogue\s*$'
        )
        if (-not $catalogueHeading.Success) { return @() }

        $catalogueStart = $catalogueHeading.Index + $catalogueHeading.Length
        $remaining = $content.Substring($catalogueStart)
        $nextHeading = [regex]::Match($remaining, '(?m)^## [^#].*$')
        $catalogue = if ($nextHeading.Success) {
            $remaining.Substring(0, $nextHeading.Index)
        }
        else {
            $remaining
        }

        return @(
            [regex]::Matches(
                $catalogue,
                '(?m)^\|[^\r\n]*\]\((?<Target>[^)#?]+\.md)(?:#[^)]+)?\)\s*\|\s*(?<Status>[^|]+?)\s*\|'
            ) |
                ForEach-Object {
                    $target = [Uri]::UnescapeDataString(
                        $_.Groups['Target'].Value
                    ).Replace('/', '\')
                    [pscustomobject]@{
                        Target = [IO.Path]::GetFullPath((Join-Path $directory $target))
                        Status = $_.Groups['Status'].Value.Trim()
                    }
                } |
                Where-Object {
                    $_.Target.StartsWith(
                        ([IO.Path]::GetFullPath($directory).TrimEnd('\') + '\'),
                        [StringComparison]::OrdinalIgnoreCase
                    )
                }
        )
    }

    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:ideaRoot = Join-Path $script:repositoryRoot 'docs\ideas'
    $script:useCaseRoot = Join-Path $script:repositoryRoot 'hr\docs\use-cases'
    $script:phase2ArchiveRoot = Join-Path $script:repositoryRoot 'docs\archive\phase-2-operating-model'
}

Describe 'Central idea portfolio and HR use-case detail' {
    It 'uses one central idea root and one HR detail root' {
        $script:ideaRoot | Should -Exist
        $script:useCaseRoot | Should -Exist
        (Join-Path $script:repositoryRoot 'hr\docs\ideas') | Should -Not -Exist
    }

    It 'retains all nineteen HR use-case idea records centrally' {
        $ideas = @(Get-ChildItem -LiteralPath $script:ideaRoot -Filter 'uc-*.md' -File)
        $ideas.Count | Should -Be 19
        foreach ($number in 1..19) {
            $pattern = 'uc-{0:d4}-*.md' -f $number
            @(Get-ChildItem -LiteralPath $script:ideaRoot -Filter $pattern -File).Count |
                Should -Be 1
        }
    }

    It 'marks UC-0001 graduated and defers Board synchronization' {
        $idea = Get-Content -LiteralPath (
            Join-Path $script:ideaRoot 'uc-0001-personal-master-data-completion-agent.md'
        ) -Raw
        $idea | Should -Match '\| \*\*Status\*\* \| Graduated \|'
        $catalogue = Get-Content -LiteralPath (Join-Path $script:ideaRoot 'README.md') -Raw
        $catalogue | Should -Match 'Deferred - not synchronized'
        $catalogue | Should -Not -Match 'AB#\d+'
    }
}

Describe 'Canonical specification and plan roots' {
    It 'has no repository documentation below docs/superpowers' {
        (Join-Path $script:repositoryRoot 'docs\superpowers') | Should -Not -Exist
    }

    It 'stores the two AI Builder designs and five plans in canonical roots' {
        foreach ($relativePath in @(
            'docs/specs/2026-09-25-tenant-2-ai-builder-models-design.md'
            'docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md'
            'docs/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md'
            'docs/plans/2026-09-26-runbook-cloud-foundation.md'
            'docs/plans/2026-09-26-runbook-customer-handover.md'
            'docs/plans/2026-09-26-runbook-foundation-workstation.md'
            'docs/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md'
        )) {
            Join-Path $script:repositoryRoot $relativePath | Should -Exist
        }
    }
}

Describe 'Phase 2 archive navigation' {
    It 'routes historical discovery through the archive catalogue' {
        (Join-Path $script:repositoryRoot 'docs\operating-model') | Should -Not -Exist

        $phase2Catalogue = Join-Path $script:phase2ArchiveRoot 'README.md'
        $phase2Catalogue | Should -Exist

        $docsNavigation = Get-Content -LiteralPath (
            Join-Path $script:repositoryRoot 'docs\README.md'
        ) -Raw
        $archiveNavigation = Get-Content -LiteralPath (
            Join-Path $script:repositoryRoot 'docs\archive\README.md'
        ) -Raw
        $docsNavigation | Should -Match 'archive/phase-2-operating-model/README\.md'
        $archiveNavigation | Should -Match 'phase-2-operating-model/README\.md'
    }
}

Describe 'Authoritative documentation catalogues' {
    It '<_> has one exact catalogue row for every direct child' -ForEach $catalogueRoots {
        $fullRoot = Join-Path $script:repositoryRoot $_
        $readmePath = Join-Path $fullRoot 'README.md'
        $readmePath | Should -Exist

        $expectedTargets = @(Get-ExpectedDirectCatalogueTargets -Directory $fullRoot)
        $rows = @(Get-CatalogueRows -ReadmePath $readmePath)
        $actualTargets = @($rows.Target | Sort-Object -Unique)
        $actualTargets | Should -Be $expectedTargets

        foreach ($file in Get-DirectMarkdownChildren -Directory $fullRoot) {
            $matching = @($rows | Where-Object Target -CEQ $file.FullName)
            $matching.Count | Should -Be 1
            $matching[0].Status | Should -Be (Get-MetadataStatus -Path $file.FullName)
        }
    }
}

Describe 'Retired placeholder documentation roots' {
    It '<_> is absent' -ForEach @(
        'docs/brandkit'
        'docs/business'
        'docs/delegation'
        'docs/issues'
        'docs/sprints'
        'docs/templates'
        'docs/superpowers'
        'docs/operating-model'
        'hr/docs/ideas'
    ) {
        Join-Path $script:repositoryRoot $_ | Should -Not -Exist
    }
}
