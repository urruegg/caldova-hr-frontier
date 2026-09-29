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

    It 'documents the attended cloud service foundation operating contract' {
        $path = Join-Path $script:repositoryRoot 'infra\docs\runbooks\02-cloud-service-foundation.md'
        $path | Should -Exist
        $content = Get-Content -Raw -LiteralPath $path
        foreach ($heading in @(
            'Purpose and Status','Operator, Scope, and Preconditions','Attended Authentication',
            'Permission Matrix','Assessment and Plan','Approval and Apply',
            'Manual and Blocking Actions','Evidence','Recovery','Cleanup and Sign-out',
            'Definition of Done'
        )) {
            $content | Should -Match ("(?m)^## {0}\r?$" -f [regex]::Escape($heading))
        }
        foreach ($literal in @(
            'Get-CloudFoundationPlan.ps1','Invoke-CloudFoundation.ps1',
            'hr-<TenantAlias>-<stage>','-Apply','-WhatIf','ShouldProcess',
            'az login --tenant <tenantId> --use-device-code',
            'gh auth login --hostname github.com --web --clipboard',
            'pac auth create --name <profile> --environment <url> --deviceCode',
            "Status = 'Planned'","ShouldProcessDecision = 'NotApplicable'",
            'PartialMutation','IncompleteManualActions','BlockedOperation','RunDirectory',
            'az bicep format --file <absoluteSource> --stdout',
            'service,targetId,condition,owner,diagnostic,recovery'
        )) {
            $content | Should -Match ([regex]::Escape($literal))
        }
        foreach ($url in @(
            'https://docs.github.com/en/rest/repos/repos#update-a-repository',
            'https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset',
            'https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset',
            'https://learn.microsoft.com/en-us/cli/azure/deployment/sub#az-deployment-sub-create',
            'https://learn.microsoft.com/en-us/cli/azure/ad/app',
            'https://learn.microsoft.com/en-us/cli/azure/ad/sp',
            'https://learn.microsoft.com/en-us/cli/azure/devops/project'
        )) {
            $content | Should -Match ([regex]::Escape($url))
        }
        $content | Should -Match '\]\(\.\./19-bootstrap-recovery\.md\)'
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
