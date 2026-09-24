# Phase 4 HR Solution Functional Design Intake Review

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [HR Solution Functional Design Intake Design](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

## Review Boundary

Phase 4 is an implementation-intake review of a new, real-named HR solution functional design package that arrived directly in the working tree (13 modified tracked files, 19 untracked new files/directories) rather than as a separate reviewed source directory. Because there was no isolated source directory to hash, this review substitutes a path-by-path git diff/view inspection for the hash-based source inventory used in Phases 1–3; the design basis is [`docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md`](../specs/2026-09-24-hr-solution-functional-design-intake-design.md).

**`infra/` is untouched.** Every path under `infra/` was confirmed byte-for-byte identical to `origin/main` before this review was written (`git diff origin/main -- infra/` — empty). The source package's own infra proposals (a modified `infra/README.md` and three new `infra/docs/`/`.gitkeep` files) were rejected outright: they assumed a lightweight Power Platform DEV/TEST/PROD infra model incompatible with this repository's live Phase 3 subscription-scope Bicep and per-tenant OIDC bootstrap work for Tenant 1 and Tenant 2.

## Confidentiality Disposition

This repository is public. The new content uses the real customer name "Georg Fischer" / "GF" where the existing baseline used the pseudonym "Caldova". **Resolved by the repository owner:** "Caldova" is the umbrella pseudonym for the two practice tenants this repository actively bootstraps (Tenant 1 and Tenant 2); Tenant 3 is the real customer's own tenant, reserved for a future repository handover. The GF-named content in this intake specifically describes that eventual Tenant 3 handover and is not pseudonymized. No content was masked or renamed on confidentiality grounds.

## Publisher Prefix Disposition

The source package hardcoded a single Dataverse publisher prefix, `gf_`, throughout `docs/solution-design.md`, two ADRs, and `hr/README.md`. **Resolved by the repository owner:** the confirmed real values are `calhr` for the Caldova practice tenants (Tenant 1 & 2, verified against the live Power Platform DEV environment for Tenant 1) and `gfhr` for the real customer tenant (Tenant 3). Every `gf_`-prefixed Dataverse logical name was corrected to `gfhr_` (this content describes the Tenant 3 / GF solution specifically), and the surrounding prose now states both tenant-specific values. Existing **ADR-0004** ("Domain Solution Architecture, Naming and Publisher") was not superseded: its actual rule — adopt the one publisher already present in the tenant's supplied solution zip, never create a second one — is tenant-scoped and remains valid; only the previously-documented concrete value (`ur_`) and the new package's concrete value (`gf_`) were both superseded by the confirmed real values.

## Inventory Disposition

| # | Path(s) | Classification | Disposition | Delivery commit |
|---:|---|---|---|---|
| 1 | `docs/adr/adr-0001..0007-*.md` (self-numbered) | `Add` (renamed) | Renamed to `docs/adr/0005..0011-*.md`, avoiding collision with existing `0001-0004`. Self-references and every cross-reference across 39 files corrected, descending order. Required metadata table added. | `a13a311` |
| 2 | `docs/adr/README.md` | `Merge` | Unified 11-record index (4 existing + 7 renumbered). ADR-0004 kept, not superseded — see Publisher Prefix Disposition above. | `66c3f4e` |
| 3 | `docs/operating-model/00-05*.md`, `docs/90-microsoft-best-practice-evaluation.md`, `hr/docs/20-hr-employee-journey.md` | `Merge` | Superseded banner added, Status field changed to `Superseded`; content otherwise untouched and retained for history. | `3dbdd7d` |
| 4 | `docs/README.md` | `Merge` | Adopted the new nav/authority-rule/evidence-rules structure; restored the Infrastructure Domain documentation map and the Documentation Policy statement; added a Superseded (Phase 2) pointer section. | `9242d7b`, `10ca571` |
| 5 | `README.md` | `Merge` | Adopted the new GF HR Agentic Platform product narrative; restored the Repository Agent Workflow (Superpowers) section, the Phase 3 Infrastructure Map, and fixed a stale link to the rejected `infra/docs/30-environment-setup.md`. | `bb083da`, `10ca571` |
| 6 | `.github/copilot-instructions.md`, `AGENTS.md` | `Merge` | Superpowers bootstrap mandate and documentation-policy pointer moved to/retained in `copilot-instructions.md`; `AGENTS.md` became the HR-agent design rules content, per the new package's own stated intent, with a short pointer retained for the repository's required-content contract. | `1b44b3c` |
| 7 | `.github/CODEOWNERS` | `Merge` | Adopted the new per-area ownership breakdown, bound to the real owner `@urruegg`; Tenant 3 ownership explicitly left open pending future handover; wildcard default-owner entry restored. | `aef7846`, `10ca571` |
| 8 | `.gitignore` | `Merge` | Restored the pre-intake baseline (453 lines, including `.wt/`, `/.superpowers/`, the `.vscode/` allowlist); appended only the genuinely new, non-redundant Power Platform/secrets/real-data entries. | `7c03b61` |
| 9 | `.github/ISSUE_TEMPLATE/config.yml`, `.github/pull_request_template.md` | `Merge` | Kept the active Azure Boards link and the HITL "Governance and data rules" link; added the new package's two contact links with real in-repo targets; PR template regained its H1, Work item, Journey stage, Environments affected, and the approved-non-secret-metadata/advisory-audit checklist items alongside the new HR-specific checklist. | `f6dcf60`, `a966e37`, `10ca571` |
| 10 | `.github/agents/README.md` | `Merge` | Corrected the new package's factual claim that the folder is "empty at handover" — it already holds three real agent definitions (docs-agent, cloud-solution-architect, ux-designer) that predate this intake. | `dffc1ac` |
| 11 | `hr/README.md`, `data/README.md` | `Merge` | Adopted the new structure; corrected the publisher-prefix prose (see above); added required metadata tables. | `dffc1ac`, `1a10d03` |
| 12 | `hr/docs/ideas/` (22 files: README + 18 flat use cases + the UC-0001 folder's 3 files) | `Add` | Added as-is after citation fixes; required metadata table added to every file. | `a13a311`, `dffc1ac` |
| 13 | `hr/src/solutions/.gitkeep` | `Reject` | `hr/src/solutions/README.md` already documents the no-payload boundary; the placeholder adds nothing. | `dffc1ac` |
| 14 | `docs/prd.md`, `docs/solution-design.md`, `docs/hr-journey-and-raci.md` | `Add` | Added after citation fixes and the publisher-prefix correction; required metadata table added (missed in the initial add, fixed in `10ca571`). | `a13a311`, `1a10d03`, `10ca571` |
| 15 | `docs/brand/` (README, tokens.css, fluent-theme.ts, mockup.html, assets/.gitkeep) | `Add` | Added as-is; required metadata table added to README.md. | `dc3e82c` |
| 16 | `.github/ISSUE_TEMPLATE/use-case-intake.yml` | `Add` | Added as-is. | `dc3e82c` |
| 17 | `infra/README.md` (modification), `infra/docs/30-environment-setup.md`, `infra/docs/README.md`, `infra/src/{bicep,config,scripts}/.gitkeep` | `PreserveTarget` / `Reject` | Modification reverted, new files discarded. `infra/` confirmed unchanged from `main`. | `dc3e82c` |
| 18 | `.github/cli/verify-repository-setup.ps1`, `.github/cli/tests/IssueFormContract.Tests.ps1`, `.github/cli/tests/Phase2SourceContract.Tests.ps1` | `Merge` (tooling) | Updated hardcoded content/hash contracts to recognize this intake's legitimate governance changes (issue-template set, CODEOWNERS format, PR-template structure) and Phase 2's deliberate supersession, without weakening what they verify. | `10ca571` |

## Reconciliation Result

The seven new-package ADRs were renumbered 0005–0011 to preserve the "numbers are never reused" rule against the existing, unrelated `0001`–`0004` (Azure DevOps/GitHub bootstrap/Bicep/publisher). Every citation across 39 files was corrected in descending-number order; a pre-existing source-material bug (a stray literal `ADR-`/`adr-` prefix embedded inside several filename-portion links, and one line with stale bare-number link text) was also corrected, since it produced links that happened to still resolve under Windows' case-insensitive filesystem but would not resolve elsewhere.

Legacy Phase 2 product/HR content (`docs/operating-model/00-05`, `docs/90-microsoft-best-practice-evaluation.md`, `hr/docs/20-hr-employee-journey.md`) is marked Superseded and retained, not deleted — mirroring the ADR supersession convention. `docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md` and `docs/specs/2026-09-17-architecture-baseline-intake-design.md` are point-in-time historical records and were not edited.

Repository governance files (`.github/copilot-instructions.md`, `AGENTS.md`, `.github/CODEOWNERS`, `.gitignore`, the issue templates, and the PR template) were merged rather than replaced, so the mandatory Superpowers bootstrap instruction, the `.wt/`/`/.superpowers/` ignore rules, the active Azure Boards and HITL governance links, and the tenant-manifest/non-secret-metadata checklist items all survive alongside the new package's HR-solution-specific additions.

**`infra/` is confirmed unchanged from `main`** (`git diff origin/main -- infra/` returns empty). Tenant 1 and Tenant 2 bootstrap work is untouched by this intake.

Every repository-owned markdown file added or rewritten by this intake carries the standard six-field documentation metadata table. This was missed initially on three core documents (`docs/prd.md`, `docs/solution-design.md`, `docs/hr-journey-and-raci.md`) and corrected during validation.

## Known Follow-Up (not addressed in this phase)

The source package's infra-domain proposals (`infra/docs/30-environment-setup.md`'s environment/DLP/publisher/capacity checklist, and its assumption of a lightweight Bicep scope limited to Key Vault/App Insights) describe genuine application-level infrastructure requirements — a DLP policy covering the connector inventory, the Workday Integration System User scope, per-environment connections — that are not yet reconciled against the real Phase 3 tenant-bootstrap implementation. This reconciliation is explicitly deferred to a future phase, once the Tenant 1/Tenant 2 bootstrap workstream reaches the Power Platform environment stage.

## Delivery Evidence

Commits on `urruegg-fix-repository-safety-validation-ci`, in delivery order:

1. `4e70fab` — design Phase 4 HR solution functional design intake (spec)
2. `d90af50` — update spec and plan with the repository owner's confidentiality and prefix decisions
3. `a13a311` — renumber new HR solution ADRs to 0005-0011 and fix all cross-references
4. `66c3f4e` — unify ADR index across governance and HR solution tracks
5. `3dbdd7d` — mark Phase 2 product/HR operating model superseded by Phase 4
6. `9242d7b` — restore infra documentation map and add Phase 2 superseded pointer to docs/README.md
7. `bb083da` — restore Repository Agent Workflow section and metadata table in root README.md
8. `1b44b3c` — restore Superpowers bootstrap mandate in copilot-instructions.md; AGENTS.md becomes HR agent design rules
9. `aef7846` — bind CODEOWNERS to the real repository owner; leave Tenant 3 ownership open pending handover
10. `7c03b61` — restore existing .gitignore rules and append Phase 4 additions
11. `f6dcf60` — merge issue-template and PR-template governance with the new HR solution checklist
12. `dffc1ac` — finish HR/data domain README reconciliation and add use-case portfolio metadata
13. `1a10d03` — correct publisher prefix to confirmed tenant values (calhr / gfhr)
14. `dc3e82c` — add BrandKit and use-case intake template; discard infra-touching changes
15. `a966e37` — restore advisory baseline audit checklist item in PR template
16. `7b27a96` — normalize line endings and trailing blank line for whitespace check
17. `10ca571` — fix validation fallout from the Phase 4 intake

## Validation

- Core contract tests (`WorkflowContract.Tests.ps1`, `RepositorySafety.Tests.ps1`, `infra/tests/pester`, 342 tests): pass.
- `verify-repository-safety.ps1`: `Repository safety validation passed.`
- `az bicep build --file infra/src/bicep/main.bicep --stdout`: succeeds.
- `git diff --check origin/main...HEAD`: clean.
- Advisory repository-setup validator (`verify-repository-setup.ps1`): `Repository setup validation passed.`
- Advisory contract test suite (222 tests, excluding the two required-status suites): zero failures once this review document exists to satisfy the 9 forward references recorded during validation.
- `git diff origin/main -- infra/`: empty.

## Approval Status

This review records implementation-intake disposition for the paths listed above. The confidentiality question and the publisher-prefix question are resolved per the sections above, with the repository owner's explicit confirmation. This review does not itself push this branch to the remote or open a pull request — that remains a separate, explicit action for the repository owner to trigger.
