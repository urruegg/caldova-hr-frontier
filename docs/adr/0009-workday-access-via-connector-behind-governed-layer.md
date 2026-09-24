# ADR-0009 — Workday access through the Microsoft Workday connector, behind a governed access layer

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
| **Date** | 2026-09-17 |
| **Supersedes** | The unnamed "Workday MCP" placeholder in GF PRD Draft 0.1 |
| **Related** | [ADR-0005](0005-workday-as-system-of-record.md) · [ADR-0008](0008-human-in-the-loop-and-write-envelope.md) · [ADR-0010](0010-organizational-data-service-as-people-context.md) |

---

## Context

GF's Draft 0.1 named a "Workday MCP" as the agent's path to Workday without specifying what it was, who would build it, or how it would be authenticated. GF IT has now **confirmed the Microsoft Workday connector** as the access API for interacting with Workday.

That confirmation is welcome and it resolves the transport question. It also exposes a problem that the placeholder had hidden.

[ADR-0008](0008-human-in-the-loop-and-write-envelope.md) commits to enforcing the write envelope **server-side** — the agent must not be able to write outside it even if its instructions are subverted. The agent reads PDFs supplied from outside the platform, so prompt injection is a live threat, not a theoretical one.

The confirmed connector's generally available write surface is **`Execute SOAP operation`**: a raw pass-through that takes a service name, a version and a SOAP request body. It applies no field-level policy of its own. **Any caller holding that action can send any SOAP body to any Workday service the credential permits** — including an overwrite of a populated field.

Three further properties of the connector shape the decision:

- It is **Premium** in Copilot Studio, Power Apps and Power Automate.
- Its connections are **not shareable** — a shared app prompts each new user to create their own.
- It throttles at **200 API calls per connection per 60 seconds**.
- Its typed actions (`Search workers`, `Transfer employee`, and the rest) are all **Preview**, and `Execute REST request` supplies **no idempotency key**.

## Decision

**The Microsoft Workday connector is the transport. It is not the control surface, and the agent never holds it.**

1. **A Workday Access Layer sits between the agent and the connector.** It exposes exactly three actions — `search_profile`, `read_fields`, `add_missing_value` — and nothing else.
2. **The access layer owns the Workday connection**, through a connection reference held by a service identity, one per environment. The Copilot Studio agent has no Workday connection of its own.
3. **The MVP builds on `Execute SOAP operation`** against the Workday `Human_Resources` web service. Preview actions are treated as unavailable for production commitments.
4. **Authentication is OAuth 2.0 or Microsoft Entra ID Integrated.** Basic authentication — a Workday username and password in the connection — is not acceptable for a write path to the system of record.
5. **`add_missing_value` carries a run-scoped idempotency key**, enforced by the access layer, because the connector provides none and a retried write would otherwise be a second write.
6. **`read_fields` is batched** — one call for the whole approved field set, not one call per field — because of the throttle.
7. **The Workday Integration System User is scoped so that an out-of-envelope write is impossible, not merely rejected.** `Get Only` on every read domain; write permission scoped to the approved fields alone.
8. **How the access layer is surfaced to Copilot Studio is deliberately left open** — MCP tools, a custom connector, or Power Automate child flows. The contract is identical in all three. TD-03 records the choice.

### The enforcement stack

| Layer | Enforces | Defeated by |
|---|---|---|
| Agent business rules | The intended behaviour | A prompt-injection attempt inside a PDF |
| **Workday Access Layer** | Read-before-write, field allow-list, idempotency | A defect in the access layer |
| **Workday ISU permissions** | What the credential can touch at all | Nothing short of a Workday security change |

The order matters. **Design the ISU permissions first**, then the access layer, then the agent — because only the first of those cannot be undone by a bug in the others.

## Options considered

### A. Give the agent the Workday connector directly — *rejected*

The simplest option, and the one the confirmation invites. It fails ADR-0008 outright: the agent would hold a raw pass-through to Workday, with the write envelope enforced only by its own instructions. For an agent whose input is untrusted documents, that is the exact failure mode the design exists to prevent. It also scatters the connection across whoever authors the agent, which the non-shareable connection behaviour makes worse rather than better.

### B. Access layer between agent and connector — *chosen*

Costs a component that would not otherwise exist, and every Workday interaction pays one extra hop. In exchange the envelope becomes enforceable, idempotency becomes possible, the throttle is managed in one place rather than in agent logic, and the next agent inherits a governed path instead of negotiating its own.

### C. Route through the existing integration platforms — *rejected for the MVP*

GF already runs Boomi, SAP Integration Suite and Informatica. Routing agent traffic through them would reuse established governance — but those platforms are built for scheduled, system-to-system integration, not for low-latency interactive calls inside an agent turn, and threading a new synchronous path through them is a larger change than building a narrow access layer. Revisit if the access layer's scope ever grows beyond agent-specific actions.

### D. Skip the agent-specific path and use the Organizational Data Service — *rejected*

It is read-only, one-way and scheduled weekly or monthly. It cannot write, so it cannot serve this use case at all. See [ADR-0010](0010-organizational-data-service-as-people-context.md).

## Consequences

### Positive

- **The write envelope becomes enforceable** rather than instructed, satisfying ADR-0008 with something stronger than a prompt.
- **A prompt-injection attempt in a PDF has no write path to exploit.** The agent cannot express an out-of-envelope call, and the credential could not perform one.
- **Idempotency exists** where the connector offers none.
- **The throttle is handled once**, in the layer that knows about it, instead of being rediscovered by every agent.
- **The second use case inherits the path.** Adding an action is a reviewed change to a known contract, not a new integration.
- **Connection ownership survives staffing changes**, because the connection reference belongs to a service identity.

### Negative

- **A component to build, test, deploy and operate** that would not otherwise exist, in three environments.
- **Latency on every Workday interaction** from the extra hop.
- **The access layer becomes load-bearing.** If it cannot express an action, that action cannot be performed — and if it is down, the agent is down.
- **Premium licensing across the path**, on top of the Power Apps Premium the code app already requires.
- **The ISU permission design is now on the critical path** and depends on Workday security work GF has not yet scheduled.

### Accepted risks

| Risk | Mitigation |
|---|---|
| The access layer becomes a general-purpose Workday gateway and its scope sprawls | Actions are added only by the ADR-0008 change process. Three actions today; each new one is a decision, not a task |
| Preview actions go GA and the SOAP implementation looks obsolete | The contract is stable; the implementation behind it can change without touching the agent. That is one of the reasons it exists |
| A single connection's throttle becomes the run-time ceiling | Add a second connection with its own quota rather than raising concurrency against one |
| Workday security cannot scope a write permission narrowly enough | Escalate before build. If the permission cannot be scoped, the hard boundary in §4.4.2 collapses to software-only controls and the risk position materially changes |

## Compliance

Any change touching the Workday path must answer:

1. Does the agent hold, or could it obtain, a direct Workday connection? *(It must not.)*
2. Is the new capability expressible as a declared access-layer action with a bounded contract?
3. Does the Integration System User's permission set still make out-of-envelope writes impossible, rather than merely rejected?
4. Is the write idempotent under retry?
5. Does the call pattern stay within 200 calls per connection per 60 seconds at the expected batch size?
