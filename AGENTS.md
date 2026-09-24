# AGENTS.md — how agents work in this repository

Two kinds of agent are in scope here, and conflating them causes real errors:

| | |
|---|---|
| **Agents we design** | The HR agents described in this repository — UC-0001 and the portfolio behind it. They run in GF's Power Platform tenant |
| **Agents that work on this repository** | GitHub Copilot and similar, editing and reasoning over these documents. Their instructions are in [`.github/copilot-instructions.md`](.github/copilot-instructions.md) |

This file is about the **first** kind: the rules every HR agent GF builds must satisfy.

---

## The floor

Every agent, without exception, regardless of use case or priority:

| Rule | Requirement |
|---|---|
| **FR-0001** | Identifies itself as an agent. Never presents itself as a person |
| **FR-0002** | Operates within a **declared write envelope** — an undeclared write is *not possible*, not merely disallowed |
| **FR-0003** | Has a **declared refusal set** and records every refusal with its reason |
| **FR-0004** | Has a **named escalation path** to a human owner |
| **FR-0005** | **Makes no decision about a person** — hiring, pay, performance, promotion, exit |
| **FR-0013** | Is invoked **only where reasoning is required**. A step that cannot state why it needs reasoning is a workflow step |
| **FR-0014** | Never owns its own audit record — deterministic workflow steps write it |

Full text in [`docs/prd.md`](docs/prd.md) §4.

---

## Where an agent is allowed to sit

```text
   WORKFLOW  ── deterministic: sequence, audit, branching, escalation
       │
       ├── step ─── rule  ──────────────► stays a workflow step
       │
       └── step ─── judgement ─────────► AGENT NODE
                                          reads, interprets, states
                                          confidence, or refuses
                                          then returns control
```

**The agent is a called component, not a controller.** It does not decide what happens next, does not own the file handling, and does not choose whether to write the audit record. This is [ADR-0011](docs/adr/0011-workflow-first-process-architecture.md), and it is the reason the audit trail can be relied on.

> **This is not a limit on ambition.** Putting a reasoning model where a rule belongs trades governability for nothing, and is the fastest way to discredit a Level 3 position. Knowing where an agent earns its place *is* the Level 3 discipline.

---

## Writing to Workday

Three independent enforcement layers. An agent instruction can be subverted by text in a document; a server-side rejection cannot; a permission never granted cannot be exercised at all.

| Layer | Enforces | Defeated by |
|---|---|---|
| Agent business rules | Intended behaviour | Prompt injection inside a source document |
| **Workday Access Layer** | Read-before-write, field allow-list, idempotency | A defect in the access layer |
| **Workday ISU permissions** | What the credential can touch at all | Nothing short of a Workday security change |

**No agent holds the Workday connector.** The Access Layer owns it, as a workflow with the *When an agent calls the flow* trigger, added to the agent as a tool. See [ADR-0009](docs/adr/0009-workday-access-via-connector-behind-governed-layer.md).

---

## Harness

Permanent per agent, **in both directions** — an agent cannot be transferred between harnesses after creation. Decide before creating.

| Harness | For | Billing |
|---|---|---|
| **GitHub Copilot** | Reasoning-heavy, multi-step work across tools and documents | Usage-based, for **building, testing, evaluating and running** |
| **Standard** | Rule-based, predictable conversational flows; computer use | Per answer/action at runtime |
| **Copilot chat** | Grounded knowledge answers | **No charge** for Microsoft 365 Copilot-licensed users in employee scenarios |

**Known constraint:** computer use is documented against the *standard* harness. A process needing both computer use and GitHub Copilot reasoning requires two agents joined by a workflow. Verify in tenant before committing a use case that assumes otherwise.

---

## Turned off, deliberately

| Capability | Status | Why |
|---|---|---|
| **Memory** | **Off** for any write-capable agent | Per-user memory is invisible to makers by design. If it influenced a write to Workday, the audit trail has a hole — and memories are deleted after 28 days of inactivity. Evidence with an expiry date is not evidence |
| **Work IQ / Microsoft IQ** | **Off** for HR agents | Giving an agent that operates on employment data access to mail, calendar, files and chats is a data-classification escalation, not a feature toggle. It needs Privacy sign-off as its own decision |
| **Connected agents** | **Blocked** pending an envelope rule | A connected agent may hold privileges its parent is denied. Until D-0011 is settled, delegation could become a bypass |

These are decisions, not defaults. Reversing one requires an ADR.

---

## Shared components

Authored once, reused by every agent, so the floor is never re-litigated:

- **Self-identification** — FR-0001
- **Escalation to a named human** — FR-0004
- **Refusal of any employment decision** — FR-0005

Built as Copilot Studio **skills**: modular instruction sets created once, added to multiple agents, exportable as Markdown and version-controlled here.

---

## Before an agent is built

The seven declarations from [`docs/hr-journey-and-raci.md`](docs/hr-journey-and-raci.md) §9:

write envelope · refusal set · escalation path · grounding sources · data classification · employment-decision surface · measurement

**A use case that cannot answer all seven is not ready, whatever its business value.** For UC-0001 specifically, the Definition of Ready is in its [PRD](hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md) §13 — and it is not yet met.
