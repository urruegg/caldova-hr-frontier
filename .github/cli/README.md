# CLI

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |


This folder contains command-line utilities for repository setup, validation, and contributor automation.

Scripts must be non-interactive where practical, document prerequisites, fail with a nonzero exit code, and avoid changing contributor-level configuration.

## Source Inventory

[New-ArchitectureSourceInventory.ps1](New-ArchitectureSourceInventory.ps1) generates deterministic JSON evidence from an assessed architecture source. `-SourceRoot` is required and must identify an existing FileSystem directory without reparse points or nested Git metadata. `-OutputPath` is also required and must resolve outside the source root.

[SourceInventory.psm1](modules/SourceInventory.psm1) owns ordinal path ordering, byte counts, lowercase SHA-256 values, and exact UTC timestamp handling. Output follows [source-inventory.schema.json](schemas/source-inventory.schema.json); the reviewed Phase 1 result is [2026-09-17-architecture-baseline-source-inventory.json](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json).

The generator writes UTF-8 JSON without a byte-order mark, emits `Wrote source inventory: <OutputPath>` after a successful atomic write, and terminates on validation or write failures.

## Documentation Metadata

[DocumentationMetadata.psm1](modules/DocumentationMetadata.psm1) owns repository-relative eligibility, CommonMark-aware H1 detection, the six-field metadata contract, and metadata table construction. [Set-DocumentationMetadata.ps1](Set-DocumentationMetadata.ps1) applies that contract atomically to one eligible repository file and refuses malformed, excluded, external, or reparse-point paths.

Use `-WhatIf` with the setter to review the intended insertion without changing the document. A successful run reports either `Metadata added: <path>` or `Metadata already valid: <path>`; rejected input terminates with a nonzero exit.

## Repository Validation

[verify-repository-safety.ps1](verify-repository-safety.ps1) is the deterministic merge-gate safety scan. It scans every infrastructure PowerShell script and repository workflow for subscription deployment execution and credential-based bootstrap patterns without authenticating or calling cloud services. It also validates every external workflow `uses:` entry against [action-pins.json](../../infra/src/config/github/action-pins.json), rejects mutable or unknown references, and rejects unused manifest entries. Its focused Pester tests validate the scanner against fixtures; the workflow invokes the scanner separately against the real checkout.

Third-party action updates require two reviewed changes: the workflow `uses:` SHA and its matching manifest entry. The manifest records a human-readable source reference for review, but enforcement uses the immutable lowercase 40-character SHA.

External reusable workflows use the same `owner/repository/subpath@sha` policy and require a manifest entry. Repository-local actions and reusable workflows referenced with `./` remain repository content and do not require a third-party pin entry.

[verify-repository-setup.ps1](verify-repository-setup.ps1) performs the comprehensive baseline audit: repository structure, the protected Superpowers runtime and manifest, the exact issue-form byte snapshot, Git index and working-tree coherence, documentation metadata, governance artifacts, and the integrated repository and infrastructure Pester contracts. Its Phase 3 checks cover required infrastructure paths, the Tenant 1 manifest and naming contract, five-service discovery, prohibited data, immutable GitHub OIDC identity, the Bicep resource allowlist and local build, pinned workflow actions and permissions, documentation links, rejected placeholders, and the absence of Tenant 2 and Tenant 3 manifests.

Run it from the repository root with Git, Windows PowerShell, exact Pester 5.7.1, and Azure CLI with the Bicep command installed locally. The validator does not authenticate or call Azure services.

Success exits `0` and writes exactly one line: `Repository setup validation passed.` Failure writes `ERROR:` lines plus a summary and exits nonzero. Use `-SkipIntegratedTests -SkipBicepBuild` only from the advisory [audit-repository.yml](../workflows/audit-repository.yml), where those checks are deliberately skipped to avoid re-running the Pester suites and Bicep build owned by the required [validate-repository.yml](../workflows/validate-repository.yml) gate.

## Tests

Run the full suite from the repository root in Windows PowerShell with exact Pester 5.7.1:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester .github/cli/tests,infra/tests/pester -Output Detailed -CI
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
az bicep build --file infra/src/bicep/main.bicep --stdout
```

`-CI` ensures that any failed contract test fails the calling step.
