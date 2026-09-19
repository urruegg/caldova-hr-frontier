# Microsoft Best Practice Evaluation

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-09-19 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Cross-cutting (all solution domains) |
| **References** | [Approved Intake Design](./specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](./reviews/2026-09-17-architecture-baseline-source-inventory.json) |

This is a source-derived Proposed Baseline assessment. `Aligned` means alignment of documented design, not proof of deployed controls; deployment/configuration claims remain planned or not yet verified.

## 1. How to Read This

This document assesses the Caldova HR Frontier design against Microsoft's published guidance, pillar by pillar, citing the specific checklist item each finding relates to.

| Verdict | Meaning |
|---|---|
| **Aligned** | The design satisfies the recommendation |
| **Partial** | Addressed in part; the gap is stated |
| **Gap** | Not addressed. A real finding, not a formatting complaint |
| **Deviation** | We deliberately do something else, with a stated reason |
| **Watch** | Guidance is stale, preview, contradictory or unverified — revalidate before relying on it |

Checklist identifiers (`RE:01`, `SE:03`, `XO:10`, …) are Microsoft's, taken from each pillar's checklist page. Where a Microsoft recommendation guide and its checklist disagree on an item's number, **the checklist page is treated as authoritative** — see §8.

---

## 2. Frameworks Used

### 2.1 The correction

Version 1.x of this document assessed the workload against the [Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/) and its five pillars, including **Cost Optimization**. That was wrong for a Power Platform workload.

**[Power Platform Well-Architected](https://learn.microsoft.com/en-us/power-platform/well-architected/)** is a separate framework. Microsoft states the relationship directly:

> *"Four of the five pillars in Power Platform Well-Architected (Reliability, Security, Operational Excellence, Performance Efficiency) are based on the Azure Well-Architected Framework. The fifth pillar, Experience Optimization, is unique to Power Platform Well-Architected."*
> — [What is Power Platform Well-Architected?](https://learn.microsoft.com/en-us/power-platform/well-architected/what-is-power-well-architected)

Two consequences matter:

1. **There is no Cost Optimization pillar, and no cost pillar under any name.** Cost has not been renamed — it was dropped as a pillar and distributed into others. `OE:05` asks you to *"optimize a supply chain to make your workload reliable, secure, cost-effective, and performant"*, and Performance Efficiency folds cost into its design tradeoffs. Licensing and capacity arguments in this document are therefore attached to **PE** and **OE**, or sourced from licensing documentation outside the framework.
2. **Experience Optimization is a net-new pillar**, not a substitute. For a workload whose primary surfaces are an employee-facing app and six conversational agents, it is arguably the most load-bearing pillar of the five — and it was entirely absent from v1.x.

The Azure WAF remains relevant to the **Azure** resources planned for the future `infra/bicep` path. Microsoft's own note: *"Power Platform Well-Architected is based on the methodology and guidance of the Microsoft Azure Well-Architected Framework. It is designed to be used in alignment with Azure Well-Architected for those organizations that use both Power Platform and Azure."*

### 2.2 The two frameworks, and their scopes

| Framework | Scope | Pillars | Applies to |
|---|---|---|---|
| [Power Platform Well-Architected](https://learn.microsoft.com/en-us/power-platform/well-architected/) | **Workload** | RE · SE · OE · PE · XO | The HR Frontier solution itself — §3 |
| [Power Platform adoption guidance](https://learn.microsoft.com/en-us/power-platform/guidance/adoption/methodology) | **Tenant / organisation** | Strategy · Plan · Security · Governance · Operations · Availability · Readiness · Community | The tenant, environments and governance — §5 |

The split is real and reflected in the framework itself. Well-Architected formalises the distinction between the **workload team** and **centralized teams** who *"provide services, guidance, and guardrails for workloads"* — which in this showcase are the same people wearing different hats, but the documents are separated accordingly.

> ⚠️ Microsoft publishes **no mapping table** between the eight adoption pillars and the five Well-Architected pillars. Any correspondence drawn in §5 is our inference.

### 2.3 Verified negatives

Worth stating explicitly, because each was searched for and is genuinely absent:

| Sought | Status |
|---|---|
| A Cloud Adoption Framework **scenario for Power Platform** | **Does not exist.** The CAF scenario list is Azure adoption, Data platform, AI adoption, **AI agents**, Sovereignty, Azure VMware Solution. Power Platform adoption guidance lives in its own tree, not in CAF |
| A Cost Optimization pillar in Power Platform WAF | Does not exist |
| An **HR or employee-experience reference architecture** in the Architecture Center | Does not exist. The nearest structural analogues are *Automate service order lifecycle and SLA governance with Power Platform* and *Migrate legacy meetings to Microsoft Teams with a conversational agent* |
| Well-Architected guidance for **Copilot Studio agents** | Does not exist in Power Platform WAF or the Architecture Center. Declarative agent guidance sits in the M365 Copilot developer documentation |
| A Well-Architected page on **DLP policies, Managed Environments or workload identity federation** | Does not exist. These must be argued under `SE:04` (segmentation) and `OE:09` (governance guardrails) |

> **On CAF specifically:** the new **AI agents** CAF scenario is the nearest framework-level hook for the Copilot Studio agent components, but it is Azure-scoped rather than Power Platform-scoped. Treat any use of it here as extrapolation.

### 2.4 Source currency

| Source | Last updated | Treat as |
|---|---|---|
| Power Platform WAF pillars | August 2025 | **Stable spine.** Roughly 13 months old; *What's new* has no entry after August 2025 |
| [Architecture Center](https://learn.microsoft.com/en-us/power-platform/architecture/) | September 2026 | Current |
| [Copilot Studio guidance](https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/) | March–June 2026 | **Current — this is where live agent guidance is being invested** |
| [Adoption guidance](https://learn.microsoft.com/en-us/power-platform/guidance/adoption/methodology) | August 2026 | Current |
| [`microsoft/industry` landing zones repo](https://github.com/microsoft/industry/tree/main/foundations/powerPlatform) | ~3 years old, **archived** | Vocabulary only — superseded by §5.2 |

> ⚠️ **The resources hub at `microsoft.github.io/power-platform-resources` is not official Microsoft documentation.** It is hosted under Microsoft's GitHub organisation, MIT-licensed, individually maintained, with no docs review process. Use it as a **discovery index**; always follow through to the Microsoft Learn or GitHub target and cite that instead. Its links are also not all current — it lists the archived landing-zones repo without flagging the archive.

---

## 3. Pillar Assessment

### 3.1 Reliability (`RE:`) — the weakest pillar in this design

> *"Ensure the workload meets the uptime and recovery targets by building redundancy and resiliency at scale."*
> [Checklist](https://learn.microsoft.com/en-us/power-platform/well-architected/reliability/checklist)

| Item | Recommendation (abbreviated) | Verdict | Position |
|---|---|---|---|
| **RE:01** | Align to business objectives, avoid unnecessary complexity | **Aligned** | Two solutions rather than four (ADR-0004); Bicep plus PowerShell rather than a third toolchain (ADR-0003). *"Keep it simple"* is an explicit design principle here and we have applied it |
| **RE:02** | Identify and rate user and system flows by criticality | **Gap** | The employee journey is documented as stages, not as **rated flows**. Nothing says which flow is critical. Onboarding day-one task generation and offboarding access revocation are plainly more critical than a policy question — the design does not say so |
| **RE:03** | Failure mode analysis | **Gap** | No FMA exists. Obvious candidates unanalysed: Dataverse throttling during bulk task generation, a flow failing mid-journey leaving a partial task set, an agent knowledge source becoming unavailable, connection reference expiry |
| **RE:04** | Define reliability and recovery targets; build a health model | **Gap** | No targets defined. No healthy / degraded / unhealthy definition for any flow |
| **RE:05** | Error handling and transient fault handling | **Partial** | The proposed agent workload configuration requires run-after paths and writing failures to `ur_hrcase`. No transient-fault or retry strategy is specified |
| **RE:06** | Test for resiliency and availability | **Gap** | The testing strategy covers correctness, not resiliency. No fault injection, no degradation testing |
| **RE:07** | Business continuity and disaster recovery plans | **Partial** | Extended backup retention is planned for TEST and PROD via the environment group, but it is not yet verified. There is **no BCDR plan**, no documented recovery procedure, and no recovery test. For a time-boxed demo tenant the real continuity asset is the repository — which is proposed in ADR-0002 but never framed as BCDR |
| **RE:08** | Measure and publish health indicators | **Partial** | Observability is listed in [System Design](./operating-model/02-system-design.md) as things "to be monitored". No health indicator is defined, captured or published |

**Summary:** Reliability is the least-developed pillar. That is defensible for a showcase and it should be **stated as a conscious position rather than left as an omission**. The cheapest high-value additions are `RE:02` (rate the flows — half a page) and `RE:04` (targets and a health model for the two critical flows).

### 3.2 Security (`SE:`) — the strongest pillar

> [Checklist](https://learn.microsoft.com/en-us/power-platform/well-architected/security/checklist)

| Item | Recommendation (abbreviated) | Verdict | Position |
|---|---|---|---|
| **SE:01** | Establish a security baseline aligned to compliance and platform recommendations | **Aligned** | The proposed security baseline documents DLP, Managed Environments, tenant isolation, Dataverse security, and auditing, but deployed controls are not yet verified |
| **SE:02** | Secure development lifecycle; hardened, auditable software supply chain; threat modelling | **Partial** | Supply chain is strong — reviewed pull requests, federated identity, secret scanning with push protection, Solution Checker gates. **No threat model exists.** `SE:02` asks for one explicitly |
| **SE:03** | Classify and consistently apply sensitivity and information type labels | **Aligned, and central** | Four data classes are defined in [HITL Governance](./operating-model/04-hitl-governance.md), planned for Dataverse column security, and intended to propagate into work item tags and the PR checklist. This aligns with Microsoft's own taxonomy, where **Sensitive PII sits in the "Highly confidential" tier** |
| — | *"Don't create your own classification system"* — follow the organisation's taxonomy | **Watch** | Our four classes are workload-invented because no tenant taxonomy exists in a demo tenant. Correct in context; would need reconciling in a real tenant |
| — | *"protect personal data by removing or obfuscating it from any kind of application logs"* | **Gap** | Classification is applied to Dataverse columns and to repository content. It is **not** applied to Power Automate run history or **agent conversation transcripts**, both of which will contain employee text |
| **SE:04** | Intentional segmentation across networks, roles, workload identities, resource organisation | **Aligned** | The proposed design uses three environments with security groups, environment groups, two separate service principals by plane, Dataverse business units and teams |
| **SE:05** | Strict, conditional, auditable identity and access management | **Aligned** | The proposed identity model treats identity as the primary perimeter: admin account for configuration, federated service principals for automation, no user credential in any pipeline |
| **SE:06** | Encrypt data with platform-native methods aligned to classification | **Partial** | Platform-native encryption is assumed and never stated. Customer-managed keys are available on Managed Environments and not discussed |
| **SE:07** | Protect application secrets; regular rotation with emergency capability | **Aligned** | Federation removes the steady-state secret. Where one is unavoidable it is a gated environment secret or Key Vault. **No rotation procedure** is documented for the fallback case |
| **SE:08** | Holistic monitoring with modern threat detection integrated with the platform | **Partial** | Purview auditing is planned but not yet verified. Microsoft Sentinel integration for Copilot Studio is mentioned but not designed. **Sandbox environments produce no user-activity logs**, which is a real constraint on what can be demonstrated |
| **SE:09** | Comprehensive security testing regimen | **Gap** | Push protection is verified by a planted secret. No other security testing is defined — no access-control verification matrix beyond a checkbox, no agent prompt-injection testing despite six agents reading employee-authored text |
| **SE:10** | Defined and tested incident response procedures | **Partial** | `AGENT_WORKFLOW.md` treats a leaked secret or personal data as an incident with a stated response. It has never been tested, and no other incident class is covered |

**Notable strength:** the design independently arrived at the segmentation and identity model `SE:04` and `SE:05` describe. **Notable gap:** `SE:02` threat modelling and `SE:09` security testing are both absent, and agent prompt injection is the specific untested risk worth naming.

### 3.3 Operational Excellence (`OE:`) — strong, and explicitly endorsed

> [Checklist](https://learn.microsoft.com/en-us/power-platform/well-architected/operational-excellence/checklist)

| Item | Recommendation (abbreviated) | Verdict | Position |
|---|---|---|---|
| **OE:01** | Team specialisations, clear decision rights, blameless continuous learning | **Aligned** | The proposed operating model documents named owner roles; Kaizen ownership and KPI baseline details remain planned or not yet verified |
| **OE:02** | Formalise routine, as-needed and emergency operations; shift-left | **Aligned** | The proposed agent workflow, release checklists per workload, and failure-handling and escalation sections document the intended operating model |
| **OE:03** | Formalise ideation and planning; common prioritised backlog | **Aligned** | Azure Boards is proposed as the single backlog; Idea → Spec → Design → Governance → Plan with named gates |
| **OE:04** | Standardise tooling, source control, design patterns, documentation, style guides | **Aligned** | [.github/copilot-instructions.md](../.github/copilot-instructions.md) is exactly this artefact |
| **OE:05** | Build a workload supply chain driving changes through predictable automated pipelines | **Aligned** | The proposed ALM chain documents Microsoft's own tenets: *"All changes are proposed changes until they're deployed into production"*, and *"Use one set of code assets and artifacts across all environments and pipelines"* |
| — | *"Enforce a strict policy of automated template-based deployments… don't perform updates by using manual processes or human interaction"* | **Aligned** | "No manual changes in PROD" is a hard proposed rule, intended to be mechanically enforced by the **unmanaged customizations blocked** environment group rule |
| — | ⭐ *"You can use Terraform, **Bicep**, and Azure Resource Manager for immutable infrastructure as code (IaC) deployments"* | **Aligned** | Direct Well-Architected endorsement of the ADR-0003 toolchain |
| — | ⭐ Named facilitation: **Power Platform Build Tools for Azure DevOps**, **GitHub Actions for Power Platform**, **PAC CLI**, *"deploy via service principals"* | **Aligned** | The design uses all four |
| **OE:06** | Monitoring system capturing operational telemetry, metrics and logs | **Partial** | Purview and the admin centre experiences are planned or not yet verified. No telemetry design, no Application Insights integration for Copilot Studio agents |
| **OE:07** | Emergency operations practice; meaningful health signals, actionable alerts, on-call, postmortems | **Gap** | None of this exists. Acceptable for a showcase; should be stated |
| **OE:08** | Automate tasks that do not benefit from human judgement; prefer off-the-shelf | **Aligned** | Provisioning is proposed to be automated and idempotent; the interactive steps are precisely those with no API |
| **OE:09** | Design automation up front for lifecycle, governance and compliance guardrails; *"Don't try to retrofit automation later"* | **Aligned** | DLP baseline and Managed Environment rules are planned early, before artefacts exist. The sequencing constraints table exists for exactly this reason |
| **OE:10** | Safe deployment practices; small, incremental, quality-gated releases | **Aligned** | Small pull requests, required review, Solution Checker, and environment approvals for TEST and PROD are proposed controls |
| **OE:11** | Deployment failure mitigation with rapid recovery | **Partial** | The proposed agent workflow prefers roll-forward with a corrected managed solution and warns against hand-editing the target. No rollback has been tested; no feature-disablement strategy exists |

**Fusion development.** Microsoft defines this as *"bringing together professional developers with citizen, or low-code, developers"* and makes it the first Operational Excellence design principle. This design is fusion-shaped — Copilot Studio and Power Automate alongside Bicep and PowerShell — but never names the practice or the handoffs between maker and pro-dev work. A cheap, genuine improvement.

### 3.4 Performance Efficiency (`PE:`) — largely unaddressed

> [Checklist](https://learn.microsoft.com/en-us/power-platform/well-architected/performance-efficiency/checklist)

| Item | Recommendation (abbreviated) | Verdict | Position |
|---|---|---|---|
| **PE:01** | Define numerical performance targets tied to requirements, for all flows | **Gap** | None defined |
| **PE:02** | Conduct performance planning ahead of predicted usage changes | **Gap** | A showcase has a very predictable usage spike — the demo itself. Not planned for |
| **PE:03** | Select the right services; weigh platform features against custom implementation | **Partial** | The platform-versus-custom judgement is made repeatedly and well — solutions over manual config, native pipelines considered and rejected with reasons. It is never framed as a performance decision. **Deferring the code app in the roadmap removed the one place custom was chosen over platform** — this item improved from Partial toward Aligned as a side effect of the MVP scope decision |
| **PE:04** | Collect performance data across application, platform and data levels | **Gap** | Not designed |
| **PE:05** | Test performance in a production-like environment against targets | **Gap** | No performance testing. TEST is a Sandbox and PROD is Production type, so they are not equivalent |
| **PE:06** | Optimize logic; offload responsibilities to the platform | **Partial** | Orchestration sits in Power Automate and data logic in Dataverse, which is the right shape. No explicit guidance on where logic must *not* go |
| **PE:07** | Prioritise the performance of critical flows | **Gap** | Follows from `RE:02` — flows are not rated, so they cannot be prioritised |
| **PE:08** | Optimize data usage | **Partial** | The data model is deliberate and normalised. No indexing, retention or query strategy |
| **PE:09** | Respond to live performance issues | **Gap** | No process |
| **PE:10** | Continuously optimize | **Gap** | Not established |

> 🚩 **The specific risk this pillar would have caught.** Copilot Studio guidance warns that *"Rate limits apply across the full runtime path — including Power Automate, Dataverse, connectors, and downstream APIs — and architecture decisions such as environment segmentation and trigger design directly affect whether the solution stays within those limits under peak traffic."* This design has six agents, Dataverse-triggered flows and connector calls in one runtime path, and **has not considered rate limits anywhere**. For a live demo, this is the most likely thing to fail visibly.

**Summary:** Performance Efficiency is the pillar with the widest gap between the framework's expectations and this design. `PE:01` and `PE:07` for the two critical journey flows, plus a rate-limit review, would close most of the practical risk.

### 3.5 Experience Optimization (`XO:`) — the pillar v1.x missed entirely

> *"Create meaningful and useful experiences that ensure successful business outcomes."*
> [Checklist](https://learn.microsoft.com/en-us/power-platform/well-architected/experience-optimization/checklist)

Three design principles: **Design for the user**, **Design for simplicity**, **Design for efficiency**.

| Item | Recommendation (abbreviated) | Verdict | Position |
|---|---|---|---|
| **XO:01** | Meet user expectations; ensure the workload is useful with a positive experience | **Partial** | Personas and journey stages are defined. No user research, no stated user needs beyond inferred ones, no success definition from the employee's point of view |
| **XO:02** | Follow established standards, conventions and guidelines; consistent design elements, terminology, interactions | **Gap now addressed in design** | The pillar names **Fluent UI** and the **Creator Kit** as its related standards. The design previously said only "Fluent design" in passing. The [UX Designer agent](../.github/agents/ux-designer.agent.md) is now grounded in **Fluent 2**, applied through Power Apps **modern controls**, which the pillar states *"use the components in the Fluent (2) design system"* |
| **XO:03** | Implement a consistent information architecture; navigation, contextual cues, consistent labels | **Gap** | A five-stage journey across an app, Teams and Microsoft 365 Copilot has no documented information architecture. Where does an employee go for what? |
| **XO:04** | Prioritise ease of use; minimise effort, streamline complex processes | **Partial** | The requirement exists as an example in the redaction pattern — *"complete my equipment request in as few steps as possible"* — but is not a design discipline anywhere |
| **XO:05** | Meaningful, useful, simple guidance in notifications and messages | **Partial** | Teams status messages have a defined format for delivery updates. **Employee-facing** journey notifications have no content standard, despite Power Automate generating them |
| **XO:06** | Optimize for different contexts and devices | **Gap** | New joiners often complete onboarding on a phone, sometimes before they have a corporate device. Not considered. This remains open — a standard Power App still needs a deliberate small-screen layout |
| **XO:07** | Optimize user perception and aesthetics | **Gap** | Not addressed. Fluent 2 grounding is the mechanism |
| **XO:08** | Follow interaction design best practices; help users maintain context | **Gap** | Not addressed |
| **XO:09** | Task-focused content in a professional tone | **Partial** | Documentation tone is governed. **Employee-facing content** — agent responses, task descriptions, notifications — has no content standard |
| **XO:10** | ⭐ **Design conversations that align with user needs; make clear what the AI can do; natural interactions; fallback mechanisms** | **Partial — the most significant finding** | See below |

#### XO:10 — conversational design

Added to the framework in October 2024 specifically for conversational AI. The MVP delivers **one Copilot Studio agent** (the Onboarding Assistant) with three more in Horizon 2, and the design documents their *governance* thoroughly while saying almost nothing about their *conversational design*.

Measured against Microsoft's [five conversation design strategies](https://learn.microsoft.com/en-us/power-platform/well-architected/experience-optimization/conversation-design):

| Strategy | Position |
|---|---|
| **Explain the capabilities of the AI** | **Partial.** Agents must "identify themselves as an agent" — a governance rule, not a capability explanation. Microsoft asks for more: *"if the AI can perform only specific tasks, let users know about this limitation right from the start"* |
| **Understand the user's intent** | **Gap.** No intent mapping exists for any agent |
| **Optimize how the AI interprets input** | **Gap.** Not addressed |
| **Guide the user through interactions** | **Gap.** No conversation flows, no decision trees, no handling of interruptions |
| **Design fallback mechanisms** | **Aligned, and stronger than required in design.** The escalation-to-human path is mandatory, is planned for the shared `ur_HRCommon` component collection so it is authored once, and is a planned tested item on the publication gate. Microsoft's guidance — *"If the AI fails to understand a user multiple times in a row, the fallback strategy should offer escalation… redirect the user to a human"* — is exactly the design. Governance-driven, but it lands precisely where the framework wants it |

**Conclusion:** the governance model accidentally produced excellent fallback design and nothing else. Intent mapping and conversation flows for the four journey agents are the single highest-value addition available to this workload.

---

## 4. Cross-Pillar Tradeoffs Being Accepted

Microsoft publishes a tradeoffs page per pillar. Four apply directly here and should be acknowledged rather than discovered later.

| Tradeoff | Microsoft's wording | Our position |
|---|---|---|
| **XO ↔ Security** | *"Increased workload surface area… **Using code components can inadvertently increase the workload's attack surface**"* ⭐ **Closed by deferring the code app.** A standard Power App adds no custom code surface. Revisit if H2-E is ever taken |
| **Security ↔ XO** | *"Increased friction… **Data classification can make finding and consuming data in the workload more difficult.** Security protocols increase the complexity of user interactions"* | **Accepted and under-examined.** Column security on four HR columns will make some experiences show masked values. No thought has been given to how that reads to a manager |
| **XO ↔ Performance** | *"Performance Efficiency prioritizes platform features over customization… Customizations… can have a negative impact on performance"* ⭐ **Materially reduced by deferring the code app.** Platform controls are the Performance Efficiency preference. Residual customisation risk remains unquantified because no targets exist (`PE:01`) |
| **XO ↔ Reliability** | *"**Customizing the user interface with code and components adds new reliability targets**"* ⭐ **Closed by deferring the code app.** No custom UI code means no additional reliability target. The underlying gap — no reliability targets at all (`RE:04`) — still stands |
| **OE ↔ Observability** | *"there's an increased risk that data classification controls, like data masking, of the source systems don't extend to the logs and log sinks of the observability platform"* | **Live risk.** Directly relevant to Power Automate run history and agent transcripts — see `SE:03` |

---

## 5. Adoption Guidance Alignment (Tenant Scope)

Assessed against the [eight adoption pillars](https://learn.microsoft.com/en-us/power-platform/guidance/adoption/methodology).

| Pillar | Verdict | Position |
|---|---|---|
| **Strategy** | Aligned | North Star, PRD and showcase objectives state the measurable intent |
| **Plan** | Aligned | Roles, responsibilities and the delivery model are named in `01-prd.md` §6 and the agent boards |
| **Security** | Aligned | The proposed security baseline documents the intended controls; deployment remains not yet verified |
| **Governance** | **Strong** | *"digital guardrails"* is precisely what the proposed DLP baseline, environment group rules and HITL gates are intended to implement |
| **Operations** | Aligned | ALM strategy in `12`; production support is out of scope for a showcase and should say so |
| **Availability** | **Gap** | *"Plan for failures and build a disaster recovery plan."* Mirrors `RE:07`. Not done |
| **Readiness** | Partial | The documentation set is the upskilling asset. No maker enablement path |
| **Community** | Not applicable | Single-team showcase. Worth stating rather than silently omitting |

### 5.2 Environment strategy — use the current source

The [tenant environment strategy guidance](https://learn.microsoft.com/en-us/power-platform/guidance/adoption/environment-strategy) supersedes the archived landing-zones repository, and says so:

> *"the approach in this article aligns with Microsoft's latest product direction and uses current features and near-term planned enhancements."*

Our DEV/TEST/PROD design, environment security groups, environment groups and DLP baseline align with it. The archived [`microsoft/industry` Power Platform landing zones](https://github.com/microsoft/industry/tree/main/foundations/powerPlatform) repository remains useful for **vocabulary** — its five design principles (Environment Democratization, Policy Driven Governance, Single Control and Management Plane, Persona Agnostic, Power Platform Native Design) and its eight Critical Design Areas — but it is Microsoft-published, **archived, and roughly three years stale**. It predates Managed Environments maturity. Do not present it as current guidance.

---

## 6. Deliberate Deviations

Each is a conscious choice with a stated reason, unchanged in substance from v1.x.

| Deviation | Reason |
|---|---|
| **No Dataverse Git integration** | Preview for GitHub; requires GitHub organisation admin and an Entra-resident Key Vault, both awkward for an external personal account. **Power Apps do not support it at all** |
| **No in-product pipelines as the primary path** | *"Can pipelines deploy to a different tenant? No… we recommend using Azure DevOps or GitHub."* Reproducibility into another tenant is a stated objective |
| **No CoE Starter Kit** | *"no longer actively maintained… Issues are no longer reviewed or addressed."* Use the admin centre Inventory, Usage, Monitor and Actions experiences |
| **No GitHub Projects** | Azure Boards is the single backlog; there is no bidirectional sync, so two boards would drift |
| **No B2B guest as the build identity** | Dataverse guest access is restricted by default; guests cannot access Copilot Studio at all |
| **No TeamsFx** | In deprecation; community-only support until September 2026 |
| **No `az devops` CLI as the automation surface** | Microsoft's own documentation conflicts on credential flow-through from GitHub Actions; no command exists for environments or approval checks |
| **No Terraform** | Organisation standard is Bicep and PowerShell — [ADR-0003](./adr/0003-bicep-and-powershell-for-infrastructure-as-code.md). Note `OE:05` explicitly endorses Bicep |

---

## 7. Priority Findings

Ordered by value, not by pillar.

| # | Finding | Pillar | Why it matters here |
|---|---|---|---|
| 1 | **No intent mapping or conversation flows** for six agents | `XO:10` | The agents *are* the showcase. Governance is complete; conversational design is absent |
| 2 | **Rate limits never considered** across the Power Automate → Dataverse → connector path | `PE:02` `PE:03` `PE:07` | The most likely visible failure during a live demo |
| 3 | **Flows not rated by criticality** | `RE:02` `PE:07` | Half a page of work that unlocks reliability and performance prioritisation |
| 4 | **No threat model** | `SE:02` | Explicitly required. Agents reading employee-authored text is an untested injection surface |
| 5 | **Classification not extended to run history and agent transcripts** | `SE:03` | *"protect personal data by removing or obfuscating it from any kind of application logs"* — currently unaddressed and squarely in scope for an HR workload |
| 6 | **No information architecture** across app, Teams and Microsoft 365 Copilot | `XO:03` | Three surfaces, one journey, no map |
| 7 | **No reliability or performance targets** | `RE:04` `PE:01` | Nothing can be said to be degraded without them |
| 8 | **No mobile or alternate-device consideration** | `XO:06` | New joiners frequently onboard before receiving a corporate device |
| 9 | **No security testing regimen** | `SE:09` | Push protection is verified; nothing else is |
| 10 | **BCDR not framed** | `RE:07` · Availability | The repository *is* the continuity asset — say so and test a rebuild |

---

## 8. Documentation Defects Found

Worth recording, because they affect how findings should be cited.

| Defect | Handling |
|---|---|
| **`OE:05` vs `OE:06`** — the checklist assigns `OE:05` to "Build a workload supply chain"; the recommendation guide's banner says `OE:06`, apparently retaining Azure WAF numbering | **Cite the checklist.** This document uses `OE:05` for supply chain and `OE:06` for monitoring |
| **`SE:03` wording** — checklist says *"sensitivity and information type labels"*; the guide says *"sensitivity labels"* | Cite the checklist |
| **PE principle name** — landing page says *"Design to meet capacity requirements"*; the principles page says *"performance requirements"* | Cite the principles page |
| Duplicated codes rendering in checklist tables (`RE:05 RE:05…`) | Rendering artifact; ignore |

---

## 9. Open Items

| # | Item | Action |
|---|---|---|
| 1 | Run the [Power Platform Well-Architected assessment](https://learn.microsoft.com/en-us/assessments/689fd8d9-1000-4cbb-8096-a6c8f3294fc7/) | ~60 minutes. Microsoft recommends one pillar at a time, staggered, and exporting recommendations into the backlog. Start with **XO** and **PE** |
| 2 | OIDC from GitHub Actions to Power Platform | Tutorial and reference page disagree on whether a client secret is required. Prototype in DEV |
| 3 | Bootstrap identity creating an Azure DevOps project | Inference from the permission model. Smoke-test |
| 4 | Custom connectors alongside connection references in one solution | ADR-0004. Verify a clean Infra import into an empty TEST environment |
| 5 | Code apps GA status | No explicit GA declaration in the documentation; the `pac code` CLI is deprecating |
| 6 | Declarative agent `Dataverse` capability | Confirm regional and licensing availability |
| 7 | Managed Environment licensing enforcement, February 2027 | Run the PPAC exposure report |
| 8 | Immutable OIDC subject format | Resolved 2026-09-19: repository API read-back confirmed `use_immutable_subject: true` and prefix `repo:urruegg@46865858/caldova-hr-frontier@1371297722`; federated credentials must append the exact Environment context to this prefix. |
| 9 | Purview user-activity logging in Sandbox environments | Not captured. Audit demonstrations must run against PROD |
| 10 | Intelligent application workload guidance | The `en-us` URLs redirect to the Copilot Studio guidance tree; content may be mid-migration. Re-check before citing |
| 11 | CoE Starter Kit deprecation | Asserted by the community-curated hub. Verify against official documentation before relying on it |
| 12 | Check configurations API has no GA version | Pin `7.1-preview.1`; retest after Azure DevOps sprint updates |

---

## 10. Summary Judgement

**Security and Operational Excellence are strong** and in several places exceed what the framework asks. The identity model, the supply chain, the governance gates and the classification scheme would survive scrutiny in a production tenant, not merely a demo one. `OE:05` explicitly endorses the Bicep toolchain chosen in ADR-0003.

**Reliability and Performance Efficiency are thin.** Neither has targets, neither has testing, and flows are not rated by criticality. For a showcase that is a defensible position — but it should be *stated* as a position rather than left as an absence. Rate limits across the agent-to-flow-to-Dataverse path are the concrete near-term risk.

**Experience Optimization was missing entirely from v1.x**, and it is the pillar this workload most needs. Six agents and an employee-facing app are assessed by a pillar that did not appear in the previous evaluation. The finding is not cosmetic: there is no intent mapping, no conversation flow design and no information architecture, for a solution whose entire value proposition is the quality of those interactions. The one bright spot is that the governance model's mandatory human-escalation path lands exactly where `XO:10` asks it to.

**Two residual risks remain unchanged and worth restating:**

**Push protection detects credentials, not personal data.** Human review, backed by the Governance Agent and the redaction checklist, is still the only control preventing employee data from entering a permanent public record. `SE:03` now adds a dimension we had not covered — that classification must extend to logs and transcripts, not just to stored data.

**The demo tenant is time-boxed.** Anything whose existence depends on an account or an environment inside it is temporary by construction. That is the strongest argument for the repository being the source of truth, and — framed properly — it is also this workload's BCDR answer under `RE:07`.
