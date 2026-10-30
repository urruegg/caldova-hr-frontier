# Caldova Blueprint Progress Overview Implementation Plan

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | Caldova project/demo; GF source/customer context: repository overview: controlled projection, evidence checks, gated maintainer and private handover |
| **References** | [Specification](../specs/2026-10-29-caldova-blueprint-progress-overview-design.md), [Sprint](2026-10-29-caldova-blueprint-progress-overview-sprint.md), [Idea](../ideas/caldova-blueprint-progress-overview-idea.md), [Repository-agent portfolio](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md), [Caldova repository target](../specs/2026-10-28-caldova-azure-devops-repository-design.md), [Caldova delivery design](../specs/2026-10-28-caldova-azure-devops-solution-cicd-design.md) |

## Caldova project and GF source boundary

This is a Caldova project/demo document using the explicitly identified GF source/customer scenario. GF facts, approvals, requirements and trademarks remain GF-scoped; project renaming does not establish Caldova corporate policy or runtime acceptance. See the [source and authority boundary](../README.md#caldova-project-and-gf-source-boundary). Existing stable IDs are retained for traceability, not reassigned.

> **For agentic workers:** Use `executing-plans` for inline execution with checkpoints, or `subagent-driven-development` only when explicitly selected. Steps use checkbox syntax. This Draft is not authorization to execute the future writer or renderer.

**Goal:** Keep the existing GF blueprint current at a traceable repository-input snapshot, with evidence-backed progress, reviewed narrative changes, deterministic controlled HTML updates and a reproducible customer handover.

**Architecture:** A manually invoked Copilot maintainer proposes changes; repository records and reviewed evidence remain authoritative. A bounded local parser/validator/builder updates only declared HTML/data regions and provides a non-writing freshness check. Existing validation rejects stale or unsafe results; humans retain scope, acceptance and publication authority.

**Tech stack:** Workspace Copilot custom-agent Markdown, PowerShell entry point, Python standard-library parsing/hashing/atomic-file tooling, existing `jsonschema` dependency, Pester plus Python `unittest`, self-contained HTML/JavaScript and existing repository validation.

**Spec:** [Caldova blueprint overview specification](../specs/2026-10-29-caldova-blueprint-progress-overview-design.md). The user approved the design direction and the read-only preview slice. Written-specification review was requested but the user was unavailable; this plan remains provisional, with that review still pending.

## Global constraints

- Repository sprint/delivery records and verified evidence first; Azure Boards later. No invented external identifier.
- Document status, delivery, environment verification, human acceptance and freshness remain separate.
- The original three workshop MVPs are not expanded by counting technical/proposal work packages.
- Narrative changes need sufficient reviewed authority and exact provenance; no inference that Draft means delivered or approved.
- Preserve imported HTML outside declared managed regions, unapproved blueprint fields, stable IDs, asset values and attribution.
- Browser feedback is explicit user-selected input; never read browser profiles, silently clear notes or equate workshop validation with delivery.
- Current profile is manual read/search/task-only; no edit, execute, web, MCP, tenant, delegation, publication or merge capability.
- Full role, renderer, synchronization and validation integration require written-spec review, scoped portfolio approval and separate execution authorization.
- No new GitHub-only autonomous publisher. Use existing validation and the later Caldova direct GitHub-source Azure Pipelines equivalent.
- No employee data, private configuration, raw evidence, unreviewed browser notes or confidential attachments in projection records or public outputs.
- Check never writes. Failures are explicit; preserve the last good HTML and conflicting/manual edits.
- Same inputs yield identical bytes. Current wall clock, unrelated HEAD changes and generated output must not create self-induced staleness.

## 1. Execution and file ownership

The only implementation approved in the current request is Task 1's gated read-only profile and its contract tests. Tasks 2-9 remain unexecuted future work. First resolve written-specification review and the actual scope of the portfolio companion amendment before enabling any writer.

Use the repository's [external-worktree prerequisite](../../infra/docs/runbooks/01-developer-workstation.md#external-worktree-prerequisite) for future feature execution. Resolve the sibling `wt` root from the primary checkout, prove write/delete access and path budget, and use a reviewed short branch name. Do not change ACLs, enable long paths or remove unrelated worktrees.

The supplied [HTML](../Georg%20Fischer%20Frontier%20Company%20Blueprint.html) is unchanged during current planning. Future source migration is limited to the approved controlled-layer approach, not full generator extraction.

| Intended file | Responsibility |
|---|---|
| `.github\agents\blueprint-maintainer.agent.md` | Gated preview profile now; separately reviewed later role upgrade |
| `.github\agents\README.md` | Distinguish current operational profiles from this proposed preview |
| `.github\cli\tests\BlueprintMaintainerAgent.Tests.ps1` | Exact frontmatter, tool/invocation boundary, status and authority references |
| `.github\blueprint\README.md` | Future input/schema/template ownership and status |
| `.github\blueprint\package-map.json` | Explicit package/document/blueprint ID mappings, no title inference |
| `.github\blueprint\progress.json` | Reported delivery facts, scope, blockers/next actions and evidence references |
| `.github\blueprint\narrative-updates.json` | Field-targeted, preconditioned, source-backed narrative proposals |
| `.github\blueprint\schemas\package-map.schema.json` | Strict package/source mapping contract |
| `.github\blueprint\schemas\progress.schema.json` | Separate progress/verification/acceptance/freshness-related source fields |
| `.github\blueprint\schemas\narrative-updates.schema.json` | Allowed target/field/precondition/provenance contract |
| `.github\blueprint\delivery-panel.js` | Future controlled renderer extension, using text-safe rendering |
| `.github\cli\blueprint\blueprint_overview.py` | Bounded local parse, validation, projection and Check logic |
| `.github\cli\Update-BlueprintOverview.ps1` | Explicit Build/Check wrapper; propagates errors and performs no publication |
| `.github\cli\tests\test_blueprint_overview.py` | Standard-library synthetic parser/projection/freshness tests |
| `.github\cli\tests\BlueprintOverview.Tests.ps1` | Pester wrapper that runs Python tests and fails on a nonzero result |
| `.github\cli\tests\fixtures\blueprint\` | Small synthetic HTML/JSON fixtures, never a copy of the large customer payload |
| `.github\workflows\validate-repository.yml` | Future single added check step after tooling tests pass |
| `docs\Georg Fischer Frontier Company Blueprint.html` | Future controlled output; no change in this planning/preview slice |
| `docs\README.md` and lifecycle catalogues | Route to primary four documents and actual supporting artifacts |

Exact source paths are repository-relative in data. Resolve them inside the repository root; reject absolute paths, traversal, missing files and unreviewed outside-root evidence. An approved external evidence pointer is a reference for human verification, not permission to download or copy it.

## 2. Shared implementation interfaces

These are proposed local tooling interfaces, not existing plugin APIs. Define them in `blueprint_overview.py`; use strict schemas and clear structured diagnostics rather than returning an empty success.

| Function | Inputs | Output and responsibility |
|---|---|---|
| `parse_blueprint(content)` | HTML bytes | Parsed blueprint object, byte-region offsets, schema/ID/version and preservation fingerprints; fails on duplicate/missing/unsupported structure |
| `load_inputs(repository_root)` | Explicit root `Path` | Validated package/progress/narrative inputs and exact referenced source snapshots; no network calls |
| `validate_claims(inputs)` | Validated input collection | Diagnostics for missing/conflicting authority, evidence scope and invalid progress/acceptance transitions |
| `apply_narrative(blueprint, changes)` | Parsed data and declared changes | Candidate data and field-level summary; exact-before/already-applied checks; no arbitrary patch/code execution |
| `build_candidate(content, inputs)` | Original bytes and inputs | Candidate bytes, input fingerprint, summaries and diagnostics; deterministic, does not write |
| `check_candidate(content, inputs)` | Existing output bytes and inputs | `current`, `stale`, `unassessable` or `invalid`, plus exact diagnostics; does not write |
| `replace_if_unchanged(path, expected_hash, candidate)` | Explicit target, expected source hash and validated bytes | Atomic replacement only when the file still matches; otherwise a conflict error |

CLI modes are `Build` and `Check`, with explicit `-RepositoryRoot` and `-BlueprintPath`; default target is the named repository HTML, never a remote URI. Optional input paths must stay under approved configuration roots. Define stable nonzero exit results for invalid/stale/unassessable input and propagate them through PowerShell/CI; success is only a passing check/build.

Record source identity using content hashes and deliberately recorded provenance. Freshness comparisons must not depend on the current HEAD SHA or on whether writing the generated HTML itself makes Git dirty. Snapshot metadata may truthfully record a candidate/dirty source state, but it does not refresh on every invocation. Produce final handover commit/worktree metadata in the external manifest, not as a circular source-output dependency.

## Task 1: Create and test the manual read-only preview

**Files:** create `.github\agents\blueprint-maintainer.agent.md` and `.github\cli\tests\BlueprintMaintainerAgent.Tests.ps1`; update `.github\agents\README.md`.

**Consumes:** the user's explicit preview approval and the Draft specification. **Produces:** one Proposed Baseline profile with no update/command privilege and focused static contract tests. This is the current change's only implemented agent slice.

- [ ] Write the missing-profile/tool-boundary tests first. The exact frontmatter contract is:

```yaml
---
name: blueprint-maintainer
description: "Use when reviewing the GF blueprint, sprint progress, project overview or handover freshness. Gated read-only preview: analyze repository evidence and propose changes without editing or execution."
tools: [read, search, todo]
user-invocable: true
disable-model-invocation: true
---
```

- [ ] Run `Invoke-Pester -Path '.github\cli\tests\BlueprintMaintainerAgent.Tests.ps1' -Output Detailed` and observe failure because the profile does not yet exist.
- [ ] Add the profile with the required six-field metadata, Proposed Baseline/Gated preview status, allowed repository inputs, source/authority distinctions, mandatory proposal output and refusal rules. No model override, remote tool, delegate, write or terminal capability.
- [ ] Document that the profile does not update files or run a renderer/stale gate, and must report missing structured inputs or unavailable checks instead of claiming freshness. Keep the existing three operational profiles unchanged.
- [ ] Re-run the focused tests and documentation metadata/link checks. Static frontmatter validation is not proof that every host has reloaded/invoked the profile; report that limit.
- [ ] Retain for human review. A future commit, only when requested, may use `feat(agents): add gated blueprint maintainer preview` with the required co-author trailer.

## Task 2: Establish source/mapping contracts and honest initial records

**Files:** create `.github\blueprint\README.md`, the three JSON inputs, their three schemas, synthetic fixtures and the Python/Pester tests.

**Consumes:** actual blueprint IDs and repository document inventory. **Produces:** strict, versioned mappings and progress records that preserve unknowns.

- [ ] Add tests before data creation for all eight legacy package IDs, including `IDEA-GF-BLUEPRINT` and `IDEA-GF-AGENT-IDENTITY`, with unique mappings and resolvable Caldova document paths.
- [ ] Require separate `document_status`, `delivery_state`, `verification` and `acceptance` concepts. Initialize absent execution evidence as `Unreported`, not a guessed start/block/completion state. Derive document metadata from owning files rather than copy it as an independent truth.
- [ ] Use a small synthetic progress record for tests:

```json
{
  "package_id": "IDEA-GF-ESS",
  "delivery_state": "Unreported",
  "claim_scope": "runtime",
  "evidence_refs": [],
  "verification": [],
  "acceptance": [],
  "blockers": [],
  "next_actions": []
}
```

- [ ] Reject extra fields, invalid IDs/statuses, duplicate source records, path traversal, arbitrary external identifiers and unsupported claim scopes. Include an explicit distinction between reported assertions and corroborating evidence.
- [ ] Declare inspected blueprint ID mappings explicitly; do not generate new runtime IDs for technical/proposal packages or infer a match from similar names.
- [ ] Run the synthetic tests:

```powershell
python -m unittest discover -s '.github\cli\tests' -p 'test_blueprint_overview.py' -v
if ($LASTEXITCODE -ne 0) { throw 'Blueprint tests failed.' }
```

- [ ] Add a Pester wrapper for this command so existing maintained-test discovery executes it. Use the existing Python schema dependency; install/restore only after the configured runner reports it missing.

## Task 3: Parse and preserve the imported blueprint without executing it

**Files:** implement `parse_blueprint` in `.github\cli\blueprint\blueprint_overview.py`; extend synthetic HTML fixtures/tests.

**Consumes:** HTML bytes, supported schema and structural fingerprints. **Produces:** exact data/managed-region locations and preservation diagnostics.

- [ ] Write failures for absent/duplicate `bp-data`, wrong MIME/schema, malformed JSON, unknown marker versions and unexpected renderer anchors.
- [ ] Use a parser to find exactly one `script#bp-data`; decode data without running JavaScript, loading links or reading browser storage. Preserve byte offsets and unowned bytes.
- [ ] Test a large synthetic payload without logging its encoded asset content. Verify unchanged brand/asset values and renderer attribution through before/after fingerprints.
- [ ] Reject an unsupported upstream plugin/renderer shape rather than recreating the entire generator. No original `build_blueprint.py` is assumed to exist locally.
- [ ] Run tests against fixtures, then perform an explicitly read-only parse of the local imported HTML. Retain the original file hash; do not write it in this task.

## Task 4: Validate evidence and reviewed narrative proposals

**Files:** implement `validate_claims` and `apply_narrative`; extend the three schemas and synthetic tests.

**Consumes:** Task 2 inputs and Task 3 data/schema. **Produces:** reviewed field changes and scoped diagnostics, not invented approvals.

- [ ] Write tests that reject promotion from Draft/checkbox/browser validation into implemented/verified/accepted states without the proper evidence, and reject documentation-only test evidence as runtime verification.
- [ ] Test partial source/DEV evidence without claiming TEST/production acceptance, unavailable evidence, conflicting revisions and unknown owners/dates.
- [ ] Require a narrative target stable ID/allowed field, exact old-value precondition, replacement and authority/source references. Reject executable patch paths, stable-ID/brand/approval-history changes and array-position-only targeting.
- [ ] Test deterministic no-op when the exact desired value/provenance is already applied; conflict when neither old nor desired state matches. Never overwrite an unrelated manual change.
- [ ] Require human disposition through normal repository review. A JSON `approved` or `passed` flag alone cannot authorize a claim.
- [ ] Run tests and produce a field-level proposal summary using synthetic data. Missing authority blocks the affected change and remains visible.

## Task 5: Build the controlled delivery view and narrative projection

**Files:** implement `build_candidate`/`replace_if_unchanged`, create `.github\blueprint\delivery-panel.js`, add synthetic rendering tests; modify the real HTML only after explicit implementation and baseline-update approval.

**Consumes:** validated input/proposals and supported baseline. **Produces:** a self-contained candidate with managed data/display sections, unchanged unowned content and a review summary.

- [ ] Write tests for exact preservation outside managed regions, unchanged unapproved JSON fields/assets, repeat-build identity, failed validation leaving the target untouched and concurrent file changes refusing replacement.
- [ ] Introduce one declared delivery-data block and one managed renderer extension. The existing renderer's `VIEWS`, `ORDER`, `RENDER` and helper functions are inside its closure: validate a single supported insertion point there before extending them. Do not assume a new external script can access those variables.
- [ ] Add a `Project progress` view that shows package kind, document/delivery/verification/acceptance dimensions, blockers/next actions, source links, snapshot state and unverified claims. Preserve the three workshop-MVP distinction.
- [ ] Use text-safe DOM construction. Serialize script data with `<` escaped as `\\u003c`; reject unsafe URL schemes. Do not introduce external assets or a new logo file.
- [ ] Create candidate bytes entirely before writing. Re-read/hash the target, abort on a concurrent change, and atomically replace only the validated expected file. Errors never produce a blank fallback or partial file.
- [ ] Run fixture tests and inspect the explicitly authorized local candidate in a browser with no publication/server requirement. Verify navigation, keyboard focus, readable state labels and evidence links. Report browser checks separately from structural tests.

## Task 6: Implement the read-only stale-output gate

**Files:** implement `check_candidate`, add `.github\cli\Update-BlueprintOverview.ps1`, update `.github\cli\README.md`, and extend Python/Pester tests.

**Consumes:** exact source/input/template snapshots and existing HTML. **Produces:** reproducible read-only Check result and Build wrapper.

- [ ] Write tests for source record changes, missing evidence, unsupported source version, manually conflicting output and unchanged input. Assert no write/mtime change in Check mode, including failures.
- [ ] Compute a canonical fingerprint from relevant source content, input contracts/proposals, template/builder version and unmanaged baseline, excluding generated sections and volatile output metadata.
- [ ] Prove that an unrelated file/commit, the generated file becoming dirty, or a repeated invocation does not cause a freshness loop. Changed relevant input must fail even when the displayed generation date is recent.
- [ ] Wrap Build/Check with explicit local arguments and nonzero error propagation. Do not create a service, watcher, new remote authentication or automatic publisher.
- [ ] Exercise the intended future command only after implementation:

```powershell
& '.\.github\cli\Update-BlueprintOverview.ps1' `
    -Mode Check `
    -RepositoryRoot '.' `
    -BlueprintPath '.\docs\Georg Fischer Frontier Company Blueprint.html'
if ($LASTEXITCODE -ne 0) { throw 'Blueprint overview is stale or unverifiable.' }
```

- [ ] Validate that failure identifies the affected input/claim and retains the last good file. The tool reports current-at-snapshot, not continuous liveness or business acceptance.

## Task 7: Integrate validation and review the full maintainer role

**Files:** modify `.github\workflows\validate-repository.yml`, the scoped agent governance companion/README, profile and its tests only after full-role approval.

**Consumes:** passing Tasks 2-6, written-specification review, portfolio amendment and documentation-cleanup prerequisite evidence. **Produces:** same-change integration protection and an independently accepted update-role boundary.

- [ ] Test the existing pipeline invocation contract before adding one Check step to the existing workflow. No new GitHub Action or autonomous-main publisher.
- [ ] Prove a changed sprint/evidence input fails validation until a valid reviewed projection accompanies it. Gate meaningful source changes, not unrelated history.
- [ ] Record the equivalent check requirement in GF's Azure DevOps delivery mapping; do not create or claim a live pipeline if that package has not established it.
- [ ] Obtain explicit portfolio disposition for the dedicated role and exact allowed paths/commands. Generic agent tool grants are not path enforcement; prove diff/command controls and negative cases before granting write/execute.
- [ ] Keep read-only preview if any control/prerequisite is missing. Never make that profile appear to be a working updater simply by changing its description.
- [ ] Test attempted unrelated file edits, evidence creation, source-status promotion, arbitrary commands, tenant access and merge/publication. They must be impossible or rejected by controls, not merely discouraged in instructions.

## Task 8: Preserve browser notes and validate feedback/version transitions

**Files:** extend parser/validation tooling, feedback fixtures/schema ownership and tests; update blueprint maintenance instructions.

**Consumes:** explicitly selected exported feedback, source blueprint ID/version and reviewer disposition. **Produces:** reviewed proposals and an explicit tested note/version migration procedure.

- [ ] Write tests for wrong blueprint/version, duplicate feedback, unrecognized fields, malicious script text and attempts to turn browser validation into delivery acceptance.
- [ ] Keep feedback separate from shared project progress. Never read a browser profile or upload its localStorage.
- [ ] Before an authorized blueprint ID/version change, require an export/backup, preserve stable keys and demonstrate how the reviewed notes are retained/migrated. Default projection refreshes use a separate delivery snapshot identity.
- [ ] Test version mismatch and cancelled migration without clearing or orphaning source notes. Browser changes remain explicit user actions.
- [ ] Review the feedback proposal under the same narrative/evidence authority rules, then run the relevant structural/browser tests.

## Task 9: Prove a clean, authorized GF handover

**Files:** update maintenance/receiving instructions and validation tests; produce an explicit approved file inventory and hash manifest only in the selected private handover location.

**Consumes:** accepted implementation snapshot, source/authority review and approved disclosure inventory. **Produces:** a clean-folder, self-contained handover candidate and human acceptance evidence.

- [ ] Require an explicit private destination and inventory; do not copy Git history, private configuration, raw evidence, unreviewed notes or source attachments by default.
- [ ] Include the HTML, required linked documents, admitted profile/tooling/schemas, attribution and reproducibility instructions. Preserve relative paths rather than workstation-specific absolute links.
- [ ] Build and verify in a clean receiving folder without the original workstation, localStorage or tenant credentials. Check local navigation, keyboard behavior, source links, visible stale/error state and source/snapshot labels.
- [ ] Record final artifact hashes and actual source/worktree provenance in the external manifest. A customer-audience metadata label is not publication permission.
- [ ] Run the smallest relevant tests, then the documented CI-equivalent suite at integration. Proposed focused commands after implementation are:

```powershell
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1
$result = Invoke-Pester -Path @(
    '.github\cli\tests\BlueprintMaintainerAgent.Tests.ps1',
    '.github\cli\tests\BlueprintOverview.Tests.ps1',
    '.github\cli\tests\DocumentationMetadata.Tests.ps1',
    '.github\cli\tests\DocumentationLinks.Tests.ps1',
    '.github\cli\tests\DocumentationNavigation.Tests.ps1'
) -Output Detailed -PassThru
if ($result.Result -ne 'Passed') { throw 'Blueprint handover verification failed.' }
& '.\.github\cli\verify-repository-safety.ps1'
git --no-pager diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace verification failed.' }
```

- [ ] Obtain named recipient/owner acceptance or report remaining blockers. No public hosting, publication or transfer is implied by a generated bundle.

## 3. Coverage and current handoff status

| Specification responsibility | Tasks |
|---|---|
| Gated profile, tool boundary and proposed portfolio specialization | 1, 7 |
| Explicit package/source mapping and honest status dimensions | 2, 4 |
| Original structure, data, assets, attribution and manual-edit preservation | 3, 5 |
| Reviewed narrative authority and idempotent application | 4, 5 |
| Safe deterministic projection and no false freshness | 5, 6 |
| Same-change validation and Caldova GitHub-source Azure Pipelines compatibility | 7 |
| Browser notes/feedback and version handling | 8 |
| Private disclosure inventory and clean receiving-folder proof | 9 |

Review the written specification and provisional plan before executing Tasks 2-9. No parser/writer, source registers, renderer, freshness gate, scheduler, portal or deployment is implemented by this document. Task 1 creates only a static read-only preview and contract tests; host invocation/loading remains separate from static test evidence.

When implementation is later authorized, use inline execution with checkpoints or explicitly selected subagent-driven slices. Preserve the imported HTML and existing unrelated work until the relevant task is approved.

Board synchronization is Deferred - not synchronized.
