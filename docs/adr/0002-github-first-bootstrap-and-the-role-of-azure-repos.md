# ADR-0002: GitHub-First Bootstrap, and the Role of Azure Repos

| Field | Value |
|---|---|
| **Version** | 3.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md), [Source Inventory](../reviews/2026-09-17-architecture-baseline-source-inventory.json), [ADR-0012](0012-per-tenant-github-repository-and-account-topology.md) |

## Attended Decision

Approved on 2026-09-28 for **Option A — Lean single-tenant platform**, as defined by
the [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md).
The lean design supersedes the broader remediation topology. This ADR approves a
target and does not authorize a live service mutation.

## Revision Note (v3.0)

Version 3.0 removes the private Azure Repo and automated bootstrap from the current
target. Tenant 1 uses explicit, ignored local configuration with an encrypted,
restore-tested backup outside Git. GitHub remains the only product-source repository.

## Context

ADR-0001 establishes GitHub as the sole product-source authority and Azure Boards as
the single backlog. The superseded remediation design proposed provisioning Azure
DevOps from GitHub, a private Azure Repo for configuration, OIDC bootstrap, and a
protected `bootstrap-tenant1` Environment.

The approved lean design rejects that complexity for the current need. Tenant-private
values still must not enter a public repository, but a second repository and
privileged cloud bootstrap are not justified. The current problem is therefore to
keep private configuration explicit, recoverable, and outside Git while retaining a
simple attended operating model.

---

## Decision

GitHub is the sole product-source and pull-request authority. Azure Boards is the
single delivery backlog and remains on the built-in Basic process. Repository
validation runs in GitHub Actions. A future Azure Pipeline will consume this GitHub
repository directly for HR solution CI/CD; no Azure Pipeline is created this sprint.

Tenant 1 private configuration is an ignored local file with an encrypted,
restore-tested backup outside Git. A private Azure Repo, OIDC bootstrap,
`bootstrap-tenant1` Environment, cloud workflow retrieval, and Basic-to-Agile
conversion are not current targets.
No initial or current mirror is approved.

The tracked `_template.psd1` remains synthetic. Every attended live command receives
the ignored `infra/src/config/tenants/tenant1.local.psd1` through an explicit
`-TenantConfigurationPath`; there is no real-tenant default, repository scan, cloud
retrieval, or template fallback.

Pull requests and successful repository validation remain mandatory. The current
solo-owner profile has zero mandatory approvals and does not require CODEOWNERS
review. Requiring one approval and CODEOWNERS review is deferred until a second
eligible maintainer exists.

---

## Rationale

1. **It preserves the private boundary without a second source location.** The real Tenant 1 file and raw evidence stay outside Git.
2. **It is recoverable.** The external encrypted backup is restore-tested by hash before tracked Tenant 1 material is removed.
3. **It fails closed.** Explicit path and tenant validation stop a live command before external access on absence, ambiguity, or mismatch.
4. **It avoids premature privilege.** No bootstrap identity, federation, cloud retrieval, or service connection is needed for the lean foundation.
5. **It fits the current ownership model.** Zero mandatory approvals avoids a solo-owner deadlock while pull requests, validation, and resolved conversations remain enforced.

---

## Consequences

### Positive

- The public repository can remain free of Tenant 1 private values.
- The active configuration path is explicit and can be validated mechanically.
- Backup and restore proof provide a proportionate recovery control.
- The current sprint creates no privileged cloud bootstrap surface.

### Negative

- **Operator dependency.** Unattended rebuild and cloud bootstrap are unavailable.
- **Local loss risk.** Recovery depends on the encrypted backup being current and restorable.
- **No centrally versioned private configuration.** Changes require attended local discipline and evidence outside Git.

### Mitigations

- Validation rejects tracked `tenant1.local.psd1` and Tenant 1 private values.
- The operator maintains the encrypted backup outside the repository and the workstation's primary failure domain.
- Restore is proven by byte hash and schema validation before tracked Tenant 1 configuration is removed.
- Any later private repository, OIDC bootstrap, required delivery template, or cloud retrieval requires a new reviewed design.

---

## Alternatives Considered

**Create a private Azure Repo for tenant configuration and governed templates.**
Deferred: it adds a second repository and current-sprint controls without evidence of
need. Reconsider only through a new reviewed design.

**Provision Azure DevOps through OIDC bootstrap.** Deferred: it creates privileged
identity and workflow surfaces that the attended local sequence does not require.

**Track real Tenant 1 configuration in GitHub.** Rejected: repository visibility,
history, and replication are incompatible with the private-value boundary.

---

## References

- [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) — the governed intake and bootstrap design; Infrastructure detail enters in Phase 3.
- [ADR-0001](0001-azure-devops-as-engineering-control-plane.md) — the approved source, backlog, and future-delivery split
- [Tenant 1 Lean Engineering Platform Design](../specs/2026-09-28-tenant-1-lean-engineering-platform-design.md)
