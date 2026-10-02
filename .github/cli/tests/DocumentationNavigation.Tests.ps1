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

    $script:exactHistoricalAllowlist = @(
        '.github/cli/tests/Phase2SourceContract.Tests.ps1'
        'docs/plans/2026-09-15-repository-superpowers-implementation.md'
        'docs/plans/2026-09-17-governance-github-intake-implementation.md'
        'docs/plans/2026-09-17-product-hr-operating-model-intake-implementation.md'
        'docs/plans/2026-09-24-hr-solution-functional-design-intake-implementation.md'
        'docs/plans/2026-09-25-azure-boards-population-implementation.md'
        'docs/plans/2026-10-01-caldova-branding-migration-implementation.md'
        'docs/reviews/2026-09-17-architecture-baseline-source-inventory.json'
        'docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md'
        'docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md'
        'docs/reviews/evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json'
        'hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-summary.md'
        'docs/specs/2026-09-17-architecture-baseline-intake-design.md'
        'docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md'
        'docs/specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md'
        'docs/plans/2026-10-02-documentation-knowledge-architecture-cleanup-implementation.md'
        'docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md'
        'docs/archive/phase-2-operating-model/20-hr-employee-journey.md'
    )
    $script:retiredPathPattern = @(
        ('docs[/\\]' + 'superpowers[/\\]')
        ('docs[/\\]' + 'operating-model[/\\]')
        ('docs[/\\]' + 'brandkit[/\\]')
        ('docs[/\\]' + 'business[/\\]')
        ('docs[/\\]' + 'delegation[/\\]')
        ('docs[/\\]' + 'issues[/\\]')
        ('docs[/\\]' + 'sprints[/\\]')
        ('docs[/\\]' + 'templates[/\\]')
        ('hr[/\\]docs[/\\]' + 'ideas[/\\]')
    ) -join '|'

    Push-Location $script:repositoryRoot
    try {
        $grepOutput = @(
            & git grep -I -n -E $script:retiredPathPattern --
        )
        $grepExitCode = $LASTEXITCODE
        if ($grepExitCode -gt 1) {
            throw "Retired-path scan failed with exit code $grepExitCode."
        }

        $script:migrationBase = (& git merge-base origin/main HEAD).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($script:migrationBase)) {
            throw 'Cannot resolve the origin/main merge base.'
        }
    }
    finally {
        Pop-Location
    }

    $script:retiredPathMatches = @(
        foreach ($line in $grepOutput) {
            if ($line -notmatch '^(?<Path>[^:]+):(?<Line>\d+):(?<Text>.*)$') {
                throw "Cannot parse retired-path match: $line"
            }
            [pscustomobject]@{
                Path = $Matches.Path.Replace('\', '/')
                Line = [int]$Matches.Line
                Text = $Matches.Text
            }
        }
    )
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

Describe 'Canonical knowledge routing contracts' {
    It 'publishes the approved authority order from one canonical section' {
        $knowledgeMap = Get-Content -LiteralPath (
            Join-Path $script:repositoryRoot 'docs\README.md'
        ) -Raw
        $authoritySection = [regex]::Match(
            $knowledgeMap,
            '(?ms)^## Authority and Conflict Order\r?$\s*(?<Body>.*?)(?=^## )'
        )
        $authoritySection.Success | Should -BeTrue

        $expectedRules = @(
            '1. law, organizational governance, and explicit human authority;'
            '2. Accepted or Approved policies, ADRs, and specifications;'
            '3. approved platform requirements and cross-cutting governance;'
            '4. the more specific domain or use-case contract, provided it does not weaken higher governance;'
            '5. the approved implementation plan for the selected specification; and'
            '6. evidence of the implemented state.'
        )
        $cursor = -1
        foreach ($rule in $expectedRules) {
            $next = $authoritySection.Groups['Body'].Value.IndexOf(
                $rule,
                ($cursor + 1),
                [StringComparison]::Ordinal
            )
            $next | Should -BeGreaterThan $cursor
            $cursor = $next
        }

        $instructions = Get-Content -LiteralPath (
            Join-Path $script:repositoryRoot '.github\copilot-instructions.md'
        ) -Raw
        $instructions |
            Should -Match '\[authority and conflict order\]\(\.\./docs/README\.md#authority-and-conflict-order\)'
        $instructions | Should -Not -Match '(?i)\bmore specific wins\b'
    }

    It 'keeps maintained Phase 2 archive navigation active' {
        $phase2Catalogue = Join-Path $script:phase2ArchiveRoot 'README.md'
        Get-MetadataStatus -Path $phase2Catalogue | Should -Be 'Active'

        $archiveRows = @(Get-CatalogueRows -ReadmePath (
            Join-Path $script:repositoryRoot 'docs\archive\README.md'
        ))
        $phase2Rows = @(
            $archiveRows |
                Where-Object Target -CEQ ([IO.Path]::GetFullPath($phase2Catalogue))
        )
        $phase2Rows.Count | Should -Be 1
        $phase2Rows[0].Status | Should -Be 'Active'

        $snapshotRows = @(Get-CatalogueRows -ReadmePath $phase2Catalogue)
        $snapshotRows.Count | Should -Be 8
        @($snapshotRows | Where-Object Status -ne 'Superseded') |
            Should -BeNullOrEmpty
    }

    It 'routes stand-up questions to the maintained infrastructure catalogue' {
        $instructionsPath = Join-Path $script:repositoryRoot '.github\copilot-instructions.md'
        $instructions = Get-Content -LiteralPath $instructionsPath -Raw
        $route = [regex]::Match(
            $instructions,
            '(?m)^\| How do we stand it up \| \[Infrastructure documentation\]\((?<Target>\.\./infra/docs/README\.md)\) \|'
        )
        $route.Success | Should -BeTrue
        if ($route.Success) {
            $target = [IO.Path]::GetFullPath((
                Join-Path (Split-Path -Parent $instructionsPath) (
                    $route.Groups['Target'].Value.Replace('/', '\')
                )
            ))
            $target | Should -Exist
        }
    }

    It 'documents the complete approved canonical tree' {
        $knowledgeMap = Get-Content -LiteralPath (
            Join-Path $script:repositoryRoot 'docs\README.md'
        ) -Raw
        $structure = [regex]::Match(
            $knowledgeMap,
            '(?ms)^## Structure\r?$\s*```text\r?\n(?<Tree>.*?)\r?\n```'
        )
        $structure.Success | Should -BeTrue

        $expectedTree = @'
.github/copilot-instructions.md
docs/
├── README.md
├── ideas/
│   └── README.md
├── specs/
│   └── README.md
├── plans/
│   └── README.md
├── reviews/
│   └── README.md
├── archive/
│   ├── README.md
│   └── phase-2-operating-model/
│       └── README.md
├── adr/
├── brand/
├── prd.md
├── solution-design.md
└── hr-journey-and-raci.md
hr/
├── README.md
└── docs/
    └── use-cases/
        └── README.md
infra/
├── README.md
└── docs/
    └── README.md
data/
└── README.md
'@
        $structure.Groups['Tree'].Value.Trim() | Should -Be $expectedTree.Trim()
    }

    It 'distinguishes central use-case ideas from detailed HR packages' {
        $knowledgeMap = Get-Content -LiteralPath (
            Join-Path $script:repositoryRoot 'docs\README.md'
        ) -Raw
        $knowledgeMap | Should -Match (
            '(?m)^\| `uc-` \| Central portfolio idea record \| ' +
            '`docs/ideas/uc-<number>-<context>\.md` \|\r?$'
        )
        $knowledgeMap | Should -Match (
            '(?m)^\| `uc-` package \| Detailed HR use-case package \| ' +
            '`hr/docs/use-cases/uc-<number>-<context>/` \|\r?$'
        )
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

Describe 'Final migration boundaries' {
    It 'rejects every unallowlisted retired path with exact file and line evidence' {
        $unexpected = @(
            $script:retiredPathMatches |
                Where-Object {
                    -not $_.Path.StartsWith(
                        '.github/skills/',
                        [StringComparison]::Ordinal
                    ) -and
                    -not ($script:exactHistoricalAllowlist -ccontains $_.Path)
                } |
                ForEach-Object { '{0}:{1}:{2}' -f $_.Path, $_.Line, $_.Text }
        )

        $unexpected | Should -BeNullOrEmpty -Because (
            "retired paths require an exact reviewed disposition:`n{0}" -f
            ($unexpected -join "`n")
        )
    }

    It 'keeps every exact historical exception necessary' {
        $matchedAllowlist = @(
            $script:retiredPathMatches.Path |
                Where-Object { $script:exactHistoricalAllowlist -ccontains $_ } |
                Sort-Object -Unique
        )
        $unused = @(
            $script:exactHistoricalAllowlist |
                Where-Object { -not ($matchedAllowlist -ccontains $_) }
        )

        $unused | Should -BeNullOrEmpty -Because (
            "unused historical exceptions broaden the boundary: {0}" -f
            ($unused -join ', ')
        )
    }

    It 'keeps every idea catalogue row Board-neutral' {
        $catalogueLines = Get-Content -LiteralPath (
            Join-Path $script:ideaRoot 'README.md'
        )
        $ideaRows = @(
            $catalogueLines |
                Where-Object { $_ -match '^\|\s*(UC-\d{4}|IDEA-[^|]+)\s*\|' }
        )
        $ideaRows.Count | Should -BeGreaterThan 0

        foreach ($row in $ideaRows) {
            $boardStatus = @($row -split '\|')[-2].Trim()
            $boardStatus | Should -BeIn @(
                'Deferred - not synchronized'
                'Not applicable'
            )
        }
    }

    It 'keeps central idea files free of Azure Boards identifiers' {
        $boardReferences = @(
            Get-ChildItem -LiteralPath $script:ideaRoot -File -Recurse |
                Select-String -Pattern 'AB#\d+'
        )
        $boardReferences | Should -BeNullOrEmpty
    }

    It 'requires a governing record before a verified Azure Boards closure' {
        $template = Get-Content -LiteralPath (
            Join-Path $script:repositoryRoot '.github\pull_request_template.md'
        ) -Raw

        $template | Should -Match '(?m)^## Governing record\s*$'
        $template | Should -Match 'repository idea,\s+specification, and plan'
        $template | Should -Match 'Use `Fixes AB#<id>` only after Azure Boards synchronization'
        $template | Should -Match 'referenced ID has been verified'
    }

    It 'keeps the workflow directory limited to the established pair' {
        $workflowNames = @(
            Get-ChildItem -LiteralPath (
                Join-Path $script:repositoryRoot '.github\workflows'
            ) -File |
                Sort-Object Name |
                Select-Object -ExpandProperty Name
        )

        $workflowNames | Should -Be @(
            'README.md'
            'validate-repository.yml'
        )
    }

    It 'keeps the migration range workflow-neutral' {
        Push-Location $script:repositoryRoot
        try {
            $workflowChanges = @(
                & git diff --name-only "$script:migrationBase...HEAD" -- '.github/workflows'
            )
            if ($LASTEXITCODE -ne 0) {
                throw 'Workflow range comparison failed.'
            }
        }
        finally {
            Pop-Location
        }

        $workflowChanges | Should -BeNullOrEmpty
    }
}
