# GF Recruiting: Job Requisition and Job Posting Agent - Idea

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-28 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF functional package: recruiting requisition and posting |
| **References** | [Specification](../specs/2026-10-28-gf-recruiting-requisition-posting-agent-design.md), [Sprint](../plans/2026-10-28-gf-recruiting-requisition-posting-agent-sprint.md), [Package index](../README.md#gf-draft-packages) |

## Status and provenance

This is a distinct GF package. Section 4 of the supplied build brief v1.0 has been reviewed; its E20/E21/E22/E43 primary PRD, BOM, SOP and templates have not. Their reported receipt/approval states are not independently verified. See the [source register](../README.md#gf-source-basis-and-publication-boundary).

## Problem and expected value

Improve job-description consistency, reduce repetitive posting preparation and clarify the recruiter handoff. The brief cites an earlier 50% drafting-time reduction target (E06 OLD), not a measured saving or an accepted sprint target. Baselines remain missing.

## Confirmed idea

| Canvas element | Refined draft |
|---|---|
| Agent | D1-A01, Job Requisition and Job Posting agent |
| Users | Hiring managers/HR partners and assigned recruiters; final roles and pilot population require HR confirmation |
| Input | Seven-question interview, GF templates/global-item library and, after confirmed approval, authorized requisition data |
| Reasoning | Clarify vague answers; draft inclusive, job-related content; never invent global items |
| Human checkpoints | Review/edit before explicit generation; requisition/publication responsibilities remain a stakeholder decision; recruiter chooses meeting slot |
| Proposed outputs | Copy-ready description; five posting formats in one recruiter email; scheduling proposals and a meeting only after selection |
| Platform | Copilot Studio, GitHub Copilot runtime harness; workflow owns deterministic controls |

**GF-REC-D01 remains open by explicit user instruction.** The earlier conversation requested agent-created requisitions and approved publication. The brief instead requires manual Workday entry/submission and manual recruiter publication. HR stakeholders must settle the boundary. Neither Workday writes nor publishing automation is authorized by this draft.

CV screening, candidate data/assessment/ranking and hiring decisions remain excluded. Identifying Workday Recruiting in the brief is not proof of working read/event access.

## Source intake

| Expected material | Availability | Required review |
|---|---|---|
| K2.01-K2.05: Templates A-C, clean Job Description template and HR follow-up questions | Described in brief section 4.6; approval/clean-copy work remains | Interview, review, generation, email and invitation contracts |
| K2.06 global items; K2.07 approved samples; K2.08 inclusive-language guidance | Missing/proposed in brief | Do not invent missing library content or treat a placeholder as an approved final description |
| L2.01-L2.04 official guidance | Links/configuration, not uploaded copies | Employer Branding, Job Scoping, Job Requisition/Approval and Hiring Journey |
| Synthetic requisition fixtures | To create | Prototype handoff tests; not a substitute for a live approved-requisition event |

Generated Word files and their storage/retention are optional and undecided. No candidate-screening source belongs in this package.

## Open decisions and next review

Prioritize GF-REC-D01 with HR stakeholders, then confirm question-set ownership, global items, primary roles, approved-requisition event/read scope, language rules, sender/meeting identity, and optional output storage. Keep disputed actions behind the explicit gate.

The [specification](../specs/2026-10-28-gf-recruiting-requisition-posting-agent-design.md#2-process-and-interactions) diagrams show the shared preparation flow and unresolved action boundary. CAT Template-Based Document Generation is a conditional Word-output candidate, not a publishing/Workday skill. The standard-harness Adaptive Card Builder and Cowork-only Test Planner are not drop-in runtime dependencies. See the [CAT assessment](../README.md#cat-reuse-assessment).

## Board synchronization

Deferred - not synchronized.
