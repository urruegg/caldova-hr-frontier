# Tenant Replica and Customer Handover Runbook Design

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Local repository export profiles for tenant replication and customer handover |
| **References** | [Tenant 1 Runbook End-to-End Design](2026-10-02-tenant-1-runbook-end-to-end-design.md), [Tenant Replica and Handover Implementation Plan](../plans/2026-10-02-tenant-replica-handover-implementation.md), [Current Customer Handover Runbook](../../infra/docs/runbooks/03-customer-handover.md), [Customer Repository Export and Handover Design](2026-09-27-customer-repository-export-and-handover-design.md), [ADR-0012](../adr/0012-per-tenant-github-repository-and-account-topology.md), [Multi-Tenant Provisioning](../../infra/docs/18-multi-tenant-provisioning.md) |

## 1. Status and Execution Gate

The user approved this repository-handover subsystem of the [Tenant 1 end-to-end lifecycle](2026-10-02-tenant-1-runbook-end-to-end-design.md) on 2026-10-02 as implementation-planning authority for its stated local scope. Approval does not mark an existing handover design or plan Superseded and authorizes no export execution, repository creation, publication, push, transfer, Tenant 2 operation, document move, or tenant mutation.

## 2. Problem and Proposed Outcome

The existing local customer-export and independent-validation engine is substantial and tested. It creates a history-free staged tree from exact committed blobs, applies reviewed replacements, validates independently, and has no publication side effect. It does not distinguish a reusable engineering replica from a stricter customer-facing handover package.

The proposed runbook introduces two explicit manifest profiles over one shared engine:

- **`TenantReplica`** retains reusable product source, GitHub repository validation, Azure Pipeline definitions and templates, tests, and runbooks while excluding tenant-private intent, state, stable identifiers, transition payloads, and evidence.
- **`CustomerHandover`** preserves the current stricter sanitized export, exact reviewed replacement, residual-disposition, and no-publication boundary.

The current Tenant 1 sprint executes only a local `TenantReplica` export and independent validation. It does not publish the tree or perform a Tenant 2 live action.

## 3. Scope

### 3.1 Included

- One profile-aware local export assessment, plan, digest approval, Apply, and independent validation contract.
- Reuse of the current committed-blob, marker-catalogue, structured-replacement, execution-manifest, and byte-comparison engines.
- Closed schemas for shared fields and profile-specific policy.
- Exact source commit and clean-source validation.
- External staging with no `.git`, remote, history, hook, credential, or token.
- `TenantReplica` retention of reusable source and operational assets.
- `CustomerHandover` continuation of stricter sanitization and reviewed replacements.
- Deny-by-default tenant artifact, evidence, private-state, and identifier handling.
- Local validation that the reusable source repository remains unchanged.
- Sanitized evidence under the shared umbrella run ID.
- Future instructions for a tenant owner to supply new private intent and run the same workstation and foundation lifecycle.

### 3.2 Excluded

- Destination repository or Azure DevOps project creation.
- Git initialization, remote creation, push, force-push, fork detachment, transfer, or publication.
- Tenant 2 or Tenant 3 authentication, discovery, configuration, validation, or mutation.
- Generating tenant-private intent from old manifests, prose, discovery evidence, or the source tenant.
- Copying Tenant 1 intent, state, IDs, approvals, raw evidence, authentication state, or deployment evidence.
- Automatic source synchronization or backport between tenant repositories.
- Rewriting, filtering, deleting, resetting, or otherwise changing the reusable source repository.
- A customer-name or tenant-name global replacement.

## 4. Current Baseline

The current engine already provides:

- exact source commit and clean-tree checks;
- external evidence and staging roots;
- deterministic assessment and shared execution manifest;
- explicit Apply, exact approved digest, `ShouldProcess`, and `-WhatIf`;
- copying from committed Git blobs rather than the working tree;
- no `.git` in staging;
- deny-by-default paths and exact retained tenant artifacts;
- exact JSON Pointer and per-file literal Markdown replacements;
- source marker discovery and reviewed residual dispositions;
- independent regeneration of expected bytes from the approved source commit; and
- no network authentication or publication behavior.

The refactor retains those controls. It does not reactivate the older cleanup procedure as a source-tree mutation and does not add a remote operation to the export scripts.

## 5. Profile Architecture

### 5.1 Shared Profile Contract

Every manifest declares exactly one profile:

```text
TenantReplica | CustomerHandover
```

Shared fields bind:

- schema version and profile;
- exact source commit;
- expected source repository identity;
- destination and disposable staging roots;
- retained and denied path rules;
- source marker assertions;
- exact residual dispositions;
- required validation suites;
- source and manifest digests;
- evidence root and run ID; and
- profile-specific policy digest.

Unknown properties, unknown profiles, overlapping contradictory rules, wildcard replacements, or unresolved markers are blocking.

The existing customer-export schema and module helpers should evolve into this profile-aware contract rather than creating a second export engine. Compatibility with existing `CustomerHandover` manifests is explicit and test-covered; silent reinterpretation is prohibited.

### 5.2 `TenantReplica`

`TenantReplica` produces a reusable local engineering seed. Its retained capability set includes:

- repository-owned product and infrastructure source;
- repository instructions, approved reusable skills, and agent definitions subject to their own ownership rules;
- the GitHub repository-validation workflow and its static dependencies;
- root Azure Pipeline YAML and reusable pipeline templates after the cloud subsystem adds them;
- infrastructure and HR tests;
- current replacement runbooks and reusable operational guidance;
- schemas, synthetic templates, and tenant-neutral examples; and
- source required to build and validate the committed HR solution.

It denies:

- every ignored or untracked file;
- `.git`, remotes, hooks, refs, history, and local Git configuration;
- `tenant1.local.psd1`, `tenant1.state.local.json`, backups, generated parameters, and local run roots;
- Tenant 1 stable identifiers, private URLs, account selectors, application IDs, service-principal IDs, environment IDs, project IDs, subscription IDs, approval records, and raw or sanitized run evidence selected by the profile's marker and path policy;
- tracked transition manifests and discovery evidence for any tenant, including the current Tenant 2 transition artifacts;
- provider response captures, deployment outputs, pipeline artifacts, PAC profiles, and authentication material; and
- any file whose disposition is ambiguous.

The literal architectural label `Tenant 1` is not automatically a private identifier. The reviewed marker catalogue distinguishes reusable narrative from actual tenant-specific values. A retained document that embeds a prohibited stable value must be sanitized through one exact reviewed rule or excluded.

The profile does not prepopulate Tenant 2 intent. A later tenant owner starts from tracked synthetic templates and supplies a new ignored private intent and state under the destination repository's reviewed contract.

### 5.3 `CustomerHandover`

`CustomerHandover` preserves the stricter existing export posture:

- no `.github/workflows` path;
- no raw or generated evidence;
- no tenant transition payload;
- no private state or stable identifier;
- no source history or publication configuration;
- exact per-file replacements only;
- exact residual marker dispositions with written reasons;
- restricted binary and synthetic-fixture exceptions;
- human review after independent validation; and
- no publication side effect.

Its allowlist may be narrower than `TenantReplica` and may exclude internal engineering automation, tests, operational templates, or repository-agent material that is not part of the reviewed customer delivery. It may never be widened implicitly because `TenantReplica` retains an artifact.

## 6. Proposed Public Sequence

The independently runnable repository-handover sequence is:

```text
Test-RepositoryExport
-> New-RepositoryExportPlan
-> human approval of the exact digest
-> Invoke-RepositoryExport -WhatIf
-> Invoke-RepositoryExport -Apply
-> Test-RepositoryExport -Independent
-> human content review
```

The proposed thin script surface is:

```text
infra/src/scripts/runbooks/Test-RepositoryExport.ps1
infra/src/scripts/runbooks/New-RepositoryExportPlan.ps1
infra/src/scripts/runbooks/Invoke-RepositoryExport.ps1
```

The existing `New-CustomerRepositoryExport.ps1` and `Test-CustomerRepositoryExport.ps1` may remain as tested `CustomerHandover` compatibility wrappers or be retired through an approved implementation plan. They must not select a profile implicitly after the profile-aware contract becomes authoritative.

The umbrella lifecycle invokes the same public contracts with profile `TenantReplica`. The scripts remain independently runnable and never import the umbrella.

## 7. Source and Destination Invariants

### 7.1 Source

The reusable source:

- is a clean, non-sparse checkout at the exact expected commit;
- has no staged, unstaged, untracked, conflicted, or submodule state for an accepted export;
- is read through Git object data for tracked regular blobs only;
- is never cleaned, reset, checked out, filtered, rewritten, deleted, or modified;
- retains its index, object database, refs, remotes, hooks, configuration, and workflows unchanged; and
- is snapshotted before and after export to prove immutability.

The exporter does not read ignored Tenant 1 files even when they exist on the workstation.

### 7.2 Destination

The destination:

- is outside the source and every Git worktree;
- does not exist before Apply;
- has a disposable sibling staging directory;
- contains no reparse point, symlink, Git link, or `.git` path;
- is promoted atomically only after profile validation passes; and
- has no remote, publication target, credentials, or hidden push behavior.

`-WhatIf`, missing approval, failed confirmation, or failed validation creates neither destination nor disposable staging.

## 8. Assessment, Planning, and Apply

### 8.1 Assessment

Assessment:

- validates source, destination, tool, profile, and manifest identities;
- enumerates the exact retained committed paths;
- evaluates every denied path and tenant artifact;
- builds the source marker catalogue;
- verifies exact replacement and residual assertions;
- computes the expected validation suite;
- identifies binary, encoding, newline, and path hazards; and
- classifies the export as `NoChange`, `Create`, `Manual`, `Blocked`, or `Refused`.

`Update` is unsupported for a completed export destination. A destination that already exists blocks rather than being edited in place.

### 8.2 Plan and Approval

The deterministic plan binds:

- exact source commit and source snapshot;
- complete retained-path inventory digest;
- complete denied-path and marker-policy digests;
- profile and profile-policy digest;
- replacement and residual-disposition digests;
- tool paths, versions, and hashes;
- destination stable path identity;
- ordered copy, transform, validate, and promote actions; and
- expected independent-validation suites.

The reviewer approves the execution-manifest digest after inspecting the source manifest directly. Counts or console summaries do not replace review.

### 8.3 Apply

Apply:

- revalidates all bound inputs;
- copies only approved committed blobs into disposable staging;
- applies only exact profile-authorized transformations in memory;
- writes no source file;
- validates the complete staged tree;
- promotes only after success; and
- records allowlisted action evidence.

No profile permits `git init`, `git remote`, `git push`, GitHub CLI, Azure CLI, Azure DevOps CLI, PAC CLI, or a service API.

## 9. Independent Validation

Independent validation does not trust staged metadata or Apply output. It:

1. rereads every expected original blob from the exact approved commit;
2. independently applies the reviewed profile rules in memory;
3. byte-compares every expected file with staging;
4. proves there is no unexpected file, directory, `.git` path, reparse point, denied artifact, prohibited marker, or evidence payload;
5. validates required repository suites against the staged tree without provider access;
6. verifies that the source pre/post snapshot is unchanged; and
7. writes a separate validation envelope and summary.

For `TenantReplica`, required suites include at least repository safety, GitHub validation static checks, infrastructure tests, HR tests relevant to retained source, runbook contract checks, pipeline-template validation after those templates exist, and the no-private-tenant boundary.

For `CustomerHandover`, required suites are the stricter manifest-selected export and residual checks; omission of internal workflows or tests is itself validated.

## 10. Current Sprint and Future Tenant 2 Handover

### 10.1 Current Sprint

The only operational handover outcome in this sprint is:

- create one local `TenantReplica` export from the accepted Tenant 1 source commit;
- run independent validation;
- perform human review;
- retain raw evidence outside Git; and
- record the sanitized acceptance result.

The export is not initialized as a repository, uploaded, published, or connected to a provider.

### 10.2 Later Tenant 2 Sequence

In a separate approved activity, the designated Tenant 2 owner, Andrea Rizzi:

1. creates the dedicated Tenant 2 GitHub repository and Azure DevOps project through attended owner authority;
2. starts from the independently validated `TenantReplica` content;
3. supplies Tenant 2 private intent and generated state outside Git;
4. proves encrypted backup and restore;
5. runs the same workstation and cloud foundation sequence against exact Tenant 2 contexts; and
6. records a separate Tenant 2 acceptance review.

No Tenant 1 ID, Tenant 2 transition manifest, approval, provider context, state, or evidence is reused as authority. Nothing in this design authorizes those later live actions now.

## 11. Evidence and Publication Boundary

Profile evidence uses the shared umbrella run root and records:

- source commit and snapshot digest;
- profile and manifest digests;
- retained, denied, replacement, residual, and marker counts;
- tool identities;
- `ShouldProcess` outcomes;
- destination content-tree digest;
- independent-validation result;
- source immutability result; and
- human-review disposition.

It excludes source text, replacement values, tenant-private markers, private paths, tokens, remotes, target repository coordinates, raw validation output, and publication credentials.

Successful validation means only that the local export matches the approved profile. It does not authorize publication. Repository creation, remote setup, push, ownership transfer, Azure Boards connection, pipeline creation, and tenant foundation execution are separate attended operations.

## 12. Failure and Recovery

- Any source, manifest, tool, profile, destination, or digest drift invalidates approval.
- A marker with no exact replacement, exclusion, or residual disposition blocks.
- Ambiguous encoding, path, binary content, tenant ownership, or retained capability blocks.
- Failed staging is deleted only within the exact disposable path after evidence is preserved; source is never used as a recovery target.
- A failed or existing destination is not patched in place. Recovery uses a new assessment, new empty destination, and new digest.
- Independent-validation mismatch invalidates the export; there is no force or skip-validation option.
- A partial publication discovered outside these scripts is escalated to the repository owner. The export tool does not alter or delete a remote.

## 13. Implementation Decomposition

The repository-handover implementation plan uses these ordered units:

1. Add failing schema tests for explicit `TenantReplica` and `CustomerHandover` profiles.
2. Refactor shared manifest import, assessment, planning, and validation without weakening current customer-export tests.
3. Define the `TenantReplica` retain/deny capability map and exact marker policy.
4. Add GitHub validation, Azure Pipeline template, test, runbook, and source-retention fixtures.
5. Add private-intent, state, tracked-transition, stable-ID, evidence, `.git`, and publication-negative fixtures.
6. Implement the three profile-aware thin entry points over the existing module engine.
7. Retain or retire existing customer-named wrappers through explicit compatibility tests.
8. Extend independent validation for profile-specific suites and source immutability.
9. Add interrupted staging, existing destination, ambiguity, drift, and no-network tests.
10. Rewrite the repository-handover runbook and infrastructure catalogues.
11. Run focused tests, all infrastructure and HR tests, repository validation, and local synthetic export tests.
12. Execute the separately approved local `TenantReplica` acceptance only after the cloud subsystem and replacement runbooks are accepted.

No task in the implementation plan may create a remote or use live tenant credentials.

## 14. Acceptance Criteria

The subsystem is acceptable only when:

- both profiles are explicit, closed, schema-valid, and independently tested;
- current `CustomerHandover` safety behavior is preserved or strengthened;
- `TenantReplica` retains reusable source, GitHub validation, Azure Pipeline templates, tests, and runbooks required by its manifest;
- no Tenant 1 private intent, state, stable identifier, backup, generated parameter, approval, or evidence appears in the replica;
- tracked tenant transition manifests and discovery evidence are absent;
- `.git`, remotes, workflows prohibited by `CustomerHandover`, and publication behavior are absent as applicable;
- source pre/post snapshots are identical;
- `-WhatIf`, declined confirmation, missing approval, and drift produce no destination;
- independent validation reconstructs and byte-compares the complete expected tree;
- all required retained-tree tests pass without provider access;
- the local `TenantReplica` receives human review and a sanitized acceptance result; and
- no Tenant 2 live operation, destination repository, Azure DevOps project, or publication occurs.

## 15. Risks and Non-goals

| Risk | Treatment |
|---|---|
| A broad replica leaks source-tenant identity | Deny tenant payloads by path and marker, require exact residual dispositions, and validate independently. |
| A narrow replica omits required build capability | Define retained capabilities, not only file patterns, and run tests in staging. |
| Two profiles drift into two engines | Keep one shared committed-blob and independent-validation core with profile-specific policy. |
| Historical narrative contains stable identifiers | Sanitize exact retained files or exclude them; do not perform global replacement. |
| Validation is mistaken for publication approval | Keep scripts network-free and make publication a separate attended authority boundary. |
| Old Tenant 2 transition files are treated as current intent | Exclude them from the replica and require new private intent from the Tenant 2 owner. |

This design does not move documents, implement scripts or tests, execute an export, publish a repository, create a provider object, or mutate a tenant. It does not authorize Tenant 2 or Tenant 3 live action and does not claim a local export currently passes.
