# HR Use Cases

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | HR Use-Case Detail |
| **References** | [Central Ideas](../../../docs/ideas/README.md), [Documentation Knowledge Architecture Cleanup](../../../docs/specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md) |

## Purpose and authority

This folder owns detailed HR packages for use cases that have graduated from the central idea catalogue. Each package can contain the use-case PRD, BoMs, operator guidance, architecture, test material, generators, truth files, and synthetic corpora needed to govern that use case.

The authoritative document depends on the question. A package README routes readers; its PRD governs use-case requirements; approved platform specifications and ADRs remain higher authority; current evidence proves implemented state.

## Contains / does not contain

This folder contains detailed, reviewable artifacts for graduated HR use cases. It does not contain candidate idea records, repository-wide platform requirements, or immutable execution evidence. Candidate and graduated idea records both remain in [`docs/ideas/`](../../../docs/ideas/README.md); AI Builder execution evidence remains in [`hr/evidence/ai-builder/`](../../evidence/ai-builder/README.md).

## Reading order

1. Start with the [central idea catalogue](../../../docs/ideas/README.md).
2. Read the graduated central record for the problem, source, and assessment.
3. Follow the domain-detail link to the package README.
4. Read the package PRD for use-case requirements and its linked BoMs or procedures for the relevant implementation surface.
5. Use current evidence to determine what has passed or exists.

## Naming and lifecycle

- Package folders use `uc-nnnn-<context>/`, matching the retained central idea filename.
- A package is created only when the central idea graduates.
- Detailed artifacts stay with their owning package rather than returning to the central idea root.
- Superseded detail is retained or archived according to the repository documentation lifecycle; it is not silently deleted.

## Complete use-case catalogue

| ID | Package | Status | Purpose | Authority | Central idea |
|---|---|---|---|---|---|
| UC-0001 | [Personal Master Data Completion Agent](uc-0001-personal-master-data-completion-agent/README.md) | Proposed Baseline | Requirements, BoMs, AI Builder setup, architecture, truth, synthetic corpus, and supporting detail for the selected MVP use case | The package PRD is authoritative for UC-0001 requirements; package artifacts govern their named surfaces | [Graduated record](../../../docs/ideas/uc-0001-personal-master-data-completion-agent.md) |

## Domain links

- [Central ideas](../../../docs/ideas/README.md)
- [HR documentation](../README.md)
- [Platform requirements](../../../docs/prd.md)
- [Solution design](../../../docs/solution-design.md)
- [HR journey and RACI](../../../docs/hr-journey-and-raci.md)
