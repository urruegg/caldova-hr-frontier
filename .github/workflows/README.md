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

The workflow grants only global `contents: read`. It requests no write or identity-token permission, consumes no secrets, and pins checkout to commit `11bd71901bbe5b1630ceea73d27597364c9af683`. Pester is installed at exact version 5.7.1.

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

[discover-tenant.yml](discover-tenant.yml) remains a manual Tenant 1 workflow while Tenant 2 completes its first attended local discovery. The Tenant 2 manifest and discovery adapter are repository-ready, but `caldova25668747` is intentionally excluded from the workflow choice until reviewed baseline evidence is committed. The job binds to `bootstrap-${{ inputs.tenantAlias }}`, serializes work with the same tenant-specific concurrency key, and runs on `windows-2025`.

The selected GitHub Environment must provide non-secret variables named `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID`. The workflow grants only `contents: read` and `id-token: write`, cross-checks those values against the reviewed tenant manifest, and authenticates to Azure through OIDC. It does not accept a client secret or personal access token.

Before discovery, the workflow runs the pinned Power Platform `who-am-i` action against the DEV, TEST, and PROD URLs loaded from the manifest. It records only stage, URL, success status, UTC timestamp, and reviewed action revision in the temporary probe file. When a manifest declares SharePoint sites, the discovery script queries only each reviewed site collection's Microsoft Graph metadata and records its stable ID, name, URL, status, and response hash; it never reads lists, files, pages, or HR content. The tenant-specific bootstrap application therefore needs read access to exactly those sites before a later Tenant 2 workflow validation is enabled.

Discovery writes normalized evidence under the runner temporary directory, validates it with pinned Pester 5.7.1, and uploads only `discovery.json` as the seven-day `redacted-tenant-discovery-*` artifact. It does not write evidence into the checkout, commit changes, push a branch, or create a pull request.

## Tenant Bootstrap Validation

[bootstrap-tenant.yml](bootstrap-tenant.yml) remains a manual, Tenant 1-only validation workflow. Tenant 2 is intentionally excluded until its attended discovery artifact, stable identifiers, explicit component intent, and Bicep parameter file are reviewed and committed. The workflow requires a `confirmRoleCleanup` boolean whose default is `false`; the first step fails a false confirmation before checkout or authentication. It uses the same Environment, variables, OIDC permissions, Windows runner, and one-tenant concurrency boundary as discovery.

Before authentication, an operator must review and commit both of these tenant-specific inputs:

- `infra/evidence/discovery/<tenantAlias>.json`
- `infra/src/bicep/params/<tenantAlias>.bicepparam`

The workflow rejects absent or untracked inputs. After OIDC login, it discovers exactly one Contributor assignment and one Role Based Access Control Administrator assignment for the reviewed principal and subscription. Their exact IDs, run ID, principal ID, and scope form one closed cleanup tuple.

`Invoke-TenantBootstrap.ps1` validates the committed evidence, intent, OIDC context, Bicep inputs, and role state; builds Bicep; runs subscription `what-if`; validates the result boundary; and performs cleanup in `finally`. No deployment-create command is permitted. A separate `if: always()` step retries the exported cleanup function idempotently with the same run, principal, scope, and two exact assignment IDs. Cleanup never selects assignments by role name alone and never broadens deletion beyond those reviewed IDs.
