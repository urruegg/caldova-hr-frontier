# GF HR Agentic Platform

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [HR Solution Functional Design Intake](docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

**A pure agentic, Frontier-driven HR organisation — with Workday as the system of record.**

Georg Fischer is not automating HR tasks. It is building an HR organisation where agents do the reading, preparing, checking and completing, and people do the deciding. This package is the design for that platform: the requirements, the architecture, the decisions, the journey it serves, and every use case considered.

---

## Where GF is positioning

Microsoft describes three levels of process automation, and organisations usually climb them in order — traditional scripted automation, then digital orchestration across systems, then agentic.

```text
LEVEL 1   Traditional (BPA)     scripts, rule-based tasks, static processes
LEVEL 2   Digital (DPA/RPA)     orchestration across systems and teams
LEVEL 3   AGENTIC               <-- GF positions here
          agents that plan, reason and act toward a business goal
```

**GF is positioning at Level 3, deliberately and from the start.** The Level 2 estate already exists — Boomi, SAP Integration Suite, Informatica, and a bi-directional Workday to ServiceNow flow. This platform does not rebuild it. It puts reasoning on top of it.

### What "pure agentic" means here — and what it does not

**It means** the operating model assumes an agent handles the work first: reading the document, finding the mismatch, preparing the case, drafting the record. Human effort moves to judgement and exception. Nobody re-keys a postal code again.

**It does not mean everything is an agent.** Where a process must behave identically every single time — the audit trail, the file handling, the escalation path — it runs as a deterministic workflow, because the same input always produces the same output. Agents bring reasoning and adaptability; workflows bring structure and consistency. Putting a reasoning model where a rule belongs is not more agentic, it is less governable.

> **The discipline is the differentiator.** A Level 3 organisation is not one that uses agents everywhere. It is one that knows exactly where an agent earns its place — and can prove it.

### Frontier-driven

Two things, both deliberate:

| | |
|---|---|
| **Operating at the frontier** | GF builds on capability as it lands — the GitHub Copilot harness, workflows with agent nodes, skills, computer use — rather than waiting for it to settle. Each is adopted against a written decision, not on release-note enthusiasm |
| **The Microsoft Frontier Program** | The concrete mechanism for early access. Several capabilities in this design reached customers through it first. **Enrolment is a recommended next step** — it is how a frontier-driven position stops being a slogan |

The trade is explicit: earlier capability, in exchange for preview terms, moving documentation, and features that occasionally change or get cancelled. That is an acceptable trade for a showcase organisation and an unacceptable one for an unmanaged estate — which is why every preview capability in this package carries a status and a named owner.

---

## The MVP — three agentic use cases

Scoped to prove the platform, not to cover HR.

| # | Use case | What it proves | Stage |
|---|---|---|---|
| **UC-0001** | **[Personal Master Data Completion Agent](hr/docs/ideas/uc-0001-personal-master-data-completion-agent/README.md)** | An agent can reason over unstructured documents and **write to the system of record** inside a governed envelope | Pre-board |
| **UC-0010** | **[Employee Data Validation](hr/docs/ideas/uc-0010-employee-data-validation-bot.md)** | The **closed loop** — detect what is still wrong across the population and feed it back. Workflow-first, agent only for ambiguity | Cross-cutting |
| **UC-0005** | **[Onboarding Assistant](hr/docs/ideas/uc-0005-onboarding-assistant.md)** | The pattern **extends across a journey stage** without rebuilding the platform | Onboard |

**Why these three.** UC-0001 and UC-0010 form a loop on the same data with the same owner: one completes what the documents allow, the other finds what remains missing across everyone else. UC-0005 then proves the second stage costs less than the first — which is the entire reuse thesis, tested rather than asserted.

> **Running alongside, not counted:** the [HR Policy Chat Assistant](hr/docs/ideas/uc-0002-hr-policy-chat-assistant.md) (UC-0002) is recommended in parallel because on the Copilot chat harness it carries **no charge for Microsoft 365 Copilot-licensed users**. It is an adoption vehicle and a cheap one — but it answers questions rather than taking action, so it is not an agentic exemplar and does not carry the Level 3 claim.

Everything else in the [portfolio](hr/docs/ideas/README.md) — fifteen further use cases — stays an idea until these three land.

---

## The shape of it

```text
EXPERIENCE       Microsoft 365 Copilot · Microsoft Teams · Cowork
                 HR Employee Control Plane App (Power Apps code app)
                                    │
AGENTIC TOOLSET  Copilot Studio · Microsoft 365 Agents · Cowork
                 AGENT  — reasoning, extraction, judgement, refusal
                 WORKFLOW — deterministic: steps, audit, HITL, escalation
                            the workflow calls the agent, not the reverse
                                    │
HR CONTROL       Dataverse — process state, task state, audit
PLANE            Copilot Studio workflows — orchestration
                                    │
GOVERNED         Workday Access Layer  →  Microsoft Workday connector
INTEGRATION      Dataverse · SharePoint · Teams · Office 365 Users · Approvals
                 declared actions · least privilege · read-before-write
                                    │
SYSTEMS OF       Workday — employee master data
RECORD           SharePoint · ServiceNow · SAP P01 (CH payroll) · ERP
```

**Five principles carry most of the weight:**

1. **Workday is the system of record.** Nothing else holds employee master data — not a cache, not a staging table, not "just for reporting". ([ADR-0005](docs/adr/0005-workday-as-system-of-record.md))
2. **Dataverse records what happened, never what the data is.** The test: *if Workday were restored from backup, would this column now be wrong?* If yes, it does not belong in Dataverse. ([ADR-0007](docs/adr/0007-dataverse-process-state-boundary.md))
3. **Every write path declares an envelope, enforced server-side.** Which fields, under which conditions, with which refusals — rejected regardless of what the agent asks for. ([ADR-0008](docs/adr/0008-human-in-the-loop-and-write-envelope.md))
4. **The agent never holds the Workday connector.** GF IT confirmed Microsoft's Workday connector as the access API, but its `Execute SOAP operation` action is a raw pass-through — so a governed access layer sits in front of it, and the Workday Integration System User's permissions make an out-of-envelope write impossible rather than merely rejected. ([ADR-0009](docs/adr/0009-workday-access-via-connector-behind-governed-layer.md))
5. **The workflow owns the process; the agent owns the judgement.** Determinism cannot live in the agent — the GitHub Copilot harness applies its orchestration model to all agents and exposes no configuration for it. So the audit trail, the step sequence and the escalation path run as a deterministic workflow, and the agent is called at the one point reasoning is required. ([ADR-0011](docs/adr/0011-workflow-first-process-architecture.md))

### How we reach Workday

| Path | Status | Role |
|---|---|---|
| **Microsoft Workday connector** (SOAP/REST) | **Confirmed by GF IT** | The transport for every read and governed write. Premium tier; connections are not shareable; throttled at 200 calls per connection per 60 seconds. The MVP builds on `Execute SOAP operation` — the typed Workday actions are all Preview |
| **Workday Access Layer** | This design | Three declared actions — `search_profile`, `read_fields`, `add_missing_value` — and nothing else. Built as a **workflow with the *When an agent calls the flow* trigger**, added to the agent as a tool. Owns the connection so the agent does not |
| **Microsoft 365 Organizational Data Service** | **Not confirmed** | A candidate for people context in Wave 2. Read-only, one-way, weekly or monthly. It cannot serve the MVP: it imports *workers*, and the MVP operates on *candidates and pre-hires* |

The full connector inventory — Dataverse, SharePoint, Teams, Office 365 Users, Outlook, Approvals, and the conditional and later-horizon ones — is in [Solution Design §4.5](docs/solution-design.md), together with the DLP grouping they all have to share.

---

## The first agent

**Personal Master Data Completion Agent** — Switzerland MVP.

HR Operations exports new-joiner PDFs from PeopleDoc to SharePoint. The agent reads them, extracts approved personal master data, matches exactly one Workday profile, and **adds missing approved values only**.

| It does | It never does |
|---|---|
| Add a value to a blank approved field | Overwrite an existing value |
| Continue when one field is missing | Write without exactly one profile match |
| Record every action, skip and exception | Create a worker record |
| Stop and escalate when uncertain | Decide anything about a person |

**Why this one first.** It sits at the stage with the highest manual re-keying, the clearest quality problem, and the narrowest safe write. Because it only fills blanks, every action is reversible — which is what makes writing to the system of record acceptable for a first use case.

> **The highest-risk open item is the matching key.** Last Name + First Name + Postal Code is weak: postal codes change and names repeat. Resolving this — ideally by carrying a Candidate or Pre-Hire ID in the document set — is the single most valuable thing to settle before build. See D-03 in the [UC-0001 PRD](hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md) §13.

---

## Repository map

```text
├── README.md                  you are here — product at a glance
├── AGENTS.md                  the rules every HR agent must satisfy
├── .github/
│   ├── copilot-instructions.md    how agents find evidence in this repo
│   ├── agents/                    definitions for repo-working agents
│   ├── CODEOWNERS                 ownership mirroring the RACI
│   └── ISSUE_TEMPLATE/            use case intake
│
├── docs/                      PLATFORM — applies to every use case
│   ├── prd.md                     FR-0001…FR-0014, NFR-0001…NFR-0012, roles, gates
│   ├── solution-design.md         architecture, integration, security, ALM
│   ├── hr-journey-and-raci.md     journey, RACI, sequencing, the seven declarations
│   ├── adr/                       7 decision records — why, and what was rejected
│   └── brand/                     BrandKit — tokens, Fluent 2 themes, logo slot
│
├── hr/                        HR DOMAIN — what HR does
│   ├── docs/ideas/                the use case portfolio
│   │   ├── uc-0001-…/                 the MVP: use case + PRD  ◀ specified
│   │   └── uc-0002 … uc-0019.md       candidates
│   └── src/solutions/             Power Platform solution source
│
├── infra/                     INFRASTRUCTURE DOMAIN — how it runs (untouched by this package)
│   ├── docs/10-19...               tenant setup, identity, ALM, bootstrap, recovery
│   └── src/{bicep,scripts,config}/    IaC artefacts, Tenant 1 manifest
│
└── data/                      field lists, mappings, test data
                               never real personal data
```

### Which document answers which question

| Question | Read |
|---|---|
| What must the platform always do | [`docs/prd.md`](docs/prd.md) |
| What must *this* use case do | the use case's own PRD in [`hr/`](hr/README.md) |
| How is it built | [`docs/solution-design.md`](docs/solution-design.md) |
| Who is accountable | [`docs/hr-journey-and-raci.md`](docs/hr-journey-and-raci.md) §5–6 |
| **Why** was it decided | [`docs/adr/`](docs/adr/README.md) — and what was rejected |
| How do we stand it up | [`infra/README.md`](infra/README.md) and its documentation map — untouched by this package, still Tenant 1 & 2 (Caldova) only |
| How must an agent behave | [`AGENTS.md`](AGENTS.md) |
| What must it look like | [`docs/brand/`](docs/brand/README.md) — GF palette, Fluent themes, EN/DE/IT/FR/ES |

**Authority rule.** More specific wins — except on governance, where the platform wins. A use-case PRD may add requirements; it may never weaken the platform's. An Accepted ADR outranks narrative text anywhere.

### Naming convention

`<type>-<number>-<context>.md` — `prd-`, `adr-`, `uc-` as filename prefixes; `FR-`, `NFR-`, `BR-`, `AC-`, `D-`, `TD-` as identifiers inside documents. Numbers are allocated once and **never reused**, including after supersession. The three platform documents carry no number because there is exactly one of each.

---

## The use case portfolio

18 candidates from the GF HR AI use case list, placed in the journey and sequenced by what unlocks what. **Three are the MVP. The rest wait.**

```text
MVP     prove Level 3, close the loop, extend one stage
        UC-0001 Master Data Completion · UC-0010 Data Validation
        UC-0005 Onboarding Assistant
        ( + UC-0002 Policy Chat alongside, at no marginal cost )

WAVE 2  service delivery at scale
        Case Classification · JD Generator · Onboarding Checklist

WAVE 3  assisted judgement
        Self-Service Assistant · Candidate Screening · Learning Recommendation · Review Draft

WAVE 4  analytics and prediction
        Workforce Insights · Performance Insights · Skills Inference
        Leadership Pipeline · Attrition Risk

DEFER   Salary Benchmark (Phase 2) · Payroll Anomaly · Pre-hire Orchestration
```

**The MVP is chosen for compounding, not priority.** UC-0001 fills the blanks it has documents for; UC-0010 finds every remaining gap across the population — same data, same owner, same quality problem. UC-0005 then tests whether the second journey stage really is cheaper than the first. If it is not, the platform thesis is wrong and better to know at three use cases than at thirteen.

**Prediction comes last deliberately.** Wave 4 use cases influence decisions about people. They need the governance model and organisational trust that the MVP and Waves 2–3 build.

---

## Three things worth surfacing early

**The Offboard stage has no use cases.** Nothing addresses leaving, access revocation confirmation, knowledge handover or alumni records — despite real compliance exposure and an existing ServiceNow hook. Is this an absence of pain, or an absence of representation?

**Five use cases carry an employment-decision adjacency.** Candidate Screening, Salary Benchmark, Continuous Performance Insights, Leadership Pipeline Prediction and Attrition Risk all produce output that shapes decisions about people. Each needs a named human decision-maker who sees the underlying evidence — a governance commitment to make before any of them starts, not during.

**Several may not need an agent — and saying so is the Level 3 discipline.** UC-0010 is built workflow-first with an agent only for ambiguity. Leadership Pipeline and Attrition Risk are predictive modelling, not conversation. Skills Inference may already be a Workday Skills Cloud capability. Each idea document asks the question rather than assuming, because an agent placed where a rule belongs is the fastest way to discredit the whole position.

---

## Before build

The seven declarations in [`hr-journey-and-raci.md`](docs/hr-journey-and-raci.md) §9 apply to every use case:

write envelope · refusal set · escalation path · grounding sources · data classification · employment-decision surface · measurement

A use case that cannot answer all seven is not ready, whatever its priority.

For the MVP specifically, the Definition of Ready is in the [PRD](hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md) §13, and the full artefact inventory — 60+ items across business, data, system, security, build, test and operations — is in the GF *Build of Materials* document.

---

## Sources

This package is built from GF-supplied material:

| Source | Contributed |
|---|---|
| `PRD_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1` | MVP scope, business rules, functional requirements, acceptance criteria, open decisions |
| `BOM_Artefacts_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1` | Artefact inventory, ownership, status |
| `GF_HR AI Use case list.xlsx` | 16 use cases with business value, KPIs, personas, complexity, risks; plus 2 HR Ops CH pain points |
| `GFAG_Workday Information for Microsoft.pptx` | Workday as system of record, integration landscape, functional areas in use |

Where a source says TBD, this package says TBD. Nothing has been invented to fill a gap — open decisions are listed as open.

---

## Status at handover

| Artefact | Status |
|---|---|
| Platform PRD | Draft 0.1 — FR-0001…FR-0014, NFR-0001…NFR-0012 |
| Solution Design | Draft 0.2 — workflow-first |
| HR Journey and RACI | Draft 0.1 |
| ADR 0005–0009, 0011 | Accepted, pending GF ratification |
| ADR 0010 | **Proposed** — Organizational Data Service not confirmed by GF |
| UC-0001 | **Specified** — PRD Draft 0.3. Definition of Ready **not met** |
| UC-0010, UC-0005 | In MVP scope, **no PRD yet** |
| 15 further use cases | Ideas. No commitment attached |
| Solution source, IaC | **Empty.** This is a design repository; nothing is built yet |

### The three things to settle first

1. **D-03 — the Workday matching key.** Last Name + First Name + Postal Code is marked TBD in GF's own draft and is not sufficient: names repeat and postal codes change, so a false match writes one person's data onto another's record. Carrying a Candidate or Pre-Hire ID through the PeopleDoc export would remove the risk rather than mitigate it. **This is the highest-risk open item in the MVP.**
2. **D-0002 — the Workday ISU write scope.** If Workday security cannot scope a write permission to the approved field set alone, the hard enforcement boundary collapses to software-only controls and the risk position changes materially. Confirm before build, not during.
3. **D-01 — the approved field list.** Until it is final, extraction mapping cannot be completed and MVP scope is unstable.

---

### Phase 3 Infrastructure Map

The [Phase 3 Infrastructure and Tenant Bootstrap Intake](docs/reviews/2026-09-17-phase-3-infrastructure-tenant-bootstrap-intake.md) approves the reviewed repository implementation for local validation, independently of this HR solution package. It covers Tenant 1 and Tenant 2 — the Caldova practice tenants; Tenant 3, the real customer, is out of scope for that intake and untouched by it.

| Entry point | Current role |
|---|---|
| `infra/src/config/tenants/caldova25156897.psd1` | Reviewed Tenant 1 desired-state manifest and immutable GitHub identity inputs. |
| `infra/src/scripts/Invoke-TenantDiscovery.ps1` | Read-only five-service discovery entry point that produces local evidence for review. |
| `infra/src/scripts/Initialize-TenantTrust.ps1` | Attended trust entry point, gated by reviewed intent and separate authorization before any mutation. |
| `infra/src/scripts/Invoke-TenantBootstrap.ps1` | Local orchestration for validation, Bicep parameter generation, `what-if`, boundary checks, and exact-ID cleanup; it does not deploy. |
| `infra/src/bicep/main.bicep` | Subscription-scope Bicep composition constrained to the reviewed resource-type allowlist. |

No live deployment is authorized by this repository state.

---

## Repository Agent Workflow

This repository bundles [Superpowers](https://github.com/obra/superpowers) v6.3.0 for GitHub Copilot. Contributors receive the same agent workflows by cloning the repository; no machine-level Superpowers installation is required.

GitHub Copilot discovers the skills under `.github/skills/` in:

- Visual Studio Code chat and agent mode;
- GitHub Copilot CLI when launched from this repository.

Repository instructions require Copilot to begin with the `using-superpowers` skill and load other skills when relevant.

### Verify the Bundle

From the repository root on Windows, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

The command succeeds with `Repository setup validation passed.` when the folder structure, skill metadata, exact runtime file set and SHA-256 hashes, executable Git modes, bootstrap instructions, version metadata, and license are valid.

In VS Code, open **Chat: Open Customizations** and confirm the workspace skills appear without metadata errors. Confirm `using-superpowers` shows its source/path as `.github/skills/using-superpowers/SKILL.md` so repository provenance is checked.

In Copilot CLI, from the repository root run `copilot --no-auto-update -C . skill list --json` and confirm `using-superpowers` has `source` equal to `project`, `enabled` equal to `true`, and a `path` ending in this repository's `.github/skills/using-superpowers`, regardless of whether the host displays `/` or `\` path separators. In an interactive session, `/skills info using-superpowers` can also confirm the repository location. For the behavior smoke test, start `copilot --no-auto-update -C .`, then enter a natural-language prompt such as `Use the /using-superpowers skill to identify which process applies before changing code.` Standalone `/using-superpowers` is supported, but the prompt form is recommended because it provides a verifiable response.

### Pinned Version and License

The vendored runtime is pinned to upstream release v6.3.0 at commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`.

- Source metadata: [`.github/skills/SUPERPOWERS_VERSION`](.github/skills/SUPERPOWERS_VERSION)
- Runtime SHA-256 manifest: [`.github/skills/SUPERPOWERS_SHA256SUMS`](.github/skills/SUPERPOWERS_SHA256SUMS)
- Upstream MIT license: [`.github/skills/LICENSE.superpowers`](.github/skills/LICENSE.superpowers)

### Updating Superpowers

Updates are deliberate and reviewed. To update:

1. Review the newer upstream release and release notes.
2. Replace only the 14 vendored skill directories with the newer release's `skills/` content.
3. Review and update `.github/cli/verify-repository-setup.ps1` fixed contracts for the new upstream release: the expected 14-skill inventory, seven-path executable mode inventory, source release/version/tag/commit, manifest name and metadata, and license attribution checks.
4. Regenerate `SUPERPOWERS_SHA256SUMS` from every file in the 14 reviewed upstream runtime directories using forward-slash relative paths, ordinal path sorting, and lowercase SHA-256 hashes.
5. Preserve the upstream executable Git modes for the reviewed runtime paths.
6. Refresh `LICENSE.superpowers` if the upstream license changed.
7. Update `SUPERPOWERS_VERSION` with the release, tag object, commit, date, manifest name, and included skill list.
8. Run the repository verifier and complete the VS Code and Copilot CLI smoke tests under **Verify the Bundle**.
9. Commit the runtime replacement, manifest, metadata, validator contracts, and any required bootstrap compatibility changes together.

Do not track upstream `main`, use a submodule, or edit vendored skill files for repository-specific behavior.
