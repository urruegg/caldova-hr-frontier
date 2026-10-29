# GF Grounded Agent Identity Kit Implementation Plan

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF identity adoption: preserved source, runtime bindings, guarded future stamping and verified handover |
| **References** | [Specification](../specs/2026-10-29-gf-agent-identity-kit-design.md), [Sprint](2026-10-29-gf-agent-identity-kit-sprint.md), [Idea](../ideas/gf-agent-identity-kit-idea.md), [Grounded kit](../brand/gf-agent-identity/README.md), [GF delivery design](../specs/2026-10-28-gf-azure-devops-solution-cicd-design.md), [Repository-agent governance](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md) |

> **For agentic workers:** Use `executing-plans` for inline execution with checkpoints, or `subagent-driven-development` only when explicitly selected. Steps use checkbox syntax. This plan is not tenant or pipeline execution authorization.

**Goal:** Ground every GF runtime-agent design/build in the supplied identity kit and later apply verified environment identities without source drift, unknown-component success or unreviewed technical-name changes.

**Architecture:** Preserve imported source/assets and inactive reference code under the brand folder. Use a separate reviewed binding layer and static tests now; introduce a fail-closed source adapter only after target-format and owner decisions. Bind identity/source/output hashes to reviewed artifacts and actual published-surface evidence.

**Tech stack:** JSON configuration/schema, supplied PNG/SVG/CSS assets, existing Python `jsonschema`/`unittest`, Pester 5.7.1, scoped Copilot instructions, and later the established GF Power Platform/Azure DevOps delivery toolchain.

**Spec:** [Identity adoption specification](../specs/2026-10-29-gf-agent-identity-kit-design.md). The user approved curated intake and four mappings. Written-spec review was requested while the user was unavailable; the rollout plan remains provisional, not described as ratified.

## Global constraints

- Preserve original v1.0.0 source bytes, statuses and notices; user-reported written approval is approval to adapt, not evidence that every technical decision is closed.
- Keep Caldova theme/mockup/code app and the supplied blueprint unchanged during intake.
- Current runtime mappings are D3-A01, D1-A01, D2-A01 and D3-A02. Other catalogue agents are not admitted by import.
- Resolve every new GF runtime agent to an approved identity/extension; never invent names, colours, glyphs or stable IDs.
- Source `ess` kind, older descriptions/statuses and D6 role names cannot override current runtime scope, GitHub harness or repository portfolio.
- Keep technical names environment-neutral, but never migrate existing schemas/solutions or choose `gf` versus `gfhr` implicitly.
- Source stamper/generator/pipelines/instructions remain inactive `.txt` references until separately reviewed and implemented.
- No production deployment, tenant rename, icon upload, new GitHub workflow, repository-agent rename, public publication or source normalization is authorized now.
- Do not bypass the existing branding guard with fabricated immutable-evidence exceptions or broad path exclusions.

## 1. Current slice and intended files

The curated intake, binding guidance and static tests are implemented by this request. Remaining tasks are a provisional rollout design; current checks do not prove source stamping, host instruction loading, actual icon readability or tenant identity.

| Path | Ownership |
|---|---|
| `docs\brand\gf-agent-identity\intake-manifest.json` | Exact imported source/destination paths, hashes, sizes and reference/asset roles |
| `docs\brand\gf-agent-identity\config\` | Immutable supplied identity/schema/palette snapshots |
| `docs\brand\gf-agent-identity\agents\`, `brand\`, `visuals\` | Supplied generated assets and visual references |
| `docs\brand\gf-agent-identity\reference\` | Inactive exact source text, including original notices |
| `docs\brand\gf-agent-identity\agent-bindings.json` | Reviewed current runtime mappings and unresolved technical-name/deployment states |
| `.github\instructions\gf-agent-identity.instructions.md` | Scoped design/source guidance, not an automatic mutation tool |
| `.github\cli\tests\test_gf_agent_identity.py` | Actual inventory/schema/naming/assets/contrast/binding tests |
| `.github\cli\tests\GfAgentIdentity.Tests.ps1` | Executes those tests through existing maintained discovery |
| `.github\cli\identity\gf_identity_source.py` | Future separately authored read-only planner/checker and guarded candidate writer, not a renamed upstream `.txt` |
| `.github\cli\Test-GfAgentIdentitySource.ps1` | Future explicit local validation/apply wrapper with error propagation |
| `.github\cli\tests\test_gf_identity_source.py` | Future synthetic target-format, strict matching and atomic behavior tests |
| `.github\cli\tests\fixtures\gf-identity-source\` | Synthetic supported/invalid export fixtures, no real tenant data |
| Existing GF source/pipeline files | Modify only after that delivery package has established exact target paths/contracts |

Use the repository's [external-worktree prerequisite](../../infra/docs/runbooks/01-developer-workstation.md#external-worktree-prerequisite) for later feature execution. Prove sibling `wt` access and path budget; never alter ACLs/long-path settings or discard unrelated work.

## Task 1: Verify curated source and design coverage

**Files:** existing kit/manifest/bindings, scoped instruction, four runtime specifications, repository/delivery/blueprint integration links and existing intake tests.

**Consumes:** supplied v1.0.0 files and the four user-confirmed mappings. **Produces:** source-fidelity/static coverage evidence only.

- [ ] Re-run the actual imported-data suite:

```powershell
python -m unittest discover -s '.github\cli\tests' -p 'test_gf_agent_identity.py' -v
if ($LASTEXITCODE -ne 0) { throw 'Identity source intake is invalid.' }
```

- [ ] Compare every source path/hash to the intake manifest; test that changing an imported icon/config/reference byte fails. Do not repair a mismatch by silently updating its recorded hash.
- [ ] Verify runtime names and icons for all three environments, repository records as clean-only identities, actual contrast and the four specification bindings. Do not map technical work packages as agents.
- [ ] Preserve the source snapshot and its stale behavior metadata; use reviewed integration records for current harness/scope. No direct generated JSON/PNG/SVG edit.
- [ ] Record static pass/fail and remaining visual/tenant/approval gaps. This task's local green result does not enable stamping or close the legacy guard conflict.

## Task 2: Resolve owner decisions and the customer-identity guard policy

**Files:** binding/decision documentation; only after approval, `.github\cli\modules\BrandingContract.psm1`, `.github\cli\tests\BrandingContract.Tests.ps1` and a narrowly reviewed `.github\cli\config\customer-identity-scope.json`.

**Consumes:** source N-1 through N-6/G5, reported adaptation approval and the pre-intake scanner baseline. **Produces:** explicit owner dispositions and, if approved, a tested customer-specific rule rather than a blanket bypass.

- [ ] Confirm the approval reference/scope, process-owner tokens, published descriptions, publisher and existing solution/schema identities. Record a blocked outcome rather than selecting a convenient default.
- [ ] Inventory pre-existing branding failures separately from intended new customer assets; retain the historical evidence-exception integrity checks. A stale historical exception is not permission to rehash evidence.
- [ ] Before any scanner change, write failing synthetic tests for allowed exact reviewed customer files and rejection of an unknown GF-named file, path traversal, modified source bytes, widened pattern classes and an unrelated Caldova file.
- [ ] Require exact customer/profile source and reviewed paths/content identity. No `docs/**` allow-all rule and no allowance inferred merely from a filename starting `gf-`. Keep imported-source integrity checking independent from a policy file that could otherwise bless arbitrary changes.
- [ ] If the scoped policy is not approved, leave scanner behavior unchanged and keep merge/publication readiness blocked. Do not exclude the test to manufacture a green full suite.
- [ ] If approved and implemented, run both scanner unit tests and the current-repository contract; retain explicit failures until the exact existing conflicts are dispositioned.

## Task 3: Prove the selected harness source and exact runtime mappings

**Files:** add synthetic fixtures/tests under the intended paths; update `agent-bindings.json` only from reviewed owner/export evidence, preserving the original supplied configuration.

**Consumes:** Task 2 owner decisions and separately authorized DEV export/read access. **Produces:** actual supported component paths/fields, exact schema-to-identity mappings and no mutation.

- [ ] Write tests for no target components, duplicate/unknown schemas, absent name/icon field, unsupported format, invalid manifests and ambiguous prefix/suffix matches.
- [ ] Inspect a real authorized GitHub-harness export and publication manifest without changing it. The source's classic `bots/*/bot.xml` and community-observed Teams keys are hypotheses until demonstrated.
- [ ] Record exact identity/component mapping after first-save suffix inspection; never reproduce upstream short-suffix guessing. Two matches or missing mapping must block.
- [ ] Resolve actual supported source fields, selected agent count and immutable technical attributes. Missing/unsupported format must return explicit errors, not "nothing to stamp" success.
- [ ] Add redacted synthetic fixtures that reproduce only required structure. No raw export ZIP, real tenant values or personal data in Git.
- [ ] Run:

```powershell
python -m unittest discover -s '.github\cli\tests' -p 'test_gf_identity_source.py' -v
if ($LASTEXITCODE -ne 0) { throw 'Identity source-format contract failed.' }
```

This command is a future task command; its test file does not exist in the current intake.

## Task 4: Implement fail-closed local identity planning and candidate application

**Files:** create `gf_identity_source.py` and the PowerShell wrapper; extend the synthetic tests. Never execute or rename the imported stamper reference into production.

**Consumes:** Task 3 proven structure/mappings and selected environment. **Produces:** a validated candidate plan, optional explicitly applied candidate and structured result.

Define these application interfaces:

| Interface | Contract |
|---|---|
| `plan_identity(source_root, bindings, environment)` | Read-only preflight of every selected component; returns exact required changes, source/icon hashes and errors |
| `check_identity(source_root, expected_plan)` | Non-writing comparison of names/icons/manifests and unselected-content fingerprints |
| `apply_identity(candidate_root, plan)` | Writes only an isolated candidate after complete preflight and source-hash recheck; produces a verified result or no-write failure |

- [ ] Write failures first for missing/unknown/duplicate components, absent name/icon/manifest, missing or tampered assets and wrong environment. All errors must precede the first write.
- [ ] Add a synthetic round-trip test:

```python
def test_missing_required_icon_rejects_without_partial_writes(self):
    before = self.snapshot_bytes()
    result = self.invoke_plan(environment="TEST", fixture="missing-icon")
    self.assertEqual(result["status"], "blocked")
    self.assertEqual(result["changedFiles"], [])
    self.assertEqual(self.snapshot_bytes(), before)
```

`snapshot_bytes` and `invoke_plan` are test helpers using an explicit temporary fixture root and the CLI/API defined in this task, never the source download or a real solution folder.

- [ ] Implement exact unique schema matching, validated source names/icon paths, deterministic serialization and unchanged technical identity/unselected content. Do not accept arbitrary source/asset paths or free-form XML/JSON patch expressions.
- [ ] Build all candidate bytes before writes; recheck source hashes, write an isolated staging tree, verify every planned result and only then hand it to the pack step. On any failure retain the original input; do not partly stamp a live/shared directory.
- [ ] Test non-writing dry run, same-input no-op, PROD clean identity, DEV/TEST correct icons, corrupt PNG/manifest, concurrent change and missing expected agent. Unknown format always blocks.
- [ ] Propagate nonzero exit codes/reports through the wrapper. No silent catches or warning-only success for a required identity field.

## Task 5: Resolve artifact identity and wire the existing validation/release path

**Files:** established GF delivery source/pipeline paths, identity source tests and handover guidance; no guessed new pipeline root or GitHub Actions file.

**Consumes:** Tasks 2-4 and GF CI/CD readiness. **Produces:** explicit identity/source/artifact provenance and release gates.

- [ ] Decide the artifact policy before stamping. TEST/PROD name/icon differences change bytes; select a reviewed paired-artifact or supported external-configuration model and amend the delivery contract if necessary. Do not label different packages identical.
- [ ] Write tests requiring source revision, exact identity/config/icon hashes, environment and packaged artifact identity to match. Reject an untracked post-test stamp/rebuild.
- [ ] Add the intake and admitted source-adapter checks to the existing PR/main validation surface and its GF Azure DevOps equivalent. No duplicate workflow or autonomous publisher.
- [ ] Keep source canonicalization distinct from deploy-time presentation. Do not automatically rewrite DEV source to clean PROD in the capture branch before the supported-source/owner contract is proven.
- [ ] Test denied identity checks blocking candidate acceptance, source changes invalidating evidence and all runtime assets included after source capture/unpack/pack.
- [ ] Leave production deployment outside the current sprint even if its identity variants exist in the kit.

## Task 6: Verify actual Copilot Studio and published non-production surfaces

**Files:** synthetic expectations, minimized observation records and read-back instructions; private raw observations stay outside Git.

**Consumes:** separately authorized TEST deployment/publication, exact candidate/artifact identity and approved test identities. **Produces:** observed identity evidence, not a config-only success.

- [ ] Verify the actual Copilot Studio display name/icon and published Teams/M365 short/full name, accent/colour icon and transparent outline where supported.
- [ ] Check crop/safe area, DEV/TEST labels, tiny-size recognizability, light/dark host rendering, contrast and accessible environment text. Palette calculations alone do not prove perception/rendering.
- [ ] Handle icon caching explicitly: record the observed client/version/time and distinguish not-yet-refreshed from verified. No indefinite retry or fabricated pass.
- [ ] Prove technical identifiers and unrelated functional permissions did not change; branding must not enable Workday writes, change audience or select another harness.
- [ ] Require exact per-agent acceptance or report blocked/not observed. An approved four-agent mapping is not four successful deployments.

## Task 7: Prepare a reproducible, authorized GF handover

**Files:** the four handover documents, kit manifest/bindings/notices and explicit private inventory/validation report.

**Consumes:** actual results from applicable tasks and named owner/recipient disclosure authorization. **Produces:** a clean receiving-folder package and honest remaining-gate register.

- [ ] Include the curated source/assets, notices, mappings and maintained guidance. Keep original scripts/pipelines inactive unless separately admitted; include the evidence of any adaptations.
- [ ] Validate file counts/hashes in a clean receiving folder without the download directory, maker session or credentials. Preserve relative references.
- [ ] Run focused local checks:

```powershell
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1
$result = Invoke-Pester -Path @(
    '.github\cli\tests\GfAgentIdentity.Tests.ps1',
    '.github\cli\tests\DocumentationMetadata.Tests.ps1',
    '.github\cli\tests\DocumentationLinks.Tests.ps1',
    '.github\cli\tests\DocumentationNavigation.Tests.ps1'
) -Output Detailed -PassThru
if ($result.Result -ne 'Passed') { throw 'Identity handover checks failed.' }
& '.\.github\cli\verify-repository-safety.ps1'
git --no-pager diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace validation failed.' }
```

- [ ] Run the documented broader CI suite before integration only after the legacy guard disposition. Report pre-existing failures and future unsupported tasks explicitly; no selective test result becomes a claim that the full suite is green.
- [ ] Obtain human acceptance of the exact inventory, trademark/notices, unresolved decisions and demonstrated deployment scope. No public hosting, source upload or tenant action is implied by a local handover bundle.

## Coverage and current handoff

| Specification contract | Task |
|---|---|
| IDN-01/02 bindings, exact source and current scope | 1-3 |
| IDN-03/05/06 names, markers, contrast and actual visual host checks | 1, 4, 6 |
| IDN-04 technical-name decisions/preservation | 2-4, 6 |
| IDN-07 source/runtime/portfolio distinction | 1-3, 6 |
| IDN-08 fail-closed adapter and artifact contract | 3-5 |
| IDN-09 release hashes and read-back | 5-7 |
| IDN-10 notices, demo/blueprint preservation and disclosure | 1, 7 |

The current request completes curated source intake, four bindings, repository design guidance and static tests only. Source adapter, owner-decision closure, legacy guard scope policy, artifact model and tenant verification are not implemented. Written-spec review is pending; this provisional plan does not authorize its remaining tasks.

If future implementation is authorized, use inline `executing-plans` with checkpoints or explicitly selected subagent-driven slices. Any commit needs the repository co-author trailer and explicit publication/disclosure permission; no commit or push is performed now.

Board synchronization is Deferred - not synchronized.
