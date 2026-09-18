# CLI

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
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

[verify-repository-setup.ps1](verify-repository-setup.ps1) validates repository structure, the protected Superpowers runtime and manifest, the exact issue-form byte snapshot, Git index and working-tree coherence, documentation metadata, governance artifacts, and the repository Pester contracts. It requires Git and exact Pester 5.7.1.

Success exits `0` and writes exactly one line: `Repository setup validation passed.` Failure writes `ERROR:` lines plus a summary and exits nonzero. The corresponding CI entry point is [validate-repository.yml](../workflows/validate-repository.yml).

## Tests

Run the full suite from the repository root in Windows PowerShell with exact Pester 5.7.1:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
Invoke-Pester .github/cli/tests -Output Detailed -CI
```

`-CI` ensures that any failed contract test fails the calling step.
