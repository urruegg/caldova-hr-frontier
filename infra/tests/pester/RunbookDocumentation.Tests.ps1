BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    Import-Module (Join-Path $script:repositoryRoot '.github\cli\modules\DocumentationMetadata.psm1') -Force

    function Get-MarkdownRelativeLinks {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        $content = Get-Content -Raw -LiteralPath $Path
        $content = [regex]::Replace(
            $content,
            '(?ms)^```.*?^```\s*',
            '',
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
        $matches = [regex]::Matches(
            $content,
            '\[[^\]]+\]\((?<target>[^)]+)\)',
            [Text.RegularExpressions.RegexOptions]::CultureInvariant
        )

        foreach ($match in $matches) {
            $target = $match.Groups['target'].Value.Trim()
            if ($target -match '^(?i:https://|http://|mailto:|#)') {
                continue
            }

            $pathPart = ($target -split '#', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) {
                continue
            }

            [pscustomobject]@{
                Source = $Path
                Target = $target
                PathPart = $pathPart
            }
        }
    }

    function Get-ProhibitedActiveBootstrapClaims {
        param(
            [Parameter(Mandatory)]
            [string]$Content
        )

        $statusMatch = [regex]::Match(
            $Content,
            '(?im)^\|\s+\*\*Status\*\*\s+\|\s+(?<Status>[^|]+?)\s+\|\s*$'
        )
        if (-not $statusMatch.Success) {
            throw 'Maintained documentation must declare metadata Status before bootstrap-claim scanning.'
        }
        if ($statusMatch.Groups['Status'].Value.Trim().StartsWith(
            'Superseded',
            [StringComparison]::OrdinalIgnoreCase
        )) {
            return @()
        }

        $bootstrapAuthTarget = '(?:OIDC|GitHub (?:bootstrap[- ]?)?Environment|bootstrap[- ]Environment)'
        $temporaryRoleTarget = 'temporary(?:-| )(?:subscription(?:-| ))?role(?:s|(?:-| )assignments?)?'
        $patterns = @(
            "\b${bootstrapAuthTarget}\b[^.;\r\n]{0,80}\b(?:is|remains|becomes)\s+(?:required|supported|current|a prerequisite|an? dependency)\b",
            "(?<!not )(?<!never )(?<!do not )\b(?:requires?|uses?|depends? on)\b(?:(?!\b(?:no|not|without)\b)[^.;\r\n]){0,120}\b${bootstrapAuthTarget}\b",
            "(?<!not )(?<!never )\bauthenticates?\s+(?:through|with|using)\b[^.;\r\n]{0,120}\b${bootstrapAuthTarget}\b",
            "\b${temporaryRoleTarget}\b[^.;\r\n]{0,120}\b(?:is|are|remain|becomes?|must be)\s+(?:required|supported|current|grant(?:ed)?|time-bound|recorded|delet(?:e|ed)|remov(?:e|ed)|cleanup|cleaned|verified)\b",
            "\b${temporaryRoleTarget}(?:-| )cleanup\b[^.;\r\n]{0,80}\b(?:is|remains|becomes)\s+(?:required|supported|current)\b",
            "\b(?:grant(?:ed)?|creat(?:e|ed)|delet(?:e|ed)|remov(?:e|ed)|clean(?:\s+up|ed)|cleanup)\b[^.;\r\n]{0,120}\b${temporaryRoleTarget}\b"
        )
        $claims = [System.Collections.Generic.List[string]]::new()
        foreach ($pattern in $patterns) {
            foreach ($match in [regex]::Matches(
                $Content,
                $pattern,
                [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                    [Text.RegularExpressions.RegexOptions]::Singleline -bor
                    [Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) {
                $claims.Add($match.Value) | Out-Null
            }
        }

        @($claims)
    }
}

Describe 'Runbook documentation contracts' {
    It 'records the controlling coordinate-only plan authority' {
        $specPath = Join-Path $script:repositoryRoot (
            'docs\specs\' +
            '2026-10-03-tenant-lifecycle-coordinate-only-simplification-design.md'
        )
        $correctionPath = Join-Path $script:repositoryRoot (
            'docs\plans\' +
            '2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md'
        )
        $planOnePath = Join-Path $script:repositoryRoot (
            'docs\plans\2026-10-02-tenant-lifecycle-core-implementation.md'
        )
        foreach ($path in @($specPath, $correctionPath, $planOnePath)) {
            $path | Should -Exist
        }

        $spec = Get-Content -Raw -LiteralPath $specPath
        $correction = Get-Content -Raw -LiteralPath $correctionPath
        $planOne = Get-Content -Raw -LiteralPath $planOnePath
        $spec | Should -Match (
            '(?m)^\|\s+\*\*Status\*\*\s+\|\s+Approved\s+\|\s*$'
        )
        $spec | Should -Match (
            'Plan 1.+Replace the mutation-capable umbrella contract.+exact ' +
            'coordinate-only signature and stage-result schema'
        )
        $correction | Should -Match (
            'Correct.+coordinate-only umbrella authority.+canonical child stage results'
        )
        $planOne | Should -Match (
            'This amendment is controlling.+Approved coordinate-only design'
        )
        $planOne | Should -Match (
            'Plan 1 is incomplete until every corrective task passes focused review'
        )
    }

    It 'publishes the exact coordinate-only documentation and child-owned operator sequence' {
        $paths = @(
            'infra/docs/runbooks/README.md',
            'infra/docs/runbooks/01-developer-workstation.md',
            'infra/docs/runbooks/03-customer-handover.md',
            'infra/docs/README.md',
            'infra/README.md'
        )
        $documents = @{}
        foreach ($relativePath in $paths) {
            $documents[$relativePath] = Get-Content `
                -Raw `
                -LiteralPath (Join-Path $script:repositoryRoot $relativePath)
            $documents[$relativePath] | Should -Match (
                'Plan 1 was implemented with local synthetic tests only; ' +
                'no live cloud, provider, or tenant operation was performed[.]'
            )
        }

        $index = $documents['infra/docs/runbooks/README.md']
        $index | Should -Match (
            '\[-Mode <Assess\|Plan\|Verify>\]'
        )
        $index | Should -Not -Match (
            '\[-Mode <Assess\|Plan\|Invoke>\]|' +
            'Invoke-TenantLifecycle[.]ps1[\s\S]{0,500}-Apply'
        )
        $sequence = @(
            'invoke the child directly in `Plan` mode',
            'record the exact child approval in child `approvals.json`',
            'invoke the child directly with `WhatIf`',
            'invoke the child directly with `Apply`',
            'complete child read-back',
            'write the immutable canonical stage result',
            'run umbrella `Verify`'
        )
        $lastPosition = -1
        foreach ($step in $sequence) {
            $position = $index.IndexOf(
                $step,
                [StringComparison]::Ordinal
            )
            $position | Should -BeGreaterThan $lastPosition
            $lastPosition = $position
        }
        $index | Should -Match (
            [regex]::Escape('<run>/stage-results/<stage>.json')
        )
        $index | Should -Match (
            'Umbrella `Verify` never invokes a child'
        )
        $index | Should -Match (
            'Child execution manifests and summaries are read-only ' +
            'umbrella `Verify` inputs[.]'
        )
        $index | Should -Match (
            'Child `approvals[.]json`, provider actions, WhatIf/Apply, ' +
            '`ShouldProcess`, state adoption, and provider read-back remain ' +
            'child-only and are neither umbrella authority nor umbrella output[.]'
        )
        $index | Should -Not -Match (
            'Those files are not umbrella inputs or outputs[.]'
        )
        $index | Should -Match (
            'literal `Passed`'
        )
        foreach ($nonClaim in @(
            'The umbrella did not execute a provider mutation.',
            'Provider approvals and read-back remain child-runbook evidence.',
            'This projection discloses no provider resource identity or raw provider response.'
        )) {
            $index | Should -Match ([regex]::Escape($nonClaim))
        }
        $index | Should -Match (
            'stage-only projection.+does not claim provider execution, ' +
            'provider approval, provider read-back, deployment, publication, ' +
            'or live tenant state'
        )

        foreach ($relativePath in @(
            'infra/docs/runbooks/01-developer-workstation.md',
            'infra/docs/runbooks/03-customer-handover.md'
        )) {
            $content = $documents[$relativePath]
            $content | Should -Match (
                'child `Plan` -> child `approvals[.]json` -> child ' +
                '`WhatIf` -> child `Apply` -> child read-back -> canonical ' +
                'stage result -> umbrella `Verify`'
            )
            $content | Should -Match (
                'Umbrella `Verify` never invokes'
            )
        }
    }

    It 'publishes the Approved child summary envelope and residual implementation gate' {
        $unmergedGate = (
            'Plan 1 and the child summary envelope implementation remain ' +
            'synthetic, `Draft`, and blocked until reviewed merge and ' +
            'then-current green `main`.'
        )
        $documentCases = @(
            @{
                Path = 'infra/docs/runbooks/README.md'
                Version = '1.9'
                Date = '2026-10-26'
                Gate = $unmergedGate
            }
            @{
                Path = 'infra/docs/runbooks/01-developer-workstation.md'
                Version = '1.5'
                Date = '2026-10-19'
                Gate = $unmergedGate
            }
            @{
                Path = 'infra/docs/runbooks/03-customer-handover.md'
                Version = '1.14'
                Date = '2026-10-26'
                Gate = @(
                    'Plan 1 and the child summary envelope implementation remain synthetic evidence.',
                    'The profile-contract slice does not change their approval status or establish live acceptance.'
                )
            }
            @{
                Path = 'infra/docs/README.md'
                Version = '1.4'
                Date = '2026-10-19'
                Gate = $unmergedGate
            }
            @{
                Path = 'infra/README.md'
                Version = '1.10'
                Date = '2026-10-19'
                Gate = $unmergedGate
            }
        )
        $requiredStatements = @(
            (
                'The shared child summary envelope reserves exactly ' +
                '`schemaVersion`, `runId`, `stage`, `sourceCommit`, ' +
                '`publicTenantKey`, `intentDigest`, `stateDigest`, ' +
                '`phaseManifestDigest`, `status`, `classification`, and ' +
                '`completedAtUtc`, and retains the five standard fields ' +
                '`startedAtUtc`, `counts`, `prerequisites`, `actions`, and ' +
                '`nonClaims`.'
            ),
            (
                'Provider-specific extras are root-only and opaque, are ' +
                'absent from projections and errors, and cannot enter the ' +
                'closed shared nested structures.'
            ),
            (
                'The manifest embedded `digest`, exact-file ' +
                '`phaseManifestDigest`, and exact-file ' +
                '`phaseSummaryDigest` are three distinct checks.'
            ),
            (
                'The child writes the summary before the stage result, and ' +
                'the summary has no self-digest.'
            ),
            (
                'Umbrella `Verify` and `Assess`/`Plan` prerequisite dispatch ' +
                'enforce the same envelope and embedded manifest digest.'
            ),
            (
                'Legacy evidence fails closed and requires a new run; there ' +
                'is no compatibility, inference, or repair path.'
            ),
            (
                'Umbrella authority remains exactly `Assess`, `Plan`, and ' +
                '`Verify`; `stage-results` remains authoritative and the ' +
                'second `Verify` pass remains required.'
            ),
            (
                'No live, provider, or tenant operation was performed, and ' +
                'no merge-readiness claim is made.'
            )
        )

        foreach ($documentCase in $documentCases) {
            $content = Get-Content `
                -Raw `
                -LiteralPath (
                    Join-Path $script:repositoryRoot $documentCase.Path
                )
            $content | Should -Match (
                '(?m)^\|\s+\*\*Version\*\*\s+\|\s+' +
                [regex]::Escape($documentCase.Version) +
                '\s+\|\s*$'
            )
            $content | Should -Match (
                '(?m)^\|\s+\*\*Date\*\*\s+\|\s+' +
                [regex]::Escape($documentCase.Date) +
                '\s+\|\s*$'
            )
            $content | Should -Match (
                'Approved Child Summary Envelope Design.+child-summary-' +
                'envelope-design[.]md'
            )
            $content | Should -Match (
                'Draft Child Summary Envelope Implementation Plan.+' +
                'child-summary-envelope-implementation[.]md'
            )
            foreach ($statement in $requiredStatements) {
                $content |
                    Should -Match ([regex]::Escape($statement)) -Because (
                        "$($documentCase.Path) publishes the full boundary"
                    )
            }
            foreach ($statement in @($documentCase.Gate)) {
                $content | Should -Match ([regex]::Escape($statement))
            }
            $content | Should -Not -Match (
                'summar(?:y|ies).{0,120}validated only by exact bytes and digest|' +
                'validates only their canonical coordinates and exact bytes/digests'
            )
        }
    }

    It 'preserves the Plan 1 corrective gate and keeps Plans 2-6 Draft and blocked' {
        $planPaths = @(
            'docs/plans/2026-10-02-tenant-lifecycle-core-implementation.md',
            'docs/plans/2026-10-02-developer-workstation-runbook-refactor-implementation.md',
            'docs/plans/2026-10-02-cloud-service-foundation-core-implementation.md',
            'docs/plans/2026-10-02-power-platform-dev-delivery-implementation.md',
            'docs/plans/2026-10-02-tenant-replica-handover-implementation.md',
            'docs/plans/2026-10-02-tenant-1-end-to-end-acceptance-implementation.md',
            'docs/plans/2026-10-03-tenant-lifecycle-coordinate-only-correction-implementation.md'
        )
        foreach ($relativePath in $planPaths) {
            $content = Get-Content `
                -Raw `
                -LiteralPath (Join-Path $script:repositoryRoot $relativePath)
            $content | Should -Match (
                '(?m)^\|\s+\*\*Status\*\*\s+\|\s+Draft\s+\|\s*$'
            )
        }

        $planOne = Get-Content -Raw -LiteralPath (
            Join-Path $script:repositoryRoot $planPaths[0]
        )
        $planOne | Should -Match (
            'This amendment is controlling.+Approved coordinate-only design'
        )
        $planOne | Should -Match (
            'Plan 1 is incomplete until every corrective task passes focused review'
        )
        $planOne | Should -Match (
            'Until the corrective plan is merged and then-current `main` is green, ' +
            'Plan 1 remains incomplete and blocked'
        )
        foreach ($relativePath in $planPaths[1..5]) {
            $content = Get-Content `
                -Raw `
                -LiteralPath (Join-Path $script:repositoryRoot $relativePath)
            $content | Should -Match (
                'coordinate-only correction.+merged.+then-current `main` is green'
            )
        }

        $correctivePlan = Get-Content -Raw -LiteralPath (
            Join-Path $script:repositoryRoot $planPaths[6]
        )
        $correctivePlan | Should -Match (
            '`feat/tenant-lifecycle-core` remains blocked and nonmergeable ' +
            'until the clean review is accepted'
        )
        $correctivePlan | Should -Match (
            'Plans 2-6 remain `Draft` and blocked until the corrective change ' +
            'is merged and then-current `main` is green'
        )
        foreach ($unquotedCommand in @(
            'git diff --check $MergeBase..HEAD',
            'git diff --exit-code $MergeBase..HEAD',
            'git diff --stat $MergeBase..HEAD'
        )) {
            $correctivePlan |
                Should -Not -Match ([regex]::Escape($unquotedCommand))
        }
        foreach ($quotedCommand in @(
            'git diff --check "$MergeBase..HEAD"',
            'git diff --exit-code "$MergeBase..HEAD" -- .github/workflows',
            'git diff --exit-code "$MergeBase..HEAD" -- `',
            'git diff --stat "$MergeBase..HEAD"',
            '`git diff --check "$MergeBase..HEAD"`'
        )) {
            $correctivePlan |
                Should -Match ([regex]::Escape($quotedCommand))
        }
    }

    It 'includes metadata-compliant infrastructure runbooks in the documentation set' {
        foreach ($relative in @(
            'README.md',
            'docs/README.md',
            'infra/docs/16-security-governance-and-compliance.md',
            'infra/docs/20-tenant-trust-activation-runbook.md',
            'infra/docs/21-azure-boards-population-runbook.md',
            'infra/docs/23-customer-repository-export-and-handover-runbook.md',
            'infra/docs/runbooks/README.md',
            'infra/docs/runbooks/01-developer-workstation.md',
            'infra/docs/runbooks/02-cloud-service-foundation.md',
            'infra/docs/runbooks/03-customer-handover.md',
            'infra/docs/24-tenant-1-lean-platform-runbook.md'
        )) {
            $path = Join-Path $script:repositoryRoot $relative
            $path | Should -Exist
            @(Test-DocumentationMetadataContent -Content (Get-Content -Raw $path) -DocumentRelativePath $relative).Count | Should -Be 0
        }

    }

    It 'publishes only a superseded cloud foundation stop notice' {
        $path = Join-Path $script:repositoryRoot 'infra\docs\runbooks\02-cloud-service-foundation.md'
        $path | Should -Exist
        $content = Get-Content -Raw -LiteralPath $path
        $content | Should -Match '(?m)^\|\s+\*\*Status\*\*\s+\|\s+Superseded\s+\|\s*$'
        $content | Should -Match 'STOP.+SUPERSEDED'
        $content | Should -Match 'Get-CloudFoundationPlan\.ps1.+Invoke-CloudFoundation\.ps1.+dormant and unsupported'
        $content | Should -Match 'new reviewed design and implementation plan'
        $content | Should -Not -Match '(?m)^```powershell'

        $index = Get-Content -Raw -LiteralPath (Join-Path $script:repositoryRoot 'infra\docs\runbooks\README.md')
        $index | Should -Match 'Cloud Service Foundation Runbook.+Superseded stop notice.+\|\s+Superseded\s+\|'
    }

    It 'documents local attended authentication and rejects workload execution' {
        $index = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\docs\runbooks\README.md')
        $workstation = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\docs\runbooks\01-developer-workstation.md')
        $content = $index + "`n" + $workstation
        $content | Should -Match ([regex]::Escape('az login --tenant $tenantId --use-device-code'))
        $content | Should -Match ([regex]::Escape('gh auth login --hostname github.com --git-protocol https --web'))
        $content | Should -Match ([regex]::Escape('az devops project show'))
        $content | Should -Match ([regex]::Escape('pac auth create --deviceCode'))
        $content | Should -Match 'MFA'
        $content | Should -Match 'Conditional Access'
        $content | Should -Match 'GitHub Actions.+prohibited'
        $content | Should -Match 'OIDC workload identit.+prohibited'
        $content | Should -Match 'token.+never'
    }

    It 'links the infrastructure map to both runbook documents' {
        $readme = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\README.md')

        $readme | Should -Match '\[Operational Runbooks\]\(docs/runbooks/README\.md\)'
        $readme | Should -Match '\[Developer Workstation\]\(docs/runbooks/01-developer-workstation\.md\)'
        $readme | Should -Match '\[Customer Repository Handover\]\(docs/runbooks/03-customer-handover\.md\)'
    }

    It 'documents the complete Tenant 1 lean operator sequence' {
        $path = Join-Path $script:repositoryRoot 'infra\docs\24-tenant-1-lean-platform-runbook.md'
        $path | Should -Exist
        $content = Get-Content -Raw -LiteralPath $path
        foreach ($heading in @(
            'Private Configuration and Backup',
            'Attended Context and Minimum Access',
            'Local Discovery',
            'Sanitized Review',
            'Bicep Build',
            'Subscription What-If',
            'Boundary and Access Read-Back',
            'GitHub Governance',
            'Basic Boards',
            'Empty Azure Repo Checkpoint',
            'Final Governed Transaction',
            'Failure and Recovery',
            'Acceptance'
        )) {
            $content | Should -Match ("(?m)^## {0}\r?$" -f [regex]::Escape($heading))
        }
    }

    It 'records committed Tenant 1 deletion and requires external restore proof' {
        $currentBoundaryPaths = @(
            'infra/README.md',
            'infra/docs/10-tenant-setup-and-configuration.md',
            'infra/docs/14-github-repository-blueprint.md',
            'infra/docs/18-multi-tenant-provisioning.md',
            'infra/docs/19-bootstrap-recovery.md',
            'infra/docs/24-tenant-1-lean-platform-runbook.md'
        )
        foreach ($relativePath in $currentBoundaryPaths) {
            $content = Get-Content -Raw -LiteralPath (Join-Path $script:repositoryRoot $relativePath)
            $content | Should -Not -Match 'tracked Tenant 1 (?:transition )?files remain|deletion approval was unavailable|tracked Tenant 1 transition-file deletion remains'
        }

        $runbook = Get-Content -Raw -LiteralPath (
            Join-Path $script:repositoryRoot 'infra\docs\24-tenant-1-lean-platform-runbook.md'
        )
        $runbook | Should -Match 'approved committed deletion'
        $runbook | Should -Match 'Read-Host.+encrypted external backup'
        $runbook | Should -Match 'separate failure domain'
        $runbook | Should -Match 'Get-FileHash.+SHA256'
        $runbook | Should -Match '\$RestoreRoot'
        $runbook | Should -Match 'Import-TenantConfiguration'
        $runbook | Should -Match 'RequireLocalUntracked'
        $runbook | Should -Match 'git check-ignore'
        $runbook | Should -Not -Match '\$BackupRoot\s*=\s*Join-Path\s+\$OperatorRoot\s+''backup'''
    }

    It 'documents the irreversible checkpoint order without claiming execution' {
        $path = Join-Path $script:repositoryRoot 'infra\docs\24-tenant-1-lean-platform-runbook.md'
        $content = Get-Content -Raw -LiteralPath $path
        $headings = @(
            'Merge Tool Changes',
            'Current-Main Validator',
            'Local Validation and Access Read-Back',
            'GitHub Governance',
            'Basic Boards Issue',
            'Empty Azure Repo Checkpoint',
            'Final Governed Transaction',
            'Acceptance Read-Back'
        )
        $positions = @($headings | ForEach-Object { $content.IndexOf("## $_", [StringComparison]::Ordinal) })
        @($positions | Where-Object { $_ -lt 0 }).Count | Should -Be 0
        for ($index = 1; $index -lt $positions.Count; $index++) {
            $positions[$index] | Should -BeGreaterThan $positions[$index - 1]
        }
        $content | Should -Match 'Do not apply.+governance.+before.+tool.+main'
        $content | Should -Match 'Not Run'
    }

    It 'keeps all 14 Draft acceptance controls at Not Run without current read-back' {
        $reviewPath = Join-Path $script:repositoryRoot 'docs\reviews\2026-09-28-tenant-1-lean-engineering-platform-acceptance-review.md'
        $review = Get-Content -Raw -LiteralPath $reviewPath
        $review | Should -Match '(?m)^\|\s+\*\*Status\*\*\s+\|\s+Draft\s+\|\s*$'

        $acceptanceSection = [regex]::Match(
            $review,
            '(?ms)^## Acceptance Controls\r?\n(?<Table>.*?)(?=^## )'
        )
        $acceptanceSection.Success | Should -BeTrue
        $controlRows = @(
            $acceptanceSection.Groups['Table'].Value -split '\r?\n' |
                Where-Object {
                    $_ -match '^\|' -and
                    $_ -notmatch '^\|\s*Control\s*\|' -and
                    $_ -notmatch '^\|\s*---'
                }
        )
        $controlRows.Count | Should -Be 14
        foreach ($row in $controlRows) {
            $cells = @($row.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
            $cells.Count | Should -Be 6 -Because $row
            $cells[4] | Should -BeExactly 'Not Run' -Because $cells[0]
        }

        $reviewIndex = Get-Content -Raw -LiteralPath (Join-Path $script:repositoryRoot 'docs\reviews\README.md')
        $documentationIndex = Get-Content -Raw -LiteralPath (Join-Path $script:repositoryRoot 'docs\README.md')
        $reviewIndex | Should -Match 'Tenant 1 Lean Engineering Platform Acceptance Review.+\|\s+Draft\s+\|'
        $documentationIndex |
            Should -Match 'Tenant 1 Lean Engineering Platform Acceptance Review.+Draft.+every outcome remains `Not Run`'
    }

    It 'labels dormant trust OIDC and role-cleanup paths as unsupported' {
        $repositoryReadme = Get-Content -Raw (Join-Path $script:repositoryRoot 'README.md')
        $documentationIndex = Get-Content -Raw (Join-Path $script:repositoryRoot 'docs\README.md')
        $security = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\docs\16-security-governance-and-compliance.md')
        $boards = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\docs\21-azure-boards-population-runbook.md')
        $handover = Get-Content -Raw (Join-Path $script:repositoryRoot 'infra\docs\23-customer-repository-export-and-handover-runbook.md')

        $repositoryReadme | Should -Match 'Initialize-TenantTrust\.ps1` \| Dormant and unsupported'
        $repositoryReadme | Should -Match 'Invoke-TenantBootstrap\.ps1` \| Attended local orchestration.+no role mutation'
        $documentationIndex | Should -Match 'Tenant Trust Activation Runbook.+Superseded stop notice'
        $documentationIndex | Should -Match 'Bootstrap and Provisioning.+attended local.+minimum-access'

        $boards | Should -Match '\|\s+\*\*Status\*\*\s+\|\s+Superseded\s+\|'
        $boards | Should -Match 'STOP.+dormant.+not a lean-platform prerequisite'
        $boards | Should -Not -Match 'assumes Tenant 1''s trust is already active|already-active OIDC session|must already be complete before this runbook can authenticate'

        $handover | Should -Match 'delivery identity or trust activation.+Deferred.+new reviewed design'
        $handover | Should -Not -Match 'Activating your tenant''s trust.+Tenant Trust Activation Runbook'

        $security | Should -Match 'attended local user context'
        $security | Should -Match 'pre-existing, separately approved exact least-privilege custom validation role'
        $security | Should -Match 'no role mutation'
        $security | Should -Match 'no bootstrap OIDC or GitHub Environment dependency'
        $security | Should -Match 'attended principal, tenant, subscription, and exact approved validation-role access read-back'

        foreach ($relative in @(
            'README.md',
            'docs/README.md',
            'infra/docs/11-identity-and-access.md',
            'infra/docs/16-security-governance-and-compliance.md',
            'infra/docs/17-bootstrap-and-provisioning.md',
            'infra/docs/19-bootstrap-recovery.md',
            'infra/docs/20-tenant-trust-activation-runbook.md',
            'infra/docs/21-azure-boards-population-runbook.md',
            'infra/docs/23-customer-repository-export-and-handover-runbook.md',
            'infra/docs/24-tenant-1-lean-platform-runbook.md',
            'infra/docs/runbooks/README.md',
            'infra/docs/runbooks/01-developer-workstation.md',
            'infra/docs/runbooks/02-cloud-service-foundation.md',
            'infra/docs/runbooks/03-customer-handover.md'
        )) {
            $content = Get-Content -Raw (Join-Path $script:repositoryRoot $relative)
            @(Get-ProhibitedActiveBootstrapClaims -Content $content).Count |
                Should -Be 0 -Because "$relative must not require bootstrap OIDC, Environments, or temporary roles"
        }
    }

    It 'rejects active bootstrap claims despite a same-line <Marker> qualifier' -ForEach @(
        @{
            Marker = 'unsupported'
            Claim = 'OIDC is required; the previous flow is unsupported.'
        }
        @{
            Marker = 'historical'
            Claim = 'The GitHub bootstrap Environment is required; this is historical wording.'
        }
        @{
            Marker = 'previous'
            Claim = 'Temporary subscription roles are granted and deleted; this was the previous flow.'
        }
        @{
            Marker = 'deferred'
            Claim = 'Temporary-role cleanup is required; later redesign is deferred.'
        }
    ) {
        param($Marker, $Claim)

        $fixture = @"
# Active fixture

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-29 |
| **Author** | test |
| **Status** | Active |
| **Scope** | Test |
| **References** | None |

$Claim
"@
        @(Get-ProhibitedActiveBootstrapClaims -Content $fixture).Count | Should -BeGreaterThan 0
    }

    It 'excludes prohibited historical claims only when document status is Superseded' {
        $fixture = @'
# Superseded fixture

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-29 |
| **Author** | test |
| **Status** | Superseded |
| **Scope** | Test |
| **References** | None |

OIDC is required.
Temporary subscription roles are granted and deleted.
'@
        @(Get-ProhibitedActiveBootstrapClaims -Content $fixture).Count | Should -Be 0
    }

    It 'resolves every local markdown destination referenced by the runbook documents' {
        foreach ($relative in @(
            'README.md',
            'docs/README.md',
            'infra/docs/16-security-governance-and-compliance.md',
            'infra/docs/20-tenant-trust-activation-runbook.md',
            'infra/docs/21-azure-boards-population-runbook.md',
            'infra/docs/23-customer-repository-export-and-handover-runbook.md',
            'infra/docs/runbooks/README.md',
            'infra/docs/runbooks/01-developer-workstation.md',
            'infra/docs/runbooks/02-cloud-service-foundation.md',
            'infra/docs/runbooks/03-customer-handover.md',
            'infra/docs/24-tenant-1-lean-platform-runbook.md'
        )) {
            $path = Join-Path $script:repositoryRoot $relative
            foreach ($link in @(Get-MarkdownRelativeLinks -Path $path)) {
                $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $path) $link.PathPart.Replace('/', '\')))
                Test-Path -LiteralPath $resolved | Should -BeTrue -Because "$relative links to $($link.Target)"
            }
        }
    }
}
