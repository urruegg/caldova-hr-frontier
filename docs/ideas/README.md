# Ideas

| Field | Value |
|---|---|
| **Version** | 2.6 |
| **Date** | 2026-10-29 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Repository Ideas |
| **References** | [Documentation Knowledge Architecture Cleanup](../specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md), [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

## Purpose and authority

This is the single repository-wide intake and catalogue for ideas. An idea records a problem, expected value, source authority, assumptions, and open questions before the repository commits to a specification or implementation.

Idea records are routing and assessment material. They do not override approved requirements, specifications, ADRs, or implementation evidence. The metadata status on each record is authoritative for its lifecycle state; this catalogue must match it.

## Contains / does not contain

This folder contains:

- permanent idea records, including records that have graduated;
- early repository-owned design explorations; and
- companion material that is meaningful only with an idea record.

This folder does not contain:

- detailed domain packages, requirements, BoMs, test guidance, or evidence;
- approved specifications or implementation plans; or
- generated corpora and immutable evidence.

HR-specific delivery detail belongs under [`hr/docs/use-cases/`](../../hr/docs/use-cases/README.md). Repository-wide specifications and plans belong under [`docs/specs/`](../specs/README.md) and [`docs/plans/`](../plans/README.md).

## Reading order

1. Start with the catalogue below.
2. Read the linked central idea record for the problem, source material, value, and assessment.
3. If the record is `Graduated`, follow its domain-detail, governing-specification, and implementation-plan links.
4. Use current evidence, not an idea or plan, to determine what has actually been implemented or verified.

## Naming and lifecycle

- Customer use-case records use `uc-nnnn-<context>.md`; the `UC-nnnn` identifier is stable.
- Other ideas use a descriptive kebab-case filename and do not receive a customer use-case identifier.
- Candidate records normally remain `Draft` or `Proposed Baseline`.
- Selection retains the central record and changes its status to `Graduated`; detailed artifacts move to the owning domain.
- Rejected or obsolete ideas become `Archived`; they are not silently deleted.
- No Azure Boards identifier is inferred. Board synchronization remains deferred until a later, explicit synchronization activity.

## Catalogue

The next-stage column comes before the owned record so automated navigation can identify the final Markdown link in each row deterministically.

| ID | Domain detail and next stage | Idea | Status | Domain | Purpose | Authority | Board synchronization |
|---|---|---|---|---|---|---|---|
| UC-0001 | [HR use-case package](../../hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md); [governing specification](../specs/2026-09-24-hr-solution-functional-design-intake-design.md); [implementation plan](../plans/2026-09-24-hr-solution-functional-design-intake-implementation.md) | [Personal Master Data Completion Agent](uc-0001-personal-master-data-completion-agent.md) | Graduated | HR | Eliminate manual re-keying of personal master data at pre-boarding | Customer-supplied UC-0001 draft PRD and artefact inventory; the central record is orientation | Deferred - not synchronized |
| UC-0002 | Not created | [HR Policy Chat Assistant](uc-0002-hr-policy-chat-assistant.md) | Proposed Baseline | HR | Reduce HR tickets through grounded policy answers | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0003 | Not created | [Employee Self-Service Assistant](uc-0003-employee-self-service-assistant.md) | Proposed Baseline | HR | Provide faster HR responses through guided self-service | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0004 | Not created | [HR Case Classification Bot](uc-0004-hr-case-classification-bot.md) | Proposed Baseline | HR | Improve routing and resolution speed for HR cases | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0005 | Not created | [Onboarding Assistant](uc-0005-onboarding-assistant.md) | Proposed Baseline | HR | Improve the employee onboarding experience | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0006 | Not created | [Job Description Generator](uc-0006-job-description-generator.md) | Proposed Baseline | HR | Accelerate hiring preparation | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0007 | Not created | [Candidate Screening Summary](uc-0007-candidate-screening-summary.md) | Proposed Baseline | HR | Improve hiring quality with evidence-preserving summaries | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0008 | Not created | [Salary Benchmark Assistant](uc-0008-salary-benchmark-assistant.md) | Proposed Baseline | HR | Support pay consistency without automating employment decisions | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0009 | Not created | [Workforce Insights Assistant](uc-0009-workforce-insights-assistant.md) | Proposed Baseline | HR | Shorten the path from workforce data to human decisions | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0010 | Not created | [Employee Data Validation Bot](uc-0010-employee-data-validation-bot.md) | Proposed Baseline | HR | Improve employee-data quality through a governed closed loop | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0011 | Not created | [Learning Recommendation Agent](uc-0011-learning-recommendation-agent.md) | Proposed Baseline | HR | Support employee skill development | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0012 | Not created | [Payroll Anomaly Detection](uc-0012-payroll-anomaly-detection.md) | Proposed Baseline | HR | Reduce payroll errors and compliance risk | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0013 | Not created | [Performance Review Draft Assistant](uc-0013-performance-review-draft-assistant.md) | Proposed Baseline | HR | Improve performance-review draft quality | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0014 | Not created | [Continuous Performance Insights](uc-0014-continuous-performance-insights.md) | Proposed Baseline | HR | Support better human performance decisions | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0015 | Not created | [Leadership Pipeline Prediction](uc-0015-leadership-pipeline-prediction.md) | Proposed Baseline | HR | Improve leadership continuity while retaining human authority | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0016 | Not created | [Skills Inference Engine](uc-0016-skills-inference-engine.md) | Proposed Baseline | HR | Improve workforce skill visibility | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| UC-0017 | Not created | [Pre-hire Process Orchestration](uc-0017-pre-hire-process-orchestration.md) | Proposed Baseline | HR | Close the pre-hire process gap end to end | Customer-supplied HR Ops CH pain points | Deferred - not synchronized |
| UC-0018 | Not created | [Onboarding Checklist Rebuild](uc-0018-onboarding-checklist-rebuild.md) | Proposed Baseline | HR | Replace the onboarding checklist with an owned, usable process | Customer-supplied HR Ops CH pain points | Deferred - not synchronized |
| UC-0019 | Not created | [Attrition Risk Insight Lite](uc-0019-attrition-risk-insight-lite.md) | Proposed Baseline | HR | Support retention improvement without automated employment decisions | Customer-supplied HR AI use-case workbook | Deferred - not synchronized |
| IDEA-HR-CONTROL-PLANE | [HTML companion](hr-control-plane-mockup.html); no committed next stage | [HR Control Plane Mockup](hr-control-plane-mockup-idea.md) | Draft | HR | Explore an operational cockpit for agent runs, field actions, and exceptions | Repository-owned design exploration; non-authoritative | Deferred - not synchronized |

### Caldova project packages

| ID | Domain detail and next stage | Idea | Status | Domain | Purpose | Authority | Board synchronization |
|---|---|---|---|---|---|---|---|
| IDEA-GF-POLICY | [Specification](../specs/2026-10-28-caldova-sse-hr-policy-assistant-design.md); [sprint](../plans/2026-10-28-caldova-sse-hr-policy-assistant-sprint.md) | [Caldova SSE HR Policy assistant](caldova-sse-hr-policy-assistant-idea.md) | Draft | GF HR | Swiss-only cited policy guidance, with future regional onboarding design. | Brief reviewed; primary sources/access gates pending; GitHub runtime harness selected. | Deferred - not synchronized |
| IDEA-GF-RECRUITING | [Specification](../specs/2026-10-28-caldova-recruiting-requisition-posting-agent-design.md); [sprint](../plans/2026-10-28-caldova-recruiting-requisition-posting-agent-sprint.md) | [Caldova Recruiting: Job Requisition and Job Posting agent](caldova-recruiting-requisition-posting-agent-idea.md) | Draft | GF HR | Interview/generation and conditional recruiter handoff; no CV screening. | HR must resolve GF-REC-D01 creation/publication conflict; no operational write envelope approved. | Deferred - not synchronized |
| IDEA-GF-HR-OPERATIONS | [Specification](../specs/2026-10-28-caldova-hr-operations-agent-design.md); [sprint](../plans/2026-10-28-caldova-hr-operations-agent-sprint.md) | [Caldova HR Operations Agent](caldova-hr-operations-agent-idea.md) | Draft | GF HR | Detailed Swiss PeopleDoc-to-Workday proposal process. | Propose-only; matching/approval/data/interface and safety gates block writes. | Deferred - not synchronized |
| IDEA-GF-REPOSITORY | [Specification](../specs/2026-10-28-caldova-azure-devops-repository-design.md); [sprint](../plans/2026-10-28-caldova-azure-devops-repository-sprint.md) | [Caldova GitHub authority and Azure Repos secondary](caldova-azure-devops-repository-idea.md) | Draft | Caldova engineering | Approved GitHub-main history copied separately under manual validation/approval gates. | Proposed ADR-0015; GitHub remains sole source/PR authority, no live replication configured. | Deferred - not synchronized |
| IDEA-GF-SOLUTION-CICD | [Specification](../specs/2026-10-28-caldova-azure-devops-solution-cicd-design.md); [sprint](../plans/2026-10-28-caldova-azure-devops-solution-cicd-sprint.md) | [Caldova Azure DevOps solution CI/CD and DEV capture](caldova-azure-devops-solution-cicd-idea.md) | Draft | GF Engineering | Explicit reusable DEV capture to branch/PR, reviewed-source build and TEST delivery. | User-confirmed boundary; solution/environment inventory and access unverified. | Deferred - not synchronized |
| IDEA-GF-ESS | [Specification](../specs/2026-10-28-caldova-ess-github-harness-workiq-design.md); [sprint](../plans/2026-10-28-caldova-ess-github-harness-workiq-sprint.md); [implementation plan](../plans/2026-10-28-caldova-ess-github-harness-workiq-implementation.md) | [Caldova ESS-equivalent employee self-service rebuild](caldova-ess-github-harness-workiq-idea.md) | Draft | GF HR | New GitHub-harness ESS-equivalent with policy guidance, six self-only Workday operations and scoped M365 support. | Draft handover basis; formal scope, APIs, delegated identity, tool enforcement and acceptance remain gated. | Deferred - not synchronized |
| IDEA-GF-BLUEPRINT | [Specification](../specs/2026-10-29-caldova-blueprint-progress-overview-design.md); [sprint](../plans/2026-10-29-caldova-blueprint-progress-overview-sprint.md); [provisional plan](../plans/2026-10-29-caldova-blueprint-progress-overview-implementation.md) | [Caldova blueprint and project progress overview](caldova-blueprint-progress-overview-idea.md) | Draft | GF Project overview | Evidence-backed delivery overview, reviewed narrative updates and a scoped repository-working maintainer. | Read-only preview created; written-spec review and full writer/render/check activation remain gated. | Deferred - not synchronized |
| IDEA-GF-AGENT-IDENTITY | [Specification](../specs/2026-10-29-caldova-agent-identity-kit-design.md); [sprint](../plans/2026-10-29-caldova-agent-identity-kit-sprint.md); [provisional plan](../plans/2026-10-29-caldova-agent-identity-kit-implementation.md) | [Caldova grounded agent identity kit](caldova-agent-identity-kit-idea.md) | Draft | GF Brand / runtime identity | Grounded naming, palette, icons and environment identity for current/future GF runtime designs. | Four mappings adopted; technical/publisher, source-format, guard policy and live application remain gated. | Deferred - not synchronized |

The [eight Caldova project packages](../README.md#caldova-draft-packages) are separate from the nineteen Caldova `UC-nnnn` records. Each has a primary sprint, idea and specification; implementation plans, ADRs, the identity source kit and the gated preview agent are supporting artifacts. Draft specifications and sprint proposals do not constitute idea graduation or implementation approval. The [source/CAT assessment](../README.md#cat-reuse-assessment) separates reusable authoring aids from conditional runtime candidates; none is installed or admitted.

`IDEA-GF-*` keys are retained legacy identifiers. The package owner/surface is the
Caldova project/demo; GF domain/source labels identify the customer scenario and
do not transfer policy, trademark or approval authority to Caldova.

## HR portfolio guidance

### Evidence rules

1. A `Proposed Baseline` use-case record is not approved work. UC-0005 and UC-0010 are named MVP candidates but remain ungraduated until their detailed artifacts exist.
2. Separate customer-stated material from repository assessment. Section 1 of each HR record contains customer-stated material; later assessment sections are repository analysis.
3. The assessment must ask whether an agent is the right answer. A workflow, scheduled report, product capability, or process correction can be the better outcome.
4. Cite stable `UC-nnnn` identifiers rather than relying on titles.
5. UC-0007, UC-0008, UC-0014, UC-0015, and UC-0019 touch employment decisions. Each requires a named human decision-maker who sees the underlying evidence; none may decide anything about a person.

### Portfolio shape

The MVP thesis uses three records:

- **UC-0001** demonstrates reasoning over unstructured documents plus a governed additive write to the system of record.
- **UC-0010** demonstrates the closed data-quality loop and is expected to remain workflow-first.
- **UC-0005** demonstrates reuse across a second journey stage.

UC-0002 is an adoption vehicle alongside the MVP rather than an agentic exemplar. The remaining records are suggested waves, not a customer-approved roadmap:

- service delivery at scale: UC-0004, UC-0006, UC-0018;
- assisted judgement: UC-0003, UC-0007, UC-0011, UC-0013;
- analytics and prediction: UC-0009, UC-0014, UC-0015, UC-0016, UC-0019; and
- deferred: UC-0008, UC-0012, UC-0017.

### Portfolio observations

- The Offboard journey stage has no use case despite the compliance exposure around access revocation, handover, and alumni records.
- Five records have employment-decision adjacency and therefore need explicit human authority before any implementation starts.
- Several records may not need an agent: UC-0010 may be deterministic reporting, UC-0015 and UC-0019 are predictive modelling, and UC-0016 may overlap a Workday capability.

## Domain links

- [Documentation knowledge map](../README.md)
- [HR documentation](../../hr/README.md)
- [HR use-case detail](../../hr/docs/use-cases/README.md)
- [Platform requirements](../prd.md)
- [Solution design](../solution-design.md)
- [HR journey and RACI](../hr-journey-and-raci.md)

## Sources

- The customer-supplied HR AI use-case workbook
- The source Workday presentation
- The customer-supplied UC-0001 draft PRD
- The customer-supplied UC-0001 artefact inventory
- The customer-supplied personal-master-data field workbook referenced by UC-0001 source material
