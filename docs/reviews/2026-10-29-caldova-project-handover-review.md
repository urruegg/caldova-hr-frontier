# Caldova Project Documentation Handover

| Field | Value |
|---|---|
| **Version** | 0.4 |
| **Date** | 2026-10-30 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | Eight Caldova project/demo document sets, source-model refinement and labelled GF source preservation |
| **References** | [Knowledge map](../README.md), [Proposed ADR-0015](../adr/0015-caldova-github-authority-and-azure-repos-secondary.md), [Migration map](evidence/2026-10-29-caldova-document-migration/rename-map.json), [Historical GF pointer](2026-10-29-gf-project-handover-review.md) |

## 1. Outcome and authority

This handover replaces current GF project-document routing with eight Caldova
project/demo sets: eight ideas, eight sprints, eight specifications and the three
existing implementation plans. All 27 remain Draft. This is design preparation,
not evidence that the HR agents or new delivery platform have been built.

GF remains the identified customer/source scenario for supplied HR material,
reported approvals, the blueprint and the identity kit. Those facts are not
reassigned to Caldova. Stable `IDEA-GF-*` and requirement IDs remain traceability
keys; filename ownership is not approval, renumbering or a transfer of trademarks.

The selected source model is GitHub authority, Azure Pipelines consuming GitHub
directly and a separate manually approved Azure Repos secondary copy.
[ADR-0015](../adr/0015-caldova-github-authority-and-azure-repos-secondary.md) is
Proposed Baseline, not ratification of an exception to Approved history.

No remote, service connection, pipeline, permission, required check, source copy
or deployment is configured by this documentation change. Commit/push and public
publication are also outside this refinement's authorization.

## 2. All eight primary sets and supporting plans

Each row has one primary idea/sprint/specification set. Supporting plans exist
only where already established; no five additional plans were invented.

| Caldova project package | Idea | Sprint | Specification | Supporting implementation plan |
|---|---|---|---|---|
| SSE HR Policy assistant | [Idea](../ideas/caldova-sse-hr-policy-assistant-idea.md) | [Sprint](../plans/2026-10-28-caldova-sse-hr-policy-assistant-sprint.md) | [Specification](../specs/2026-10-28-caldova-sse-hr-policy-assistant-design.md) | Not established |
| Recruiting requisition/posting | [Idea](../ideas/caldova-recruiting-requisition-posting-agent-idea.md) | [Sprint](../plans/2026-10-28-caldova-recruiting-requisition-posting-agent-sprint.md) | [Specification](../specs/2026-10-28-caldova-recruiting-requisition-posting-agent-design.md) | Not established |
| HR Operations | [Idea](../ideas/caldova-hr-operations-agent-idea.md) | [Sprint](../plans/2026-10-28-caldova-hr-operations-agent-sprint.md) | [Specification](../specs/2026-10-28-caldova-hr-operations-agent-design.md) | Not established |
| GitHub authority/Azure Repos secondary | [Idea](../ideas/caldova-azure-devops-repository-idea.md) | [Sprint](../plans/2026-10-28-caldova-azure-devops-repository-sprint.md) | [Specification](../specs/2026-10-28-caldova-azure-devops-repository-design.md) | Not established |
| GitHub-source Azure Pipelines CI/CD | [Idea](../ideas/caldova-azure-devops-solution-cicd-idea.md) | [Sprint](../plans/2026-10-28-caldova-azure-devops-solution-cicd-sprint.md) | [Specification](../specs/2026-10-28-caldova-azure-devops-solution-cicd-design.md) | Not established |
| ESS-equivalent GitHub harness/Work IQ | [Idea](../ideas/caldova-ess-github-harness-workiq-idea.md) | [Sprint](../plans/2026-10-28-caldova-ess-github-harness-workiq-sprint.md) | [Specification](../specs/2026-10-28-caldova-ess-github-harness-workiq-design.md) | [Plan](../plans/2026-10-28-caldova-ess-github-harness-workiq-implementation.md) |
| Blueprint progress overview | [Idea](../ideas/caldova-blueprint-progress-overview-idea.md) | [Sprint](../plans/2026-10-29-caldova-blueprint-progress-overview-sprint.md) | [Specification](../specs/2026-10-29-caldova-blueprint-progress-overview-design.md) | [Plan](../plans/2026-10-29-caldova-blueprint-progress-overview-implementation.md) |
| Grounded GF-source agent identity | [Idea](../ideas/caldova-agent-identity-kit-idea.md) | [Sprint](../plans/2026-10-29-caldova-agent-identity-kit-sprint.md) | [Specification](../specs/2026-10-29-caldova-agent-identity-kit-design.md) | [Plan](../plans/2026-10-29-caldova-agent-identity-kit-implementation.md) |

Read each document's status and unresolved decisions before its candidate backlog.
The [source register](../README.md#caldova-project-and-gf-source-boundary) continues
to distinguish the reviewed build brief from originals still to be supplied on
the agreed SharePoint site.

## 3. Functional scope that has not changed

Policy remains Swiss-first with a regional extension model, not Workday writes.
Recruiting excludes CV screening; its agent-versus-manual Workday action boundary
still requires the source SOP and HR decision. HR Operations retains propose-only
fallback, the add-only/read-before-write controls and unresolved source/capability
gates. Renaming does not activate writes or graduate the separate Caldova use cases.

The ESS-equivalent proposal remains a new build from evaluated Microsoft
references, not a refactor of a deployed baseline. Its six self-only operations
retain governed Workday access, employee-delegated identity, explicit confirmation,
human approval where applicable and operation-specific proof gates. Work IQ
M365 capability is separate from the Workday OAuth audience. Reported GF Privacy
approval is not Caldova approval or proof of tenant enforcement.

The overview covers all eight packages without turning them into eight approved
customer MVPs. The supplied blueprint's three workshop MVPs and wider portfolio
remain distinct.

## 4. Repository and delivery changes

| Surface | Current draft contract |
|---|---|
| GitHub | Sole source, YAML and PR authority; existing validation remains |
| Azure Pipelines | Direct checkout of GitHub for PR/main CI, controlled DEV-capture GitHub PR and reviewed-artifact TEST delivery |
| Azure Repos | Secondary approved-main history, never a second development/PR authority or alternate release source |
| Replication | Separately queued trusted pipeline, exact-source validation, external approval/resource controls, main-only non-force update and read-back |
| Optional local remote | A distinct future `azdo` endpoint, not a second `origin` push URL or implicit dual push |

Equal source/target is NoChange. An initial copy needs approved empty-target
preflight; later updates require safe ancestry/fast-forward. Divergent, unrelated,
behind, ambiguous or unauthorized state blocks. No force/mirror/deletion, reverse
sync or automatic repair is allowed. Reachable history, LFS/submodules, target
privacy/content and credential isolation require review before any copy.

Current GitHub checks cannot be retired until equivalent Azure PR/main results,
actual GitHub required-check blocking, source/artifact identity, retained logs,
ownership/rollback and explicit retirement approval are evidenced. Azure Repos
policies do not gate GitHub PRs. Synthetic PR merge SHA and final main SHA are
not interchangeable artifacts. TEST/PROD identity-byte differences remain an
explicit unresolved release contract.

The actual supplied endpoint stays in session/private configuration, not new
tracked tenant configuration. Confidential unpushed commits must not be published
to public GitHub merely to make them eligible for replication.

## 5. Governance and routing artifacts

| Artifacts | Change and boundary |
|---|---|
| [ADR-0015](../adr/0015-caldova-github-authority-and-azure-repos-secondary.md) | New scoped Proposed Baseline, with separate direct-source CI and secondary-copy responsibilities |
| [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0012](../adr/0012-per-tenant-github-repository-and-account-topology.md) | Proposed-successor annotations only; Approved statuses and historical decisions preserved |
| [ADR-0013](../adr/0013-gf-azure-repos-source-authority.md), [ADR-0014](../adr/0014-gf-ess-workiq-and-self-service-write-envelope.md) | GF historical/customer-scenario scope clarified; not Caldova operational authority |
| [Older connection draft](../specs/2026-09-24-azure-devops-github-single-source-of-truth-design.md) | Superseded, with current repository/CI/CD successors instead of stale current-state claims |
| [Knowledge map](../README.md), [ideas](../ideas/README.md), [plans](../plans/README.md), [specifications](../specs/README.md), [ADRs](../adr/README.md), [reviews](README.md) | Current filenames, status, model summaries and handover routing |
| [Repository blueprint](../../infra/docs/14-github-repository-blueprint.md) | Links proposed extension without activating it or retiring existing validation |
| [Read-only preview](../../.github/agents/blueprint-maintainer.agent.md), [agent catalogue](../../.github/agents/README.md) | Caldova progress/eight-package routing; unchanged name, tools, manual invocation and gated status |
| [Shared instructions](../../.github/copilot-instructions.md), [scoped identity guidance](../../.github/instructions/gf-agent-identity.instructions.md) | Renamed document globs; GF identity guidance remains conditional, not Caldova corporate rebranding |
| [Brand catalogue](../brand/README.md), [kit guide](../brand/gf-agent-identity/README.md), [authored bindings](../brand/gf-agent-identity/agent-bindings.json) | Current project/source distinction and four renamed specification pointers; imported kit untouched |

## 6. Preserved evidence and historical recovery

The [466-file supplied identity source](../brand/gf-agent-identity/README.md),
source manifest, original paths/notices and byte-preservation attributes remain
protected. The original [GF blueprint HTML](../Georg%20Fischer%20Frontier%20Company%20Blueprint.html)
and Caldova CSS/Fluent/mockup assets are not rethemed or regenerated.

The [historical pointer](2026-10-29-gf-project-handover-review.md) explains recovery
of the original full GF report from `a4e4fbcf2cbf84162c1b2e7d6663fe26ad162cd3`.
The original [521-record GF manifest](evidence/2026-10-29-gf-handover/artifact-manifest.json)
is unchanged and applies only to that fixed snapshot.

The new [rename map](evidence/2026-10-29-caldova-document-migration/rename-map.json)
records exactly 27 old/new paths and explicitly normalized maintained-document
hashes. It is not a new exhaustive inventory, GF acceptance record or substitute
for the byte-exact imported-source manifest.

## 7. Verification and known limits

| Check | Evidence/disposition |
|---|---|
| Pre-edit focused baseline | 230 tests passed before this refinement |
| Current focused documentation/identity/navigation/profile suite | 230 passed, zero failed; navigation newline regression resolved by preserving the existing README CRLF format |
| Python identity intake checks | Eight passed, including original-source hashes and four exact identity bindings |
| Exact 27 moves, Draft counts and current path bindings | Eight ideas, eight sprints, eight specifications and three plans verified Draft; four specification pointers resolve |
| 474 protected file byte comparisons and unchanged main/remotes | All protected raw hashes unchanged; primary checkout/main and existing origin-only remote configuration unchanged |
| Mermaid parsing and whitespace/safety checks | 26 diagrams parsed with Mermaid 11.12.1; repository safety and working-tree/index whitespace checks passed |
| Strict branding units after amendment | 60 passed on PowerShell 5.1 and 7; the unit selector is separate from the complete run, which includes the actual-repository case |
| Complete CI-equivalent maintained suite | 53 files, 1,670 tests: 1,667 passed, zero failed, three skipped; no test exclusions |
| Actual retained-source gate | Zero unapproved findings; 524 exact source classifications and seven unchanged evidence approvals |
| Host/link regressions | 23 targeted cases passed on each host; a genuinely failing Python validation is still rejected with its diagnostic |
| Independent review | Attempted but unavailable because the reviewer session lacked local file/Git tools; no independent approval is claimed |

The focused commands below were run from the task worktree and passed. Their
success does not replace the separately reported failed complete-suite result:

```powershell
Import-Module Pester -RequiredVersion 5.7.1
$result = Invoke-Pester -Path @(
    '.github\cli\tests\GfAgentIdentity.Tests.ps1',
    '.github\cli\tests\DocumentationMetadata.Tests.ps1',
    '.github\cli\tests\DocumentationLinks.Tests.ps1',
    '.github\cli\tests\DocumentationNavigation.Tests.ps1',
    '.github\cli\tests\DocsAgentContract.Tests.ps1',
    '.github\cli\tests\BlueprintMaintainerAgent.Tests.ps1',
    'infra\tests\pester\EngineeringControlPlaneDocumentation.Tests.ps1'
) -Output Normal -PassThru
if ($result.Result -ne 'Passed') { throw 'Caldova focused documentation verification failed.' }
python -m unittest discover -s '.github\cli\tests' -p 'test_gf_agent_identity.py' -v
& '.\.github\cli\verify-repository-safety.ps1'
git --no-pager diff --check
git --no-pager diff --cached --check
```

After the scoped amendment, this separate command passes 60 unit cases.
It does not run the actual repository branding case:

```powershell
Invoke-Pester -Path '.github\cli\tests\BrandingContract.Tests.ps1' -Tag BrandingContractUnit -Output Normal -PassThru
```

The local migration check compares the 27 mappings and 474 pre-edit raw hashes;
the separate local parser checks Mermaid syntax, not browser rendering or live
pipeline behavior. Neither check is a deployment result.

The two former immutable-evidence unit failures are resolved by accepting JSON
integer one as either Int32 or Int64, without accepting fractional, string,
Boolean or wrong-count values. The existing seven approved evidence records
are recognized; no exception records were added and unknown occurrences still
block. Equivalent green mandatory CI remains unproven.

### Repository sprint execution assessment

The subsequent request to finish the repository sprint triggered read-only
inspection of the intended Azure target and published GitHub source. The
[sprint execution record](../plans/2026-10-28-caldova-azure-devops-repository-sprint.md)
is **Blocked**, not Done. The private enabled target returned no refs, policies
or project pipelines; accountable ownership, effective permissions and protected
replication approvals remain unverified.

Published GitHub main was `a4e4fbcf2cbf84162c1b2e7d6663fe26ad162cd3`.
Its [required validation run](https://github.com/urruegg/caldova-hr-frontier/actions/runs/40831896096)
failed with three cases: actual branding scan, curated identity validation and
runbook link resolution. These historical published-check findings are distinct
from the later local remediation below. Public source visibility is
not disclosure approval, and local focused passes do not make that source
eligible. No source copy or live setup was performed.

### Local repairs and remaining policy decision

The changed validation files are [BrandingContract.psm1](../../.github/cli/modules/BrandingContract.psm1),
[BrandingContract.Tests.ps1](../../.github/cli/tests/BrandingContract.Tests.ps1),
[GfAgentIdentity.Tests.ps1](../../.github/cli/tests/GfAgentIdentity.Tests.ps1) and
[RunbookDocumentation.Tests.ps1](../../infra/tests/pester/RunbookDocumentation.Tests.ps1).

The Python wrapper now separates progress on stderr from process failure under
Windows PowerShell 5.1 and retains the actual failing exit code and diagnostics.
Runbook link validation decodes URI filenames after separating fragments,
preserving literal plus signs and still rejecting missing files. The branding
parser retains exact count-one validation across both JSON integer types.

The pre-amendment workflow-equivalent maintained Pester run used Windows PowerShell
5.1 and the same discovery as the workflow, without test exclusions. It reported
1,641 passed, one failed and three skipped. The remaining failure is the actual
branding guard; its scan recorded 1,210 blocking path/class pairs across 524 paths.
All five Bicep entry points compile, and repository safety/whitespace checks pass.

The complete-run discovery below was repeated after the approved amendment, using
Windows PowerShell 5.1.26100.9711 and Pester 5.7.1. It passed: 1,667 tests passed,
zero failed and three existing Tenant 1 blueprint-evidence cases were skipped.
The local runner kept `Run.Exit=false` only to save the complete result before
strictly rejecting a non-Passed result; discovery and tests were unchanged:

```powershell
$githubTests = @(
    Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File |
        Sort-Object FullName |
        Select-Object -ExpandProperty FullName
)
Invoke-Pester -Path @($githubTests + @('infra\tests\pester', 'hr\tests\pester')) -Output Normal -CI -PassThru
```

The earlier one-failure result describes the pre-amendment tree. The user subsequently gave
explicit approval on 2026-10-30 for the scoped source-classification amendment.
The [Approved branding design](../specs/2026-10-01-caldova-branding-migration-design.md)
now authorizes a separate hash-pinned exact registry, not new AI Builder evidence
exceptions. The [identity specification](../specs/2026-10-29-caldova-agent-identity-kit-design.md)
records the scope and unchanged runtime/disclosure boundaries.

The implementation binds each reviewed source file to its exact path, raw or
declared UTF-8/LF hash, provenance and path/content class-count sets. Unknown
matches, altered sources, invalid registry data, missing approval and Windows
evidence-path aliases remain blocking. Registry admission is atomic and its
authority comes from the actual Approved policy header and pinned registry hash,
not a self-approval or a status example. All seven evidence records are unchanged.

The new source contracts were observed failing before implementation. Expanded
strict units passed 60 cases on both hosts. Actual source admission passed with
zero findings, 524 exact source records and the seven unchanged evidence
approvals. The full maintained run passed all 1,667 executed cases, with three
maintained evidence-dependent skips. This clears the local branding/validation
blocker; no historical failed result is relabelled as a pass.

Source-classification approval is not disclosure or copying permission. Local
repairs remain uncommitted; the published main check and remaining
ownership/ADR/replication acceptance gates are not closed.

## 8. Recipient actions and decisions

Review the 27 drafts and ratify or reject ADR-0015 before live repository changes.
Complete named ownership, effective security checks and disclosure/history scope
before write-authorizing target preflight or credential configuration. Resolve the individual HR source/API/OAuth/approval
gates before runtime work. Prove Azure check equivalence and protected credential
boundaries before migration or validation retirement. Public publication and
production remain separately gated.
