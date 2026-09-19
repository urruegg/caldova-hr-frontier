# Implementation Roadmap: Caldova HR Frontier

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [System Design](./02-system-design.md) |

Proposed Baseline orientation: This document describes intended future operating-model behavior. It does not prove that agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, Teams structures, Work IQ configuration, or tenant controls currently exist.

## 1. Purpose

This roadmap describes a stepwise introduction of the Frontier Operating System for Caldova HR Frontier.

The focus is on fast usability, controlled automation and clear human-in-the-loop governance — and on making the showcase reproducible from the public repository.

## 2. Phase Model

Planned delivery is split into an **MVP** and a **Horizon 2**. The MVP boundary is deliberate: it is the smallest thing that proves the operating model end to end, and it is the line the showcase is demonstrated against.

```text
── MVP ───────────────────────────────────────────────────────
Phase 0: Tenant minimum (admin account, break-glass, bootstrap identity)
Phase 1: GitHub repository and Azure DevOps provisioning
Phase 2: Power Platform foundation (environments, DLP, publisher, solutions)
Phase 3: Delivery transparency (Azure DevOps/GitHub -> Teams)
Phase 4: HR Journey MVP — three selected use cases
── Horizon 2 ─────────────────────────────────────────────────
H2-A: Work IQ agent intake
H2-B: Full journey coverage (Hire, Enable, Change)
H2-C: Release to outcome loop
H2-D: Agent mesh scale-out
H2-E: Deferred surfaces (code apps, declarative agents)
```

The planned build sequence is **GitHub-first**: the public repository would be created before the Azure DevOps project and would provision it. Phase 0 is the minimum tenant work that must precede it, because a workflow cannot reach Azure DevOps until an identity exists in the tenant that it can federate to.

### Why the MVP stops where it does

| Included in MVP | Reason |
|---|---|
| Phases 0–3 | They are the operating model. Without them there is no traceable, governed delivery to demonstrate |
| Three journey use cases | Enough to prove Dataverse, Power Automate, an app surface and a Copilot Studio agent working together under governance |
| Onboarding **and** offboarding | The North Star claims "onboarding to offboarding". One bookend is not the claim |

| Deferred to Horizon 2 | Reason |
|---|---|
| Work IQ agent intake | Valuable, but it automates the *inbound* loop. The outbound delivery loop must work first |
| Hire, Enable and Change stages | Same patterns as Onboard and Offboard. Repetition, not proof |
| Outcome loop and agent mesh | Both require delivered capability to measure and scale |
| **Power Apps** | A custom React surface adds attack surface, reliability targets and a Premium licence dependency for a UI a standard Power App already provides. See §12 |
| **Copilot Studio agents** | The Copilot chat harness delivers grounded policy answers with less scaffolding, and at no charge for Microsoft 365 Copilot-licensed users. See §12 |

## 3. Phase 0: Tenant Minimum

### Goal

Create just enough in the tenant for the GitHub repository to take over. Performed interactively by `admin@Caldova25156897.onmicrosoft.com`. Roughly one hour.

### Deliverables

- Admin account secured — MFA, cloud-only, Global Administrator count confirmed below five.
- **Two break-glass accounts** created, excluded from restrictive Conditional Access, sign-in tested.
- **Security defaults vs Conditional Access decision recorded.** Security defaults block device code flow, so `pac auth create --deviceCode` will fail if they remain on.
- `CHF-Bootstrap-SP` registered with a federated credential for `repo:urruegg/caldova-hr-frontier:environment:bootstrap`, and **no client secret**.
- `CHF-Bootstrap-SP` added to the Azure DevOps organisation with a **Basic** licence and Project Collection Administrators.
- Confirm licensing plan. [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) is the governing repository-local reference until the infrastructure document is imported. Infrastructure detail enters in Phase 3.
- Roles named: Product Owner, Agent Owner, Governance Owner, Technical Owner, Platform Owner.
- Teams channel structure defined.
- Data classification rules defined.

### Exit criteria

- A throwaway `POST /_apis/projects` call using the bootstrap principal succeeds — proving a service principal can create a project in this organisation. **This is documented only by inference; test it before building the workflow.** If it fails, create the project interactively and let the workflow provision everything below it.

## 4. Phase 1: GitHub Repository and Azure DevOps Provisioning

### Goal

The public repository is intended to exist, be hardened, and provision the engineering control plane.

### Deliverables

- Create the public GitHub repository with rulesets, CODEOWNERS, secret scanning and push protection.
- Commit operating model and platform documentation.
- Create `bootstrap`, `test` and `prod` GitHub environments with required reviewers.
- Commit IaC under `infra/` — Bicep for Azure resources, PowerShell for Azure DevOps and Power Platform. [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md) is the governing repository-local reference until the bootstrap documentation is imported. Infrastructure detail enters in Phase 3.
- Bootstrap workflow provisions: the **private** Azure DevOps project, the private Azure Repos repository `caldova-hr-frontier-config`, area paths, iterations, pipeline environments with approvals, and service connections.
- Complete interactive finishing by `admin@`: the Azure Boards ↔ GitHub connection (**no create API exists**), the Power Platform Build Tools extension, the Entra federated credential for the Azure DevOps service connection, and billing.
- `AB#` linking convention documented and enforced by a ruleset commit-message pattern.
- GitHub Issues disabled as a backlog; GitHub Projects not used.
- Create work item tags in Azure Boards:

```text
type:bug          type:feature      type:story       type:epic
type:process      type:architecture type:governance
source:teams      source:work-iq    source:review    source:hr-case
stage:hire        stage:onboard     stage:enable     stage:change      stage:offboard
status:needs-review  status:approved  status:in-sprint
env:test          env:prod
data:public       data:internal     data:personal    data:sensitive
```

### Exit criteria

- Re-running the bootstrap produces no changes and no errors.
- A commit containing `AB#<id>` produces a link on the work item.
- No secret may exist in the repository and push protection must be proven to block one.
- The bootstrap is idempotent: re-running it produces no changes and no errors.

## 5. Phase 2: Power Platform Foundation

### Goal

The three environments are intended to be configured, governed and ready to receive solutions.

### Deliverables

- Confirm DEV and TEST as **Sandbox**, PROD as **Production**.
- Apply tenant-level data policy across all three — **before any flow or agent exists**.
- Enable Managed Environments on TEST and PROD; create the `CHF-Production` environment group and publish its rules.
- Create Entra security groups and bind them to each environment.
- `pac admin self-elevate` completed in each environment by `admin@`.
- Create `CHF-Deploy-SP` and add it as an application user in all three environments.
- Create publisher `Caldova` with prefix `cald` and set it as the preferred solution.
- Create the two domain solutions: `CaldovaHRFrontierInfra`, then `CaldovaHRFrontierHR`.
- Secretless authentication from GitHub Actions to Power Platform proven in DEV, or the gated-secret fallback documented.

### Exit criteria

- A trivial solution change travels DEV → export → unpack → PR → merge → TEST import.
- A PROD import cannot run without a recorded approval.

## 6. Phase 3: Delivery Transparency

### Goal

Employees see in Teams what is happening in delivery.

### Deliverables

- Teams channel `Sprint Delivery` established.
- Teams channel `Release Notes` established.
- Deployment status messages defined for TEST and PROD.
- Standard format for sprint status updates defined.
- Delivery Agent instructions committed.

### Example status message

```text
Sprint Update

Status: TEST deployed
Scope: Day-one task generator for new joiners
Work items: AB#1234, AB#1237
Risks: no critical blockers
Next step: functional review by Product Owner
```

## 7. Phase 4: HR Journey MVP

### Goal

Deliver **three selected use cases** that together are intended to prove the whole chain: a governed Dataverse model, orchestration, a human experience and a grounded agent — deployed through the ALM pipeline with recorded approvals.

This is the MVP boundary. Everything beyond these three is Horizon 2.

### The three use cases

| # | Use case | Stage | Built with | Proves |
|---|---|---|---|---|
| **1** | **Onboarding journey orchestration** — day-one, week-one and 90-day tasks generated from a journey template when a joiner record is created | Onboard | Dataverse + Power Automate | The data model, the orchestration layer, and journey state |
| **2** | **Onboarding Assistant** — answers a new joiner's questions from approved SharePoint knowledge, cites its source, and escalates any individual case to a named human | Onboard | Copilot Studio agent | The agent surface, grounding discipline and the HITL escalation gate |
| **3** | **Offboarding checklist and access revocation handover** — leaver intake generates the checklist across employee, manager, IT and HR, tracks asset return, and produces the access revocation handover pack | Offboard | Dataverse + Power Automate + Power Apps | The other bookend of the journey, and exception handling |

Use case 1 and 3 share the same `ur_journey` / `ur_journeytask` model, which is the point — one model, two stages, no special-casing.

### Flow

```text
Future HR journey design (planned under HR domain documentation)
  -> Dataverse tables and security model      (ur_ solution, Infra imported first)
    -> Power Automate orchestration
      -> Power App task experience
        -> Copilot Studio Onboarding Assistant
          -> TEST -> PROD
```

### Deliverables

- Deploy the Dataverse journey data model as a managed solution to TEST and PROD.
- Create journey template and template-task records for onboarding and offboarding.
- Build the onboarding orchestration flow that generates day-one, week-one and 90-day tasks.
- Build the employee and manager task experience (Power App — **not** a code app; see §12).
- Publish the Onboarding Assistant to Teams through the agent publication gate.
- Build offboarding orchestration including asset return tracking and the access revocation handover pack.
- Commit the synthetic demo data set to `data/`.
- Write the demo script covering the three use cases end to end.

### Exit criteria

- A synthetic new joiner can be created in DEV, receive generated onboarding tasks, ask the Onboarding Assistant a question and get a cited answer, be escalated to a human on an individual-case question, and then be taken through offboarding to a completed checklist with one deliberate outstanding exception.
- Every artefact must reach PROD through the pipeline with a recorded approval — nothing hand-made in the target environment.
- The demo runs in under ten minutes from a clean reset.

---

## 8. Horizon 2

Everything below is designed, documented and **not built during the MVP**. Each item names what unblocks it.

### H2-A: Work IQ agent intake

Work IQ becomes the interaction layer between people and agents, closing the inbound half of the loop.

**Deliverables:** intake prompt; Product Discovery Agent connected; governance review enforced before engineering handover; HITL approval card; work item draft schema.

**Work item draft schema**

```yaml
title: ""
type: "bug | feature | story | epic | process | architecture | governance"
source: "teams | work-iq | review | hr-case | dataverse"
journey_stage: "hire | onboard | enable | change | offboard"
summary: ""
problem: ""
user_impact: ""
acceptance_criteria:
  - ""
risks:
  - ""
tags:
  - ""
data_classification: "public | internal | personal | sensitive"
redaction_applied: true
requires_governance_review: true
confidence: 0.0
human_reviewer: ""
azure_boards_id: ""
```

**Exit criteria:** a draft carrying `data_classification: personal` cannot become a work item without a recorded Governance Owner approval.

**Unblocked by:** MVP Phase 4 complete — there must be delivery capacity for intake to feed.

### H2-B: Full journey coverage

Extend to the **Hire**, **Enable** and **Change** stages using the patterns proven in the MVP: pre-boarding checklist, learning path assignment, manager check-ins, HR case intake and routing, role and location change checklists, Manager Assistant, Offboarding Assistant.

**Unblocked by:** MVP Phase 4 complete. These are repetitions of a proven pattern, which is precisely why they are not MVP.

### H2-C: Release to outcome loop

After every release, check whether value was created.

```text
Release -> Delivery Agent -> Teams Release Update
  -> Dataverse Outcome Signals -> Outcome Agent -> Learning Summary
```

**Deliverables:** release note template; outcome signal schema; Dataverse measurement points; outcome report template; Teams review format.

**Outcome signal examples**

```text
Day-one task completion rate
Time to first productive week
Onboarding cycle time
HR case volume per journey stage
Policy question deflection rate
Offboarding checklist completion before last day
Manager satisfaction with journey tooling
Agent containment and escalation rate
```

**Unblocked by:** capability in PROD long enough to produce a before-and-after.

### H2-D: Agent mesh scale-out

Agents scaled as a digital workforce model: agent registry, superpower mapping, agent-to-agent handover rules, automated quality gates, governance monitoring, outcome-based sprint prioritisation, and an evaluation set per agent run before each publication.

**Unblocked by:** more than two agents in production.

### H2-E: Deferred surfaces

Two surfaces are designed and deliberately not built in the MVP. Both remain documented so the decision is reversible.

| Surface | Why deferred | Revisit when |
|---|---|---|
| **Power App** | Adds attack surface (*"Using code components can inadvertently increase the workload's attack surface"*), new reliability targets, a **Power Apps Premium** licence for every end user, and a publicly accessible asset endpoint with no IP restriction. A standard Power App delivers the MVP task experience without any of it | The journey experience needs something a standard Power App genuinely cannot do |
| **Microsoft 365 declarative agent** | The **Copilot chat harness** in Copilot Studio delivers grounded policy answers from SharePoint, and that usage is **included at no charge for Microsoft 365 Copilot-licensed users**. A declarative agent adds a second toolchain, a second publishing path and Agent Registry approval for the same outcome | Policy answers must reach surfaces Copilot Studio cannot publish to |

> Deferring these **reduces MVP licensing, governance and delivery surface simultaneously**. It is the highest-leverage scope decision in this roadmap.

---

## 9. MVP Backlog

Epics 1–5 are the MVP. Everything after is Horizon 2 and is not scheduled until the MVP exits.

### Epic 1: Tenant Minimum

- Secure `admin@Caldova25156897.onmicrosoft.com` and confirm the Global Administrator count.
- Create two break-glass accounts and test sign-in.
- Decide security defaults vs Conditional Access and record it.
- Register `CHF-Bootstrap-SP` with a federated credential and no client secret.
- Add `CHF-Bootstrap-SP` to the Azure DevOps organisation with a Basic licence.
- Smoke-test service principal project creation.
- Confirm licensing and name the owning roles.

### Epic 2: GitHub Repository and Azure DevOps Provisioning

- Create the public repository with rulesets, CODEOWNERS and push protection.
- Commit the operating model and domain documentation set.
- Create the `bootstrap`, `test` and `prod` GitHub environments with required reviewers.
- Build the idempotent bootstrap that provisions the private project, the `caldova-hr-frontier-config` repository, area paths, iterations, environments, approvals and service connections.
- Complete the interactive finishing steps: Azure Boards ↔ GitHub connection, Build Tools extension, Entra federated credential, billing.
- Define branch, commit and pull request conventions and enforce `AB#` by ruleset.

### Epic 3: Power Platform Foundation

- Confirm environment types and bind security groups.
- Apply the DLP baseline before any artefact exists.
- Enable Managed Environments and publish the environment group rules.
- Self-elevate in each environment; create `CHF-Deploy-SP` and its application users.
- Create the publisher, prefix and **the two domain solutions** — `CaldovaHRFrontierInfra`, then `CaldovaHRFrontierHR`.
- Verify the Infra solution imports cleanly into an empty TEST environment, with custom connectors and connection references resolving.
- Prove secretless authentication from GitHub Actions to Power Platform, or document the fallback.

### Epic 4: Delivery Transparency Loop

- Define the Sprint Delivery channel.
- Define the Release Notes channel.
- Define delivery status notifications to Teams.
- Define TEST and PROD communication format.

### Epic 5: HR Journey MVP

The three MVP use cases, in build order.

**Use case 1 — Onboarding journey orchestration**
- Deploy the Dataverse journey data model and security roles.
- Create onboarding journey template and template tasks.
- Build the day-one, week-one and 90-day task generation flow.
- Build the employee and manager task experience as a Power App.

**Use case 2 — Onboarding Assistant**
- Create the `ur_HRCommon` component collection: self-identification, escalation, employment-decision refusal.
- Build the Onboarding Assistant on approved SharePoint knowledge, grounded and citing.
- Write the capability statement, intent map, conversation flow and fallback behaviour.
- Pass the agent publication gate and publish to Teams.

**Use case 3 — Offboarding checklist and access revocation handover**
- Create the offboarding journey template.
- Build leaver intake and last-day calculation.
- Build the offboarding checklist across employee, manager, IT and HR.
- Build asset return tracking and the access revocation handover pack.

**Across all three**
- Produce the synthetic demo data set in `data/`, including deliberate exceptions.
- Write the demo script and the reset procedure.
- Validate that the showcase can be rebuilt from the repository alone.

---

### Horizon 2 backlog

Not scheduled until the MVP exits. Listed so the intent is visible, not so it is started.

| Epic | Contents |
|---|---|
| **H2-A** Work IQ intake layer | Intake prompt, Product Discovery Agent schema, HITL approval process, Governance Agent redaction pattern and its test |
| **H2-B** Full journey coverage | Hire, Enable and Change stages; Manager and Offboarding assistants; HR case intake and routing |
| **H2-C** Outcome measurement | Outcome signal schema, Dataverse measurement points, Outcome Agent prompt, outcome report in Teams |
| **H2-D** Agent mesh scale-out | Agent registry, superpower mapping, handover rules, automated quality gates, governance monitoring |
| **H2-E** Deferred surfaces | Power App; Copilot Studio agents |

## 10. Recommended Sequence Within the MVP

Phases 0–3 are sequential and non-negotiable. Within **Phase 4**, the three use cases have a recommended order:

```text
1. Onboarding journey orchestration   — the data model everything else depends on
2. Offboarding checklist + handover   — same model, second stage; proves reuse early
3. Onboarding Assistant               — needs journey data to be useful, and carries the
                                        governance gate, so it benefits from going last
```

Building use case 3 second is a common instinct — the agent is the most demonstrable piece. Resist it: an assistant with no journey data to talk about demos badly, and the publication gate is easier to pass once the data it grounds on is stable.

## 11. Sequencing Constraints

| Constraint | Reason |
|---|---|
| The bootstrap identity exists before the repository can provision anything | A workflow cannot reach Azure DevOps until there is an identity in the tenant it can federate to. This is why Phase 0 is not skippable |
| The security defaults decision precedes the first CLI sign-in | Security defaults block device code flow, so `pac auth create --deviceCode` fails |
| `pac admin self-elevate` precedes any Dataverse configuration | Administrators are no longer auto-assigned the System Administrator role |
| Break-glass accounts exist before Conditional Access is tightened | A single administrator plus a restrictive policy is a lockout waiting to happen |
| Phase 0 identity work precedes all pipeline work | Pipelines cannot authenticate without the service principal and application users |
| DLP baseline precedes any flow or agent build | Retro-fitting a DLP policy breaks existing connections |
| Solution publisher and prefix are decided once, before the first table | Changing a prefix later requires rebuilding components |
| **Infra solution is imported before the HR solution, in every environment** | The HR solution depends on its connection references, environment variables and security roles |
| Governance redaction is proven before intake automation | Otherwise personal data can reach a public repository |
| Managed Environment settings are applied before PROD use | Some controls cannot be applied retroactively without disruption |
| **The journey data model precedes the Onboarding Assistant** | An agent grounded on an unstable model is rework, and its publication gate is harder to pass |
