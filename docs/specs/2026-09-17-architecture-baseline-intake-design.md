# Architecture Baseline Intake and Tenant Bootstrap Design

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-19 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Repository Superpowers Integration Design](./2026-09-15-repository-superpowers-design.md) |

## Status

Approved through attended design review on 2026-09-17. The immutable GitHub OIDC subject amendment was approved on 2026-09-19 after repository API read-back confirmed that immutable subjects are enabled.

Imported architecture and governance documents remain a **Proposed Baseline** until each document is accepted through a later decision or implementation review. Approval of this specification authorizes the intake and bootstrap design; it does not silently accept every imported recommendation.

## Objective

Selectively incorporate the prepared Caldova HR Frontier architecture package into the governed repository baseline, establish reproducible GitHub and Microsoft Entra control-plane foundations, and prove the first tenant's Azure subscription baseline with a successful Bicep `what-if`.

The result must support three independent tenants that use the same configuration model and automation. Tenant-specific identifiers, existing services, regions, and lifecycle decisions remain isolated per tenant.

## Clarified Terminology

`DEV`, `TEST`, and `PROD` describe the Power Platform application lifecycle inside each tenant:

```text
Build solution in DEV -> deploy through Azure DevOps -> TEST -> PROD
```

They are not Azure infrastructure environments, subscriptions, or Bicep deployment stages. No Azure resource name or Bicep composition may infer an infrastructure environment from these Power Platform labels.

The term `bootstrap` means establishing and validating the control plane needed for secretless discovery and future provisioning. In this sprint, bootstrap may change GitHub objects, Microsoft Entra objects, and Azure authorization objects required for OIDC and least-privilege access. It does not deploy the platform resources shown by the Bicep `what-if`.

## Dependency and Branch Sequence

The completed Superpowers foundation is merged and pushed to `main` before this sprint begins. Intake work starts from that merged commit on a separate branch and in an isolated worktree.

The vendored Superpowers runtime, its integrity manifest, and its byte-stability contracts remain unchanged. Repository-specific intake and bootstrap behavior belongs in repository-owned scripts, workflows, instructions, policies, specifications, and plans.

## Source Package Assessment

The assessed source package contains 45 files in 21 directories with a total size of 485,126 bytes. Its principal domains are:

- `.github/` for governance, agent, and collaboration material;
- `docs/` for the cross-cutting operating model and decisions;
- `data/` for synthetic demonstration data;
- `hr/` for the HR solution domain;
- `infra/` for infrastructure documentation, configuration, scripts, solutions, and tests.

The assessment found no nested Git repository, reparse point, symlink, binary payload, build manifest, deployable Bicep implementation, or confirmed secret file. Implementation must regenerate and version a source inventory with relative paths, sizes, and SHA-256 hashes before copying content. A changed source package invalidates the assessment and requires a new reviewed inventory.

## Intake Architecture

Intake occurs in three separately reviewable phases:

1. Governance and GitHub.
2. Product, HR, and operating model.
3. Infrastructure and tenant bootstrap.

Each phase has its own deterministic path inventory, collision report, validation result, and commit boundary. A phase does not advance until its review is complete.

The source domain boundaries are preserved. In particular, `data/`, `hr/`, `infra/`, and `docs/operating-model/` remain distinct top-level ownership areas. Infrastructure Power Platform solution assets remain under `infra/src/solutions/`; HR solution assets remain under `hr/src/solutions/`.

### Collision Rules

The repository baseline wins every path collision. Intake never performs a directory-wide overwrite.

For every source path, the intake process must classify the result as one of:

- `Add`: the path does not exist and can be copied after validation;
- `Merge`: both paths contain compatible repository-owned guidance and require a reviewed semantic merge;
- `PreserveTarget`: the governed repository version remains authoritative;
- `Reject`: the source path violates a repository invariant or cannot be classified safely.

The following paths require explicit merge behavior:

- `README.md`: preserve the repository agent workflow and Superpowers verification material while adding the product and architecture map.
- `AGENTS.md`: preserve the Superpowers bootstrap and add only non-duplicative repository operating rules.
- `.github/copilot-instructions.md`: preserve project-skill activation and add domain-specific constraints without copying vendored skill content.
- `.gitignore`: preserve `.wt/` and existing repository exclusions, then add only source rules that remain applicable.
- `.github/ISSUE_TEMPLATE/config.yml`: retain blank-issue blocking and add the reviewed Azure Boards and governance contact links.
- `.github/ISSUE_TEMPLATE/intake.yml`: add the Frontier Intake as a third active form while retaining the existing bug and feature forms.
- Existing folder `README.md` files: retain their lifecycle contracts and add domain guidance only where it does not weaken them.

The active issue-form set after intake is exactly:

- `01-bug.yml`;
- `02-feature.yml`;
- `03-frontier-intake.yml`;
- `config.yml`.

The repository validator and raw-byte Git contracts are updated atomically for this reviewed set. The intake form keeps its prohibition on personal and special-category data.

### Proposed Baseline Marking

Each imported architecture, governance, and operating-model document receives the standard metadata header immediately below its title. Its initial values include:

```text
Date: 2026-09-17
Author: docs-agent (Voice of Knowledge)
Status: Proposed Baseline
Scope: The owning solution domain or Cross-cutting (all solution domains)
References: The source inventory and relevant governing documents
```

The status is removed or changed only by a later reviewed decision. Imported content cannot become authoritative merely because its file exists on `main`.

## Documentation Language Policy

All maintained repository documentation is written in English. This includes specifications, plans, ADRs, reviews, templates, folder guidance, issue forms, pull request guidance, runbooks, governance policies, and explanatory comments in configuration files.

The policy is anchored in:

- `docs/README.md` as the authoritative documentation policy;
- `AGENTS.md` for cross-host agent behavior;
- `.github/copilot-instructions.md` for GitHub Copilot behavior;
- `.github/pull_request_template.md` for contributor review;
- the repository validator, which verifies that these anchors exist and reference the policy.

Automated natural-language classification is not an acceptance gate because it is not reliable enough to decide whether prose is English. Reviewers enforce the semantic requirement. Proper nouns, product names, identifiers, code, commands, URLs, source quotations, and immutable license text are not translated.

### Standard Document Header

Every repository-owned Markdown artifact contains this table immediately after its first level-one heading:

```markdown
| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Relevant governing artifact](relative-path.md) |
```

The rule applies to repository-owned `*.md`, `*.agent.md`, and `*.instructions.md` files, including root guidance, folder `README.md` files, specifications, plans, ADRs, reviews, policies, runbooks, and agent definitions.

The following content is excluded:

- vendored files below `.github/skills/<skill>/`;
- `LICENSE` and `.github/skills/LICENSE.superpowers`;
- generated evidence and machine-readable manifests;
- externally owned immutable text that must remain byte-identical to its source.

The repository-owned `.github/skills/README.md` is not vendored and therefore receives the header.

Header fields follow these rules:

- `Version` uses `major.minor`. Major changes alter the artifact's governing contract; minor changes add or clarify current content.
- `Date` is the ISO 8601 date of the latest substantive review. It is never backdated to imply earlier approval.
- `Author` identifies the accountable contributor or agent. Documents consolidated through the documentation workflow use `docs-agent (Voice of Knowledge)`.
- `Status` starts with one of `Draft`, `Proposed Baseline`, `Active`, `Approved`, `Superseded`, or `Archived` and may include a concise parenthetical qualifier.
- `Scope` identifies `Repository`, `Cross-cutting (all solution domains)`, `Infrastructure`, `HR`, `Data`, or another explicitly named solution domain.
- `References` contains one or more relative Markdown links or the literal `None` when no governing reference exists.

Git history is the change log. The standard does not add an in-document change log or duplicate commit history.

### Documentation Agent Contract

The policy owner is `.github/agents/docs-agent.agent.md`, adapted for this repository as the **Voice of Knowledge**. Its discovery description names documentation creation, consolidation, placement, metadata headers, English-language review, traceability, and catalogue maintenance.

Root `AGENTS.md` links directly to `.github/agents/docs-agent.agent.md` and identifies it as the owner of the documentation policy and standard metadata header. This link is the cross-host discovery anchor; `.github/copilot-instructions.md` reinforces the same ownership for GitHub Copilot.

The agent:

- applies the Superpowers brainstorming workflow before restructuring documentation;
- edits only repository-owned Markdown and documentation catalogues;
- preserves domain ownership across `docs/`, `infra/docs/`, `hr/docs/`, `data/`, and repository-governance documentation;
- adds and validates the standard header;
- writes maintained prose in English and checks UTF-8 for corruption;
- keeps content lean and aligned with delivered behavior or an explicitly marked Proposed Baseline;
- updates references and the documentation map in `docs/README.md` when artifacts move or are added;
- never edits vendored Superpowers, licenses, generated evidence, source code, or deployment state;
- never invents approval, backdates metadata, or converts proposed guidance into an active policy without review.

Its minimal tool contract is read, search, edit, and todo management. It has no terminal or deployment tool. The agent definition itself follows the same standard header after its YAML frontmatter and level-one heading.

## Tenant Model

The architecture supports exactly three independently onboarded tenants through one shared schema and shared automation. A workflow run targets exactly one tenant. It cannot process multiple tenants through a matrix or share a tenant's environment variables with another tenant.

Each tenant has:

- a stable lowercase alias;
- a display name;
- a Microsoft Entra tenant ID;
- an administrative UPN used only for attended initial trust establishment;
- an Azure subscription ID;
- an independently selected Azure primary region;
- an Azure DevOps organization and project declaration;
- three Power Platform environment declarations for DEV, TEST, and PROD;
- a company three-letter abbreviation;
- a six-character lowercase alphanumeric naming suffix;
- explicit `Existing` or `Create` intent for every managed component;
- a dedicated GitHub Environment named `bootstrap-${tenantAlias}`;
- a dedicated single-tenant Microsoft Entra application and service principal for this repository.

Tenant 2 and Tenant 3 use the same schema and workflows but are not provisioned during this sprint. Their future attended discovery determines which components are declared `Existing` and which are declared `Create`.

## Tenant Configuration Contract

The reviewed desired state for each tenant is stored at:

```text
infra/src/config/tenants/<tenantAlias>.psd1
```

The PowerShell data file contains data only. It must not contain executable expressions, credential material, access tokens, keys, client secrets, private certificate data, connection strings, or personal HR data.

The schema includes:

- `SchemaVersion`;
- `TenantAlias`;
- `DisplayName`;
- `TenantId`;
- `AdminUpn`;
- `SubscriptionId`;
- `PrimaryLocation`;
- `CompanyTla`;
- `WorkloadName`;
- `UniqueSuffix`;
- `NamingRoot`;
- `GitHub.Owner`, `GitHub.OwnerId`, `GitHub.Repository`, `GitHub.RepositoryId`, and `GitHub.EnvironmentName`;
- `AzureDevOps.OrganizationUrl` and `AzureDevOps.ProjectName`;
- `PowerPlatform.DevUrl`, `PowerPlatform.TestUrl`, and `PowerPlatform.ProdUrl`;
- a `Components` map whose entries contain `Mode` and, for `Existing`, the stable identifier needed to validate the object.

`Mode` permits only `Existing` or `Create`. There is no `Auto` mode. Discovery reports evidence; a reviewed pull request records intent.

The configuration parser validates the data file in constrained language mode, rejects unknown keys, and checks identifiers, URLs, casing, suffix format, naming derivation, and cross-field consistency before any authenticated operation.

## Tenant 1 Baseline

Tenant 1 has the following reviewed non-secret metadata:

| Field | Value |
|---|---|
| Tenant alias | `caldova25156897` |
| Display name | `Caldova25156897` |
| GitHub owner | `urruegg` |
| GitHub owner ID | `46865858` |
| GitHub repository | `caldova-hr-frontier` |
| GitHub repository ID | `1371297722` |
| Tenant ID | `e2312862-df63-440c-8bcf-007a2c52859d` |
| Admin UPN | `admin@Caldova25156897.onmicrosoft.com` |
| Subscription ID | `edb45a24-408d-47c4-bbc7-685b9b3fc017` |
| Primary Azure region | `switzerlandnorth` |
| Azure DevOps organization | `https://dev.azure.com/caldova25156897/` |
| Azure DevOps project | `Caldova HR Frontier` |
| Power Platform DEV | `https://hrfrontierdev.crm17.dynamics.com/` |
| Power Platform TEST | `https://hrfrontiertest.crm17.dynamics.com/` |
| Power Platform PROD | `https://hrfrontier.crm17.dynamics.com/` |
| Company abbreviation | `cal` |
| Unique suffix | Not assigned before onboarding; generated once and committed before `what-if` |
| Naming root | Derived as `cal-hr-agentic-<unique-suffix>` after suffix assignment |

The initial discovery must validate these values against service evidence. A mismatch is reported and blocks bootstrap; the script does not silently rewrite the configuration.

## Naming Contract

The human-readable canonical naming root follows:

```text
<company-tla>-hr-agentic-<unique-suffix>
```

For Tenant 1, the company abbreviation is `cal`. A cryptographically secure generator creates the six-character lowercase alphanumeric suffix once during onboarding. The generated value is committed to `infra/src/config/tenants/caldova25156897.psd1` through a reviewed pull request before any Bicep `what-if` is run. Once that commit reaches `main`, the suffix is immutable for that tenant.

Every Azure name is derived from the canonical root through a resource-type-specific function that applies Microsoft naming constraints. The function must be deterministic and unit tested. It may remove hyphens, truncate only at a documented boundary, or add a standard resource prefix, but it may not generate a second random value.

Examples after a hypothetical suffix `a7k29x` include:

```text
Canonical root: cal-hr-agentic-a7k29x
Platform resource group: rg-cal-hr-agentic-a7k29x-platform
Log Analytics workspace: log-cal-hr-agentic-a7k29x
```

The example suffix is illustrative and is not Tenant 1's assigned value.

## Evidence-Based Service Discovery

Discovery is a separate, read-only operation. It covers:

- GitHub repository settings, rulesets, environments, variables, secret names, workflows, and collaboration controls visible to the authenticated principal;
- Microsoft Entra applications, service principals, federated credentials, relevant directory roles, and consented permissions;
- Azure subscription identity, resource groups, resources, role assignments, policy assignments, diagnostic settings, and provider state;
- Azure DevOps organization, project, repositories, service connections, environments, pipelines, checks, and relevant permissions;
- Power Platform tenant and the declared DEV, TEST, and PROD environments, including identifiers and governance metadata available through supported APIs.

Discovery output is normalized to:

```text
infra/evidence/discovery/<tenantAlias>.json
```

The JSON contract includes:

- schema and discovery-tool versions;
- tenant alias and verified tenant ID;
- UTC collection time;
- authenticated principal identifiers;
- per-service query status;
- normalized objects and stable identifiers;
- evidence references that name the service, API or command, query scope, collection time, and response hash;
- explicit `Found`, `Missing`, `Unauthorized`, `Unavailable`, or `Ambiguous` outcomes.

Raw API responses are not committed. The normalized inventory is committed because the repository is the evidence record. Serialization uses an allowlisted schema rather than copying and redacting arbitrary response objects. Safe fields include stable object IDs, Azure resource IDs, approved service URLs, resource names and types, role names, non-secret variable names, secret names, status values, timestamps, and response hashes.

Values for secrets, tokens, keys, certificates, connection strings, authentication headers, unrestricted access-control membership, personal names, employee identifiers, and HR records are never admitted to the schema. The configured administrative UPN may appear only when it exactly matches the reviewed tenant manifest. A secondary denylist scan detects common credential field names, JWTs, SAS signatures, private-key blocks, and connection-string patterns before output can be written.

Discovery must fail its decision gate if any required service is `Unauthorized`, `Unavailable`, or `Ambiguous`. A bootstrap-changing run requires every service result to share one discovery-run ID and a collection-start timestamp within the preceding 24 hours. The bootstrap workflow compares `CollectionStartedUtc + 24 hours` with its current UTC evaluation time. Older evidence remains historical but cannot authorize change.

Initial discovery runs locally and attended with interactive administrator authentication. After OIDC trust is established, subsequent discovery runs through GitHub Actions with read-only service permissions and the repository `GITHUB_TOKEN`; no PAT or client secret is introduced.

## Evidence-Gated State Machine

The tenant lifecycle is a fail-closed state machine:

```text
SourceAssessed
  -> ContentReviewed
  -> TenantDeclared
  -> DiscoveryCollected
  -> IntentReviewed
  -> TrustEstablished
  -> OidcValidated
  -> WhatIfValidated
  -> GitHubGovernanceActivated
```

Each transition produces a reviewable artifact and validates the preceding state. A failed, partial, stale, or ambiguous state cannot advance automatically.

The normal flow is:

1. Inventory and review the source package.
2. Import the three content phases without overwriting governed paths.
3. Create the Tenant 1 manifest and generate its immutable suffix.
4. Run attended local discovery.
5. Commit the normalized inventory.
6. Review and commit explicit `Existing` or `Create` decisions.
7. Create or validate the tenant-specific GitHub and Microsoft Entra trust objects.
8. An attended subscription administrator grants the provisioning service principal the two temporary bootstrap roles and records their exact assignment IDs.
9. Validate OIDC from the tenant's GitHub Environment.
10. Run fresh OIDC discovery and compare it with desired state.
11. Build and lint Bicep, then run Tenant 1's subscription-scope `what-if`.
12. Remove `Contributor` first and `Role Based Access Control Administrator` last, then verify both recorded assignments are absent.
13. Activate the reviewed GitHub `main` ruleset only after its required validator check has succeeded.

## Authentication and Trust Bootstrap

Each target tenant and this repository receive one dedicated single-tenant Microsoft Entra application registration and service principal. Provisioned Azure workloads use their own managed identities later; they do not reuse the provisioning application.

The GitHub federated identity credential uses:

```text
Issuer: https://token.actions.githubusercontent.com
Audience: api://AzureADTokenExchange
Subject: repo:${owner}@${ownerId}/${repository}@${repositoryId}:environment:bootstrap-${tenantAlias}
```

GitHub's read-only repository and OIDC customization APIs are queried before trust creation. The owner and repository names and their immutable numeric IDs are stored as reviewed non-secret manifest fields. The returned `sub_claim_prefix` must match the manifest-derived prefix, `use_default` and `use_immutable_subject` must both be `true`, and any mismatch stops the operation.

The repository was created on 2026-09-15. Read-only API evidence collected on 2026-09-19 returned owner ID `46865858`, repository ID `1371297722`, and immutable prefix `repo:urruegg@46865858/caldova-hr-frontier@1371297722`. Tenant 1 therefore uses:

```text
repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-caldova25156897
```

The initial trust operation is attended and local. The configured admin UPN is versioned as non-secret metadata and is used only to select and verify the interactive account. Passwords, MFA responses, tokens, and recovery material are never accepted by scripts, written to disk, routed through an agent, or stored in GitHub.

`infra/src/scripts/Initialize-TenantTrust.ps1` is the single attended entry point. It requires interactive Microsoft Entra/Azure authentication for the configured tenant and authenticated GitHub repository-administrator context. It creates or validates the single-tenant application, service principal, exact federated credential, GitHub Environment, required reviewer configuration, and non-secret Environment variables. It refuses to create a client secret or certificate credential.

The trust script validates the application sign-in audience, service-principal relationship, issuer, audience, subject, tenant, repository, and environment name through API read-back. It records stable object IDs in the tenant manifest through an explicit reviewed update; it does not commit credentials.

Each GitHub Environment stores its own non-secret variables:

- `AZURE_CLIENT_ID`;
- `AZURE_TENANT_ID`;
- `AZURE_SUBSCRIPTION_ID`.

The workflow derives the environment name from the required `tenantAlias` dispatch input and loads the corresponding `.psd1`. It must compare all three environment values with the manifest and authenticated Azure context. Any mismatch stops the run.

Environment self-approval is allowed for all three tenant administrators during bootstrap and is documented as an explicit pilot exception.

## Privilege Lifecycle

The provisioning service principal may receive temporary subscription-scope `Contributor` and `Role Based Access Control Administrator` assignments only for the attended trust and role-bootstrap window. An attended subscription administrator grants both roles after trust creation and records their exact assignment IDs before dispatching the bootstrap workflow.

The workflow uses `Role Based Access Control Administrator` to create or validate the steady-state custom role and assignment. Its unconditional cleanup path deletes the recorded `Contributor` assignment first and the recorded `Role Based Access Control Administrator` assignment last. It then queries Azure authorization state until both assignments are absent or the bounded retry expires. A cleanup failure makes the entire run fail and requires attended remediation.

The steady state retains only:

- Azure read access required for discovery;
- a custom Azure permission set limited to deployment validation and `what-if`, with no resource-provider write actions;
- separately scoped read access required for Microsoft Entra, Azure DevOps, and Power Platform discovery;
- no client secret or private certificate credential.

Future live provisioning is a separate sprint and must use a newly reviewed, time-bound elevation path. Standing `Contributor` or role-administration access is not accepted as bootstrap completion.

The temporary grants, steady-state custom role definition, and role assignments are live Azure authorization changes. They are explicitly permitted control-plane bootstrap operations and are not a Bicep deployment of the planned platform resources.

## GitHub Workflows

### Tenant Discovery

`.github/workflows/discover-tenant.yml` is manually dispatched with a required `tenantAlias`. It binds to `bootstrap-${tenantAlias}`, authenticates through OIDC, executes only read operations, validates redaction, and publishes the normalized JSON for review. The workflow does not push or open a pull request automatically.

### Tenant Bootstrap and What-If

`.github/workflows/bootstrap-tenant.yml` is manually dispatched with a required `tenantAlias`. It:

1. validates the tenant schema and naming contract;
2. validates evidence age and service completeness;
3. compares environment variables, manifest values, and authenticated context;
4. verifies every `Existing` object by stable identifier;
5. rejects any `Create` intent when an ambiguous or conflicting object exists;
6. creates or validates the steady-state custom role and assignment;
7. builds and lints the subscription Bicep entry point;
8. runs `what-if` for the selected tenant;
9. uploads the redacted `what-if` result;
10. removes the two recorded temporary assignments in the required order;
11. verifies that both temporary assignments are absent.

This sprint executes the workflow for Tenant 1 only. A live Azure deployment command is not present in the workflow.

## Azure What-If Boundary

The Bicep entry point is `infra/src/bicep/main.bicep` with `targetScope = 'subscription'`. Its reviewed parameter file is `infra/src/bicep/params/<tenantAlias>.bicepparam`, generated from and cross-checked against the tenant manifest. Tenant 1's composition models only the subscription baseline:

- one tenant-wide platform resource group in `switzerlandnorth`;
- one Log Analytics workspace in that resource group;
- one subscription Activity Log diagnostic setting targeting that workspace;
- the steady-state discovery and `what-if` role definition and assignment;
- a reusable subscription-policy assignment module with an explicit empty Tenant 1 assignment set.

No policy is inferred or enabled without a reviewed tenant declaration. The empty assignment set establishes the tested policy composition boundary without introducing unapproved deny behavior. Policy enforcement is a later decision.

Machine-readable `what-if` validation permits only these resource types and scopes:

| Resource type | Required scope |
|---|---|
| `Microsoft.Resources/resourceGroups` | Tenant subscription |
| `Microsoft.OperationalInsights/workspaces` | Approved platform resource group |
| `Microsoft.Insights/diagnosticSettings` | Tenant subscription Activity Log |
| `Microsoft.Authorization/roleDefinitions` | Tenant subscription |
| `Microsoft.Authorization/roleAssignments` | Tenant subscription |

The empty policy module produces no policy-assignment resource change. Any other resource type, resource group, subscription, or location fails the boundary check.

The `what-if` must show no resources outside this boundary. In particular, it excludes:

- Power Platform environments and solutions;
- Azure DevOps organizations, projects, pipelines, service connections, and Boards configuration;
- Microsoft Entra application and federated credential creation;
- GitHub settings;
- application runtime services;
- workload managed identities;
- Key Vault, storage, integration, and HR workload resources;
- live role elevation or live Azure deployment.

## Power Platform ALM Boundary

Each tenant contains independent DEV, TEST, and PROD Power Platform environments. The solution is built in DEV and promoted by Azure DevOps pipeline to TEST and then PROD. The production stage requires its recorded approval and receives managed solutions only.

Tenant 1's three supplied URLs are existing-service candidates until discovery confirms their stable environment identifiers. This sprint inventories and declares them but does not create environments, import a solution, configure a pipeline, or deploy to TEST or PROD.

## Azure DevOps Boundary

Tenant 1 uses the existing organization `caldova25156897` and the existing project `Caldova HR Frontier`, subject to discovery validation. Tenant 2 and Tenant 3 explicitly declare whether their organization and project already exist or must be created in a future provisioning sprint.

The organization itself is always a prerequisite because automated Azure DevOps organization creation is unsupported. A future `Create` decision may apply to a project, repository, pipeline, environment, or supported project-level object, but not to the organization.

## GitHub Collaboration and Governance

The imported Frontier Intake becomes the third active issue form. The issue chooser retains `blank_issues_enabled: false` and adds:

- a link to the Tenant 1 Azure DevOps organization for backlog and delivery tracking;
- a link to the repository HITL governance document for data-handling guidance.

The `main` ruleset requires:

- changes through pull requests;
- one approval;
- CODEOWNERS review;
- resolved review conversations;
- the repository validator status check;
- blocked force pushes;
- blocked branch deletion.

The normal administrator bypass is pull-request-only. It permits an administrator to complete a pull request when independent approval is unavailable, but it does not permit a direct push to `main`.

A full bypass is allowed only as a documented break-glass operation. The administrator must record the reason, scope, commands or settings changed, validation evidence, and follow-up corrective pull request. The break-glass procedure is stored in `.github/agent-policy/BREAK_GLASS.md`.

The validator workflow is added and successfully executed before the ruleset is activated. Ruleset activation is the final GitHub mutation in the sprint. The applied ruleset and Environment settings are read back through the GitHub API and compared with the reviewed desired state.

Each `bootstrap-${tenantAlias}` Environment is restricted to the `main` branch, names the tenant administrator's GitHub identity as a required reviewer, and has prevent-self-review disabled for the approved pilot exception. It contains only the three reviewed non-secret Azure variables. Environment secrets are not required. The API read-back must confirm branch restriction, reviewer identity, self-review setting, and variable names without attempting to disclose secret values.

## Error Handling and Recovery

All discovery and bootstrap components use terminating errors and produce a structured result. They distinguish absence from lack of authorization and service failure.

The process stops on:

- a missing or invalid tenant manifest;
- an unversioned or changed naming suffix;
- stale or incomplete evidence;
- tenant, subscription, organization, project, or environment mismatch;
- an `Existing` object whose stable identifier does not match;
- an unexpected object that conflicts with `Create` intent;
- an unsupported or unautomatable operation represented as automated;
- an OIDC issuer, audience, subject, client, tenant, or subscription mismatch;
- a secret or prohibited data finding;
- Bicep build or lint failure;
- a failed or out-of-boundary `what-if`;
- unsuccessful privilege cleanup;
- inability to read back and verify a control-plane mutation.

Re-running a completed state is idempotent. A retry validates existing objects before continuing and never creates a duplicate to mask an uncertain result. Recovery instructions identify the last proven state and the attended action required; they do not weaken a gate automatically.

`infra/docs/19-bootstrap-recovery.md` owns the attended recovery procedures. It covers trust-creation failure, OIDC mismatch, partial service discovery, stale evidence, ambiguous existing objects, Bicep failure, privilege-cleanup failure, and GitHub control read-back failure. Every procedure states the last trusted state, required operator role, non-destructive diagnostic steps, repair action, revalidation command, and escalation boundary.

## Validation Strategy

### Repository Validation

The repository validator is extended to cover:

- required imported domain paths and English-language policy anchors;
- the exact eligible Markdown path set and documented exclusions for the standard header;
- header position and exact field names;
- `major.minor` version syntax, ISO 8601 date syntax, allowed status prefix, allowed scope, non-empty author, and linked references or `None`;
- the adapted `docs-agent.agent.md` frontmatter, minimal tool boundary, policy references, and direct ownership links from `AGENTS.md` and `.github/copilot-instructions.md`;
- the exact active issue-form path set and pinned raw-byte contract;
- unchanged vendored Superpowers content;
- deterministic source inventory and collision classifications;
- tenant manifest path, schema, and constrained-data parsing;
- discovery JSON schema and prohibited-field checks;
- workflow presence and required permission boundaries;
- documentation links and Proposed Baseline status blocks.

### Automated Tests

Pester tests cover:

- eligible and excluded Markdown path classification;
- valid and invalid standard metadata headers;
- preservation of vendored and immutable files during header migration;
- tenant schema acceptance and rejection;
- unknown-key and executable-expression rejection;
- secure suffix generation and immutability;
- resource-type naming derivation and Azure length constraints;
- service-response normalization using checked-in synthetic fixtures;
- distinction among `Missing`, `Unauthorized`, `Unavailable`, and `Ambiguous`;
- secret and personal-data redaction;
- evidence-age enforcement;
- `Existing` and `Create` gate behavior;
- cleanup execution after simulated failures;
- idempotent retries;
- exact immutable OIDC subject derivation from reviewed owner and repository names and IDs.

Bicep validation covers build, lint, subscription-scope composition, parameter generation, and a machine-readable check that the Tenant 1 `what-if` contains only the approved baseline resource types and scopes.

### Integration Checks

The attended integration checks confirm:

1. Tenant 1 discovery validates all supplied identifiers and URLs.
2. The committed inventory contains no secret or prohibited personal data.
3. The GitHub Environment requires approval but permits the documented administrator self-approval exception.
4. GitHub OIDC signs into the expected application, tenant, and subscription without a stored credential.
5. Subsequent discovery succeeds with steady-state read permissions.
6. Tenant 1's Bicep `what-if` succeeds and remains within scope.
7. `Contributor` and `Role Based Access Control Administrator` are absent from the provisioning principal after the run.
8. The validator workflow succeeds on `main` before ruleset activation.
9. GitHub API read-back matches the approved ruleset and Environment configuration.
10. The documentation agent is discoverable in VS Code and correctly identifies a missing or invalid metadata header without editing excluded content.

## Acceptance Criteria

This sprint is complete when:

1. The three intake phases are reviewed and committed without overwriting protected repository content.
2. Imported architecture and governance documents are visibly marked Proposed Baseline.
3. The English-only documentation policy and six-field metadata header are anchored in all specified repository guidance surfaces.
4. Every eligible repository-owned Markdown artifact has a valid standard header, and every excluded path remains byte-stable.
5. The adapted `docs-agent.agent.md` is discoverable through direct links from `AGENTS.md` and `.github/copilot-instructions.md`, is English-language and minimally tooled, and is responsible for header, placement, reference, and catalogue maintenance.
6. The merged root guidance preserves Superpowers activation and verification.
7. Bug, feature, and Frontier Intake forms are active, blank issues are disabled, and both contact links are present.
8. The Tenant 1 manifest contains the reviewed metadata and a generated, reviewed, immutable six-character suffix.
9. Attended discovery covers GitHub, Microsoft Entra, Azure, Azure DevOps, and Power Platform and produces a committed normalized inventory.
10. Every managed Tenant 1 component has an explicit reviewed `Existing` or `Create` declaration supported by current evidence.
11. The dedicated single-tenant Entra application, service principal, federated credential, and GitHub Environment are created or validated without a client secret.
12. OIDC authentication resolves to the expected Tenant 1 client, tenant, and subscription.
13. The Tenant 1 subscription Bicep builds and lints successfully.
14. Tenant 1's subscription-scope `what-if` succeeds and contains only the approved baseline composition.
15. Temporary elevated Azure role assignments are removed and their absence is verified.
16. The repository validator workflow succeeds before the approved `main` ruleset is activated.
17. API read-back confirms the final GitHub controls.
18. No live deployment of the planned platform resource group, Log Analytics workspace, diagnostic setting, policy assignment, Power Platform solution, or Tenant 2/Tenant 3 configuration occurs. Only the explicitly approved GitHub, Microsoft Entra, and Azure authorization bootstrap changes are live.

## Non-Goals

- Accepting imported architecture as final merely by importing it.
- Replacing or modifying the vendored Superpowers runtime.
- Deploying the planned Azure platform or workload resources during this sprint.
- Creating an Azure subscription or Azure DevOps organization.
- Creating or deploying Tenant 2 or Tenant 3.
- Creating Power Platform environments.
- Building or deploying Power Platform solutions.
- Implementing the Azure DevOps DEV-to-TEST-to-PROD ALM pipeline.
- Provisioning application runtime, integration, HR workload, or workload managed-identity resources.
- Enabling subscription policy enforcement without a separately reviewed policy set.
- Introducing client secrets, PATs, stored administrator credentials, or private certificates.
- Automatically deciding `Existing` or `Create` from discovery output.
- Translating immutable licenses, product names, identifiers, code, commands, or quoted evidence.