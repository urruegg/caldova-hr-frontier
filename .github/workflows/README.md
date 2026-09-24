# Workflows

| Field | Value |
|---|---|
| **Version** | 1.3 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |


This folder contains GitHub Actions workflow definitions for continuous integration and repository automation.

Use descriptive YAML file names, grant least-privilege permissions, pin third-party actions to reviewed versions, and document required secrets without committing their values.

## Repository Validation

[validate-repository.yml](validate-repository.yml) runs for pull requests, pushes to `main`, and manual `workflow_dispatch` requests. Its `validate` job uses `windows-2025` with a 15-minute timeout.

The workflow grants only global `contents: read`. It requests no write or identity-token permission, consumes no secrets, and pins actions/checkout v7.0.1 to commit `3d3c42e5aac5ba805825da76410c181273ba90b1`. Pester is installed at exact version 5.7.1.

The job performs these checks in order:

1. Checks out the complete Git history with `fetch-depth: 0`.
2. Runs the workflow and safety contracts plus every infrastructure Pester test.
3. Scans the real checkout for prohibited deployment commands and credential-based bootstrap patterns.
4. Builds the Bicep entry point without deploying resources.
5. Runs `git diff --check origin/main...HEAD` to reject branch whitespace errors.

## Repository Baseline Audit

[audit-repository.yml](audit-repository.yml) runs for the same pull request, `main`, and manual events. It validates the comprehensive repository baseline and the seven documentation, source-inventory, and intake contract files without repeating the required Pester paths or Bicep build.

The `Repository baseline audit (advisory)` check remains visibly red when drift is found, but it is not a required status in the reviewed `main` ruleset. A pull request may proceed only when a reviewer records acceptance and rationale for any advisory failure in the pull request completion contract.

## Tenant Discovery

[discover-tenant.yml](discover-tenant.yml) is a manual, Tenant 1-only discovery workflow. Its required `tenantAlias` choice currently contains only `caldova25156897`. The job binds to `bootstrap-${{ inputs.tenantAlias }}`, serializes work with the same tenant-specific concurrency key, and runs on `windows-2025`.

The selected GitHub Environment must provide non-secret variables named `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`. The workflow grants only `contents: read` and `id-token: write`, cross-checks those values against the reviewed tenant manifest, and authenticates to Azure through OIDC. It does not accept a client secret or personal access token.

Before discovery, the workflow runs the pinned Power Platform `who-am-i` action against the DEV, TEST, and PROD URLs loaded from the manifest. It records only stage, URL, success status, UTC timestamp, and reviewed action revision in the temporary probe file. Discovery writes normalized evidence under the runner temporary directory, validates it with pinned Pester 5.7.1, and uploads only `discovery.json` as the seven-day `redacted-tenant-discovery-*` artifact. It does not write evidence into the checkout, commit changes, push a branch, or create a pull request.

## Tenant Bootstrap Validation

[bootstrap-tenant.yml](bootstrap-tenant.yml) is a manual, Tenant 1-only validation workflow. It requires the same `tenantAlias` choice and a required `confirmRoleCleanup` boolean whose default is `false`. The first step fails a false confirmation before checkout or authentication. The workflow uses the same Environment, variables, OIDC permissions, Windows runner, and one-tenant concurrency boundary as discovery.

Before authentication, an operator must review and commit both of these tenant-specific inputs:

- `infra/evidence/discovery/<tenantAlias>.json`
- `infra/src/bicep/params/<tenantAlias>.bicepparam`

The workflow rejects absent or untracked inputs. After OIDC login, it discovers exactly one Contributor assignment and one Role Based Access Control Administrator assignment for the reviewed principal and subscription. Their exact IDs, run ID, principal ID, and scope form one closed cleanup tuple.

`Invoke-TenantBootstrap.ps1` validates the committed evidence, intent, OIDC context, Bicep inputs, and role state; builds Bicep; runs subscription `what-if`; validates the result boundary; and performs cleanup in `finally`. No deployment-create command is permitted. A separate `if: always()` step retries the exported cleanup function idempotently with the same run, principal, scope, and two exact assignment IDs. Cleanup never selects assignments by role name alone and never broadens deletion beyond those reviewed IDs.
