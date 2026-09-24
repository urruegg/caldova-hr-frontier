# ADR-0007: The Dataverse Process-State Boundary

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
- **Deciders:** DAAI / HR AI Business Lead, Workday / HRIS Owner, Security / Privacy

---

## Context

[ADR-0005](0005-workday-as-system-of-record.md) establishes Workday as the system of record. [ADR-0006](0006-agentic-toolset-and-hr-control-plane.md) scopes Dataverse to "simple process". Both are correct and neither is precise enough to survive a design review six months from now, when someone reasonably asks:

> *"We already record that we wrote the postal code. Why not record what we wrote? It would make the audit report so much more useful."*

That question is how a process store becomes a shadow HR database. This ADR answers it in advance, with a line that can be checked mechanically.

---

## Decision

**Dataverse records what happened. It never records what the data is.**

### The test

For any proposed Dataverse column, ask:

> **If Workday were wiped and restored from backup, would this column now be wrong?**

- **No** → it is process state. It belongs in Dataverse.
- **Yes** → it is master data. It belongs in Workday.

`gfhr_fieldaction.action = "Added"` survives a Workday restore unchanged — it remains true that the agent performed that action. `gfhr_fieldaction.value_written = "8005"` would become a claim about employee data that Workday might now contradict. The first is history; the second is a competing record.

### What Dataverse holds

| Category | Examples | Rationale |
|---|---|---|
| **Run state** | Run ID, trigger, actor, start, end, status, counts | Pure process |
| **Package state** | Documents in the package, match outcome, package status | Pure process |
| **Field decisions** | Field name, action taken, confidence, access-layer result | What happened, not what is |
| **References** | Workday profile reference, SharePoint document reference | Pointers, not payloads |
| **Provenance** | Source document and location within it | Enables verification without duplication |
| **Exceptions** | Type, owner, status, resolution | Pure process |
| **Follow-ups** | Which field is still blank, who owns it | The gap, not the expected value |
| **Configuration** | Approved field list, thresholds, versioned | Rules, not data |

### What Dataverse must never hold

| Never | Because |
|---|---|
| Employee name, address, date of birth, nationality, bank details, any master-data attribute | It is Workday's, and a copy will drift |
| **The value written to a field** | The most tempting violation, and the one that creates a shadow record |
| A "current state" view of an employee profile | That is Workday's job, live |
| Cached Workday reads "for performance" | Staleness with no bound |
| Extracted PDF values retained after a run | Processing exhaust, not a record |

> **On the last one.** During a run the agent necessarily holds extracted values in memory to compare and write them. That is transient processing. The boundary is about **persistence**: once the run ends, the value is gone and only the decision remains.

---

## Rationale

1. **Two stores of the same fact is one store too many.** The second will drift, and nobody will know which is right until it matters.
2. **The test is mechanical.** "Would a Workday restore make this wrong?" can be applied by a reviewer who was not in the original design discussion.
3. **Privacy scope stays small.** Dataverse holding references and decisions rather than attributes means a data-subject request is answered from Workday, with the process store providing an activity trail — not a second disclosure surface.
4. **Provenance replaces duplication.** HR's real need is *"what did the agent do, and can I verify it?"* — answered by recording the source document and location. They can open the PDF; they do not need the platform to restate its contents.
5. **It keeps the platform honest about its role.** The agentic layer is a tool that operates on GF's systems of record. The moment it holds its own version of employee data, it has quietly become one.

---

## Consequences

### Positive

- No drift, because there is nothing to drift.
- Small, comprehensible privacy footprint.
- Audit is defensible: it records actions, and points at sources.
- Dataverse capacity and retention stay modest.

### Negative

- **Audit reports cannot show old and new values side by side.** HR sees *"Postal Code — Added — from document 3, page 1"* and opens the source to see what was added. This is a genuine usability cost, and it is the price of the boundary.
- **Cross-referencing process and master data requires a live Workday call.** Reporting that needs both is built in Workday.
- **Reconstructing "what did this profile look like before the run" is not possible from Dataverse.** Workday's own audit history is the answer.
- **The boundary needs defending.** It will be questioned at every schema change, usually for good-sounding reasons.

### Mitigations

- **Provenance is mandatory** (FR-20): every field action records its source document and the location within it, so verification is one click rather than a search.
- The `gfhr_approvedfield` table is versioned, so it is always possible to say which rules applied to a historical run without storing the data those rules acted on.
- A schema-change checklist applies the restore test to every new column, and requires a Privacy sign-off to override.

---

## Alternatives Considered

**Store values with a short retention window.** Rejected. A short-lived shadow record is still a shadow record, and "short" becomes "indefinite" the first time someone needs it for an investigation.

**Store a hash of the written value.** Considered more seriously — it would allow verifying that a value had not changed without storing the value. Rejected for the MVP as complexity without a demonstrated need: nobody has asked for tamper-evidence on individual field writes. Revisit if an audit requirement demands it.

**Store values only for exception cases.** Rejected. The exception path is exactly where personal data is most sensitive and least reviewed.

**Allow a read-only cache with a defined refresh.** Rejected under [ADR-0005](0005-workday-as-system-of-record.md).

---

## Enforcement

| Control | How |
|---|---|
| **Schema review** | Every new Dataverse column passes the restore test before it is created |
| **Solution review** | Table design reviewed at every solution change against this ADR |
| **Privacy sign-off** | Any proposed exception requires Security / Privacy approval and supersedes this ADR — it is not a waiver |
| **Audit sampling** | Periodic check that no master-data value has appeared in a process table |

---

## References

- [`solution-design.md`](../solution-design.md) §4.3
- [ADR-0005](0005-workday-as-system-of-record.md) · [ADR-0006](0006-agentic-toolset-and-hr-control-plane.md)
