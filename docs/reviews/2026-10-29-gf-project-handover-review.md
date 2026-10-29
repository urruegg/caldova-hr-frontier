# Georg Fischer HR Agentic Project - Detailed Handover

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF repository handover: eight document packages, ESS design, blueprint preview, grounded identity intake and changed-artifact inventory |
| **References** | [Project knowledge map](../README.md), [Complete changed-artifact manifest](evidence/2026-10-29-gf-handover/artifact-manifest.json), [GF repository target](../specs/2026-10-28-gf-azure-devops-repository-design.md), [Grounded identity kit](../brand/gf-agent-identity/README.md), [Documentation authority](../README.md#authority-and-conflict-order) |

## 1. Executive handover summary

This package is a **design and implementation starting point**, not a delivered HR runtime platform. It provides eight separate GF work-package sets, each with a Draft idea, sprint and specification: twenty-four primary documents. Three work packages also have detailed implementation plans. The repository includes a read-only Blueprint Maintainer preview and a curated identity kit with local validation.

The original blueprint describes three customer workshop MVPs. The eight work packages include technical enablement and a separately proposed ESS-equivalent rebuild; they are not eight GF-approved runtime MVPs or deployed agents.

No live Workday/M365 action, tenant permission change, agent publication, solution identity stamp, pipeline activation or customer acceptance was performed in this work. Document approval for planning is not Privacy/HRIS ratification or runtime release authority.

### Publication and repository snapshot

- The first five-package baseline was committed as `5dd2435f19e6ac1f358ae2b35ce68cc61f0f2ccb`; its parent baseline is `f828eff`.
- On 2026-10-29, local `main` and the configured public GitHub remote's `main` both pointed to that commit before this handover snapshot.
- The new additions include confidential GF-derived blueprint/material and trademark assets. The configured remote is public; these additions are **not approved for public publication by this handover**.
- The requested local snapshot commit can retain the complete work without publishing it. A private authorized GF destination, or a separately reviewed public-safe package, is required before remote transfer.
- This document does not embed its own eventual commit hash. Identify the receiving snapshot from Git history and verify the included artifact manifest rather than inventing a self-referential revision.

GF's intended target remains an independent Azure Repos repository after a reviewed one-time transfer, with no automatic GitHub synchronization. Existing public repository contents do not authorize publishing additional confidential material.

## 2. What the recipient should read first

1. Read this handover and the [eight-package map](../README.md#gf-draft-packages).
2. Select a work package below. Read its idea for intent, sprint for candidate work/gates, and specification for behavior/architecture.
3. For ESS, blueprint or identity rollout, read the corresponding implementation plan only after checking its approval/review status.
4. Read [ADR-0013](../adr/0013-gf-azure-repos-source-authority.md), [ADR-0014](../adr/0014-gf-ess-workiq-and-self-service-write-envelope.md), the [grounded identity guide](../brand/gf-agent-identity/README.md) and source/brand/privacy boundaries before execution.
5. Resolve the blockers in section 9 and verify the exact snapshot with section 10 before accepting or transferring it.

README catalogues route readers; the child's own metadata and governing authority determine its status. A Draft plan, a checkbox or a passing documentation test does not prove a runtime implementation.

## 3. Complete primary document sets

All twenty-four documents below are Draft. Stable package identifiers are navigation keys, not invented Azure Boards IDs.

| Package | Idea | Sprint | Specification |
|---|---|---|---|
| IDEA-GF-POLICY | [SSE HR Policy assistant](../ideas/gf-sse-hr-policy-assistant-idea.md) | [Policy sprint](../plans/2026-10-28-gf-sse-hr-policy-assistant-sprint.md) | [Policy specification](../specs/2026-10-28-gf-sse-hr-policy-assistant-design.md) |
| IDEA-GF-RECRUITING | [Job Requisition and Job Posting agent](../ideas/gf-recruiting-requisition-posting-agent-idea.md) | [Recruiting sprint](../plans/2026-10-28-gf-recruiting-requisition-posting-agent-sprint.md) | [Recruiting specification](../specs/2026-10-28-gf-recruiting-requisition-posting-agent-design.md) |
| IDEA-GF-HR-OPERATIONS | [HR Operations Agent](../ideas/gf-hr-operations-agent-idea.md) | [HR Operations sprint](../plans/2026-10-28-gf-hr-operations-agent-sprint.md) | [HR Operations specification](../specs/2026-10-28-gf-hr-operations-agent-design.md) |
| IDEA-GF-REPOSITORY | [GF Azure DevOps repository](../ideas/gf-azure-devops-repository-idea.md) | [Repository sprint](../plans/2026-10-28-gf-azure-devops-repository-sprint.md) | [Repository specification](../specs/2026-10-28-gf-azure-devops-repository-design.md) |
| IDEA-GF-SOLUTION-CICD | [Solution CI/CD and DEV capture](../ideas/gf-azure-devops-solution-cicd-idea.md) | [CI/CD sprint](../plans/2026-10-28-gf-azure-devops-solution-cicd-sprint.md) | [CI/CD specification](../specs/2026-10-28-gf-azure-devops-solution-cicd-design.md) |
| IDEA-GF-ESS | [ESS-equivalent rebuild](../ideas/gf-ess-github-harness-workiq-idea.md) | [ESS sprint](../plans/2026-10-28-gf-ess-github-harness-workiq-sprint.md) | [ESS specification](../specs/2026-10-28-gf-ess-github-harness-workiq-design.md) |
| IDEA-GF-BLUEPRINT | [Blueprint and progress overview](../ideas/gf-blueprint-progress-overview-idea.md) | [Blueprint sprint](../plans/2026-10-29-gf-blueprint-progress-overview-sprint.md) | [Blueprint specification](../specs/2026-10-29-gf-blueprint-progress-overview-design.md) |
| IDEA-GF-AGENT-IDENTITY | [Grounded identity kit](../ideas/gf-agent-identity-kit-idea.md) | [Identity sprint](../plans/2026-10-29-gf-agent-identity-kit-sprint.md) | [Identity specification](../specs/2026-10-29-gf-agent-identity-kit-design.md) |

### 3.1 Policy assistant

**Intent:** read-only, cited guidance for eligible employees and HR in Switzerland, with HR escalation. Future regional onboarding needs separate sources, access, applicability, languages, owners and evaluation.

**Artifacts add:** an agent canvas, approved-source versus FAQ-test separation, the brief-reported 66-question evaluation input, seven declarations, process/interaction diagrams and evaluation-first sprint dependencies.

**Not delivered/decided:** actual policy/FAQ originals and their approved/current state, effective permissions, named policy owner, support URL, supported languages and deployment evidence. There is no employee-record lookup or transaction in this package.

### 3.2 Recruiting

**Intent:** guided interview, review/edit/generate, job-description/posting preparation and conditional recruiter handoff/scheduling; no CV screening, candidate assessment/ranking or hiring decisions.

**Artifacts add:** source/template/global-item inventory, process/interaction diagrams, explicit generation confirmation, synthetic-event versus live Workday-read distinction, and duplicate/uncertain Outlook handling.

**Critical unresolved question:** `GF-REC-D01` remains with HR stakeholders. Earlier discussion requested approved agent requisition creation/publication; the supplied brief requires manual Workday entry and recruiter publication. Neither path is silently selected as final. No operational Workday-write/publishing envelope is enabled.

### 3.3 HR Operations

**Intent:** Switzerland PeopleDoc-to-Workday proposal process, with approved non-identity fields and a governed add-only Access Layer.

**Artifacts add:** extraction/provenance/confidence, exact-profile comparison, blank/existing/missing status handling, deterministic audit/movement, safety scenarios and stakeholder decision register.

**Current boundary:** propose-only; writes remain blocked. Resolve matching-key conflict, document/field allow-list, pre-write approval versus weekly review, target object/API, confidence/accuracy, delegated/workload identity, transient processing/privacy and failure/file disposition. Do not equate an own-profile REST read with matching/write capability.

### 3.4 GF repository

**Intent:** one-time reviewed transfer into independent GF Azure Repos source/PR authority, separate from the demo GitHub repository and with no automatic synchronization.

**Artifacts add:** source/history inclusion review, private-material/licensing checks, destination ownership and access, effective branch controls, independent checkout/read-back and source cutover evidence.

**Not performed:** destination creation, repository import, permission change, history decision or live handover. GitHub files/protections do not become working Azure DevOps controls simply by copying them.

### 3.5 CI/CD and DEV solution capture

**Intent:** explicit reusable DEV export/unpack into a branch and PR, reviewed-source artifact creation and TEST-only deployment.

**Artifacts add:** capture/build/release separation, concurrent/no-change capture behavior, artifact/source traceability, configuration/dependency/identity gates and failed/uncertain import handling.

**Not performed:** pipeline creation/queue, export/import, service connection or TEST deployment. Prove chosen GitHub-harness source/export/import coverage. Standard-harness export guidance is not portability proof. Production is later scope.

### 3.6 ESS-equivalent rebuild

**Intent:** a new Copilot Studio GitHub-harness ESS-equivalent from Microsoft reference—not migration of an existing deployed source baseline.

**Selected self-only Workday operations:** personal phone, personal email, home address, emergency contact, time-off submission through Workday approval, and employee-reviewed/confirmed Workday Help case creation.

**Architecture:** deterministic workflows and governed Access Layer, employee-delegated OAuth, exact actor/content-bound confirmation, replay/concurrency/reconciliation controls, and per-use-case Work IQ reads/drafts/confirmed M365 actions. Work IQ is not assumed to be a direct Workday connector gateway.

**Reference assessment:** Microsoft ESS Custom Engine, simplified versus legacy Workday authentication, sample versus baseline scenarios, Work IQ policy/tool restrictions and pinned ESS Developer Kit main/declarative versus Custom Engine branches. The kit's ISU/Basic developer MCP is not the selected employee OAuth runtime.

**Not performed:** source implementation, OAuth connection or tool enablement. Formal Privacy/Security scope is user-reported but unverified. Address/emergency-contact updates and Help create/status/routing APIs need actual HRIS evidence. An unanswered policy question never automatically creates a case.

### 3.7 Blueprint overview

**Intent:** derive project progress and reviewed narrative updates from repository records/evidence, with deterministic controlled HTML updates and a same-change stale-output gate. Azure Boards is later scope.

**Artifacts add:** separate document/delivery/verification/acceptance/freshness dimensions, stable package mapping, preservation of original HTML/assets/IDs, safe narrative preconditions, explicit browser-feedback handling and private handover checks.

**Actually present:** a manually selected read/search-only preview profile and its static contract tests. **Not present:** the writer, progress registry, renderer, freshness gate, scheduler or working automatic synchronization. Written-spec review and full portfolio-role activation remain pending.

### 3.8 Grounded identity kit

**Intent:** all GF runtime-agent designs/builds use a versioned grounded identity, not maker-invented names/colours/icons.

**Actually present:** curated v1.0.0 source, exact hashes/notices, four adopted bindings, scoped repository guidance and static validation. Original scripts/pipelines/instructions are inactive text references.

**Approval boundary:** the owner reports GF written approval to adapt; no approval artifact/reference was supplied. Original proposal/N-1 through N-6/G5 questions remain visible. Publisher/solution/schema migration, fail-closed stamping and tenant/published-surface proof are not implied.

## 4. Supporting plans and architecture records

### Implementation plans

| Artifact | Detail and review state |
|---|---|
| [ESS implementation plan](../plans/2026-10-28-gf-ess-github-harness-workiq-implementation.md) | Ten test-first slices covering source/identity proof, synthetic contracts, trusted confirmation/audit, six operations, scoped M365, TEST and business evidence. Written specification reviewed as planning basis; live activation remains gated. |
| [Blueprint implementation plan](../plans/2026-10-29-gf-blueprint-progress-overview-implementation.md) | Provisional nine-task plan covering mappings/contracts, parser/preservation, narrative authority, controlled rendering, freshness checks, role controls, notes and handover. Written-spec review pending. Only read-only preview slice implemented. |
| [Identity implementation plan](../plans/2026-10-29-gf-agent-identity-kit-implementation.md) | Provisional seven-task plan covering intake, owner/legacy-guard policy, supported source mapping, fail-closed adaptation, artifact identity, actual host read-back and handover. Written review pending; intake/guidance/static checks only implemented. |

The first five packages have candidate sprint plans; they do not gain a detailed executable implementation plan by association with these three. Existing unrelated Caldova plans remain under their own authority.

### Architecture decision records

| Changed artifact | Meaning |
|---|---|
| [ADR-0001](../adr/0001-azure-devops-as-engineering-control-plane.md), [ADR-0002](../adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md), [ADR-0012](../adr/0012-per-tenant-github-repository-and-account-topology.md) | Approved demo decisions retain history; GF applicability notes link to the proposed scoped successor rather than rewriting the global model. |
| [ADR-0013](../adr/0013-gf-azure-repos-source-authority.md) | Proposed Baseline GF source/PR authority and independent-transfer refinement; also distinguishes runtime harness from source hosting. No live transfer approved. |
| [ADR-0008](../adr/0008-human-in-the-loop-and-write-envelope.md), [ADR-0009](../adr/0009-workday-access-via-connector-behind-governed-layer.md) | Added links explaining the proposed separate ESS specialization. HR Operations add-only safeguards and Access Layer connector ownership remain intact. |
| [ADR-0014](../adr/0014-gf-ess-workiq-and-self-service-write-envelope.md) | Proposed Baseline scoped Work IQ and six-operation self-service envelope. Formal scope/approval reference, HRIS contracts and effective enforcement remain gates. |
| [ADR catalogue](../adr/README.md) | Routes statuses and scoped successor/specialization references; does not ratify a proposal. |

## 5. Repository guidance, preview agent and navigation

| Changed artifact | What changed / how to use it |
|---|---|
| [Shared Copilot instructions](../../.github/copilot-instructions.md) | Adds the canonical GF runtime identity entry point. Does not globally retheme the demo or authorize stamping/deployment. |
| [Scoped GF identity instructions](../../.github/instructions/gf-agent-identity.instructions.md) | Active repository guidance for matched GF design/source paths; resolves bindings/assets, rejects invented identities and preserves technical/platform gates. Host instruction loading is not certified by static tests. |
| [Blueprint Maintainer profile](../../.github/agents/blueprint-maintainer.agent.md) | Proposed Baseline, manual `user-invocable`, model invocation disabled, tools limited to read/search/task tracking. It can propose changes in chat, not edit/render/run/network/merge/publish. |
| [Repository-agent index](../../.github/agents/README.md) | Separates the gated preview from the existing three operational profiles and pending full-role portfolio amendment. |
| [Knowledge map](../README.md) | Eight-package index, source/publication boundaries, ESS/blueprint/identity navigation and CAT assessment. |
| [Ideas catalogue](../ideas/README.md) | Eight GF intake records, draft statuses and deferred Board synchronization. Does not graduate the nineteen Caldova portfolio IDs. |
| [Specifications catalogue](../specs/README.md) | Owning specification/status and source/gate routing for all eight packages. |
| [Plans catalogue](../plans/README.md) | All eight sprint records plus three supporting implementation plans and explicit authority limits. |
| [Brand index](../brand/README.md) | Separates unchanged Caldova theme from the curated GF identity kit. |
| [Reviews catalogue](README.md) and this handover | Routes the detailed receiving package and exact changed-artifact inventory. This handover is Draft, not recipient acceptance. |

The approved repository-agent portfolio remains the governing reference. A read-only preview is not silent activation of a thirteenth operational writer, and supplied D6 factory identity names do not rename installed repository profiles.

## 6. Supplied blueprint and grounded identity assets

### 6.1 Blueprint

The newly included [Georg Fischer Frontier Company Blueprint.html](../Georg%20Fischer%20Frontier%20Company%20Blueprint.html) is the user-supplied self-contained hypothesis baseline, v0.5 dated 2026-10-28. Its bytes have not been changed by the blueprint or identity work.

Original SHA256:

```text
60952243830052A2C38CB12C4E5E5B1DEF953F10A0B8F8508AEDB74748843F47
```

It contains embedded structured data, renderer/assets and source evidence. No external asset URLs were found in the prior static inspection, but this is not a comprehensive privacy/security certification. Its browser notes remain localStorage-only until explicitly exported and reviewed; copying the HTML does not copy workshop notes.

Retain attribution and embedded assets, do not add a logo or rewrite this baseline as a side effect of handover, and do not infer implementation completion from its hypothesis/validation labels.

The [docs-local Git attribute](../.gitattributes) disables newline conversion for
this exact imported file, preserving its recorded bytes on Windows/Unix checkout.
It does not change whitespace behavior for other documentation or alter the HTML.

### 6.2 Curated identity subtree

Read [the maintained kit guide](../brand/gf-agent-identity/README.md) and [intake manifest](../brand/gf-agent-identity/intake-manifest.json). The latter enumerates **every one of the 466 imported source files**, their original and curated paths, bytes, SHA256 and role.

| Content | Quantity / detail | Treatment |
|---|---|---|
| Source configuration | Three JSON files: [identity catalogue](../brand/gf-agent-identity/config/agent-identity.json), [source schema](../brand/gf-agent-identity/config/agent-identity.schema.json), [palette](../brand/gf-agent-identity/config/palette.json) | Unmodified source bytes; catalogue has 37 identities, not 37 approved runtime agents. |
| Per-agent identities/assets | 433 files under [agents](../brand/gf-agent-identity/agents/) | Per-agent JSON, colour/outline PNG, SVG and visual cards for the source catalogue. Source status/scope remains visible. |
| Brand references | Three files under [brand](../brand/gf-agent-identity/brand/) | Palette CSS and supplied GF logo references; trademark restrictions apply. |
| Visual sheets | Three PNGs under [visuals](../brand/gf-agent-identity/visuals/) | Family overview, MVP identity sheet and colour schema; not delivery evidence. |
| Inactive source references | 24 `.txt` files under [reference](../brand/gf-agent-identity/reference/) | Original docs/code/pipelines/instructions/fixtures retained exactly, not installed or executed. |
| [Adopted bindings](../brand/gf-agent-identity/agent-bindings.json) | Four current runtime mappings | Identity-only adoption, current harness/scope conflicts and unapproved technical-name migration explicitly separated. |
| [Kit guide](../brand/gf-agent-identity/README.md) | Maintained interpretation | Approval/provenance, use rules, limits, validation and future automation gates. |
| [Kit-local Git attributes](../brand/gf-agent-identity/.gitattributes) | Imported subtrees use `-text` | Prevents checkout newline conversion breaking source hashes; repository-wide settings unchanged. |

There are 442 imported asset/config/visual files and 24 inactive reference files. Adding the guide, bindings, intake manifest and Git attributes makes 470 curated subtree files.

### Adopted runtime identities

| Package / source ID | DEV | TEST | PROD |
|---|---|---|---|
| Policy / D3-A01 | HR Policy Assistant DEV | HR Policy Assistant TEST | HR Policy Assistant |
| Recruiting / D1-A01 | Recruiting Job Posting DEV | Recruiting Job Posting TEST | Recruiting Job Posting |
| HR Operations / D2-A01 | HR Ops Master Data CH DEV | HR Ops Master Data CH TEST | HR Ops Master Data CH |
| ESS-equivalent / D3-A02 | HR Ops Self-Service DEV | HR Ops Self-Service TEST | HR Ops Self-Service |

Read exact icon paths from each bound identity's environment object. The source contains 29 environment-scoped runtime identities and 8 repository identities; hypotheses, deferred work and excluded screening are not activated by intake.

The [third-party notice](../brand/gf-agent-identity/reference/THIRD-PARTY-NOTICES.md.txt) retains MIT terms for Fluent glyphs and the GF trademark statement. Neither source inclusion nor adaptation approval is an unrestricted public-distribution licence. Do not hand-edit generated icons/JSON or promote original scripts by dropping `.txt`.

### 6.3 Unchanged reference/application surfaces

The existing [Caldova CSS tokens](../brand/caldova-tokens.css), [Fluent theme](../brand/caldova-fluent-theme.ts) and [mockup](../brand/hr-control-plane-mockup.html) remain unchanged. No code-app retheme, runtime source change, new deployment workflow or logo in the Caldova reserved slot was introduced. The tagged repository validation workflow was not edited.

## 7. Exact changed-artifact inventory

The companion [artifact manifest](evidence/2026-10-29-gf-handover/artifact-manifest.json) is the exhaustive file-level inventory for this local handover snapshot. It covers the first five-package change after `f828eff`, subsequent pending additions, the supplied blueprint, this handover and its catalogue updates.

Each entry records repository-relative path, change classification, hash basis,
bytes, SHA256, artifact category and whether it was already in the `5dd2435`
baseline or added/modified afterward. Imported identity entries also identify
their original package path. Files are listed once; the manifest excludes itself
to avoid a self-hash cycle.

This narrative describes the purpose/status of all artifact families; the manifest provides the exact per-file list and hashes rather than reproducing hundreds of icon filenames in prose. Neither manifest is a proof of runtime quality, approval or customer acceptance.

Use the manifest with the exact receiving snapshot. Imported source assets and
the supplied blueprint use **verbatim bytes**; maintained UTF-8 text uses
**CRLF-to-LF normalization**, so normal Windows/Unix Git checkouts do not create
false differences. `bytes` and `sha256` use that declared basis;
`workingTreeBytesAtInventory` is diagnostic only. Content changes still invalidate
the inventory. Regenerate only through a reviewed inventory change; do not
silently rehash modified source assets.

From the receiving repository root, verify the recorded content without access
to the original workstation:

```powershell
@'
from pathlib import Path
import hashlib, json
root = Path.cwd().resolve()
manifest = json.loads((root / "docs/reviews/evidence/2026-10-29-gf-handover/artifact-manifest.json").read_text(encoding="utf-8"))
for row in manifest["files"]:
    target = (root / row["path"]).resolve()
    target.relative_to(root)
    data = target.read_bytes()
    if row["hashBasis"] == "utf8-lf-normalized":
        data.decode("utf-8-sig")
        data = data.replace(b"\r\n", b"\n")
    elif row["hashBasis"] != "verbatim-source":
        raise SystemExit("Unknown hash basis: " + row["path"])
    if len(data) != row["bytes"] or hashlib.sha256(data).hexdigest() != row["sha256"]:
        raise SystemExit("Artifact differs: " + row["path"])
print("Verified", len(manifest["files"]), "recorded artifacts.")
'@ | python -
if ($LASTEXITCODE -ne 0) { throw 'Receiving handover inventory failed.' }
```

## 8. Validation inventory and commands

### Changed test artifacts

| Artifact | Coverage | Limit |
|---|---|---|
| [BlueprintMaintainerAgent.Tests.ps1](../../.github/cli/tests/BlueprintMaintainerAgent.Tests.ps1) | Six static profile tests: discovery, identification, tools, manual invocation, no hook/delegation route, Proposed status | Not live host invocation or an implemented updater |
| [GfAgentIdentity.Tests.ps1](../../.github/cli/tests/GfAgentIdentity.Tests.ps1) | Runs the actual Python intake suite through maintained Pester discovery | Does not run imported source automation |
| [test_gf_agent_identity.py](../../.github/cli/tests/test_gf_agent_identity.py) | Eight tests covering imported hashes/inventory, source schema, naming/environment behavior, icons/SVG references, contrast, four bindings, inactive automation and Git byte preservation | Not pixel-perfect rendering, complete alpha certification, target stamping or tenant read-back |

### Verification for the final handover snapshot

The following results were observed locally for the handover snapshot on
2026-10-29. They are static/source checks, not GF runtime or customer acceptance.

| Exact command / selector | Result |
|---|---|
| `Invoke-Pester -Path @('.github\cli\tests\GfAgentIdentity.Tests.ps1','.github\cli\tests\DocumentationMetadata.Tests.ps1','.github\cli\tests\DocumentationLinks.Tests.ps1','.github\cli\tests\DocumentationNavigation.Tests.ps1','.github\cli\tests\DocsAgentContract.Tests.ps1','.github\cli\tests\BlueprintMaintainerAgent.Tests.ps1','infra\tests\pester\EngineeringControlPlaneDocumentation.Tests.ps1') -Output Normal -PassThru` | Passed: 230 tests, 0 failures |
| `python -m unittest discover -s '.github\cli\tests' -p 'test_gf_agent_identity.py' -v` | Passed: 8 tests |
| `Invoke-Pester -Path '.github\cli\tests\BrandingContract.Tests.ps1' -Tag BrandingContractUnit -Output None -PassThru` | Failed: 18 passed, 2 known failures, 1 not run; unchanged module/tests verified |
| `& '.\.github\cli\verify-repository-safety.ps1'` | Passed |
| `git --no-pager diff --check` | Passed |
| Receiving inventory/hash, eight-package and unchanged-blueprint/demo checks | Passed locally; recipient must repeat against the received snapshot |

Previous work parsed the Mermaid diagrams in each newly authored package locally; this handover adds no new diagram. That is syntax evidence for those documents, not implementation acceptance. The full maintained CI suite/Bicep builds are not represented by the focused command above.

### Known existing validation failures

The legacy anonymization guard's pre-intake scan reported 87 findings and zero accepted historical exceptions. Its blanket GF-name ban conflicts with intentional customer content. Its unchanged unit tests have two independently reproduced immutable-evidence exception failures:

- `suppresses one exact hash-bound immutable evidence occurrence without disclosing matched content`;
- `leaves an unknown immutable-evidence occurrence as a normal blocking finding`.

The same failures were reproduced with HEAD-equivalent module/tests in an isolated scratch location. This work does not disable the guard, create fabricated exceptions or repair those unrelated pre-existing failures. **Do not claim a green full repository/merge gate.** Source intake adds legitimate customer material that needs a reviewed, narrowly scoped policy disposition before merge/public handover.

## 9. Open decisions and required GF actions

Owners below are required roles, not invented named assignees or commitments.

| Priority / area | Required action | Accountable role to confirm |
|---|---|---|
| Publication and destination | Confirm an authorized private GF repository and allowed transfer inventory, or review/redact a separate public-safe package. Current origin is public. | Repository owner, GF IT and disclosure/Privacy authority |
| Existing validation gate | Resolve immutable-evidence exception failures and approve a narrow customer-identity scope policy; no broad exclusions or rehashed historical evidence. | Repository governance/test owner |
| Document review | Review the provisional blueprint and identity specifications/plans; preserve Draft status until actual disposition. | GF project/technical owners |
| Work IQ | Supply the formal approval reference/scope, permitted workloads/resources/actions and retention; verify effective policies, not defaults. | Privacy/Security and platform owners |
| Recruiting | Resolve GF-REC-D01 creation/submission/publication responsibility with the SOP and HR stakeholders. | People Attraction/Recruiting and HRIS |
| HR Operations | Confirm match key/object, fields/types, approval seam, extraction thresholds, transient processing, identity and failure disposition. | HR Operations, HRIS and Privacy |
| ESS | Prove all six operation contracts, self-only delegated identity and trusted confirmation/replay/concurrency; especially address/contact write and Help case APIs. | HRIS/Workday Help and platform owners |
| Identity | Confirm approval reference, PO/prefix/solution/name/description decisions, actual source/manifest fields and TEST/PROD artifact policy. | GF process/brand and Power Platform owners |
| Blueprint | Approve the full maintainer role, evidence mappings, allowed narrative changes and freshness/renderer implementation; preview cannot update files. | GF project and repository-governance owners |
| Source material | Supply approved SharePoint SOP/FAQ/policy/template/workbook originals; preserve knowledge/test/rule/intake separation. | HR source/process owners |
| Delivery | Establish actual GF environments, connections, permissions, source round-trip, pipeline gate and TEST read-back evidence. | GF IT/release owners |
| Value and acceptance | Set pilot baselines, capacity, scenario priorities, measurable thresholds, support/incident route and named recipient acceptance. | Business/process and operational owners |

No pending identity/API/approval issue is resolved by a hypothetical schema name, logo, policy badge, document existence or agent recommendation.

## 10. Receiving checklist

- [ ] Receive an explicitly authorized private snapshot; do not assume public GitHub publication or an unreviewed full-history clone is appropriate.
- [ ] Read the source/publishing scope and retain a list of excluded private material, evidence, browser notes and configuration.
- [ ] Verify the companion artifact manifest's paths, bytes and SHA256 against the receiving folder.
- [ ] Run the identity intake tests and verify its original 466-file manifest; preserve imported `-text` attributes and all notices.
- [ ] Confirm eight cross-linked primary sets and their actual Draft/Proposed statuses; read only the applicable implementation plan.
- [ ] Confirm original blueprint SHA256 and unchanged demo assets; open the local HTML offline without assuming notes or runtime synchronization transferred with it.
- [ ] Treat Blueprint Maintainer as a manual read-only preview. Verify host loading separately if using it; do not grant writes/commands to bypass its gates.
- [ ] Re-run the exact validation commands, preserve failures and distinguish local static results from live GF/TEST evidence.
- [ ] Resolve the required approvals, source/API/identity decisions and known validation blockers before implementation/release.
- [ ] Record recipient, accepted artifact snapshot, outstanding conditions and support ownership in an authorized acceptance record.

## 11. Handover disposition

**Prepared for review; recipient acceptance and remote publication are not established.** This report inventories the current work, not the completion of every planned implementation slice.

The only implemented additions in this design phase are repository documentation/navigation, static instruction/profile configuration, curated identity assets/bindings and local validation tests. Automatic blueprint updates, identity stamping, runtime agents, Workday/M365 operations and GF deployment pipelines remain unimplemented or unverified as described above.

Do not treat a local commit as public-push permission, GF repository migration or customer acceptance. This Draft and its inventory can support a later authorized private transfer once disclosure and validation gates are dispositioned.
