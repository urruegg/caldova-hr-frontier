# ADR-0006: Agentic Toolset and HR Control Plane Split

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | HR Solution Architecture |
| **References** | [HR Solution Functional Design Intake](../specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

- **Status:** Accepted
- **Date:** 2026-09-17
- **Deciders:** DAAI / HR AI Business Lead, IT / Platform Owners, Switzerland HR Operations

---

## Context

The GF HR agentic platform needs two different things from the Power Platform, and conflating them produces a confused architecture:

1. **Reasoning** — reading documents, applying rules, calling tools, deciding when to refuse and escalate.
2. **Operating** — a place where HR Operations starts work, sees what happened, and resolves what the agent could not.

Microsoft's stack offers several surfaces for each, and the risk is building everything in whichever one is reached for first.

---

## Decision

**Split the platform into an agentic toolset and an HR control plane, with a declared purpose for each.**

### Agentic toolset — reasoning

| Component | Use for |
|---|---|
| **Microsoft Copilot Studio** | Agents that read, reason, call tools and write within a declared envelope |
| **Microsoft 365 Agents** | Knowledge-grounded assistance inside Microsoft 365 |
| **Cowork** | Human–agent collaboration across documents and systems |

### HR control plane — operating

| Component | Use for | Boundary |
|---|---|---|
| **Dataverse** | Process state, task state, audit | **Simple process only.** Not master data, not complex workflow engines |
| **Power Apps code app** | The HR Employee Control Plane App | The operational cockpit for HR Operations |
| **Power Automate** | Orchestration between steps | Not business logic that belongs in the agent |

### Experience — Microsoft 365

Microsoft 365 Copilot, Microsoft Teams and Cowork are where HR Operations is notified, asks questions and picks up follow-ups. **The control plane app is for operational depth, not routine awareness.**

---

## Rationale

### Why the split at all

An agent that also owns its own operational UI becomes a monolith that the next use case cannot reuse. Separating reasoning from operating means the second agent inherits the run list, the exception queue, the audit pattern and the notification path without rebuilding them.

### Why Dataverse is scoped to "simple process"

Dataverse is capable of far more than this platform should ask of it. Left unbounded it will accumulate employee attributes, then business rules, then a workflow engine — and become a shadow HR system competing with Workday.

The constraint is deliberate: **run state, task state, exception state, audit.** Anything richer is a signal to reconsider whether the process belongs in Workday.

### Why a code app for the control plane

The control plane is a dense operational surface: run lists, per-field drill-down, a live exception queue, bulk resolution, filtering across runs. A canvas app can approximate it; a code app is the right tool for it.

> **This is a GF-specific judgement, and it goes the opposite way to the equivalent decision in the Caldova HR Frontier reference implementation**, where a code app was deferred because a standard Power App met the need. The difference is the user: an HR Operations cockpit processing exceptions all day is a different problem from a new joiner completing a checklist.

The trade-offs are accepted knowingly:

| Trade-off | Position |
|---|---|
| Every end user needs **Power Apps Premium** | Accepted — the control plane has a small, defined user group |
| Custom code adds attack surface | Accepted — no sensitive data rendered client-side; Conditional Access applied |
| Assets are served from a publicly accessible endpoint with **no IP restriction** | Mitigated by Conditional Access location policy; no master data in the client |
| Not supported in Power Apps for Windows | Accepted — browser and Teams are sufficient for HR Operations |
| Adds a reliability target the platform would not otherwise have | Accepted and stated |

### Why Microsoft 365 is the experience layer

HR Operations already works in Teams and Outlook. Routine awareness — a run finished, an exception needs attention — belongs there. Requiring a separate application for routine awareness is how operational tools stop being used.

---

## Consequences

### Positive

- The second use case reuses the control plane rather than rebuilding it.
- Dataverse stays small enough to reason about, and stays clearly subordinate to Workday.
- HR Operations gets an operational surface that fits how they actually work.
- Reasoning lives in one place, so agent behaviour is reviewable in one place.

### Negative

- **Three surfaces to keep coherent** — Teams, the control plane app, and Workday reporting. Each must have a clear "what do I look at this for" answer, or users will check all three.
- **The code app is a build cost and a maintenance commitment**, including a licence dependency.
- **The Dataverse boundary needs active defence.** It will be tested at every schema change.
- **Harness choice is permanent per agent** and must be made before creation — an operational discipline, not just a design note.

### Mitigations

- A one-line statement of purpose per surface, in the README and the control plane app itself: *Teams tells you something happened; the control plane app tells you what; Workday tells you what the data looks like now.*
- The Dataverse table design in [`solution-design.md`](../solution-design.md) §4.3 is reviewed at every schema change against [ADR-0007](0007-dataverse-process-state-boundary.md).
- Shared agent components — self-identification, escalation, refusal — are authored once and reused, so agent count grows faster than agent governance cost.

---

## Harness Selection Policy

Because the choice cannot be changed after an agent is created:

| Use case shape | Harness | Reason |
|---|---|---|
| Grounded knowledge answers from approved sources | **Copilot chat harness** | Included at no charge for Microsoft 365 Copilot-licensed users in employee scenarios |
| Rule-based, predictable conversational flow | **Standard harness** | Predictability; per-answer billing at runtime |
| Reasoning-heavy, multi-step, multi-tool, document-handling | **GitHub Copilot harness** | The only harness that fits; note it bills Copilot Credits **from the start of building**, not at publish |

**The MVP agent uses the GitHub Copilot harness.** Confirm the credit budget before the agent is created, because authoring, previewing and evaluating all consume credits.

---

## Alternatives Considered

**Everything in Copilot Studio, no control plane.** Rejected. Run history, exception queues and follow-up tracking are not conversational, and building them into an agent makes them unreusable.

**Canvas app instead of a code app.** Seriously considered and would work for a simpler surface. Rejected for the density of the exception-handling workflow. Revisit if the control plane turns out narrower than expected — it is a smaller decision to reverse than the Dataverse boundary.

**Model-driven app instead of a code app.** A reasonable middle option, and the closest alternative. Rejected because the run/package/field-action drill-down and bulk exception handling fit a purpose-built UI better than a generated one. Worth revisiting if code app maintenance proves heavier than expected.

**Dataverse as a full HR process store.** Rejected — see [ADR-0007](0007-dataverse-process-state-boundary.md).

---

## References

- [`solution-design.md`](../solution-design.md) §4
- [ADR-0005](0005-workday-as-system-of-record.md) · [ADR-0007](0007-dataverse-process-state-boundary.md)
