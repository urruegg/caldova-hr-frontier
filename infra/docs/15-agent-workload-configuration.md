# Agent and Workload Configuration

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure |
| **References** | [Approved Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This source-derived Proposed Baseline describes intended agent and workload configuration. It does not prove that any Power Platform solution, app, flow, agent, knowledge source, connection, channel, runtime, pipeline, environment, or deployed service currently exists.

## Workload Boundary

| Future workload | Intended packaging | Current evidence |
|---|---|---|
| HR journey agents | Managed component of the HR Power Platform solution | Documentation only; no agent payload |
| Journey orchestration | Solution-aware Power Automate flows | Documentation only; no flow payload |
| Task and dashboard experiences | Power Apps components | Documentation only; no app payload |
| Shared configuration | Infrastructure solution definitions for approved variables, references, and roles | Ownership README only; no solution payload |
| Azure-hosted runtime | Separate future architecture with workload managed identities | Out of this sprint |

Infrastructure solution source precedes HR solution source in every future Power Platform ALM stage. `DEV`, `TEST`, and `PROD` remain Power Platform stages only.

## Copilot Studio Design Rules

Future Copilot Studio work follows Microsoft's [ALM guidance](https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/alm):

1. customize only in the reviewed DEV environment;
2. work in a solution with a reviewed publisher;
3. use environment variables for stage-specific configuration;
4. export managed artifacts for downstream stages while keeping DEV source unmanaged;
5. add required objects before export and verify imported dependencies;
6. reconfigure non-solution-aware settings after import;
7. publish and share only after the human approval gate.

Task 1 does not create a publisher, solution, environment, component collection, agent, channel, or authentication setting.

## Grounding and Response Safety

Future HR agents use only approved, versioned knowledge sources. Public-website grounding and ad hoc document uploads are outside the Proposed Baseline. Ungrounded responses remain disabled for policy answers, and the agent escalates individual employment decisions to a human.

The governing human-in-the-loop constraints are defined in [HITL Governance](../../docs/operating-model/04-hitl-governance.md). The HR data and journey boundary is defined in [HR Employee Journey](../../hr/docs/20-hr-employee-journey.md).

Relevant platform constraints are documented in [Knowledge sources overview](https://learn.microsoft.com/en-us/microsoft-copilot-studio/knowledge-copilot-studio) and [Import and export agents](https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-solutions-import-export). Their presence here is design guidance, not evidence of configured knowledge or a successful import.

## Power Automate Rules

Future flows:

- are authored inside the HR solution;
- bind through connection references;
- use environment variables rather than hard-coded URLs or identifiers;
- include explicit failure paths and human escalation;
- process only approved Dataverse events;
- are enabled by an approved non-human owner with access to every required connection.

No flow exists in Task 1, and no connection or owner assignment is made.

## Power Apps Rules

Future Power Apps:

- are solution-aware and use the reviewed Dataverse model;
- enforce row, role, and column security on the service side;
- display the Power Platform ALM stage so demonstrations cannot confuse DEV, TEST, and PROD;
- are tested with non-admin personas using synthetic data;
- contain no embedded credential or environment-specific secret.

No app or Dataverse payload is imported in Task 1.

## Release Contract

A future promotion must prove:

1. normalized evidence still matches the target environment stable ID;
2. the Infrastructure managed solution imports before HR;
3. deployment settings supply reviewed target values outside source;
4. Solution Checker and repository validation pass;
5. authentication, channels, sharing, connections, and monitoring are revalidated after import;
6. a human approves PROD;
7. no manual unmanaged layer bypasses the release.

Microsoft notes that imported agents require explicit publication and availability configuration in [Publish agents](https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/publish). That later operational step is not authorized by this document alone.

## Data Prohibitions

Workload source, fixtures, prompts, and evidence must not contain real employee records, health data, compensation data, performance data, disciplinary data, credentials, tokens, or raw production conversations. Only synthetic demonstration data and reviewed policy text may be used.

## Current State

Phase 3 Task 1 owns documentation only. Any claim that a workload, agent, app, flow, solution, knowledge source, channel, or runtime is active requires separate current evidence and review.
