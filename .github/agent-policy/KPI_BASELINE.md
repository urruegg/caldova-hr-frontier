# KPI Baseline - Agent-Assisted Delivery

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](../../docs/reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This proposed baseline defines how the use of agents in this repository would be measured. These are delivery-process metrics for the agent-assisted workflow, not product outcomes and never measurements of an individual person.

No metric may use personal or special-category data, expose a secret, influence an employment decision, or substitute automated scoring for accountable human review. See [Non-Delegable Work](./NON_DELEGABLE_WORK.md).

Targets are provisional unless marked absolute. A named collection source is a proposed evidence source, not a claim that the corresponding work item, pipeline, review automation, tenant service, or control currently exists.

## 1. Flow

| Metric | Definition | Baseline target |
|---|---|---|
| Work-item-to-PR lead time | Hours from an evidenced `stage:plan-ready` transition to pull request creation | Establish in Phase 1, then improve |
| PR cycle time | Hours from pull request creation to merge | Less than 48 hours for a single slice |
| Slice size | Files changed per pull request | Median less than 10 |
| Rework rate | Share of pull requests requiring a second round of substantive review | Less than 30% |
| Blocked rate | Share of slices that stall while awaiting a gate or decision | Trend downward without weakening gates |

Where an Azure Boards record or stage transition does not exist, report the lead-time metric as unavailable. Never infer or fabricate a timestamp.

## 2. Quality

| Metric | Definition | Baseline target |
|---|---|---|
| First-pass validation rate | Share of pull requests whose required validation passes on the first run | Greater than 70% |
| Evidence completeness | Share of pull requests containing real command output for every completion claim | **100%** |
| TDD compliance | Share of testable code changes with a demonstrated RED-to-GREEN cycle | **100%** for testable code |
| Acceptance-check compliance | Share of low-code changes with an acceptance check written and failed before implementation | **100%** |
| Solution Checker criticals | Critical findings reaching a pull request | **0** |
| Coverage delta | Change in coverage for an affected implemented product area | Never negative without explicit reviewed justification |

Required validation is never skipped, disabled, or weakened to improve a metric. A blocked or failed check is reported as evidence, not hidden as missing data.

## 3. Governance

These metrics carry the highest priority. A regression is a stop-the-line event rather than a trend to accept later.

| Metric | Definition | Baseline target |
|---|---|---|
| **Personal data incidents** | Occurrences of personal or special-category data reaching the repository | **0 - absolute** |
| **Secret incidents** | Secrets committed or a secret-protection control bypassed | **0 - absolute** |
| Redaction catch rate | Share of reviewed drafts where prohibited data was removed before repository handoff | Track once a review record exists; a rising number can mean the gate is working |
| Governance escalation rate | Share of slices escalated to the Governance Owner | Track, do not minimize; a low value can mean under-escalation |
| Agent publication gate compliance | Employee-facing agent releases with complete, recorded human approval evidence | **100%** once publication exists |
| Non-delegable violations | Agent attempts to execute a human-only action | **0**, with every occurrence reviewed |
| Unlinked work | Completed delivery records lacking a required verified external link | Trend to 0 once external tracking is adopted |

The governance escalation rate is not optimized downward. An agent that never escalates might be missing cases rather than handling them correctly.

## 4. Agent Effectiveness

| Metric | Definition | Baseline target |
|---|---|---|
| Delegation success rate | Share of delegated slices completed through review without human implementation takeover | Establish, then improve |
| Human intervention rate | Share of agent proposals requiring substantive human correction | Track without using it to rank people |
| Scope adherence | Share of pull requests confined to approved paths | Greater than 95% |
| Review-section completeness | Share of agent-assisted pull requests containing every section required by the current review contract | **100%** once that contract is implemented |

Effectiveness measures workflow fitness. It does not authorize unsupported autonomy or expand an agent's tools, permissions, publication rights, or decision authority.

## 5. Proposed Evidence Sources

| Potential source | Evidence it could provide |
|---|---|
| Azure Boards | Lead time, cycle time, blocked rate, external links, and stage-tag distribution after tracked work items exist |
| GitHub validation workflows | First-pass validation, solution-checking findings, and coverage delta after the corresponding workflows exist |
| Pull request review | Evidence completeness, TDD compliance, acceptance-check compliance, scope adherence, and required review sections |
| Governance records | Escalations, redaction catches, publication approvals, incidents, and non-delegable stops |
| Power Platform administration evidence | Deployment success and environment drift after an authorized collection process exists |

Only collect from an implemented, approved, access-controlled source. Do not add personal data or secrets to make a metric computable. Do not perform tenant, platform, identity, or administrative changes to enable collection without explicit human approval.

At the end of each iteration, the accountable delivery owner should present available aggregate evidence to the Product Owner and Governance Owner. Missing systems or measurements remain explicit gaps.

## 6. Baseline Status

All non-absolute targets remain provisional until the first real, reviewed measurements exist. Record actual aggregate results and revise targets deliberately through review rather than changing a target whenever it is missed.

| Metric group | Baseline established? |
|---|---|
| Flow | Not yet - pending implemented tracking and Phase 1 evidence |
| Quality | Not yet - pending implemented validation evidence |
| Governance | Absolute zero-incident targets apply from day one; other measures await approved records |
| Agent effectiveness | Not yet - pending reviewed delivery evidence |
