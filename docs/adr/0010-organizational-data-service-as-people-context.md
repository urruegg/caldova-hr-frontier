# ADR-0010 — Organizational Data Service as people context, not as an integration path

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
| **Status** | **Proposed** — not confirmed by GF, and nothing in the MVP depends on it |
| **Date** | 2026-09-17 |
| **Related** | [ADR-0005](0005-workday-as-system-of-record.md) · [ADR-0009](0009-workday-access-via-connector-behind-governed-layer.md) |

---

## Context

Microsoft 365 can import organizational data directly from Workday through the **Microsoft 365 Organizational Data Service**, which lands worker attributes in the Microsoft 365 profile store for Microsoft 365 and Viva apps to consume. GF has raised it as a **potential additional API**, explicitly not yet confirmed.

It is worth being precise about what it is, because the name invites a misreading. It is **not** a second way to talk to Workday. It is a scheduled, one-way import into a profile store:

| Property | Value |
|---|---|
| Direction | Workday → Microsoft 365. One-way. **No write path** |
| Mechanism | The `Get Workers` operation of the Workday `Human_Resources` SOAP web service — explicitly *not* the Workday REST API |
| Population limit | Up to 100,000 users. Beyond that, or without SOAP access, the documented route is Workday RaaS to Azure Blob Storage or to an API-based connection |
| Frequency | **Weekly or monthly** |
| Latency to availability | Validation takes a few hours; a full upload can take **up to three days** to appear in the profile store |
| Setup authority | A Microsoft 365 **Global Administrator**, plus a Workday admin creating an Integration System User, an unconstrained security group with `Get Only` on five domains, and a JWT API client with an x509 key |

Its default mapping supplies employee ID, person and manager email, manager ID and dotted-line managers, department, company, job title, management level, job family, cost centre, office location and country, hire date, employment status and type, phone, and active skills.

## Decision

**Adopt it, if at all, as a source of people context for grounding — and never as an integration path. The MVP does not depend on it, and that independence is deliberate.**

1. **The MVP is not coupled to it.** No requirement, table or agent behaviour assumes its presence.
2. **It is evaluated as a Wave 2 enabler**, for the use cases whose value comes from knowing organisational context rather than from transacting: Workforce Insights, Skills Inference, Learning Recommendation, HR Policy Chat.
3. **It does not become a source of truth.** Workday remains the system of record under ADR-0005. The profile store holds a scheduled, lagging copy, and anything needing current accuracy reads Workday through the access layer.
4. **Two settings need an explicit decision, not a default** — the sync frequency, and whether the service takes priority over existing profile data.
5. **Manual approval before sharing is enabled for the first imports**, so data quality is inspected before downstream apps consume it.

## Why it does not help the MVP

This is the part most likely to be assumed otherwise, so it is stated plainly.

| Assumption | Reality |
|---|---|
| "It could give the agent the Workday data it needs" | It imports **workers**. The MVP operates on **candidates and pre-hires**, who are not yet in the worker population. The records the MVP needs would not be there |
| "It could solve the D-03 matching problem" | The postal code it maps is `Business_Site_Summary_Data/.../Postal_Code` — the **office** postal code, not the employee's home address. It cannot support the matching key even in principle |
| "It could replace the Workday connector" | It is read-only and one-way. The MVP's purpose is to write |
| "It would at least be fresher than nothing" | Weekly or monthly, with up to three days to first availability. Not a substitute for a read at the moment of need |

## Options considered

### A. Do not adopt it — *viable*

Costs nothing and adds no drift. The grounding-dependent use cases would each solve people context themselves, most likely by calling Workday through the access layer, which multiplies round-trips and puts organisational data in prompts. Acceptable while those use cases remain hypothetical.

### B. Adopt it as people context for Wave 2 — *proposed*

A genuine reduction in Workday round-trips for exactly the queries that do not need real-time accuracy — *who reports to whom*, *which cost centre*, *what skills*. Costs a Global Administrator setup, Workday security work, and a standing drift between the profile store and Workday.

### C. Adopt it as a general integration path — *rejected*

It cannot write, it cannot be read on demand, and it is scheduled in weeks. Treating it as an integration path would mean building on a stale copy of the system of record, which ADR-0005 exists to prevent.

### D. Use the Workday RaaS route to Azure Blob Storage instead — *held open*

The documented alternative when the SOAP API is not available or the population exceeds 100,000. GF's SOAP API is confirmed available and the population is well inside the limit, so this is not needed — but it is the fallback if Workday security declines the additional ISU.

## Consequences

### If adopted

**Positive** — org hierarchy, department, cost centre, location, job family and skills become available to Copilot and agents without a Workday call; the Wave 4 analytics use cases gain a ready-made people dimension; Viva surfaces improve as a side effect.

**Negative** — a second Workday integration to operate, with its own ISU, security group and certificate; a standing drift of up to a month between the profile store and Workday; a Global Administrator dependency for every configuration change; four Microsoft fields (`Layer`, `CompanyCode`, `SecondaryJobTitle`, `CompanyPostOfficeBox`) that Workday does not map and that will need another source or must stay empty.

### If not adopted

The grounding-dependent use cases each pay their own round-trip to Workday, and organisational context has to be passed into prompts rather than being available from the platform. Tolerable at Wave 1 scale; increasingly wasteful as the portfolio grows.

## Open questions before this can move to Accepted

1. Will Workday security grant a **second** Integration System User, separate from the one ADR-0009 requires?
2. Is weekly sufficient, or does any consuming use case need fresher data than that — in which case it is the wrong mechanism?
3. Should the service take priority over existing Microsoft 365 profile data, and who owns that call?
4. Which of the four unmapped Microsoft fields does GF actually need, and where would they come from?
5. Does anything in scope require the contingent-worker population, and is it included in the import?

## Compliance

Before adopting, and at each scope change:

1. Does any MVP or Wave 1 component now depend on the profile store? *(It must not.)*
2. Is the freshness of the data adequate for every consumer, with the sync frequency written down rather than assumed?
3. Does any decision about a person rest on profile-store data rather than on Workday?
4. Is the additional ISU scoped to `Get Only`, and reviewed on the same cycle as the ADR-0009 one?
