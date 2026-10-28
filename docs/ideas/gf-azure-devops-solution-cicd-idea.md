# GF Azure DevOps Solution CI/CD and DEV Capture - Idea

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-28 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF technical package: Power Platform DEV capture and TEST delivery |
| **References** | [Specification](../specs/2026-10-28-gf-azure-devops-solution-cicd-design.md), [Sprint](../plans/2026-10-28-gf-azure-devops-solution-cicd-sprint.md), [Repository package](gf-azure-devops-repository-idea.md), [Package index](../README.md#gf-draft-packages) |

## Status and provenance

The user confirmed on 2026-10-28 that Azure DevOps must capture existing solution packages from DEV, unpack them into repository solution source, and build and deploy solutions. DEV capture must be reusable and explicitly triggered, producing a branch and pull request. Initial delivery targets TEST only; production is later scope.

The supplied build brief v1.0 sections 1, 3.7, 4.7 and 5.7 add evaluation-first delivery and reported solution/environment inputs. Those inputs have not been independently inventoried. The user selects Copilot Studio's GitHub Copilot runtime harness for all three agents and excludes ESS.

## Problem and expected value

Maker changes in DEV need a reviewable path into GF's engineering baseline and repeatable TEST delivery. The expected value is traceability from environment capture through accepted source to a deployed artifact, rather than manual exports becoming untracked releases.

## Confirmed idea

Separate controlled DEV capture from CI and CD. Capture proposes source changes; it does not overwrite the protected main branch. Reviewed GF Azure Repos source drives builds and traceable TEST deployment.

Production deployment, production service access and automatic GitHub synchronization are outside this sprint.

## Inputs and dependencies

The independent GF repository is a prerequisite to execution. Solution inventory, DEV and TEST identities, solution types, dependencies, service connections, build tooling and current deployment state have not been verified. This draft does not claim that existing demo pipeline assets work unchanged for GF.

Prove export/unpack/build/import and dependency coverage for this specific harness before claiming deployability. Standard-harness topic YAML, separate prompts and card-node examples in the brief must not become an assumed GitHub-harness implementation contract.

## Open decisions and next review

Confirm the solution capture/packaging contract, export permissions, TEST import permissions, environment-specific configuration, required validation, artifact identity, failure recovery and accountable deployment owner. Demonstrate that unpacked source can produce the agreed deployable artifact; do not assume changing a packaging flag converts solution type.

The specification and sprint retain these as entry gates rather than inventing environment identifiers or implementation commands.

Use the brief's 100% signed-off golden/refusal evaluation target as a proposed promotion gate, not a claim that the FAQ workbook or tests exist locally. CAT Agent Evaluation Designer is a methodology candidate; it is not an automated pipeline runner. Pin any admitted skill/assets alongside the release source, verify their inclusion in the selected export format, and retest after changes. The Cowork-only Test Planner is not a CI dependency. See the [CAT assessment](../README.md#cat-reuse-assessment) and [delivery diagrams](../specs/2026-10-28-gf-azure-devops-solution-cicd-design.md#2-draft-lifecycle).

## Board synchronization

Deferred - not synchronized.
