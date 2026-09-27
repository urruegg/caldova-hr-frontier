# Customer Repository Export and Handover

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (all tenants) |
| **References** | [ADR-0012](../adr/0012-per-tenant-github-repository-and-account-topology.md), [Multi-Tenant Provisioning](../../infra/docs/18-multi-tenant-provisioning.md), [GitHub Repository Blueprint](../../infra/docs/14-github-repository-blueprint.md), [Tenant Trust Activation Runbook](../../infra/docs/20-tenant-trust-activation-runbook.md), [Azure Boards Population Runbook](../../infra/docs/21-azure-boards-population-runbook.md) |

## Status

Proposed Baseline. This document operationalizes ADR-0012 (itself still Proposed Baseline) into a concrete delivery sprint. It introduces no new architectural decision - the one-repository-per-tenant topology is already recorded - and instead designs the two runbooks and the Tenant 1 completion work needed to execute it safely.

## Objective

ADR-0012 decided that Tenant 1, Tenant 2, and Tenant 3 (Georg Fischer) each get their own dedicated GitHub repository. This document designs **how that split actually happens**, reframed per direction from this sprint's kickoff:

1. **Nothing is deleted yet.** Tenant 2's and Tenant 3's configuration stays in this repository for now. Their removal is written as a separate, reusable runbook - not executed as a one-off cleanup pass.
2. **Tenant 1 finishes first, as the proven blueprint.** This repository completes its target configuration for Tenant 1 alone, and every step is verified end-to-end, before anyone else uses the pattern.
3. **Tenant 2's owner (Andrea Rizzi) validates the handover runbooks themselves**, acting as the first real test of the documentation - not just a second customer, but the dry run that proves the runbook is followable by someone who is not the person who wrote it.
4. **Tenant 3 (Georg Fischer) receives the same, by-then-validated runbooks.**

This produces two outcomes: a proven, working reference configuration (Tenant 1), and a handover process that has already survived one real execution (Tenant 2) before the customer who matters most for revenue (Tenant 3) receives it.

## Scope

### In scope

- Finishing Tenant 1's documented target configuration in this repository - the single-tenant blueprint state, matching ADR-0012's decision that this repository belongs to Tenant 1 alone going forward.
- A **Repository Clean-Up Runbook**: a standalone, tenant-agnostic procedure for removing every other tenant's configuration, evidence, and references from a freshly copied repository. Reusable by any future tenant, not written as a one-time script for Tenant 2 specifically.
- A **Customer Repository Export and Handover Runbook**: the parent procedure a new tenant owner follows end-to-end - create the destination repository, seed it from this one, run the Clean-Up Runbook against it, populate the tenant's own manifest, connect Azure DevOps and Azure Boards, and verify the result.
- Updating the two "shared repository" documents (`infra/docs/14`, `infra/docs/18`) from pending-supersession notes to their corrected, per-tenant description - but only once Tenant 1's blueprint work in this document is itself complete, so the documentation change and the proven design land together.

### Out of scope (this sprint)

- **Actually creating** Andrea Rizzi's repository or Georg Fischer's GitHub Organization and repository. Both require credentials this environment does not hold and remain attended, human-only actions performed by their respective owners, using the runbooks this sprint produces.
- **Removing Tenant 2's or Tenant 3's configuration from this repository.** That happens only when each tenant's owner runs the Clean-Up Runbook against *their own new repository* - never against this one.
- **Live Entra Application, Service Principal, Federated Identity Credential, or GitHub Environment provisioning for Tenant 1.** "Finishing the blueprint" in this sprint means completing the *documented and code-level* target state - tenant manifest, workflows, scripts, verification runbooks - to a state that is provably correct and ready to execute. Actually running that live, security-sensitive provisioning is a separate attended activity, consistent with how every other live-mutation step in this repository's history has required an explicit, present human to trigger it.

## Design

### 1. Tenant 1 blueprint completion

Tenant 1's manifest (`infra/src/config/tenants/caldova25156897.psd1`) already records `Existing` for the GitHub repository, the Azure Subscription, the Azure DevOps project, and all three Power Platform environments - confirmed by discovery evidence collected earlier in this platform's history. It records `Create` for:

- `EntraApplication`, `EntraServicePrincipal`, `EntraFederatedIdentityCredential`
- `GitHubEnvironment`
- `AzureDevOpsServicePrincipalEntitlement`, `AzureDevOpsReadersMembership`

"Finishing the blueprint" means:

- Confirming `Initialize-TenantTrust.ps1` (already built) is the complete, correct, re-runnable path to these six `Create` items, with no gaps found during this sprint's review.
- Confirming the Azure Boards Population Runbook and the live GitHub<->Boards connection (both already completed and verified live earlier this platform's history) are correctly reflected as **done**, not pending, in Tenant 1's manifest and in `infra/docs/18`'s per-tenant status table.
- Producing one document - a **Tenant 1 Blueprint Verification Runbook**, or folded into an existing runbook if that is cleaner once drafted - that an independent reviewer can run to confirm every `Existing`/`Create` claim in Tenant 1's manifest is still true, without re-deriving that knowledge from this whole conversation history.
- This sprint does **not** flip any remaining `Create` item to `Existing` by actually running the live provisioning. It proves the path is complete and correct on paper and in code; running it remains a deliberate, attended, separately-scheduled action.

### 2. Repository Clean-Up Runbook (new, standalone)

A tenant-agnostic procedure, parameterized by "the tenant alias to keep," covering:

- Removing every `infra/src/config/tenants/<other-alias>.psd1` manifest except the one being kept.
- Removing every `infra/evidence/discovery/<other-alias>.json` evidence file except the one being kept.
- Removing any other tenant-scoped artifact discovered during this sprint's review (Bicep parameter files, per-tenant GitHub Environments defined only for reference, etc.) - enumerated exhaustively rather than described vaguely, so the runbook has a checklist a human can tick off, not a paragraph to interpret.
- A verification step: after clean-up, re-running the repository's existing safety/contract tests (`.github/cli/tests/RepositorySafety.Tests.ps1`, the Pester suites under `infra/tests/pester`) to confirm nothing referencing the removed tenant remains and nothing broke.

This runbook is written once and reused by Tenant 2's owner, Tenant 3's owner, and any future tenant - it is explicitly not a one-time script tied to "the Tenant 2 migration."

### 3. Customer Repository Export and Handover Runbook (new, parent procedure)

The end-to-end procedure a new tenant owner follows, referencing the Clean-Up Runbook as one of its steps rather than duplicating its content:

1. Create the destination repository (personal account or GitHub Organization, per that tenant's account-type decision from ADR-0012).
2. Seed it as a one-time copy of the source repository's current state (GitHub's "generate from template," or fork-then-detach) - matching ADR-0012's stated seeding strategy, not a live fork relationship.
3. Run the Repository Clean-Up Runbook against the new repository, keeping only that tenant's own configuration.
4. Populate or correct that tenant's manifest - at minimum, `GitHub.Owner` and `GitHub.Repository` must match the new repository's actual location.
5. Install the Azure Boards GitHub App on the new repository, connected to that tenant's own Azure DevOps organization and project.
6. Run this repository's existing verification tooling (discovery, Pester suites, the live `githubconnections` REST check demonstrated earlier this platform's history) against the new repository to prove the split actually worked, not merely that the files were copied.
7. Record the result: which checks passed, what (if anything) needed manual correction, and the date - so Tenant 3's onboarding can point at Tenant 2's completed record as evidence the runbook works, not merely as documentation that it exists.

### Validation loop

Tenant 2's owner (Andrea Rizzi) runs this runbook as a genuine end-to-end user, not merely a second reader - an owner who did not write the runbook, following it as written. Gaps, ambiguous steps, or missing prerequisites found during that run are corrected in the runbook itself before Tenant 3 (Georg Fischer) receives it. This is the deliberate "validate the runbook once for real before the customer that matters most" sequencing requested for this sprint.

## Open Items (resolved)

- Runbook numbering: assigned as `infra/docs/22-repository-cleanup-runbook.md` and `infra/docs/23-customer-repository-export-and-handover-runbook.md`.
- The Tenant 1 Blueprint Verification was folded into `infra/docs/18-multi-tenant-provisioning.md` (a new "Tenant 1 Blueprint Verification" section) plus a dedicated Pester suite (`infra/tests/pester/TenantBlueprintVerification.Tests.ps1`), rather than becoming a fourth standalone document.
- The Repository Clean-Up Runbook's artifact list is exhaustive only for the three *removable file types* it deletes (tenant config manifests, discovery evidence files, Bicep parameter files) -- not for every tenant-scoped reference in the repository. The runbook's Step 3 now carries an accurate checklist of files with tenant-scoped references that are not removed and must be manually reviewed per tenant; see [`infra/docs/22-repository-cleanup-runbook.md`](../../infra/docs/22-repository-cleanup-runbook.md).

## Verification Plan

1. Tenant 1's manifest and `infra/docs/18`'s per-tenant status table match, and every `Existing` claim in Tenant 1's manifest has a corresponding evidence file or prior verification record cited by this sprint's work.
2. The Repository Clean-Up Runbook, run in a disposable local clone against a synthetic second-tenant fixture, correctly removes only the targeted tenant's files and leaves the kept tenant's files and shared tooling untouched - proven by a passing repository safety/contract test run afterward.
3. `infra/docs/14` and `infra/docs/18` no longer carry a pending-supersession note once their "One Shared Repository" / "Shared-Repository Model" sections are rewritten to describe the per-tenant topology - and ADR-0012's own status may then be reconsidered for promotion from Proposed, since its description now matches the repository's actual documented design.
4. No live GitHub, Azure DevOps, or Entra mutation occurs as part of this sprint's automated work; every live action remains attended and explicitly triggered by a human, consistent with this repository's established governance pattern.
