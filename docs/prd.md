# Product Requirements — GF HR Agentic Platform

| | |
|---|---|
| **Document** | `prd.md` — platform-level product requirements |
| **Status** | Draft 0.1 |
| **Date** | 2026-09-17 |
| **Scope** | The HR agentic platform as a whole. **Not** a single agent |
| **Use-case requirements** | Each selected use case carries its own PRD — see [`ideas/`](../hr/docs/ideas/README.md) |

---

## 1. Purpose

This document states what the **platform** must do, once, so that no individual use case has to restate it. Every agent GF builds inherits these requirements; a use-case PRD adds only what is specific to that use case.

The distinction matters because it is where governance either holds or erodes. If each use case re-decides how it escalates to a human, what it refuses, or where its audit record lives, then by the fifth agent there are five answers and no platform. The requirements below are the ones that must have exactly one answer.

**The MVP proves them.** [UC-0001](../hr/docs/ideas/uc-0001-personal-master-data-completion-agent/uc-0001-personal-master-data-completion-agent.md) is the first implementation of every requirement here, which is why its PRD is the more detailed document. What it establishes, the next use case inherits.

---

## 2. Product Vision

> HR work at GF is supported by agents that read, prepare and complete — and by humans who decide.

Three commitments follow from that sentence, and they are the reason the requirements below take the shape they do:

1. **Workday stays the system of record.** The platform makes it easier to keep Workday correct. It never becomes an alternative to it. ([ADR-0005](adr/0005-workday-as-system-of-record.md))
2. **Agents act within declared envelopes.** What an agent may write is decided in advance, written down, and enforced where the agent cannot reach it. ([ADR-0008](adr/0008-human-in-the-loop-and-write-envelope.md), [ADR-0009](adr/0009-workday-access-via-connector-behind-governed-layer.md))
3. **No agent decides about a person.** Not hiring, not pay, not performance, not exit. Agents prepare the evidence; named humans decide.

---

## 2.1 Maturity Position — Level 3, Agentic

Microsoft describes three levels of process automation. GF positions at **Level 3**.

| Level | Definition | GF today |
|---|---|---|
| **1 — Traditional (BPA)** | Scripts or predefined instructions executing repetitive, rule-based tasks; best suited to static, predictable processes | Scheduled Workday integrations |
| **2 — Digital (DPA / RPA)** | Connects workflows across systems and teams, enabling end-to-end process orchestration | Boomi, SAP Integration Suite, Informatica, Workday ↔ ServiceNow |
| **3 — Agentic** | AI agents that plan, reason and act across data and applications toward a defined business goal | **This platform** |

**This is a deliberate position, not an aspiration.** The Level 2 estate exists and is not being rebuilt; the platform layers reasoning on top of it — which is also the sequence Microsoft recommends, describing it as a hybrid approach that helps enterprises modernise safely.

### What Level 3 does not mean

It does not mean every process is an agent. Where a process must behave identically every time, it runs as a deterministic workflow — see [ADR-0011](adr/0011-workflow-first-process-architecture.md). **An agent placed where a rule belongs is not a stronger Level 3 claim; it is a weaker one**, because it trades governability for nothing. Requirement FR-0013 makes that testable.

---

## 2.2 MVP Scope — Three Use Cases

The MVP proves the platform. It does not cover HR.

| # | Use case | What it proves |
|---|---|---|
| **UC-0001** | [Personal Master Data Completion Agent](../hr/docs/ideas/uc-0001-personal-master-data-completion-agent/README.md) | Reasoning over unstructured documents **plus a governed write to the system of record** |
| **UC-0010** | [Employee Data Validation](../hr/docs/ideas/uc-0010-employee-data-validation-bot.md) | The **closed loop** — detection across the population feeding completion. Workflow-first, agent only for ambiguity |
| **UC-0005** | [Onboarding Assistant](../hr/docs/ideas/uc-0005-onboarding-assistant.md) | The pattern **extends to a second journey stage** at lower cost than the first |

**Running alongside, not counted in the MVP:** [UC-0002 HR Policy Chat Assistant](../hr/docs/ideas/uc-0002-hr-policy-chat-assistant.md), because on the Copilot chat harness it carries no charge for Microsoft 365 Copilot-licensed users. It answers questions rather than taking action, so it is an adoption vehicle rather than an agentic exemplar.

**The exit test.** The MVP succeeds if UC-0005 costs materially less to build than UC-0001 — not if all three ship. If the third use case costs the same as the first, the reuse thesis is wrong, and three use cases is a cheaper place to discover that than thirteen.

---

## 3. Scope

### 3.1 In scope

- The agentic toolset: Copilot Studio, Microsoft 365 Agents, Cowork
- The HR control plane: Dataverse process state, Power Automate orchestration, the HR Employee Control Plane App
- The governed integration path to Workday, and the connector inventory it sits within
- The experience surfaces: Microsoft 365 Copilot, Microsoft Teams, Cowork
- Shared agent behaviour: refusal, escalation, self-identification, audit
- Environments, ALM, security and observability for all of the above

### 3.2 Out of scope

- Workday configuration itself, beyond the integration surface the platform consumes
- Replacement of Boomi, SAP Integration Suite or Informatica for system-to-system integration
- The ServiceNow joiner/mover/leaver flow, which already exists and is consumed, not rebuilt
- Local payroll execution (CH: SAP P01) and the 20+ local payroll and time systems
- Any use case not yet approved — the [`ideas/`](../hr/docs/ideas/README.md) folder is a portfolio, not a backlog. **Fifteen of the eighteen candidates are explicitly out of MVP scope**

---

## 4. Functional Requirements

Platform-level. A use-case PRD adds to these; it does not restate or weaken them.

### 4.1 Agent behaviour

| ID | Requirement | Verified by |
|---|---|---|
| **FR-0001** | Every agent shall **identify itself as an agent** at the start of any human interaction, and shall not present itself as a person | Conversation review |
| **FR-0002** | Every agent shall operate within a **declared write envelope** stating which targets it may write, which fields, and under which conditions. An undeclared write is not possible, not merely disallowed | Envelope document + [FR-0006](#) enforcement test |
| **FR-0003** | Every agent shall have a **declared refusal set** — the conditions under which it stops — and shall record each refusal with its reason | Refusal test suite |
| **FR-0004** | Every agent shall have a **named escalation path** to a human owner, reachable through Teams or the control plane app | Escalation test |
| **FR-0005** | No agent shall **make or communicate a decision about a person** — hiring, pay, performance, promotion or exit. Agents prepare; humans decide | Behaviour review at design and release |
| **FR-0013** | Every process shall be implemented **workflow-first**, with an agent invoked only at steps requiring reasoning that cannot be expressed as a rule. A step that cannot state why it needs reasoning is a workflow step | Design review against [ADR-0011](adr/0011-workflow-first-process-architecture.md) |
| **FR-0014** | The **audit record shall be written by deterministic workflow steps**, never left to the agent's discretion | Audit export review; forced-failure test |

### 4.2 Integration and enforcement

| ID | Requirement | Verified by |
|---|---|---|
| **FR-0006** | Writes to Workday shall pass through the **Workday Access Layer**, which enforces read-before-write, the field allow-list and idempotency **server-side**, independently of agent instructions | Negative test: an out-of-envelope call is rejected |
| **FR-0007** | No agent shall hold a **direct Workday connection**. The Access Layer owns it through a connection reference bound to a service identity | Connection audit per environment |
| **FR-0008** | The **Workday Integration System User** shall be scoped so an out-of-envelope write is *impossible*, not merely rejected — `Get Only` on read domains, write permission limited to approved fields | Workday security review |
| **FR-0009** | All reads of employee master data shall be **live from Workday**. No component shall hold a persistent copy | Dataverse schema review at every change |

### 4.3 Process state and audit

| ID | Requirement | Verified by |
|---|---|---|
| **FR-0010** | Dataverse shall hold **process state only** — what ran, what it touched, what happened, what a human must still do. It shall not hold employee master data values | The ADR-0007 test, applied at every schema change |
| **FR-0011** | Every agent action shall produce an **audit record** identifying the run, the acting identity, the target reference, the action, the outcome and the timestamp — recording *that* a value was written, never *what* | Audit export review |
| **FR-0012** | Every run shall surface its outcome to a **named human owner**, including everything it could not complete. Silent partial success is a defect | Run-completion review |

> **FR-0010 has a mechanical test**, and it is the one to apply when a new column is proposed: *if Workday were wiped and restored from backup, would this column now be wrong?* If yes, it does not belong in Dataverse. ([ADR-0007](adr/0007-dataverse-process-state-boundary.md))

---

## 5. Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| **NFR-0001** | **Security** | Every identity holds least privilege for its function. The agent identity, the Access Layer identity and the Workday ISU are distinct and separately scoped |
| **NFR-0002** | **Security** | Content retrieved from outside the platform — documents, files, external text — is treated as **data, never as instruction**. Instruction-shaped text in a source document has no effect on agent behaviour |
| **NFR-0003** | **Security** | No long-lived secret where workload identity federation is available. Where a secret is unavoidable it lives in Azure Key Vault and is rotated on a defined schedule |
| **NFR-0004** | **Privacy** | No personal data in prompts, logs or telemetry. References and outcomes only |
| **NFR-0005** | **Privacy** | Retention is defined per artefact class — source documents, archived documents, process records, audit entries — and applied, not merely documented |
| **NFR-0006** | **Governance** | A **DLP policy covering the full connector inventory** is applied to all environments **before the first artefact is built**. No connector outside the inventory is permitted without recorded review |
| **NFR-0007** | **Reliability** | Integration calls retry with backoff, inside the Access Layer rather than in agent logic. Writes are idempotent under retry |
| **NFR-0008** | **Performance** | Call patterns stay within the Workday connector's limit of **200 calls per connection per 60 seconds** at the expected batch size. Reads are batched, not iterated per field |
| **NFR-0009** | **Operability** | Run status, outcome distribution, exception rate and credit consumption are observable without inspecting logs |
| **NFR-0010** | **Maintainability** | No environment-specific value is hard-coded. Every URL, path, host and connection is an environment variable or connection reference, and promotion is by managed solution through a pipeline |
| **NFR-0011** | **Availability** | Copilot Studio capacity is monitored and alerted in every environment. **Exhausted prepaid capacity blocks new workflow runs** while in-flight runs complete — a silent failure for a date-bound HR process. PROD runs with pay-as-you-go enabled |
| **NFR-0012** | **Cost** | Reasoning is invoked only where required. Well-formed inputs are handled by the deterministic tier. Evaluation is budgeted as **recurring** spend, because usage-based billing applies to using, building, testing and evaluating |

> **NFR-0002 and FR-0006 are the same control seen twice.** The agent treats documents as data *and* the enforcement sits where document text cannot reach it. Either alone is insufficient: instructions can be subverted, and software has defects. ([ADR-0009](adr/0009-workday-access-via-connector-behind-governed-layer.md) §4.4.2)

---

## 6. Roles and Accountability

Platform-level accountabilities. Per-process RACI is in [`hr-journey-and-raci.md`](hr-journey-and-raci.md) §5–6.

| Role | Accountable for |
|---|---|
| **DAAI / HR AI Business Lead** | Product direction, use-case priority, agent behaviour standards, business outcome |
| **HR Operations (global)** | Service delivery, case handling, process standards |
| **Switzerland HR Operations** | Process design, approved fields, document handling, exception follow-up, operational acceptance for UC-0001 |
| **Workday Solutions / HRIS Owner** | Workday configuration, field definitions, Integration System User design and permissions, Access Layer action approval, data model integrity |
| **Talent Acquisition** | Recruiting process, candidate experience, hiring manager enablement |
| **Talent Management** | Performance, succession, skills, internal mobility |
| **L&D** | Learning content, paths, adoption |
| **Compensation & Benefits** | Pay structures, benchmarks, equity |
| **People Analytics** | Reporting, insight quality, measurement |
| **HRBP** | Business partnering, manager enablement, local application |
| **Local Payroll Team (CH)** | Payroll execution and controls |
| **Security / Privacy** | Data protection, access, retention, control approval |
| **IT / Platform Owners** | Environments, identity, integration, operations, support |

### The two accountabilities most often merged

> **The write envelope is accountable to HR Operations** — they carry the consequence of a bad write.
> **Enforcing it is accountable to HRIS** — the enforcement lives in the Access Layer and the ISU permissions.
>
> Merging them puts the control and the incentive in the same hands, which is how envelopes quietly widen.

---

## 7. Release Gates

Every use case passes these before build, regardless of priority. They are the seven declarations from [`hr-journey-and-raci.md`](hr-journey-and-raci.md) §9, stated as gates:

- [ ] **Write envelope** declared and enforceable server-side — FR-0002, FR-0006
- [ ] **Refusal set** declared and testable — FR-0003
- [ ] **Escalation path** named, with a human owner who has capacity — FR-0004
- [ ] **Grounding sources** approved, with a content owner and review cadence
- [ ] **Data classification** confirmed with Privacy — NFR-0004
- [ ] **Employment-decision surface** identified; if any output influences a decision about a person, the decision-maker is named and sees the underlying evidence — FR-0005
- [ ] **Measurement** defined, with a baseline captured **before** build

A use case that cannot answer all seven is not ready, whatever its business value.

---

## 8. Success Measures

| Measure | Why it is the right one |
|---|---|
| Manual effort removed at the point of measurement | The stated business case. Requires a baseline before build |
| Completeness of approved data at the moment of hire | The quality outcome, measured where it is set rather than where it is noticed |
| Exception rate by type, and time to resolve | A well-formed exception queue is a success; an invisible one is a failure |
| Proportion of runs surfacing outcomes to a named owner | FR-0012 in practice — this should be 100%, and a dip is a governance signal |
| Use cases reaching build **without** re-litigating platform requirements | The reuse thesis. If it does not fall, the platform is not a platform |

---

## 9. Constraints

| Constraint | Consequence |
|---|---|
| Workday is the system of record and is not being replaced | Every design decision defers to it — [ADR-0005](adr/0005-workday-as-system-of-record.md) |
| The Microsoft Workday connector is **Premium**, and its connections are **not shareable** | Premium licensing across the path; connections belong to service identities via connection references |
| The connector throttles at **200 calls per connection per 60 seconds** | Batch size and read strategy are design decisions — NFR-0008 |
| The connector's typed Workday actions are **Preview** | Build on `Execute SOAP operation`; treat Preview actions as unavailable for production commitments |
| Copilot Studio harness choice is **permanent per agent** | Decide before creating each agent, not after |
| Power Apps code apps require **Power Apps Premium** for end users | Licensing is confirmed before the control plane app is committed |
| Three integration platforms already exist — Boomi, SAP Integration Suite, Informatica | The Access Layer is an additional, narrow, agent-specific path. It does not replace them |
| Workday ↔ ServiceNow is bi-directional and drives IT joiner/mover/leaver globally | Consume it; do not duplicate provisioning logic |

---

## 10. Open Decisions

Platform-level. Use-case decisions sit in the relevant use-case PRD.

| ID | Decision | Owner |
|---|---|---|
| ~~D-0001~~ | ~~How the Workday Access Layer is surfaced~~ — **CLOSED**: a Copilot Studio workflow with the *When an agent calls the flow* trigger, added to the agent as a tool ([ADR-0011](adr/0011-workflow-first-process-architecture.md)) | — |
| **D-0002** | Workday ISU design: which domains, which access level, and the scoping of the single write permission | HRIS / Security |
| **D-0003** | DLP data-group assignment for the full connector inventory, agreed before the first artefact is built | IT / Security |
| **D-0004** | Whether to adopt the Microsoft 365 Organizational Data Service, at what frequency, and whether it takes profile-data priority | IT / HR |
| **D-0005** | Copilot Credits budget and the harness policy for subsequent agents | DAAI / IT |
| **D-0006** | Dataverse capacity and retention for audit tables | IT / Privacy |
| **D-0007** | Whether Cowork participates in the MVP or a later increment | DAAI |
| **D-0008** | Source-control and pipeline tooling for solution ALM | IT / DAAI |
| **D-0009** | **Microsoft Frontier Program enrolment** — whether GF joins, and which environments are in scope. This is the concrete mechanism behind the frontier-driven position | IT / DAAI |
| **D-0010** | Model lifecycle policy: what happens to a validated agent when its model is updated or retired | DAAI / IT |
| **D-0011** | Connected-agent envelope rule — a connected agent may hold privileges its parent does not, so delegation must not become a bypass | Security / DAAI |

---

## 11. What This Platform Is Not

| Not | Why it matters |
|---|---|
| A replacement for Workday | It exists to keep Workday correct, not to compete with it |
| A second source of truth | Dataverse holds process state. The moment it holds a master-data value, drift begins |
| A decision-making system | Agents prepare evidence. Named humans decide about people |
| A general-purpose Workday gateway | The Access Layer carries three actions. Each addition is a decision, not a task |
| An approved roadmap | The 19 use cases in [`ideas/`](../hr/docs/ideas/README.md) are a portfolio. One is approved |
