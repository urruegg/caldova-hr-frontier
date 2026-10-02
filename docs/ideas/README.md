# Ideas

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Date** | 2026-10-02 |
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

## Complete idea catalogue

| ID | Idea | Domain | Status | Purpose | Authority | Domain detail | Governing specification | Implementation plan | Board synchronization |
|---|---|---|---|---|---|---|---|---|---|
| UC-0001 | [Personal Master Data Completion Agent](uc-0001-personal-master-data-completion-agent.md) | HR | Graduated | Eliminate manual re-keying of personal master data at pre-boarding | Customer-supplied UC-0001 draft PRD and artefact inventory; central record is orientation | [HR use-case package](../../hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md) | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) | [HR Solution Functional Design Intake implementation](../plans/2026-09-24-hr-solution-functional-design-intake-implementation.md) | Deferred - not synchronized |
| UC-0002 | [HR Policy Chat Assistant](uc-0002-hr-policy-chat-assistant.md) | HR | Proposed Baseline | Reduce HR tickets through grounded policy answers | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0003 | [Employee Self-Service Assistant](uc-0003-employee-self-service-assistant.md) | HR | Proposed Baseline | Provide faster HR responses through guided self-service | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0004 | [HR Case Classification Bot](uc-0004-hr-case-classification-bot.md) | HR | Proposed Baseline | Improve routing and resolution speed for HR cases | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0005 | [Onboarding Assistant](uc-0005-onboarding-assistant.md) | HR | Proposed Baseline | Improve the employee onboarding experience | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0006 | [Job Description Generator](uc-0006-job-description-generator.md) | HR | Proposed Baseline | Accelerate hiring preparation | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0007 | [Candidate Screening Summary](uc-0007-candidate-screening-summary.md) | HR | Proposed Baseline | Improve hiring quality with evidence-preserving summaries | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0008 | [Salary Benchmark Assistant](uc-0008-salary-benchmark-assistant.md) | HR | Proposed Baseline | Support pay consistency without automating employment decisions | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0009 | [Workforce Insights Assistant](uc-0009-workforce-insights-assistant.md) | HR | Proposed Baseline | Shorten the path from workforce data to human decisions | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0010 | [Employee Data Validation Bot](uc-0010-employee-data-validation-bot.md) | HR | Proposed Baseline | Improve employee-data quality through a governed closed loop | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0011 | [Learning Recommendation Agent](uc-0011-learning-recommendation-agent.md) | HR | Proposed Baseline | Support employee skill development | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0012 | [Payroll Anomaly Detection](uc-0012-payroll-anomaly-detection.md) | HR | Proposed Baseline | Reduce payroll errors and compliance risk | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0013 | [Performance Review Draft Assistant](uc-0013-performance-review-draft-assistant.md) | HR | Proposed Baseline | Improve performance-review draft quality | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0014 | [Continuous Performance Insights](uc-0014-continuous-performance-insights.md) | HR | Proposed Baseline | Support better human performance decisions | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0015 | [Leadership Pipeline Prediction](uc-0015-leadership-pipeline-prediction.md) | HR | Proposed Baseline | Improve leadership continuity while retaining human authority | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0016 | [Skills Inference Engine](uc-0016-skills-inference-engine.md) | HR | Proposed Baseline | Improve workforce skill visibility | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0017 | [Pre-hire Process Orchestration](uc-0017-pre-hire-process-orchestration.md) | HR | Proposed Baseline | Close the pre-hire process gap end to end | Customer-supplied HR Ops CH pain points | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0018 | [Onboarding Checklist Rebuild](uc-0018-onboarding-checklist-rebuild.md) | HR | Proposed Baseline | Replace the onboarding checklist with an owned, usable process | Customer-supplied HR Ops CH pain points | Not created | Not created | Not created | Deferred - not synchronized |
| UC-0019 | [Attrition Risk Insight Lite](uc-0019-attrition-risk-insight-lite.md) | HR | Proposed Baseline | Support retention improvement without automated employment decisions | Customer-supplied HR AI use-case workbook | Not created | Not created | Not created | Deferred - not synchronized |
| IDEA-HR-CONTROL-PLANE | [HR Control Plane Mockup](hr-control-plane-mockup-idea.md) ([HTML companion](hr-control-plane-mockup.html)) | HR | Draft | Explore an operational cockpit for agent runs, field actions, and exceptions | Repository-owned design exploration; non-authoritative | Not created | Not created | Not created | Deferred - not synchronized |

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
