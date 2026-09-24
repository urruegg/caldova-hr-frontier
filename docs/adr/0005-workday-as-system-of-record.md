# ADR-0005: Workday Is the System of Record for Employee Master Data

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
- **Deciders:** DAAI / HR AI Business Lead, Workday / HRIS Owner, IT / Platform Owners

---

## Context

GF operates Workday as the central source for employee master data. The Workday architecture material states it directly: *"Workday as System of Record is central source for Employee Master Data"*, with integrations built across two programme phases via Boomi, SAP Integration Suite and Informatica, and a bi-directional ServiceNow integration driving IT joiner/mover/leaver globally.

Introducing a Power Platform agentic layer raises an obvious temptation: cache employee data in Dataverse so agents and apps can read it quickly, join it freely, and avoid round-trips to Workday.

That temptation is the decision this ADR closes.

---

## Decision

**Workday remains the single system of record for employee master data. No component of the HR agentic platform holds a competing copy.**

Concretely:

1. **Reads go to Workday** through the governed Workday Access Layer, at the time they are needed.
2. **Writes go to Workday** through declared access-layer actions with a narrow envelope, never by any other path.
3. **Dataverse holds process state only** — see [ADR-0007](0007-dataverse-process-state-boundary.md).
4. **References, not values.** Where the platform must remember which worker a process concerns, it stores a Workday profile **reference**, not the worker's attributes.
5. **Existing integration platforms are not replaced.** Boomi, SAP Integration Suite and Informatica continue to own system-to-system integration. The Workday Access Layer is an agent-specific path with a deliberately narrow scope.

---

## Rationale

1. **There is already a system of record, and it works.** The problem GF has is not that Workday is the wrong place for employee data. It is that getting data *into* Workday involves manual re-keying. Solving that does not require a second store.
2. **A cache is a second source of truth the moment it exists.** It will drift — through a failed sync, a Workday change made outside the platform, or a field the cache does not know about. HR will then have two answers to the same question and no way to tell which is right.
3. **Workday's validation is a feature, not an obstacle.** Field formats, allowed values and business rules exist for reasons the agent cannot see. Writing through Workday means inheriting them.
4. **ServiceNow already consumes Workday bi-directionally** for joiner/mover/leaver. A third opinion on employee data would put IT provisioning at risk.
5. **The privacy position is simpler.** One authoritative store means one retention policy, one access model and one place to answer a data-subject request.

---

## Consequences

### Positive

- One answer to "what is this employee's data?"
- Workday validation, audit and access control apply to every agent write.
- The privacy and retention story stays comprehensible.
- No synchronisation machinery to build, monitor or repair.

### Negative

- **Every read is a round-trip.** Agent and app performance depend on Workday and access-layer availability, and on the connector's limit of 200 calls per connection per 60 seconds.
- **Workday availability becomes a dependency** for agent runs. A Workday outage stops processing rather than degrading it.
- **The access-layer contract becomes load-bearing.** If it cannot express an action, that action cannot be performed. See [ADR-0009](0009-workday-access-via-connector-behind-governed-layer.md).
- **Cross-system reporting is harder.** Joining process state to master data requires a live call rather than a local join.

### Mitigations

- The access layer returns **presence rather than value** wherever a rule only needs to know whether a field is populated, reducing both payload and exposure.
- Agent runs are HR-initiated and batch-shaped, so latency is tolerable; this would need revisiting for an interactive employee-facing agent.
- A Workday outage produces a recorded exception and a safe stop, never a partial or speculative write.
- Reporting that genuinely needs master data is built **in Workday**, where the data lives. The control plane reports on process.

---

## Alternatives Considered

**Cache a read-only subset of employee data in Dataverse.** Rejected. It is the most common version of this mistake, and the "read-only" qualifier does not survive contact with the first use case that wants to filter on it. The staleness window is unbounded because nothing guarantees the platform learns about a Workday change.

**Use the existing integration platforms (Boomi, SAP IS, Informatica) for agent writes.** Rejected for the MVP. Those platforms are built for scheduled, high-volume, system-to-system movement. An agent needs interactive, per-field, read-before-write calls with an enforced envelope — a different shape. Revisit if agent write volume grows enough to justify it.

**Write to a staging table and reconcile into Workday later.** Rejected. It introduces a window where the platform believes something Workday does not, which is precisely the drift this ADR exists to prevent.

---

## Compliance Check

Any proposed change to the platform must answer **no** to all of these:

- Does it store an employee attribute value outside Workday?
- Does it let a component answer a master-data question without asking Workday?
- Does it create a write path to employee data that bypasses the declared access-layer actions — including by handing a component the Workday connector directly?

A **yes** to any of them requires this ADR to be superseded, not worked around.

---

## References

- `GFAG_Workday Information for Microsoft` — HR-IT architecture and integration landscape
- [`solution-design.md`](../solution-design.md) §3, §4.4
- [ADR-0007](0007-dataverse-process-state-boundary.md) — the Dataverse boundary this ADR implies
