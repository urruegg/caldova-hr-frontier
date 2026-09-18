# Architecture Baseline Intake Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Design](../specs/2026-09-17-architecture-baseline-intake-design.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute the approved architecture baseline intake as three independently reviewable phases and finish with Tenant 1 OIDC validation, Azure subscription `what-if`, privilege cleanup, and GitHub governance verification.

**Architecture:** Phase 1 establishes deterministic source, documentation, and repository-governance contracts. Phase 2 imports only product, HR, Data, ADR, and operating-model content as Proposed Baseline. Phase 3 adds infrastructure documentation and implementation, performs attended Tenant 1 control-plane bootstrap, and activates the `main` ruleset only after all prior checks succeed. Every phase stops for explicit review before the next begins.

**Tech Stack:** Markdown, Windows PowerShell 5.1, Pester 5.7.1, GitHub Actions, GitHub REST API, Microsoft Graph, Azure CLI, Azure DevOps REST API, Power Platform API and CLI, Bicep, Git

---

## Phase Plans

1. [Governance and GitHub Intake](./2026-09-17-governance-github-intake-implementation.md)
2. [Product, HR, and Operating Model Intake](./2026-09-17-product-hr-operating-model-intake-implementation.md)
3. [Infrastructure and Tenant Bootstrap](./2026-09-17-infrastructure-tenant-bootstrap-implementation.md)

### Task 1: Execute and Review Phase 1

**Files:**
- Plan: `docs/plans/2026-09-17-governance-github-intake-implementation.md`
- Review: `docs/reviews/2026-09-17-phase-1-governance-github-intake.md`

- [ ] **Step 1: Execute every Phase 1 task in order**

Use one implementation subagent per task, followed by specification-compliance and code-quality review. Commit after every completed task; do not batch unrelated task commits.

- [ ] **Step 2: Run the Phase 1 gate**

```powershell
Invoke-Pester .github/cli/tests -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
git diff --check main...HEAD
git diff --exit-code -- .github/skills
```

Expected: all tests pass; validator sole output is `Repository setup validation passed.`; both Git checks are empty.

- [ ] **Step 3: Stop for attended Phase 1 review**

Present the Phase 1 review document, exact commit list, validation output, and residual risks. Do not start Phase 2 until the user explicitly approves the governance, metadata, docs-agent, issue forms, and workflow foundation.

### Task 2: Execute and Review Phase 2

**Files:**
- Plan: `docs/plans/2026-09-17-product-hr-operating-model-intake-implementation.md`
- Review: `docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md`

- [ ] **Step 1: Execute every Phase 2 task in order**

Use the Phase 1 source inventory, metadata, docs-agent, link, and validator contracts. Import no executable solution or infrastructure payload.

- [ ] **Step 2: Run the Phase 2 gate**

```powershell
Invoke-Pester .github/cli/tests -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
git diff --check main...HEAD
if (Test-Path hr/src/solutions/.gitkeep) { throw 'Rejected source placeholder exists.' }
```

Expected: all tests pass; validator sole output is `Repository setup validation passed.`; diff check is empty; rejected placeholder is absent.

- [ ] **Step 3: Stop for attended Phase 2 review**

Present all imported Proposed Baseline documents, authority downgrades, root map changes, the Phase 2 review, and validation evidence. Do not start Phase 3 until the user explicitly approves the content intake.

### Task 3: Execute and Review Phase 3 Code

**Files:**
- Plan: `docs/plans/2026-09-17-infrastructure-tenant-bootstrap-implementation.md`
- Review: `docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md`

- [ ] **Step 1: Execute Phase 3 documentation and local implementation tasks**

Complete Tasks 1 through 8 of the Phase 3 plan using test-driven development. Run no cloud mutation while implementing and testing these tasks.

- [ ] **Step 2: Run the local Phase 3 gate**

```powershell
Invoke-Pester .github/cli/tests,infra/tests/pester -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
az bicep build --file infra/src/bicep/main.bicep --stdout | Out-Null
git diff --check main...HEAD
git diff --exit-code -- .github/skills
```

Expected: all tests pass; validator sole output is `Repository setup validation passed.`; Bicep builds; both Git checks are empty.

- [ ] **Step 3: Stop for code and security review**

Review tenant parsing, discovery allowlisting, OIDC binding, workflow permissions, Bicep scope, exact-ID role cleanup, and no-deployment enforcement. Resolve findings and rerun affected checks before cloud execution.

### Task 4: Execute Attended Tenant 1 Bootstrap

**Files:**
- Follow: Tasks 9 and 10 in `docs/plans/2026-09-17-infrastructure-tenant-bootstrap-implementation.md`

- [ ] **Step 1: Obtain explicit approval for each attended control-plane stage**

Separate approvals are required before:

- creating or changing the Entra application, service principal, or federated credential;
- creating or changing the Tenant 1 GitHub Environment;
- adding the provisioning application to Azure DevOps or any Power Platform environment;
- granting temporary Azure roles;
- deleting the exact temporary Azure role assignments;
- activating or changing the GitHub `main` ruleset.

- [ ] **Step 2: Complete discovery, intent review, trust, and OIDC validation**

Follow the exact Phase 3 commands. Authentication secrets and MFA interaction remain between the user and provider UI; they are never sent to an agent.

- [ ] **Step 3: Complete Tenant 1 `what-if` and cleanup**

Accept only the approved subscription boundary. Do not run a deployment command. Verify both temporary built-in roles are absent before proceeding.

### Task 5: Activate Governance and Complete the Sprint

**Files:**
- Follow: Tasks 11 and 12 in `docs/plans/2026-09-17-infrastructure-tenant-bootstrap-implementation.md`

- [ ] **Step 1: Merge all reviewed implementation through pull request**

The validator workflow must succeed on `main`. Record its GitHub Actions run ID and the successful Tenant 1 bootstrap run ID.

- [ ] **Step 2: Dry-run and approve the final ruleset mutation**

Run `Enable-GitHubGovernance.ps1 -WhatIf`, present the exact REST payload and current/desired diff, and obtain explicit approval before applying it.

- [ ] **Step 3: Verify final local and remote state**

```powershell
Invoke-Pester .github/cli/tests,infra/tests/pester -Output Detailed
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
az bicep build --file infra/src/bicep/main.bicep --stdout | Out-Null
git status --short
gh api repos/urruegg/caldova-hr-frontier/rulesets
gh api repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897
```

Expected: all local checks pass; worktree is clean; ruleset and Environment read-back match reviewed desired state; no temporary Azure role remains; no Azure platform resource or Power Platform solution was deployed.