# System Design: Caldova HR Frontier Operating System

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Implementation Roadmap](./05-implementation-roadmap.md) |

Proposed Baseline orientation: This document describes intended future operating-model behavior. It does not prove that agents, Azure DevOps objects, pipelines, environments, Power Platform solutions, Azure resources, Teams structures, Work IQ configuration, or tenant controls currently exist.

## 1. Overview

The system is intended to connect Microsoft 365, Work IQ, Microsoft 365 Copilot agents, Microsoft Copilot Studio, the Power Platform, Dataverse, Azure DevOps and GitHub into one closed human-agent feedback loop for the Caldova HR employee journey.

## 2. Architecture Principles

```text
Human-led
Agent-operated
HITL-controlled
DevOps-governed
GitHub-driven
Dataverse-backed
Teams-visible
Privacy-by-design
```

## 3. High-Level Architecture

```text
+--------------------+  +--------------------+  +--------------------+
|      Employees     |  |      Managers      |  |   HR Practitioners |
+---------+----------+  +----------+---------+  +---------+----------+
          |                        |                      |
          v                        v                      v
+----------------------------------------------------------------+
|                       Teams / Work IQ                          |
|                Human-Agent Interaction Layer                   |
+-------------------------------+--------------------------------+
                                |
                                v
+----------------------------------------------------------------+
|                        Agent Mesh                              |
|  Copilot Studio agents | Copilot Studio agents        |
|  Voice of Employee | Product | Architecture | Delivery          |
|  Release | Outcome | Governance | Quality                       |
+-------------------------------+--------------------------------+
                                |
                                v
+----------------------------------------------------------------+
|            Azure DevOps — Engineering Control Plane             |
|  Boards | Iterations | Delivery Plans | Pipelines | Approvals   |
+-------------------------------+--------------------------------+
                                |  AB# work item links
                                v
+----------------------------------------------------------------+
|              GitHub — Digital Factory (public)                  |
|  Source | PRs | Actions | Releases | .github/agents             |
|  Copilot CLI | copilot-instructions.md | Repo knowledge         |
+-------------------------------+--------------------------------+
                                |
                                v
+----------------------------------------------------------------+
|                 Power Platform / Dataverse                      |
|  DEV -> TEST -> PROD  |  Employee | Journey | Case | Outcome    |
+-------------------------------+--------------------------------+
                                |
                                v
+----------------------------------------------------------------+
|                   Teams Transparency Loop                       |
|  Status | Decisions | Releases | Outcome Review                 |
+----------------------------------------------------------------+
```

## 4. Control Planes

### 4.1 Business Control Plane: Microsoft Teams

Teams is intended to be the organisational space for:

- Employee and manager communication
- Sprint reviews and showcases
- Release communication
- Feedback
- Management decisions
- Human-in-the-loop approvals

### 4.2 Interaction Control Plane: Work IQ

Work IQ is intended to be the interaction layer for:

- Human–agent dialogue
- Prompted reviews
- Agent task routing
- Feedback intake
- Decision support
- Approvals and escalations

### 4.3 Agent Control Plane: Microsoft 365 Copilot and Copilot Studio

Agents perform:

- Summarisation
- Classification
- Draft creation
- Recommendation
- Status reporting
- Review support

Two agent surfaces are used deliberately:

| Surface | Used for | Lives in |
|---|---|---|
| Copilot Studio — Copilot chat harness | Knowledge-grounded assistance surfaced inside Microsoft 365 Copilot and Teams. Included at no charge for Microsoft 365 Copilot-licensed users | Solution component, deployed DEV → TEST → PROD |
| Microsoft Copilot Studio agents | HR process agents with Dataverse actions, topics and autonomous triggers | Power Platform solution, deployed DEV → TEST → PROD |

### 4.4 Engineering Control Plane: Azure DevOps

Azure DevOps is intended to own the **flow and governance of work**:

- Product backlog: Epics, Features, User Stories, Tasks, Bugs
- Iterations, area paths, Delivery Plans
- Pipelines for solution build, validation and deployment
- Environments with approvals and checks as the TEST and PROD gates
- Test plans and traceability
- Service connections to the Power Platform environments and the Azure subscription

Azure Boards is intended to be the **single source of truth for the backlog**. GitHub Issues are not intended to be used as a parallel backlog.

### 4.5 Digital Factory: GitHub

GitHub is intended to own the **build and the proof**:

- Source of truth for all code, configuration and documentation
- Unpacked Power Platform solution source
- Pull requests, code review and branch protection
- GitHub Actions for build, validation and publishing
- Releases and release notes
- Agent definitions under `.github/agents/`
- Copilot custom instructions, prompt files and chat modes
- GitHub Copilot CLI as the primary implementation tool

### 4.6 Operational Control Plane: Dataverse

Dataverse is intended to own operational truth:

- Employee and candidate master records (demo data)
- Journey instances and journey tasks
- HR case data
- Process status
- Outcome and measurement data
- Audit-relevant operational information

### 4.7 Platform Control Plane: Power Platform Admin Center, Entra ID and Purview

Platform owners govern:

- Environments, capacity and environment groups
- DLP policies and connector classification
- Managed Environment settings
- Identity, groups, conditional access and application registrations
- Audit, retention and compliance signal collection

## 5. Principal Data Flows

### 5.1 Feedback Intake Flow

```text
Teams / Work IQ / HR case feedback
  -> Intake Trigger
    -> Voice of Employee Agent
      -> Classification
        -> Governance Agent (sensitivity + redaction)
          -> HITL Review
            -> Azure Boards work item draft
              -> Azure Boards work item
```

### 5.2 Review Transcript Flow

```text
Teams Meeting Recording
  -> Transcript
    -> Work IQ Intake
      -> Product Discovery Agent
        -> Summary + Findings
          -> Governance Agent
            -> Work Item Drafts
              -> Product Owner Review
                -> Azure Boards / Delivery Plan
```

### 5.3 Delivery Status Flow

```text
Azure Boards work item / GitHub PR / Action run / Release
  -> Delivery Agent
    -> Status Summary
      -> Work IQ
        -> Teams Channel Update
```

### 5.4 Build Flow (source to environment)

```text
GitHub Copilot CLI task (branch)
  -> Commit with AB#<work-item-id>
    -> Pull Request + required review
      -> GitHub Actions: pack + solution checker
        -> Azure DevOps Pipeline: import to TEST
          -> Environment approval
            -> Import to PROD
              -> GitHub Release + Teams notification
```

### 5.5 Outcome Measurement Flow

```text
Release
  -> Deployment Status
    -> Dataverse usage / process signals
      -> Outcome Agent
        -> Business Impact Draft
          -> Teams Review
```

## 6. Agent Mesh

```text
Agent Mesh
  |
  +-- Voice of Employee Agent
  +-- Product Discovery Agent
  +-- Architecture Agent
  +-- Delivery Agent
  +-- Release Agent
  +-- Outcome Agent
  +-- Governance Agent
  +-- Quality Agent
  |
  +-- HR Journey Agents (Copilot Studio)
        +-- Onboarding Assistant
        +-- Policy & Benefits Assistant
        +-- Manager Assistant
        +-- Offboarding Assistant
```

## 7. Repository Structure

Two solution domains, each self-contained; synthetic data and cross-cutting documentation as siblings.

```text
infra/                              # Infrastructure domain
  docs/                             # 10-18 platform documentation
  src/
    solutions/CaldovaHRFrontierInfra/    # imported FIRST
    bicep/ scripts/ config/tenants/      # IaC (ADR-0003)
  tests/

hr/                                 # HR domain
  docs/                             # 20 journey design
  src/
    solutions/CaldovaHRFrontierHR/       # depends on Infra

data/                               # synthetic seed data

docs/                               # cross-cutting
  operating-model/ adr/ 90-microsoft-best-practice-evaluation.md

.github/
  copilot-instructions.md agents/ agent-policy/ skills/ workflows/
```

Tenant-specific configuration — deployment settings with real environment values, variable groups, governed pipeline templates and runbooks — is intended to live in the **private Azure Repos repository `caldova-hr-frontier-config`**, not here, when that private repository exists. See [Approved Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md).

## 8. Integration Patterns

### Pattern A: Teams to Azure Boards

For feedback, reviews and sprint inputs.

```text
Teams / Work IQ
  -> Agent Intake
    -> Governance Redaction
      -> Human Review
        -> Azure Boards work item
```

### Pattern B: Azure DevOps / GitHub to Teams

For sprint status, release notes and deployment updates.

```text
Pipeline / Release event
  -> Delivery Agent
    -> Teams Summary
```

### Pattern C: GitHub to Azure Boards

For engineering traceability. A commit or pull request that contains `AB#1234` links the change to work item 1234, and the work item shows the linked branch, commit, pull request and release.

```text
Commit message: "feat(onboarding): add day-one task generator AB#1234"
  -> Azure Boards work item 1234 development links
```

### Pattern D: Dataverse to Outcome Agent

For impact measurement.

```text
Dataverse Signal
  -> Outcome Agent
    -> Impact Summary
      -> Teams Review
```

### Pattern E: Agent to Agent

For more complex workflows.

```text
Voice of Employee Agent
  -> Product Discovery Agent
    -> Architecture Agent
      -> Delivery Agent
        -> Outcome Agent
```

## 9. Security Design

### 9.1 Least Privilege

Every integration receives only the permissions its workflow requires. The deployment principal has environment-scoped rights; the bootstrap principal is scoped to Azure DevOps. Neither is a tenant-wide administrator, and they are deliberately separate principals.

### 9.2 Separation of Build Identity and Tenant Identity

The GitHub account performing the build is deliberately outside the tenant. It never receives direct interactive access to PROD. Its route into the tenant is:

```text
GitHub account -> Pull Request -> Reviewed merge
  -> Pipeline -> Service principal -> Environment
```

### 9.3 Data Minimisation

Employee data is minimised or redacted before handover to GitHub. The repository is public; no tenant identifier, secret, endpoint credential or real person may appear in it.

### 9.4 Secretless Automation

Workload identity federation is preferred over stored client secrets. Where a secret is unavoidable, it is stored in Azure Key Vault or a GitHub environment secret, never in source.

### 9.5 Audit Trail

Every agent proposal, every approval and every handover to an engineering system is logged traceably.

### 9.6 Human Approval Gates

Critical steps require explicit human approval:

- Creation of final work items from sensitive sources
- Sprint prioritisation
- TEST release
- PROD deployment
- Publication of outcome reports
- Any processing of special-category employee data
- Publication or update of an agent available to employees

## 10. Planned Deployment Environments

```text
DEV  -> TEST -> PROD
```

| Environment | Planned URL | Purpose | Solution state |
|---|---|---|---|
| DEV | `hrfrontierdev.crm17.dynamics.com` (planned, not yet verified) | Authoring, unmanaged solution, Copilot Studio authoring | Unmanaged |
| TEST | `hrfrontiertest.crm17.dynamics.com` (planned, not yet verified) | Integration and acceptance validation | Managed |
| PROD | `hrfrontier.crm17.dynamics.com` (planned, not yet verified) | Showcase and demonstration environment | Managed |

Status messages must at minimum distinguish:

- Feature in delivery
- PR open
- PR merged
- TEST deployed
- PROD deployed
- Rollback required
- Blocked

## 11. Observability

To be monitored:

- Agent runs and failure rates
- HITL decisions and intervention rate
- Work item lifecycle in Azure Boards
- Pipeline and Action run results
- Deployment status per environment
- Outcome reports
- Data-protection-relevant events (redaction, DLP block, push protection block)
- Power Platform and Copilot Studio analytics

## 12. Technical Backlog Candidates

- Evaluate the Azure Boards app for GitHub and confirm `AB#` linking from the public repository.
- Define the Teams channel set for delivery and release communication.
- Define the Work IQ intake prompt.
- Equip the Product Discovery Agent with the work item schema.
- Create the work item intake template for agent-generated drafts.
- Define the pipeline that publishes release status to Teams.
- Define the Outcome Agent Dataverse signal schema.
- Define governance checks for sensitive employee data.
- Establish the deployment settings file per environment for connection references and environment variables.
- Decide the Power App surface for the journey task experience (canvas or model-driven).
