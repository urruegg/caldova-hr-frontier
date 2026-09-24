# HR Solution Functional Design Intake Design

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed |
| **Scope** | Cross-cutting (docs, hr, data, repository governance) |
| **References** | [Architecture Baseline Intake and Tenant Bootstrap Design](./2026-09-17-architecture-baseline-intake-design.md), [Phase 3 Infrastructure and Tenant Bootstrap Intake](../reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md) |

## Status

Proposed. This design has not yet been reviewed by a human. Execution proceeds on the assumptions stated below where the reviewer was unavailable to confirm them; the disposition of real-customer-name content (see §2) is held pending explicit confirmation before any push to the remote repository.

## Objective

Selectively incorporate a new, real-named HR solution functional design package (product requirements, solution architecture, journey/RACI, architecture decision records, brand kit, and a 19-item use-case portfolio) into the governed repository baseline, while leaving the in-flight Tenant 1 and Tenant 2 infrastructure bootstrap work (`infra/`) completely untouched.

This is Phase 4 of the repository's intake sequence (Phase 1: governance/GitHub, Phase 2: product/HR operating model, Phase 3: infrastructure/tenant bootstrap). It supersedes Phase 2's product/HR content as the authoritative product and solution design, without editing Phase 2's own historical review record.

## Source Package Assessment

The source package arrived as uncommitted working-tree changes (13 modified tracked files, 19 untracked new files/directories) rather than a separate reviewed drop directory. It replaces the pseudonymous "Caldova HR Frontier" product framing with the real customer name **Georg Fischer (GF)** and a concrete architecture: Workday as the system of record, a governed Workday Access Layer in front of Microsoft's Workday connector, a Dataverse process-state boundary, a workflow-first/agent-write-envelope operating model, and three MVP use cases (UC-0001 Personal Master Data Completion Agent, UC-0010 Employee Data Validation, UC-0005 Onboarding Assistant) drawn from a 19-item use-case portfolio.

Principal new content: `docs/prd.md` (19 KB), `docs/solution-design.md` (44.7 KB), `docs/hr-journey-and-raci.md` (18.3 KB), seven ADRs (`docs/adr/adr-0001..0007-*.md`, ~53 KB total), `docs/brand/` (BrandKit: tokens, Fluent 2 theme, guidance), `hr/docs/ideas/` (19 use-case documents, one — UC-0001 — graduated to a folder with a full PRD), and `.github/ISSUE_TEMPLATE/use-case-intake.yml`. It also modifies `infra/README.md` and adds `infra/docs/30-environment-setup.md`, `infra/docs/README.md`, and three `infra/src/*/.gitkeep` placeholders, all assuming a lightweight Power Platform DEV/TEST/PROD infra model that is incompatible with, and unaware of, this repository's actual Phase 3 subscription-scope Bicep / per-tenant OIDC bootstrap implementation.

**No source inventory with hashes was produced**, because there is no isolated read-only source directory to hash — the content is already merged into the working tree. Path-by-path git diff/view review (this document's basis) substitutes for the hash-based inventory used in Phases 1–3.

## Confidentiality Flag (unresolved — held for explicit confirmation)

This repository is **public** (`urruegg/caldova-hr-frontier`, confirmed via `gh repo view`). The new content repeatedly uses the real customer name "Georg Fischer" / "GF" and cites real internal source filenames (a Workday information deck, a Bill of Materials, a use-case spreadsheet). The existing repository baseline deliberately used the pseudonym "Caldova" for this reason, and its own ground rules commit to keeping "tenant-specific values" out of the public repository.

**Decision needed from the repository owner before anything from this intake is pushed to the remote:** keep the real GF name as-is, pseudonymize it back to a placeholder identity, or hold the branch unpushed until reviewed. Absent a response, this intake proceeds through local commits on the working branch only; the push/PR step is explicitly deferred and called out at the end of execution.

## Collision Rules

Same rules as the Phase 1–3 precedent (`docs/specs/2026-09-17-architecture-baseline-intake-design.md`): the repository baseline wins every path collision; intake never performs a directory-wide overwrite; every path is classified `Add`, `Merge`, `PreserveTarget`, or `Reject`.

**`infra/` is `PreserveTarget` for every path, without exception.** No file under `infra/` is modified, added, or removed by this intake, regardless of what the source package proposes there. This includes rejecting the new `infra/docs/30-environment-setup.md`, `infra/docs/README.md`, the modified `infra/README.md`, and the three `infra/src/{bicep,config,scripts}/.gitkeep` placeholders (their target directories already contain real Phase 3 content).

## Intake Architecture

### 1. ADR renumbering (the one mechanical, error-prone step)

The new package's seven ADRs are internally numbered `adr-0001`…`adr-0007` and cross-cited as `ADR-0001`…`ADR-0007` across roughly 15 files (the ADRs themselves, `prd.md`, `solution-design.md`, `docs/README.md`, root `README.md`, `hr/README.md`, `data/README.md`, `.github/copilot-instructions.md`, `.github/pull_request_template.md`, several `hr/docs/ideas/*.md` files, and the UC-0001 folder). This collides with the existing, unrelated `docs/adr/0001`…`0004-*.md` (Azure DevOps, GitHub bootstrap, Bicep/PowerShell, domain-solution-and-publisher).

**Resolution:** renumber the new ADRs to **`0005`–`0011`**, continuing the single existing sequence, per the rule the new content itself states ("numbers are never reused"). Concretely:

| Old (new-package) number | New repository number | File |
|---|---|---|
| ADR-0001 | **ADR-0005** | `adr-0001-workday-as-system-of-record.md` → `0005-workday-as-system-of-record.md` |
| ADR-0002 | **ADR-0006** | `adr-0002-agentic-toolset-and-hr-control-plane.md` → `0006-agentic-toolset-and-hr-control-plane.md` |
| ADR-0003 | **ADR-0007** | `adr-0003-dataverse-process-state-boundary.md` → `0007-dataverse-process-state-boundary.md` |
| ADR-0004 | **ADR-0008** | `adr-0004-human-in-the-loop-and-write-envelope.md` → `0008-human-in-the-loop-and-write-envelope.md` |
| ADR-0005 | **ADR-0009** | `adr-0005-workday-access-via-connector-behind-governed-layer.md` → `0009-workday-access-via-connector-behind-governed-layer.md` |
| ADR-0006 | **ADR-0010** | `adr-0006-organizational-data-service-as-people-context.md` → `0010-organizational-data-service-as-people-context.md` (keeps **Proposed** status) |
| ADR-0007 | **ADR-0011** | `adr-0007-workflow-first-process-architecture.md` → `0011-workflow-first-process-architecture.md` |

Renaming and re-citing must be done **highest number first** (11 → 5) to avoid a second pass double-shifting an already-updated citation. The existing `docs/adr/0001`–`0004-*.md` files, filenames, and content are untouched. Existing **ADR-0004** ("Domain Solution Architecture, Naming and Publisher," `ur_` prefix / `CaldovaHRFrontierHR`) substantively conflicts with the new publisher decision (`gf_` prefix / `GFHRPlatformCore`). No single new ADR states the publisher decision as its own subject — it is asserted in `hr/README.md` and `docs/solution-design.md` §3/§7 instead — so mark ADR-0004 **"Superseded by the reconciled `hr/README.md` and `docs/solution-design.md` (Phase 4 HR Solution Functional Design Intake, see `docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md`)"** rather than pointing to a single ADR number that does not exist. ADR-0001–0003 (engineering control plane, GitHub bootstrap, Bicep/PowerShell tooling) are orthogonal to the HR solution content and require no change.

The merged `docs/adr/README.md` index lists all 11 records: the four existing (with ADR-0004 marked Superseded) plus the seven renumbered new ones, keeping one authoritative table rather than the new package's index that silently drops the existing four.

### 2. Superseded legacy product/HR docs

`docs/operating-model/00-north-star.md` through `05-implementation-roadmap.md`, `docs/90-microsoft-best-practice-evaluation.md`, and `hr/docs/20-hr-employee-journey.md` are logically superseded by `docs/prd.md`, `docs/solution-design.md`, and `docs/hr-journey-and-raci.md` (more concrete, GF-real, and evidenced). Each superseded file gets a short banner added directly under its H1 stating what supersedes it and linking forward — content is kept intact beneath the banner, consistent with the repository's existing ADR-supersession convention extended to non-ADR documents. Nothing is deleted. `docs/README.md`'s active navigation stops listing them as current guidance but gains a short "Superseded (Phase 2)" pointer section so they remain discoverable.

`docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md` and `docs/specs/2026-09-17-architecture-baseline-intake-design.md` are point-in-time historical records and are **not edited** — they remain the accurate account of what Phase 1/2 approved at the time.

### 3. Repository governance files — merge, don't replace

| File | Disposition |
|---|---|
| `.github/copilot-instructions.md` | **Merge.** Retain the mandatory `using-superpowers` bootstrap instruction and the documentation-policy pointer at the top; append the new package's "what this repo is / where to look / evidence rules / six load-bearing claims / naming / tone" content beneath, scoped to the HR solution domain. |
| `AGENTS.md` | **Merge by relocation.** The new draft's own opening table already states repo-work-agent instructions belong in `copilot-instructions.md`. Move the existing Superpowers-workflow and documentation-policy bullets there (folding into the merge above) and let `AGENTS.md` become fully the new HR-platform-agent rules content — with no duplication. |
| `.github/CODEOWNERS` | **Merge.** Keep the new package's per-area ownership breakdown (it is more precise than the current default-owner-only file), but bind every entry to the real, existing owner `@urruegg` instead of the fictional `@gf-*` team handles, which do not exist in this GitHub org and would silently produce no code-owner enforcement. Retain a comment noting real teams can replace `@urruegg` later. |
| `.gitignore` | **Merge, additive only.** Keep every existing rule (notably `.wt/` and `/.superpowers/`, both load-bearing for this repo's tooling); append the new package's Power Platform build-output, secrets, and real-data patterns. |
| `.github/ISSUE_TEMPLATE/config.yml` | **Merge.** Keep the existing, functional Azure DevOps board contact link (infra-owned, in active use) and the governance-doc link (repointed to the new `docs/hr-journey-and-raci.md` §9 / `docs/prd.md` §10 as appropriate); add the new package's "platform design question" and "open decision" contact links, replacing its placeholder `https://github.com/` targets with real in-repo links. |
| `.github/pull_request_template.md` | **Merge.** Keep the existing work-item (`AB#`), environments-affected, infra-ordering, and evidence/secrets checklist items — they remain applicable, including to infra PRs; add the new package's HR/solution-specific checks (ADR non-contradiction, write envelope, Workday Access Layer, no master data outside Workday, seven declarations) as an additional section for changes touching `hr/` or `docs/`. |
| `.github/agents/README.md`, root `README.md`, `docs/README.md`, `hr/README.md`, `data/README.md` | **Merge.** Adopt the new package's structure and content (it is a substantial, well-reasoned improvement), but preserve every existing link that still resolves after this intake (notably to `infra/README.md` and the infra documentation map, which do not change), and use the renumbered ADR citations from §1. |

### 4. Straight additions

`docs/prd.md`, `docs/solution-design.md`, `docs/hr-journey-and-raci.md`, the seven renumbered ADRs, `docs/brand/` (four files plus an empty `assets/.gitkeep`), `hr/docs/ideas/` (19 use-case documents, one graduated folder), and `.github/ISSUE_TEMPLATE/use-case-intake.yml` are added as-is (after the ADR renumbering pass touches their internal citations). `hr/src/solutions/.gitkeep` is rejected — `hr/src/solutions/README.md` already documents the no-payload boundary and the placeholder adds nothing, consistent with the Phase 3 precedent of rejecting `.gitkeep` placeholders where a proper README exists.

### 5. Rejected — infra domain, unconditionally

`infra/README.md` (modification), `infra/docs/30-environment-setup.md`, `infra/docs/README.md`, and `infra/src/{bicep,config,scripts}/.gitkeep` are **not applied**. They assume an infra model (lightweight Power Platform DEV/TEST/PROD, Bicep limited to Key Vault/App Insights) that is incompatible with this repository's live Phase 3 implementation (subscription-scope Bicep, per-tenant manifests, GitHub-Environment-bound OIDC, discovery/bootstrap scripts) for Tenant 1 and Tenant 2. Reconciling the source package's application-level infra requirements (DLP policy covering the connector inventory, publisher prefix, Workday Integration System User scope, per-environment connections) against the real tenant bootstrap work is explicitly out of scope for this phase and is recorded here as a **known follow-up**, to be picked up once the tenant bootstrap workstream reaches the Power Platform environment stage.

## Validation

- `powershell -File .github/cli/verify-repository-setup.ps1` and the core Pester suite (`.github/cli/tests/`, `infra/tests/pester`) must still pass unchanged — this intake does not touch any path they assert on except documentation metadata and link contracts.
- A repository-wide link check (existing `DocumentationLinks.Tests.ps1` pattern, or an equivalent manual grep pass) confirms no citation of a superseded ADR number, no broken relative link introduced by the ADR rename, and no remaining reference to the pre-rename `adr-000N-*` filenames.
- A grep for `ADR-0001` through `ADR-0007` outside `docs/adr/0001`–`0004-*.md` after the rename returns zero matches, confirming the renumbering pass is complete.
- The disposition table in `docs/reviews/` for this phase (written after execution, following the Phase 1–3 review-document precedent) records every path's classification and delivery evidence.

## Completion Criteria

- All `Add` and `Merge` dispositions above are committed on the current branch (`urruegg-fix-repository-safety-validation-ci`, or a new intake branch — confirm during planning), with `infra/` byte-for-byte unchanged.
- A `docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md` review document is written recording the reconciliation decisions and their delivery commits.
- The confidentiality flag (§2) is presented explicitly to the repository owner before any push to the remote or pull request is opened; this intake does not push on its own authority.
