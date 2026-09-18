# ADR-0003: Bicep and PowerShell for Infrastructure as Code

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This candidate is not an accepted repository decision until attended review approves it.

## Context

ADR-0002 proposed that the public GitHub repository provisions the Azure DevOps project, and required the bootstrap to be **idempotent and re-runnable**. It recommended Terraform, chiefly because Terraform models idempotency natively and models the two-phase workload-identity-federation service connection flow as a resource pair.

Two requirements have since changed that recommendation:

1. **The organisation's IaC standard is Bicep and PowerShell.** Terraform is not used.
2. **All IaC configuration and source must live under `infra/`** — a single folder where every infrastructure artefact is maintained.

There is also a hard platform constraint that shapes any choice here.

> **There is no Bicep or ARM resource provider for Azure DevOps entities.** Projects, repositories, classification nodes, pipeline environments, approval checks and service connections cannot be expressed in Bicep or ARM at all. This is not a gap in our knowledge of the tooling — no such resource types exist.

So the question is not "Bicep or Terraform". It is "what owns which half of the provisioning surface".

---

## Proposed Decision

**The proposed baseline adopts a two-tool split, both under the future `infra/` area.**

| Tool | Owns | Why |
|---|---|---|
| **Bicep** | Azure resources: resource group, user-assigned managed identity, **federated identity credentials**, Key Vault, storage, Log Analytics | These are ARM resources. Bicep is declarative, idempotent by deployment semantics, and supports what-if preview |
| **PowerShell** | Azure DevOps (REST API), Microsoft Entra objects where a managed identity is not viable, Power Platform (`pac` CLI) | No ARM surface exists for any of these. PowerShell against the REST API is the documented path |

**Proposed folder layout:**

```text
infra/
  README.md
  config/tenants/          # tenant manifests — one per target tenant
  bicep/                   # Azure resources, modules, per-tenant parameter files
  scripts/                 # PowerShell: Azure DevOps, Entra, Power Platform
  tests/                   # Pester tests for the scripts
```

The `bootstrap/` folder proposed in ADR-0002 is **not created** in this baseline. Everything it would have held lives under `infra/` when Infrastructure detail enters in Phase 3.

**Prefer a user-assigned managed identity over an app registration** for the bootstrap identity. A managed identity is an ARM resource, so Bicep can create it *and* its GitHub federated credential in the same deployment. An Entra app registration is not an ARM resource and would need PowerShell or Graph.

---

## Rationale

1. **It matches the organisation's standard.** An IaC estate maintained in two languages, one of which nobody else uses, is a liability regardless of that language's merits.
2. **The split is forced anyway.** Terraform would not have avoided PowerShell entirely — the Power Platform service connection type has no first-class Terraform resource either, and the Azure Boards ↔ GitHub connection has no API at all. Choosing Bicep changes the size of the PowerShell half, not its existence.
3. **Bicep covers the half it can cover well.** Federated identity credentials, Key Vault, storage and managed identities are all first-class ARM resources. `az deployment what-if` gives a genuine plan-and-review step.
4. **No state file to manage.** Terraform state in Azure Storage was an operational dependency and a failure mode — a lost or corrupted state file breaks idempotency. ARM deployments are stateless from our side; the resource graph is the state.
5. **One folder, one owner.** `infra/` as the single home for IaC means a reviewer knows where to look, and `CODEOWNERS` has one path to protect.

---

## Consequences

### Positive

- One IaC toolchain, consistent with the wider estate.
- Bicep `what-if` provides the plan step without a state backend.
- No Terraform provider dependency — notably, the Microsoft-published Azure DevOps provider is absent from Microsoft Learn and its documentation still references a deprecated issuer.
- Managed identity plus Bicep-native federated credentials removes the app-registration bootstrap step in the common case.

### Negative

- **Idempotency becomes our responsibility for the PowerShell half.** Terraform would have provided it; now every script must be written check-then-act. This is the single largest cost of the decision and is addressed explicitly in §Mitigations.
- **No unified plan.** `az deployment what-if` covers Azure only. The Azure DevOps and Power Platform halves have no dry-run unless the scripts implement one.
- **More code to maintain and test.** REST calls, retry logic, polling and error handling are hand-written rather than inherited from a provider.
- **Two languages in one bootstrap**, so the orchestration order matters and must be explicit.

### Mitigations

- Every provisioning script must be **check-then-act** and safe to re-run. A shared helper module should provide the `Get-OrCreate` pattern, retry with backoff, and the asynchronous operation polling that Azure DevOps project creation requires.
- Every script must support **`-WhatIf`** so the bootstrap has a dry-run mode across both halves.
- Scripts should be covered by **Pester tests** under the future `infra/tests/` path, and the test suite should run in the validation workflow.
- A single orchestrator, `Provision-All.ps1`, should own ordering and be the only entry point the workflow calls.
- Re-running the full bootstrap against an already-provisioned tenant is part of the proposed definition of done and must be verified in the acceptance checks.

---

## Alternatives Considered

**Terraform with the `microsoft/azuredevops` provider.** Rejected on the organisation's standard. Would have given native idempotency and a unified plan across Azure and Azure DevOps, at the cost of a second IaC language, a state backend, and a provider that Microsoft publishes but does not document on Learn.

**Bicep plus Azure CLI (`az devops`) instead of REST.** Rejected. The `az devops` extension's authentication behaviour from GitHub Actions is not documented — Microsoft's own pages conflict on whether an `az login` credential flows through, and the quickstart actively steers service-principal automation toward REST or client libraries. There is also no `az` command for pipeline environments or approval checks. PowerShell against REST is the surface Microsoft documents for this case.

**Provision Azure DevOps by hand and use Bicep only for Azure.** Rejected. It contradicts the showcase objective that the whole system be rebuildable from source, and a hand-built control plane cannot be re-created for a second tenant.

---

## References

- [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) — the governed intake and bootstrap design; Infrastructure detail enters in Phase 3.
- [ADR-0002](0002-github-first-bootstrap-and-the-role-of-azure-repos.md) — the proposed GitHub-first bootstrap and repository split
