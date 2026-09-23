# Bootstrap Recovery

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Bootstrap and Provisioning](./17-bootstrap-and-provisioning.md) |

This Proposed Baseline defines attended recovery for future tenant bootstrap operations. It does not prove that any tenant, trust, identity, role, resource, Environment, or service currently exists. Recovery resumes from the last proven state, preserves approval gates, and never introduces broad permissions, stored credentials, or an Azure deployment.

## Trust creation

- **Last trusted state:** Reviewed tenant manifest and current five-service discovery evidence; no trust object is assumed to exist.
- **Required operator role:** Attended tenant Application Administrator or Cloud Application Administrator plus verified GitHub repository administrator.
- **Read-only diagnostics:** Query applications by reviewed object ID or exact display name, related service principals, federated credentials, GitHub Environments, and non-secret Environment variable names. Classify zero, one, or multiple matches explicitly.
- **Repair action:** Stop on ambiguity. After explicit approval, create or correct only the reviewed single-tenant app, related service principal, exact federated credential, tenant Environment, and three non-secret variables. Never add a password, certificate credential, or broader permission as a workaround.
- **Revalidation command/check:** Read back sign-in audience, app/service-principal relationship, empty credential collections, issuer, audience, subject, Environment name, branch restriction, reviewer, and variable names.
- **Escalation boundary:** Escalate when stable IDs conflict, duplicate candidates exist, required consent is unavailable, or the repair would exceed reviewed trust scope.

## OIDC mismatch

- **Last trusted state:** Trust objects were read back successfully, but OIDC has not authenticated to the reviewed context.
- **Required operator role:** Attended tenant application administrator and GitHub repository administrator; subscription reader for context verification.
- **Read-only diagnostics:** Compare tokenless workflow configuration, Environment name, federated issuer, audience, case-sensitive subject, client ID, tenant ID, subscription ID, and authenticated-context error metadata without printing a token.
- **Repair action:** Correct the reviewed manifest, Environment binding, non-secret variable, or federated credential only after approval. Do not add a client secret, private key, repository-wide subject, or wildcard trust.
- **Revalidation command/check:** Run the approved Environment-bound OIDC validation and confirm client, tenant, subscription, repository, and exact subject all match.
- **Escalation boundary:** Escalate if the platform emits a different subject format, repository identity changed, or exact binding cannot be proven without weakening trust.

## Service discovery authorization

- **Last trusted state:** Manifest validation and any successfully collected read-only service results from the same run.
- **Required operator role:** Service-specific administrator able to review minimum read permissions; no standing broad administrator role is assumed.
- **Read-only diagnostics:** Record which of GitHub, Entra, Azure, Azure DevOps, or Power Platform returned `Unauthorized`, the requested allowlisted scope, API, principal ID, and status code without raw response bodies or credentials.
- **Repair action:** After explicit approval, grant only the documented minimum read permission or correct the selected principal. Re-run the whole discovery to produce one run ID. Never substitute a secret or query business data.
- **Revalidation command/check:** Validate that all five service results share one run ID and return acceptable current outcomes with stable IDs and evidence hashes.
- **Escalation boundary:** Escalate when app-only access is unsupported, minimum read permission is unknown, admin consent is unavailable, or only a broad role would succeed.

## Stale evidence

- **Last trusted state:** Previously normalized evidence remains historical but no longer authorizes change.
- **Required operator role:** Attended discovery operator or approved OIDC workflow reviewer with read access to all five services.
- **Read-only diagnostics:** Check collection start time, completion time, run ID consistency, source API versions, manifest commit, and service statuses.
- **Repair action:** Collect a new complete read-only discovery run and review its normalized diff. Do not alter timestamps, mix service results from different runs, or reuse evidence older than 24 hours for bootstrap.
- **Revalidation command/check:** Confirm the new evidence passes schema, prohibited-data, age, run-ID, and service-completeness gates.
- **Escalation boundary:** Escalate if a required service cannot be queried in the evidence window or observed stable IDs differ from reviewed intent.

## Ambiguous object

- **Last trusted state:** Current discovery identified more than one candidate and made no intent decision.
- **Required operator role:** Service owner able to identify authoritative stable IDs; a deletion-capable role is not required for diagnosis.
- **Read-only diagnostics:** Compare candidate stable IDs, names, scopes, URLs, ownership, and creation metadata using allowlisted reads. Preserve ambiguity in evidence.
- **Repair action:** Stop automation. Resolve ownership through attended review, then update the manifest with one reviewed stable ID or separately approve exact-object cleanup. Never choose the first match or create another duplicate.
- **Revalidation command/check:** Re-run discovery and require exactly one candidate matching the reviewed `Existing` ID, or no conflict for reviewed `Create` intent.
- **Escalation boundary:** Escalate when ownership cannot be proven or remediation would delete, rename, transfer, or broaden access to a live object.

## Bicep build

- **Last trusted state:** Manifest, evidence, and reviewed intent passed; no `what-if` result is trusted.
- **Required operator role:** Repository contributor for source repair; no cloud role is required for local format and build.
- **Read-only diagnostics:** Run Bicep format/build diagnostics, inspect API schemas, parameter derivation, allowed resource types, and target scope. Do not suppress compiler diagnostics.
- **Repair action:** Correct the typed Bicep or generated non-secret parameters through review. Do not remove validation, expand the resource allowlist, or replace build with a deployment command.
- **Revalidation command/check:** Require clean format and successful `az bicep build --file infra/src/bicep/main.bicep --stdout`, then rerun repository tests.
- **Escalation boundary:** Escalate when the required design is unsupported by the selected stable API or correcting it changes approved resource scope.

## Out-of-boundary what-if

- **Last trusted state:** Bicep built successfully, but the machine-readable `what-if` is rejected and authorizes no deployment.
- **Required operator role:** Subscription reader for diagnostics and repository contributor for reviewed source correction.
- **Read-only diagnostics:** Identify every unexpected type, scope, resource group, location, delete, ignored diagnostic, and error in the `what-if` result.
- **Repair action:** Correct manifest, parameters, or Bicep so the result contains only approved resources. Do not ignore changes, expand the allowlist, or execute a deployment.
- **Revalidation command/check:** Re-run subscription `what-if` and the boundary validator; require zero offending changes and no delete.
- **Escalation boundary:** Escalate when observed Azure state requires a design change, an approved resource would be replaced or deleted, or validation cannot explain the result.

## Role cleanup

- **Last trusted state:** Exact temporary assignment IDs, expected principal, roles, and subscription scope were recorded; cleanup completion is not trusted.
- **Required operator role:** Attended role administrator authorized to remove the two exact assignments, with explicit deletion approval for this attempt.
- **Read-only diagnostics:** Read each assignment by exact ID and compare principal, role definition, scope, and current presence. Do not enumerate unrelated assignments as cleanup targets.
- **Repair action:** After explicit approval, remove Contributor first and Role Based Access Control Administrator last by exact ID; treat an already absent exact ID as success. Never delete by role name, principal-wide filter, or guessed ID.
- **Revalidation command/check:** Poll read-only authorization state with a bounded retry until both exact assignment IDs are absent.
- **Escalation boundary:** Escalate when an assignment differs from the recorded principal/role/scope, deletion approval is withheld, removal fails, or absence cannot be verified.

## GitHub read-back

- **Last trusted state:** A reviewed GitHub mutation was attempted, but applied state has not been proven.
- **Required operator role:** GitHub repository administrator with read access to rulesets, Environments, variables, and workflow results.
- **Read-only diagnostics:** Query the exact ruleset and tenant Environment; compare enforcement, target branch, pull-request rules, status checks, bypass actor, reviewer, self-review, branch restriction, and non-secret variable names.
- **Repair action:** Stop dependent work. After explicit approval, correct only fields in reviewed desired state; do not disable protection, add a direct-push bypass, expose secret values, or accept partial state.
- **Revalidation command/check:** Repeat API read-back and require every reviewed property to match plus a successful validator run on `main`.
- **Escalation boundary:** Escalate on duplicate rulesets, inaccessible settings, unexpected bypass actors, missing required checks, or any repair that weakens approved governance.
