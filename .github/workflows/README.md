# Workflows

| Field | Value |
|---|---|
| **Version** | 2.2 |
| **Date** | 2026-10-22 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (implementation branch; PR evidence pending) |
| **Scope** | Repository |
| **References** | [Parallel Repository Validation Design](../../docs/specs/2026-10-22-parallel-repository-validation-design.md); [Parallel Repository Validation Implementation Plan](../../docs/plans/2026-10-22-parallel-repository-validation-implementation.md); [Action Pins](../../infra/src/config/github/action-pins.json) |

This folder contains the repository's single GitHub Actions validation workflow.
The behavior below is delivered by the implementation branch and remains
subject to pull-request evidence and review. It is not a claim that the
workflow is merged, live on `main`, or configured as a required check.

Use descriptive YAML file names, grant least-privilege permissions, pin
external actions to reviewed full commit SHAs, and never commit secret values.

## Repository Validation

[validate-repository.yml](validate-repository.yml) retains the workflow name
`Validate repository` and runs for pull requests, pushes to `main`, and manual
`workflow_dispatch` requests. It has no path filters. Four validation domains
run independently, followed by one stable result gate:

| Job ID | Display name | Responsibility | Timeout |
|---|---|---|---:|
| `repository` | `Repository/documentation validation` | Repository Pester, repository safety, and merge-base whitespace validation | 30 minutes |
| `infrastructure` | `Infrastructure validation` | Non-lifecycle infrastructure Pester and recursive local Bicep compilation | 30 minutes |
| `hr` | `HR solution validation` | HR Pester | 30 minutes |
| `lifecycle` | `Lifecycle/runbook validation` | The exact lifecycle allowlist, split into smoke and remainder | 45 minutes |
| `validate` | `Repository setup validation` | Pure result gate over the four domain results | 15 minutes |

All jobs use `windows-2025`. The four domain jobs check out complete history
with the reviewed full-SHA `actions/checkout` pin from
[action-pins.json](../../infra/src/config/github/action-pins.json). Every
workflow `run` step declares `shell: powershell`, preserving Windows
PowerShell 5.1 as the workflow shell.

## Recursive Ownership and Requirements

`Get-MaintainedTestGroups.ps1` recursively discovers every maintained
`*.Tests.ps1` file under `.github/cli/tests/`, `infra/tests/pester/`, and
`hr/tests/pester/`. It proves that the four groups are nonempty, pairwise
disjoint, case-correct, duplicate-free, and a complete union before returning
one group's repository-relative paths in ordinal order.

Ownership is exact:

- Repository owns all recursively discovered `.github/cli/tests/` tests.
- Infrastructure owns all recursively discovered `infra/tests/pester/` tests
  except the lifecycle allowlist, plus recursive local Bicep compilation.
- HR owns all recursively discovered `hr/tests/pester/` tests and installs
  only `hr/tests/requirements.txt`.
- Lifecycle owns only
  `TenantLifecycleContracts.Tests.ps1`,
  `TenantLifecycleOrchestration.Tests.ps1`,
  `RunbookContracts.Tests.ps1`,
  `RunbookStaticSafety.Tests.ps1`, and
  `RunbookDocumentation.Tests.ps1`, and installs only
  `infra/tests/requirements.txt`.

Every domain installs and verifies exact Pester 5.7.1. HR and Lifecycle keep
their Python requirement files independent; Repository and Infrastructure do
not install either file.

## Lifecycle Smoke and Remainder

The Lifecycle job runs the exact five-file boundary twice in sequence:

1. include `CICompatibilitySmoke`; then
2. exclude `CICompatibilitySmoke`.

Contract discovery proves that smoke and remainder are both nonempty,
disjoint, and together equal every discovered lifecycle case. The split
therefore orders high-risk compatibility evidence without duplicate
execution.

## Raw NUnit Evidence

Each domain attempts its official full-SHA-pinned `actions/upload-artifact`
step with `if: always()`, warns when its result directory is absent, and keeps
raw NUnit XML for 14 days:

| Job | Artifact | Result directory |
|---|---|---|
| Repository | `repository-validation-test-results` | `test-results/repository/` |
| Infrastructure | `infrastructure-validation-test-results` | `test-results/infrastructure/` |
| HR | `hr-validation-test-results` | `test-results/hr/` |
| Lifecycle | `lifecycle-validation-test-results` | `test-results/lifecycle/` |

The artifacts do not publish checks and require no `checks: write`
permission.

## Concurrency and Stable Result

The workflow cancels an older run for the same pull request number or branch
reference:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

The final `validate` job has `if: always()` and succeeds only when
`repository`, `infrastructure`, `hr`, and `lifecycle` all report `success`.
It performs no checkout, setup, validation, artifact, cache, or provider work.
Its display name remains `Repository setup validation` to preserve the
intended stable check identity. The external branch-protection configuration
must be observed and compared with that identity; it cannot be inferred from
this file or changed by this workflow. Pull-request topology, timing,
artifact, and branch-protection evidence is pending controller review and
push.

## Authority Boundary

Global workflow permissions are exactly `contents: read`. There is no
check-publishing, secret, identity-token, environment, cache, deployment,
provider, or tenant authority. The workflow performs no deployment, Azure
authentication, provider call, application change, runbook operation, or live
mutation. Bicep validation is recursive local compilation only.
