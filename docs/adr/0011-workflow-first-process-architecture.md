# ADR-0011 — Workflow-first process architecture

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Architecture |
| **References** | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

| | |
|---|---|
| **Status** | Accepted |
| **Date** | 2026-09-23 |
| **Related** | [ADR-0008](0008-human-in-the-loop-and-write-envelope.md) · [ADR-0009](0009-workday-access-via-connector-behind-governed-layer.md) |
| **Supersedes** | The agent-centric process shape in Solution Design §5, Draft 0.1 |

---

## Context

The first draft of this design described the MVP as an agent that calls tools. Reviewing it against what Copilot Studio actually provides, that shape is wrong for this use case, for three reasons that only became clear once the platform's own documentation was read properly.

**1. Determinism cannot live in the agent.** The GitHub Copilot harness — selected for the MVP because the work is reasoning-heavy — uses its enhanced orchestration model for all agents, and unlike the standard harness, the orchestration behaviour is not configurable. There is no dial. An agent on this harness interprets instructions and decides when to invoke tools; that is the product's intent and its value. It is also, for a process that writes to the system of record for employee data, a property that has to be bounded from outside.

**2. Workflows provide exactly the property we need.** Workflows in Copilot Studio are deterministic: they execute actions following a rule-based path, and the same input always produces the same output. They consist of a trigger and at least one action, and their action vocabulary already includes the three things our process needs beyond reasoning — AI capabilities that can *call an agent*, human-in-the-loop actions such as requesting information, and built-in control structures for looping and branching.

**3. Counting our own steps settles it.** The MVP's process is: create the run record, list the documents, group them into packages, iterate, call Workday, decide per field, move the files, close the run, notify, surface exceptions. Exactly one of those steps requires judgement. The rest are process, and they carry the audit trail.

Microsoft's own guidance points the same way. Agents bring reasoning and adaptability; workflows bring structure and consistency — and it is no longer an either-or decision. In the pattern named *workflows that use agents*, the workflow provides the structure for the business process — the defined steps, branching logic, handoffs, and an audit trail — while the agent handles the parts that require judgement, after which control returns to the workflow and execution continues predictably.

The maturity model published alongside it makes the same argument at organisational scale: implementation often begins with digital process automation, and organisations then evolve toward agentic automation by layering AI-driven reasoning on top of digital workflows — described as a hybrid approach that helps enterprises modernise safely.

## Decision

**The workflow owns the process. The agent owns the judgement. The workflow calls the agent, not the reverse.**

1. **Every governed HR process is implemented as a Copilot Studio workflow**, with a trigger — instant, scheduled or event-based — and an explicit step sequence.
2. **The agent is invoked as a node at the points that require reasoning**: interpreting a document, resolving an ambiguity, deciding how to route an exception. It is called, it answers, control returns.
3. **The audit trail belongs to the workflow**, not the agent. Run identity, step outcomes, timings and exception records are written by deterministic steps, so the evidence for FR-0011 does not depend on a reasoning model having chosen to record something.
4. **Human-in-the-loop is a workflow action**, using the platform's request-information capability — not an instruction in an agent prompt.
5. **The Workday Access Layer is itself a workflow**, built with the *When an agent calls the flow* trigger and added to the agent as a tool. This resolves D-0001 / TD-03: the surfacing question had three candidate answers, and the platform now supplies one natively.
6. **Extraction is two-tier.** The workflow's document-processing action handles well-formed documents; only failures and ambiguities are escalated to the agent node. This is a cost control and a security control at once — it narrows the surface on which untrusted document content reaches a reasoning model.
7. **Where a process needs no reasoning at all, it is a workflow with no agent node** — and that is not a lesser outcome. UC-0010 is expected to be mostly this.

### What this does not change

The agent is still the reason the platform exists. This decision is about **where the boundary sits**, not about doing less with agents. A process with no judgement in it was never an agentic use case; a process wrapped in deterministic structure is still agentic at the point that matters.

## Options considered

### A. Agent-centric — the agent orchestrates and calls tools — *rejected*

The original shape, and the intuitive one. It fails on auditability: the sequence of steps and the completeness of the audit record would both depend on the orchestrator's choices, on a harness whose orchestration is deliberately not configurable. For a process that writes to employee master data and reads externally-supplied PDFs, that concentrates too much in the least constrainable component.

### B. Workflow-first with agent nodes — *chosen*

Costs a second authoring surface and a harder boundary to design. In exchange the audit trail is deterministic, human-in-the-loop is a first-class step rather than a prompt instruction, retry and throttle handling live in one place, and the credit profile improves because reasoning is invoked only where it is needed.

### C. Split across Power Automate and Copilot Studio — *rejected*

The original draft effectively did this: Power Automate for orchestration, Copilot Studio for the agent. It works, but it puts the process definition in one product and the reasoning in another, with the audit trail spanning both. One orchestrator is better than two, and the workflow experience now covers what Power Automate was doing here.

### D. Standard harness with agent flows — *rejected for the MVP*

The standard harness offers configurable orchestration, which would address the determinism concern differently. It is rejected because the MVP's core task is multi-step reasoning over unstructured documents, which is the GitHub Copilot harness's purpose. Note the consequence below.

## Consequences

### Positive

- **The audit trail is deterministic**, satisfying FR-0011 with a mechanism rather than an intention.
- **Refusals become testable at two levels** — the workflow's branches and the agent's evaluation test sets.
- **The credit profile improves.** Reasoning is invoked at one point rather than across the whole process, and two-tier extraction keeps well-formed documents off the agent entirely.
- **D-0001 / TD-03 closes** with a first-party mechanism instead of a build decision.
- **The prompt-injection surface narrows.** Fewer documents reach the reasoning model, and the model was never the thing holding the Workday connection.
- **The reuse thesis gets a concrete unit.** The second use case inherits a workflow pattern, not just a set of principles.

### Negative

- **Two authoring surfaces** to build, test, version and govern, with a boundary that has to be maintained deliberately.
- **The boundary will be contested.** Every new requirement raises "workflow step or agent judgement?", and getting it wrong in the permissive direction is invisible until something writes what it should not.
- **Harness split risk.** Computer use is documented against the standard harness. If a future increment needs both computer use and GitHub Copilot harness reasoning in one process, it will need two agents joined by the workflow — verify before committing a use case that assumes otherwise.
- **Workflow capacity becomes an availability dependency** — see the accepted risk below.

### Accepted risks

| Risk | Mitigation |
|---|---|
| **Capacity exhaustion silently blocks runs.** Once an environment's prepaid Copilot Studio capacity is fully consumed, new workflow runs are blocked until capacity is available, while running workflows complete normally. For a pre-boarding process with a joining date attached, this fails quietly — HR sees nothing happen | Monitor consumption in the Power Platform admin center; enable pay-as-you-go in PROD; alert on approaching thresholds. Recorded as an NFR, not a billing note |
| The boundary erodes and the workflow becomes a thin wrapper around an agent that does everything | The boundary is reviewed at every new step. A step that cannot state why it needs reasoning is a workflow step |
| Two-tier extraction degrades quality for edge-case documents | Validate both tiers against the same sample set before build; route on confidence, not on document type |
| Evaluation costs accumulate | Usage-based billing applies to using, building, testing **and evaluating** agents — budget evaluation as recurring spend, and run full suites on a defined cadence rather than every commit |

## Compliance

Any new step or use case must answer:

1. Does this step require reasoning over something that cannot be expressed as a rule? If not, it is a workflow step.
2. Is the audit record for this step written deterministically, or does it depend on the agent choosing to record it?
3. Is human-in-the-loop implemented as a workflow action rather than a prompt instruction?
4. Does untrusted content reach the agent that does not need to?
5. Has the capacity impact of this workflow been estimated, and does PROD have headroom?
