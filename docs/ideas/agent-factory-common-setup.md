# Copilot Studio Agent Factory — Part 1: Common setup for any repository

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-26 |
| **Author** | Urs Rüegg, Microsoft Innovation Hub Switzerland (source concept); adopted by docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Repository Ideas |
| **References** | [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md), [Repository-Agent Portfolio Governance Design](../specs/2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md), [Agent Policy](../../.github/agent-policy/README.md) |

**Repository adoption.** This record adopts *Agent Factory Part 1 — Common setup v1.1* as received from its author on 2026-10-25. Everything below the horizontal rule is the unchanged source text; only this header and note were added. The version above is the source concept version.

This is an idea record. It is not an approved requirement, specification, or decision. Its capability statements, status labels, source IDs, and field-evidence (FE) observations are the author's, dated 2026-10-25, and this repository has not verified them. The repository's reading of the concept, the decisions it leads to, and the authority of the Approved portfolio design over it are in the [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md).

---

## GitHub Copilot–driven DevSecOps closed loop for agents and workflows on the Copilot Studio GitHub Copilot harness

Concept v1.1 · Capability baseline 25 October 2026 · Part 1 of 3

Prepared by Urs Rüegg, Senior Solution Engineer, Microsoft Innovation Hub Switzerland

| Field | Value |
|---|---|
| Version | 1.1 (draft for review) — supersedes the single-document concept v1.0 of 25 Oct 2026 |
| Date | 25 October 2026 |
| Author | Urs Rüegg, Microsoft Innovation Hub Switzerland |
| Document set | **Part 1 — Common setup for any repository (this document, shareable)** · Parts 2 and 3 — repository-specific concepts, distributed separately to their owners |
| Audience | Engineering leads, makers, platform and security owners of any Copilot Studio programme |
| Status | Concept for discussion. Not a commitment of product capability beyond the cited documentation |
| Data | Customer-neutral. Contains no customer names, identifiers or personal data and may be shared |

### How to read this document

Part 1 describes the factory every repository should start from: principles, capability landscape, field-proven platform behaviours, the target loop, the repository blueprint, pipelines, identity, evaluation, observability and the adoption path. Parts 2 and 3 apply it to two concrete repositories and only describe what differs.

Capability statements reflect public Microsoft and GitHub documentation as read on 25 October 2026 (source IDs such as [S10] point to Appendix B). Statements marked **FE** are field evidence: platform behaviour observed and documented in a production reference implementation of this factory (October 2026). Re-check every status before each phase gate — Copilot Studio, GitHub Copilot and the Power Platform tooling change monthly.

| Status label | Meaning |
|---|---|
| GA | Generally available and supported |
| Preview | Public preview. Usable, but may change; check terms before production use |
| Private preview | Available by invitation only |
| Announced | Announced in a Microsoft blog post; no Microsoft Learn documentation found yet |
| Sample / OSS | Open-source sample or community asset; not a supported Microsoft product |
| Not verified | Documentation is silent or contradictory; must be proven in a spike |
| FE | Field evidence from a reference implementation (observed behaviour, not a support statement) |

### What changed since v1.0

| Change | Why |
|---|---|
| The concept is split into three parts | One common setup, two repository-specific concepts |
| New §5 "Field-proven platform behaviours" | A reference implementation has proven — and disproven — several assumptions that v1.0 marked "not verified" |
| Source model made concrete (§7.5) | Proven pattern: DEV export unpacked as the deployable truth, plus an authored "harness" layer, generators and a repo-to-DEV sync |
| Reference pipeline made concrete (§7.9) | Proven pattern: export → PR, SIT on merge, PROD by promoting the identical SIT artefact with a manifest and digests |
| Connections and runtime identity (§7.10) | User-owned connections break unattended activation in PROD; service-principal-owned connections and a dedicated runtime principal are required |
| Evaluation details (§7.4) | Evaluate-tab CSV constraints and the delegated permission needed by the evaluation API |

---

# 1. Executive summary

**Answer first.** A GitHub Copilot–driven, end-to-end DevSecOps closed loop for Copilot Studio agents and workflows on the GitHub Copilot harness is feasible and has been demonstrated in practice. Agents, native skills and workflows can live in Git, be generated or authored with GitHub Copilot, be validated in CI and be promoted as managed solutions from DEV through SIT/TEST to PROD. Three links still need custom tooling — the unattended evaluation gate, non-interactive identity for Copilot Studio–specific operations, and the production-to-backlog loop — and several building blocks are in preview, so they must be built as replaceable adapters.

## 1.1 What is already there

1. **Agents as code.** The GitHub Copilot harness is generally available in Copilot Studio [S03]. Agents can be scaffolded, cloned, pulled, pushed, packed and published with `pac copilot` [S11]; the Copilot Studio extension for VS Code round-trips harness agents, skills, connected agents, hooks and standalone workflows per its release notes [S18]; the Copilot Studio MCP server lets GitHub Copilot author, test and evaluate agents and workflows [S10]; the CAT Copilot Studio plugin (mcs-assistant) creates and migrates harness agents [S61]. **FE:** a DEV export of agents, native skills and workflows round-trips through `pac solution unpack/pack` and a managed import; workflows can be generated as code and the DEV export is byte-identical to the generator output.
2. **Transport and release.** Solutions/ALM are listed as supported for the harness [S02]. Packing and importing managed solutions with deployment settings [S11, S13], Power Platform Pipelines [S35–S37] and GitHub Actions / Azure DevOps with OIDC or workload identity federation [S39–S41] cover the path to PROD. **FE:** managed SIT promotion of a seven-agent harness solution with post-import workflow activation and agent publishing; managed PROD import of the identical package, with PROD workflow activation still requiring a service-owned connection (FE-22).
3. **AI-native engineering.** Repository instructions, custom agents, agent skills, hooks, plugins and MCP servers for GitHub Copilot [S71–S75]; Copilot CLI (GA) with programmatic, autopilot and parallel modes [S77, S78]; Copilot SDK (GA) [S80]; Superpowers v7.0.0 [S87]; Work IQ CLI/MCP (preview) [S70]; Learn, Dataverse and Azure DevOps MCP servers [S66, S67, S69].
4. **Governance and security.** Data policies including MCP [S43]; environment-group rules [S44]; an Entra Agent ID per agent [S26]; Agent 365 registry and observability (GA) [S27, S29]; Purview [S45]; Defender real-time protection [S47]; credit allocations and per-agent limits [S31].
5. **Observation.** Monitor tab with sessions, outcomes, reactions and credits [S51]; environment-level Application Insights telemetry for both harnesses (preview) [S50]; Agent 365 telemetry without SDK instrumentation [S29]; credit-consumption API [S30].

## 1.2 What is missing (the custom glue)

| Gap | Why it matters | Factory answer |
|---|---|---|
| **A. Unattended evaluation gate** | The harness's Evaluate tab is in preview and Learn documents only the General quality grader [S22]; it does not compare against expected answers (FE). The evaluation REST API is documented for the standard harness and needs a user token [S19]; FE: calls fail with 403 until the app registration has the delegated permission `CopilotStudio.MakerOperations.Read`. The Copilot Studio MCP server runs evaluation suites interactively [S10] | Keep evaluation sets in Git; generate the Evaluate-tab CSV; build an **Eval Runner** on the Agents SDK Copilot Studio client (harness support in preview) [S23] with deterministic graders for expected and forbidden content; attended gate until the runner is proven |
| **B. Non-interactive identity for Copilot Studio–specific operations** | OIDC/WIF is documented for `pac auth` and solution import [S12, S39]; service-principal use is not documented for `pac copilot` sync/publish, the MCP server or evaluations; app-only SDK access is private preview for anonymous agents [S24]. FE: workflow activation fails in pipelines when the bound connection is user-owned | Inner loop interactive and DEV-only; outer loop moves only solutions with a federated service principal; **service-principal-owned connections** and a dedicated **runtime principal** with a minimal Dataverse role; governed test identity for evaluations |
| **C. Production-to-backlog feedback** | No native link from Monitor, Application Insights or Agent 365 to the backlog; the session list keeps 28 days [S51] | **Feedback Harvester** that turns aggregated, privacy-safe signals into work items with evidence and regression cases |

## 1.3 Recommendation

Set up every repository as an **Agent Factory** with four interlocking loops — **Build, Verify, Release, Operate & Learn** — engineered with an agent-specific adaptation of Superpowers (**Eval-Driven Development**), a factory skill pack and custom agents for GitHub Copilot, policy-as-code, the proven two-layer source model and an evidence record at every gate. Adopt it in four phases:

| Phase | Typical duration | Outcome |
|---|---|---|
| 0 Foundation | 3–4 weeks | Decisions, repository blueprint, environments and identities, spikes for the remaining "not verified" items |
| 1 Pilot | 6–8 weeks | One agent and one workflow released to a PROD pilot through the pipeline, with an attended evaluation gate |
| 2 Automated gates | 6–8 weeks | Eval Runner, red-team suite and policy-as-code unattended; Feedback Harvester v1 |
| 3 Closed loop at scale | ongoing | Autonomy ladder per intent, automatic regression cases, template repository |

## 1.4 Short answers to the four questions

| Question | Short answer | Details |
|---|---|---|
| Which APIs are available? | Dataverse Web API; Power Platform API (evaluations, licensing and credit consumption, pac-generated command groups in preview); Microsoft 365 Agents SDK CopilotStudioClient (harness support in preview); agents exposed as MCP server or via A2A (preview); Microsoft Graph for the Agent 365 registry and Entra Agent ID; Application Insights; Power Platform Pipelines extension events. No documented API exists for authoring harness workflows or creating evaluation test sets | §4.2 |
| Which skills, plugins and MCP servers are available? | GitHub Copilot instructions, custom agents, agent skills, hooks and plugins; Superpowers v7.0.0; the Copilot Studio MCP server; the CAT Copilot Studio plugin (mcs-assistant) and Skills for Copilot Studio; Work IQ CLI/MCP; Microsoft Learn, Dataverse, Azure DevOps, GitHub, Azure and Playwright MCP servers; the CAT Agent Skills gallery; awesome-copilot Power Platform plugins; Copilot Agent Kit | §4.3–4.4 |
| Which ALM support is available? | Solutions (listed as supported; FE: agents, native skills and workflows round-trip), `pac solution` and `pac copilot` packing and import with deployment settings, Power Platform Pipelines, Dataverse Git integration (Azure DevOps; GitHub in preview), GitHub Actions and Azure DevOps Build Tools with OIDC/WIF, Copilot ALM Starter, managed environments and environment-group rules | §4.5, §7.9 |
| Which tools exist for evaluation and monitoring? | Evaluate tab for harness agents (preview), workflow node tests and run history, announced graders and workflow evaluations, evaluation suites via the Copilot Studio MCP server, the Agents SDK client for scripted tests, Copilot Agent Kit, Foundry red teaming; Monitor tab, environment-level Application Insights (preview), Agent 365, Purview, Defender and the credit API | §4.6–4.7, §7.4 |

---

# 2. Context and objectives

## 2.1 Objectives

1. Fully automate the build and maintenance of Copilot Studio agents and workflows on the GitHub Copilot harness, using GitHub Copilot, the Superpowers skills framework, the Work IQ CLI and other CLIs.
2. Establish an end-to-end DevSecOps closed loop: plan → specify → build → verify → release → operate → learn → plan.
3. Follow Microsoft best practice and Microsoft Learn guidance, and keep every capability claim traceable to a source.
4. Provide one reusable setup that any repository can adopt, independent of customer, domain or source-control platform.

## 2.2 Why now: the harness shift

Everything built in Copilot Studio now runs on a harness — the runtime between the model and what the maker builds. The GitHub Copilot harness powers agents and workflows for reasoning-heavy, multi-step work; the Customer Conversation harness serves customer voice and chat; the standard harness powers rule-based agents and agent flows [S01]. The GitHub Copilot harness is a Copilot Studio authoring and orchestration framework, not the GitHub Copilot service; customer data is not sent to the GitHub Copilot service when agents run in Copilot Studio [S01].

- **Design changes.** Makers describe the agent and connect components; skills replace prompts and hooks replace topics and system triggers [S02, S08]. Place specialist reasoning in connected agents, actions in tools, repeatable procedures in skills and exact calculations in code [S62].
- **Cost moves left.** Building, testing, evaluating and running consume Copilot Credits, and Microsoft 365 Copilot licences don't cover this usage [S31].
- **Agents become software.** An agent can live in Git, be reviewed in a pull request and be released through a pipeline [S10, S11, S18].

## 2.3 Scope

| In scope | Out of scope (for now) |
|---|---|
| GitHub Copilot harness agents: instructions, skills, hooks, memory, Work IQ and Foundry IQ knowledge, MCP and workflow tools, connected agents | Custom-engine agents built purely in Microsoft Foundry or the Agents SDK |
| GitHub Copilot harness workflows | Customer Conversation harness |
| Standard-harness agents a programme reuses (for example packaged first-party agents) | |
| Copilot Chat harness / Agent Builder agents used as planning-plane "digital colleagues" | |
| GitHub and Azure DevOps as source-control and pipeline platforms | |

---

# 3. Design principles

| # | Principle | What it means in the factory | Origin |
|---|---|---|---|
| P1 | **Specify before you build** | No build starts without the seven declarations: write envelope, refusal set, escalation path, grounding sources, data classification, decision surface, measurement | Factory standard |
| P2 | **Everything as code** | Agents, workflows, runtime skills, evaluation sets, policies, deployment settings and infrastructure live in Git. "No portal-only source code": anything built in the portal is exported, normalised and reviewed | ALM guidance [S33]; FE |
| P3 | **Evaluations first** | Eval-Driven Development: write the failing evaluation, then build the agent until it passes | Superpowers TDD, adapted |
| P4 | **The workflow owns the process; the agent owns the judgement** | Deterministic steps, state changes, audit and escalation run as workflows; the agent is called where reasoning is needed | Workflows overview [S05] |
| P5 | **Declared, server-side envelopes** | Every write path declares fields, conditions and refusals, enforced outside the agent (workflow contracts, minimal runtime roles) | Factory standard; FE |
| P6 | **Humans hold accountability gates** | People approve specifications, designs, production releases and autonomy promotions; agents are never an approval authority | Factory standard |
| P7 | **One canonical source per solution; deploy only through pipelines** | Never mix source formats for one solution; SIT/TEST and PROD change only through CI | [S33, S38]; FE |
| P8 | **Evidence over claims** | Every gate writes an evidence record (pasted command output, run IDs, hashes, versions); controls are read back, not assumed. "Skipped" is never "passed" | FE |
| P9 | **Cost-aware engineering** | Credits are consumed from the first build; budgets exist per environment and per agent | [S31, S32] |
| P10 | **Privacy by design for telemetry** | Measure quality per intent and in aggregate, never per person | Factory standard |
| P11 | **Verify on Microsoft Learn before relying on a capability** | The Learn MCP server grounds design decisions; the evidence register records URL and date | [S67] |

---

# 4. Capability landscape (as of 25 October 2026)

This section answers the four questions directly: which APIs exist (§4.2), which CLIs, skills, plugins and MCP servers exist (§4.3–4.4), what ALM support exists (§4.5), and what exists for evaluation and monitoring (§4.6–4.7).

## 4.1 The runtime: what the GitHub Copilot harness offers and constrains

| Area | Capability and constraint | Status | Source |
|---|---|---|---|
| Harness choice | Chosen when the agent is created; agents can't be transferred between harnesses. An upgrade (preview) creates a copy on the GitHub Copilot harness and reports what was migrated; knowledge sources, Power Fx expressions and child agents aren't migrated | GA (upgrade: preview) | [S02] |
| Skills | Replace prompts. A skill is a SKILL.md with YAML front matter, or a ZIP with SKILL.md plus scripts, templates and reference files; skills are portable across agents and exportable | GA | [S02, S07] |
| Hooks | Replace topics and system triggers. The hook action is always a workflow; a hook runs only after the agent is published | Preview | [S08] |
| Memory | Retains preferences and patterns per user across conversations | Preview | [S03] |
| Work IQ | Organisational context (mail, calendar, files, Teams, people). Learn describes the Work IQ tool as added by default to every GitHub Copilot harness agent, billed in credits, with write operations on by default and the Business apps workload in preview; governed in the Microsoft 365 admin center. The September 2026 announcement still called it preview — verify in the tenant | See note | [S03, S09] |
| Foundry IQ | Connects an agent to a knowledge base built in Microsoft Foundry | Preview | [S03] |
| Tools | Connectors, MCP servers and workflows as tools; computer use planned | Connectors GA; MCP and workflow tools labelled preview in parts of the docs | [S02] |
| Connected agents | Delegation to other agents — only to agents also built on the GitHub Copilot harness | Preview | [S02] |
| Code and files | Native code interpreter; creates and edits Word, Excel, PowerPoint and PDF files in a sandbox | GA | [S01, S02] |
| Not supported | Prompt tool (use skills), Azure AI Search knowledge, manual/custom authentication, custom entities, SharePoint/WhatsApp/Dynamics 365 Contact Center channels | — | [S02] |
| Channels | Smaller set than the standard harness, including Microsoft Copilot, Teams, demo website and web app embedding | GA | [S02] |
| Workflows | Deterministic visual designer with AI actions, agent handoffs and node-level testing; the "When an agent calls the workflow" trigger turns a workflow into an agent tool. Each action consumes capacity; new runs are blocked when prepaid capacity is exhausted | GA (harness) | [S05, S06, S31] |
| Billing | Usage-based Copilot Credits for building, testing, evaluating and running; not covered by Microsoft 365 Copilot licences; developer and trial environments billed since 1 Sep 2026 | GA | [S31] |
| Sovereign clouds | In FedRAMP High environments the harness agent turns off at runtime | — | [S10] |

**Design consequence.** The harness exposes no orchestration configuration, so determinism, audit and escalation belong in workflows that call the agent where judgement is needed (principle P4). The factory treats this as a hard architectural rule.

## 4.2 APIs

| API | Role in the loop | Status | Automation fit | Source |
|---|---|---|---|---|
| Dataverse Web API (agents stored as bot and bot-component rows; connection references) | Read-back, inventory, consistency checks | GA (platform) | Service principal via application user | [S11] |
| Power Platform API — agent evaluation (`/copilotstudio/environments/{env}/bots/{bot}/api/makerevaluation/...`: list test sets, run, get runs) | Trigger evaluation runs and read per-case results (abstention, relevance, completeness) | Preview; documented for the standard harness; requires a user access token. FE: returns 403 `InsufficientDelegatedPermissions` until the delegated permission `CopilotStudio.MakerOperations.Read` is granted | User identity only | [S19, S20]; FE |
| Power Platform API — licensing / credit consumption per agent | FinOps telemetry | Documented by the CAT team | Admin role | [S30] |
| Power Platform API surfaced as `pac copilot-studio` commands (maker-evaluation test sets and runs, quarantine, reassign owner, connector-consent bypass, Microsoft 365 channel manifest) | Governance automation | Preview (since 17 Sep 2026) | Uses the active pac profile | [S15, S16] |
| Microsoft 365 Agents SDK — CopilotStudioClient (JavaScript, .NET; Python planned) | Scripted, multi-turn conversations against a published agent — the basis of the Eval Runner | Harness support preview (20 Oct 2026). Delegated permission CopilotStudio.Copilots.Invoke; agent must use "Authenticate with Microsoft"; app-only access is private preview for anonymous agents only | Delegated test identity | [S23, S24] |
| Copilot Studio agent exposed as MCP server or via A2A | Let other agents (or test harnesses) call a Copilot Studio agent | Preview, early-release environments only; delegated scopes | Delegated | [S25] |
| Microsoft Graph — Agent 365 registry | Inventory of agents across platforms | GA (Agent 365) | AI admin or Global admin | [S28] |
| Microsoft Entra Agent ID | Identity per agent; Conditional Access can target connector permissions | Automatic for new agents | Read via Entra/Graph | [S26] |
| Office 365 Management API | Purview audit records for agent interactions | GA | App registration | [S45] |
| Application Insights / Log Analytics (KQL) | Environment-level spans (InvokeAgent, ExecuteTool, OutputMessages) | Preview | Workspace-based access, service principal | [S50] |
| Power Platform Pipelines extension events (pre-export step, approval, OnPreDeploymentStarted / OnPreDeploymentCompleted / UpdatePreDeploymentStepStatus) | Inject evaluation and security gates into in-product deployments | GA, rolling out by region | Power Automate / service principal | [S37] |
| Azure DevOps REST & remote MCP; GitHub REST & MCP | Backlog, PR and pipeline automation | GA | Service principal / GitHub App | [S69, S82] |
| **Not found** | REST API to author harness workflows; API to create evaluation test sets; documented Work IQ or Retrieval API for code | — | — | — |

## 4.3 CLIs and IDE tooling

| Tool | What it automates | Status | CI fit | Source |
|---|---|---|---|---|
| Power Platform CLI `pac` 2.14.1 | Platform automation backbone | GA | Yes | [S17] |
| `pac copilot` — init (incl. `--authoring-mode cli-copilot`), clone, pull, push, pack, publish, status, list, extract-template, translation, model, mcp, quarantine, delete | Agent-as-code round trip. `pack` is local, needs no authentication and is safe in a build pipeline; `push` mutates the live agent; `pull`/`push` only work inside a workspace and take no `--environment`, so promotion goes through `pack` and solution import | Documented (reference updated 9 Jul 2026) | `pack`: fully headless. Sync/publish: service principal not documented | [S11] |
| `pac solution` — clone, sync, pack, unpack, check, create-settings, import `--settings-file`, export, version | Solution build, solution checker, deployment settings | GA | Service principal, GitHub/ADO federation, managed identity | [S13] |
| `pac pipeline deploy / list` | Trigger in-product pipelines | GA | Yes | [S14] |
| `pac auth` | Service principal (secret/certificate), `--githubFederated`, `--azureDevOpsFederated`, managed identity, device code | GA | Yes | [S12] |
| Copilot Studio extension for VS Code | Clone/pull/push/apply of agents in YAML with GitHub Copilot or other coding agents; release notes add code-first (CLI) agents (Jun 2026), skill folders and connected agents (Sep 2026), hooks and standalone workflows with clone/pull/push (Oct 2026). "Apply" edits the live agent | GA (Learn page labelled standard harness; harness support per release notes) | Interactive sign-in — not for CI | [S18] |
| GitHub Copilot CLI | Programmatic mode (`-p` with tool allow/deny), `--autopilot`, `/fleet` parallel subagents, `/delegate` to the cloud agent, plugins, hooks; dynamic workflows (orchestration in code) in preview since 1 Oct 2026 | GA (25 Feb 2026) | Yes (headless with explicit tool permissions) | [S77–S79] |
| Work IQ CLI (`workiq ask`, `workiq mcp`) | Microsoft 365 context — mail, meetings, files, Teams, people — for requirements and decisions | Preview; tenant admin consent required | Interactive by design | [S70] |
| GitHub CLI (`gh`, incl. `gh skill`) | Repo automation, skill installation | GA | Yes | [S72] |
| Azure CLI / Azure Developer CLI | Infrastructure for observability (Log Analytics, Application Insights, Key Vault, alerts) via Bicep | GA | Yes (OIDC) | — |
| Microsoft 365 Agents Toolkit CLI (`atk`) | Declarative agents from the terminal or CI, non-interactive mode — relevant where declarative agents complement Copilot Studio | GA | Yes | [S90] |
| FlightCheck (ESS Agent Developer Kit) | Deterministic readiness validator with 40+ checks; `--scope local` makes no API calls. ESS-specific, but the pattern is reusable | Sample / OSS | Local scope only | [S93] |

## 4.4 Skills, plugins, custom agents and MCP servers

| Item | Type | Publisher | Role in the loop | Status | Source |
|---|---|---|---|---|---|
| Repository instructions, AGENTS.md, path-specific `*.instructions.md` | Configuration | GitHub | Encode conventions for YAML, solutions, evaluations | Supported | [S71] |
| Custom agents (`.github/agents/*.agent.md`; org and enterprise level) | Custom agent | GitHub | Factory roles with scoped tools and MCP servers | Supported | [S71] |
| Agent Skills (`.github/skills`, personal skill folders; open standard; `gh skill`) | Skill | GitHub | Repeatable build, test and release procedures | Supported | [S72] |
| Hooks (`.github/hooks/*.json`; sessionStart, preToolUse allow/deny, postToolUse, agentStop and more) | Hook | GitHub | Guardrails: block pushes outside DEV, block secrets, audit | CLI and cloud agent supported; VS Code preview | [S73] |
| Plugins and marketplaces (Agent Plugins 1.0; `enabledPlugins`) | Plugin | GitHub | Distribute the factory pack; enterprise standards via managed settings | Supported | [S74, S75] |
| Copilot cloud agent (`copilot-setup-steps.yml`, firewall, repository MCP) | Agent | GitHub | Issue/Boards → PR automation | Available for GitHub repositories only | [S81, S82] |
| Copilot code review | Agent | GitHub / Microsoft | PR review with instructions and skills; Azure Repos support in public preview since 26 Aug 2026 | GitHub: available; Azure Repos: preview | [S83, S84] |
| Copilot Autofix | GHAS | GitHub | Fixes for code-scanning alerts | Available (agentic assignment in preview) | [S85] |
| Superpowers v7.0.0 (15 skills) | Skills framework | obra / Prime Radiant | Engineering methodology (§6.3) | Latest release | [S87, S88] |
| Copilot Studio MCP server (`@microsoft/copilot-studio-mcp`): manage_agents (authoring, lifecycle, sharing, previews, evaluation suites and runs), manage_workflows (authoring, lifecycle, tests, run diagnostics), discover_resources, get_consumption, get_copilot_studio_skills | MCP server | Microsoft | Inner-loop authoring, testing and evaluation from GitHub Copilot | Doc updated 19 Oct 2026; no status label; interactive sign-in | [S10] |
| Copilot Studio plugin `mcs-assistant` (agents: architect, describer, init, manage; commands: chat, migrate; skills: create/clone/pull/push/publish/delete agent, add-skill, add-knowledge) | Plugin | Microsoft CAT | Create, edit, validate and migrate harness agents through pac; verified in Copilot CLI and Claude Code | Sample / OSS, work in progress; YAML schema may change; needs pac ≥ 2.9.3 | [S61, S62] |
| Skills for Copilot Studio | Plugin | Microsoft CAT | Standard-harness YAML authoring | Experimental | [S65] |
| CAT Agent Skills gallery (for example Copilot Studio Agent Test, Agent Red Team, Evaluation Designer, Agent Performance Triage) | Runtime skills for Copilot Studio agents | Microsoft CAT community | Test, red-team and triage agents inside the factory | Community | [S64] |
| Work IQ CLI / MCP and plugins (`microsoft/work-iq`) | CLI / MCP / plugin | Microsoft | Organisational context for discovery, specification and operations | Preview; admin consent | [S70] |
| Microsoft Learn MCP server (`https://learn.microsoft.com/api/mcp`) | MCP server | Microsoft | Capability verification, guidance, code samples | Available | [S67] |
| Dataverse MCP server (remote `/api/mcp`; preview endpoint `/api/mcp_preview`) | MCP server | Microsoft | Tables, records, synthetic test data in DEV. The GitHub Copilot MCP client must be allowed per environment; tool use outside Copilot Studio is charged | GA | [S66] |
| Azure DevOps remote MCP server (`https://mcp.dev.azure.com/{organization}`) | MCP server | Microsoft | Work items, repos, pipelines; read-only and toolset headers | GA (5 Aug 2026) | [S69] |
| GitHub MCP server, Playwright MCP | MCP server | GitHub / Microsoft | Repository operations; browser UI smoke tests | Enabled by default in the cloud agent | [S82] |
| Azure MCP Server 2.0 | MCP server | Microsoft | Azure resources (observability, Key Vault) | GA | [S68] |
| Fabric MCP servers | MCP server | Microsoft | Analytics data | Status varies by server | [S99] |
| awesome-copilot Power Platform plugins (power-platform-architect, power-apps-code-apps, dataverse, flowstudio-power-automate, pcf-development) | Plugin | GitHub community | Architecture and scaffolding helpers | Community | [S97] |
| microsoft/skills | Skill catalogue | Microsoft | SDK and Foundry skills | Work in progress | [S98] |
| Copilot Agent Kit (formerly Copilot Studio Kit) | Solution / OSS | Microsoft Power CAT | Test automation, Agent Review Tool, Compliance Hub, Agent Insights Hub, conversation KPIs | OSS; harness support not documented | [S56] |
| Microsoft Agent Framework — GitHub Copilot agent | SDK | Microsoft | Build factory services (for example a triage service) with approvals and observability | Stable (.NET, Python) | [S89] |
| CAT technical guide and BlastBox samples | Sample | Microsoft CAT | Reference harness solution (connected agents, MCP servers, runtime skills, generated files) and a deploy script | Sample / OSS | [S63] |

## 4.5 ALM support

| Capability | Tool | Status | Applies to harness agents and workflows | Source |
|---|---|---|---|---|
| Solutions as the transport container | Dataverse solutions | GA | **Partial → largely proven (FE).** Listed as supported; FE: agents, native skills (InlineAgentSkill bot components), workflow tools, connected-agent actions and workflows round-trip through export, unpack, pack and managed import. Not yet proven: memory, hooks, Work IQ/Foundry IQ knowledge and MCP tools — Microsoft's own sample re-attaches MCP tools manually after import | [S02, S63]; FE |
| Items that are not solution-aware | Application Insights settings, manual authentication, Direct Line / web channel security, deployed channels, sharing | n/a | Yes — need post-deployment steps | [S33] |
| ALM training for the harness | Learn module "Implement ALM for agents" (GitHub Copilot learning path) | Training | Yes (training, not a support statement) | [S34] |
| In-product deployment | Power Platform Pipelines: delegated deployment as service principal, approvals, gated pre-export and pre-deployment steps, same artefact through all stages | GA | Likely (solution-based); not stated | [S35–S37] |
| Pipelines constraints | One solution per deployment; one development environment per solution; no cross-tenant deployment; default import "upgrade without overwrite"; targets must be managed environments — from Oct 2026 unmanaged targets are blocked 30 days after notification | GA | Yes | [S35] |
| Source control in the product | Dataverse Git integration: Azure DevOps (no preview label), GitHub (preview); managed environments; development environments only; one branch; YAML format readable by `pac solution pack` only | GA / preview | Not stated | [S38] |
| Agent-as-code build | `pac copilot pack` → solution .zip → `pac solution import` | Documented | Yes (CliCopilot workspaces) | [S11] |
| CI/CD for GitHub | GitHub Actions for Power Platform (workload identity federation); OIDC tutorial without client secrets | GA | Partial (solution-level) | [S39, S41] |
| CI/CD for Azure DevOps | Power Platform Build Tools v2.0 with workload identity federation (recommended) and a Checker task. The `vstoken.dev.azure.com` issuer retires on 1 Jul 2027 — use the Entra issuer | GA | Partial (solution-level) | [S40, S92] |
| Reference template | Copilot ALM Starter: export → unpack → PR → build → deploy for GitHub Actions and Azure Pipelines, with federated credentials and per-environment deployment settings; predates the harness | Sample / OSS | Unknown | [S42] |
| Agent quality gate in Pipelines | Agent Review Pipeline (Copilot Agent Kit): a GitHub Action triggered from a Pipelines pre-deployment step, static and AI review against a threshold | Sample / guidance | Not documented | [S55] |
| Pre-publish security scan | Warns on no authentication, maker-provided credentials, sharing with everyone | GA | Not stated | [S48] |
| Repository governance | Rulesets, CODEOWNERS, environments with required reviewers; GitHub Advanced Security for Azure DevOps (secret push protection, secret scanning, dependency scanning, CodeQL) | GA | Yes (repository side) | [S91, S96] |

**Microsoft's tool tiering.** Learn ranks the setup complexity of ALM options as low for Power Platform Pipelines, moderate for GitHub Actions and high for Azure DevOps [S33]. The factory combines them: pro-code CI for validation and evidence, in-product Pipelines (or pac import) for governed deployment.

## 4.6 Evaluation and testing

| Stage | Capability | Tool | Status | Harness support | Programmatic / CI | Source |
|---|---|---|---|---|---|---|
| Design time | Test sets (generate, import, write), eight test methods (general quality, content safety, compare meaning, tool use, keyword, text similarity, exact match, custom); ≤ 100 single-response or ≤ 20 multi-turn cases; results kept 89 days; runs as the signed-in user | Copilot Studio evaluation (standard harness) | GA (Mar 2026) | Standard only | REST API and connector | [S19–S21, S21b, S21c, S95] |
| Design time | Conversation test sets (manual, AI-generated, CSV ≤ 5 MB); General quality grader; run comparison; CSV export; cost per run. FE: template header `conversationNumber,question,response`, at most 20 conversations per file, 6 question/answer pairs per conversation, 1,000 characters per question; no comparison with expected answers | Evaluate tab (GitHub Copilot harness) | Production-ready preview | Yes | Not documented (MCP server: interactive) | [S22, S10]; FE |
| Design time | New graders (Task Completion, Tool Accuracy, Safety, Latency), Custom Graders Library, tenant-specific AI-generated graders, Evaluation Viewer role; evaluation of AI nodes and whole workflows; Review panel (GA) warns when an agent was never evaluated or its model changed | Copilot Studio | Announced 7 Oct 2026; Learn page not found | Not verified | Not documented | [S04] |
| Design time | "Test this node" and "Run flow test" (the full test publishes the workflow first and calls live connectors); run history and replay in the Activity panel. FE: the agent-call (Skills) trigger can't be invoked through the Flow API — test through the designer and run history; a read-only negative path can be run with Power Automate "Run flow" | Workflow designer | Documented | Yes (workflows) | No | [S06]; FE |
| Inner loop | Evaluation suites and runs; workflow tests and run diagnostics | Copilot Studio MCP server | No status label | Yes | Interactive sign-in | [S10] |
| Pre-production | Scripted multi-turn conversations against a published agent | Agents SDK CopilotStudioClient | Preview | Yes | Yes, with a delegated test identity | [S23] |
| Pre-production | Rubric-based, multi-turn and generative-answer tests; Pipelines quality gate | Copilot Agent Kit | OSS | Not documented (Direct Line based) | Yes | [S56] |
| Pre-production | Load testing with Direct Line and JMeter / Azure Load Testing | Guidance and reference sample | Guidance | Direct Line support for the harness not verified | Yes | [S57, S57b] |
| Pre-production | Adversarial scans (PyRIT) with a Python callback target; single-turn, text-only | Foundry AI Red Teaming Agent | Preview | Only through a custom callback | Yes | [S59] |
| Pre-production | Trace-based evaluation of external agents from OpenTelemetry spans | Foundry external-agent registration | Preview | Bridge through Application Insights inferred, not verified | Yes | [S58] |
| CI | Foundry evaluators with statistical comparison | `microsoft/ai-agent-evals` GitHub Action / Azure DevOps task | Preview | No (Foundry agents only) | Yes | [S60] |
| Release gate | Golden prompts — curated regression set; Go requires a 100% pass rate; any failure aborts | ESS ALM guidance | Guidance | Concept applies | Needs a runner | [S94] |
| Triage | Evaluation triage and remediation framework | Copilot Studio guidance | Guidance | Concept applies | n/a | [S54] |

## 4.7 Monitoring, security and governance

| Area | Capability | Status | Harness support | Source |
|---|---|---|---|---|
| Monitor tab | Sessions, users, autonomous runs, duration, success and fail rates; reactions; credits (billing source of truth, split by production, preview testing and evaluations); outcomes Resolved, Unresolved, Escalated, Abandoned, Unengaged; 28-day session list; data can lag up to an hour | Available | Yes | [S51] |
| Feedback | Reactions and comments, filterable and downloadable | Available | Yes | [S52] |
| Application Insights | Environment-level telemetry: OpenTelemetry-aligned spans for both harnesses; managed environments only; no unauthenticated or multi-tenant scenarios; up to 24 hours on new configurations; may differ between harnesses. Agent-level telemetry is standard harness only | Preview | Yes (agents) | [S50] |
| Agent 365 | Registry and observability; Copilot Studio agents appear automatically and send telemetry without SDK instrumentation; surfaces in Microsoft 365 admin center, Defender and Purview; authenticated sessions only | GA (1 May 2026) | Yes | [S27–S29] |
| Admin center | Copilot Studio monitoring (session success, recent sessions) and licensing views per agent and workflow | Metrics in preview | Partial | [S53] |
| Credits | Environment allocation (switch off draw from tenant capacity), monthly limit per agent with Stop usage, Azure budget alerts (alert only); the Harness column is UI-only; no tenant-wide default agent limit | GA | Yes | [S31, S32] |
| Purview | DSPM for AI, audit, sensitivity labels, DLP, Insider Risk, Communication Compliance, eDiscovery, lifecycle | Supported | Not harness-specific | [S45] |
| Defender | Real-time protection for Copilot Studio agents (requires Agent 365 onboarding); external threat-detection webhook per environment — if the provider doesn't answer within 1 second the tool call is allowed | Webhook: preview | Not verified | [S46, S47] |
| Identity | Entra Agent ID created automatically for every new agent; connector permissions can be targeted by Conditional Access | Automatic | Learn page labelled standard harness | [S26] |
| Data policies | Connectors, HTTP, knowledge sources, channels, triggers and MCP (via data policies and advanced connector policies) | GA | Yes | [S43] |
| Environment-group rules | Knowledge sources, skills, sharing, unmanaged customizations, solution checker enforcement, default deployment pipeline (preview), external and preview models, credit draw | GA (some preview) | Partial | [S44] |
| GitHub governance | MCP allow/deny and plugin standards in `managed-settings.json`; agentic audit-log events (`actor:Copilot`, 180 days). Content exclusion: documentation conflicts on agent support — don't rely on it | GA | n/a | [S75, S76, S86] |

## 4.8 Automation readiness by loop stage

| Loop stage | Readiness | Reason |
|---|---|---|
| Plan and intake | High | Azure Boards or GitHub Issues, Azure DevOps and GitHub MCP servers, Work IQ for context; Azure Boards can assign work to the Copilot cloud agent when the code is in GitHub |
| Specify | High | Superpowers brainstorming and planning, Learn MCP for capability truth, repository templates |
| Build (inner loop) | Medium–high | `pac copilot`, VS Code extension, Copilot Studio MCP server and plugin cover authoring; all are interactive and partly preview |
| Verify (static) | High | `pac copilot pack`, solution checker, policy-as-code, GitHub Advanced Security, Copilot code review |
| Verify (behaviour) | Low–medium | Gap A: no supported unattended evaluation for the harness |
| Release | High for solutions, medium end to end | Post-deployment items, MCP re-attachment and publish identity need scripting and checks |
| Operate and observe | Medium | Telemetry exists but is partly preview, delayed and harness-dependent |
| Learn and feed back | Low | Gap C: no native link from production signals to the backlog |

---

# 5. Field-proven platform behaviours (FE)

A production reference implementation of this factory (seven GitHub Copilot harness agents with native skills, agent-callable workflows and connected agents, promoted DEV → SIT → PROD through GitHub Actions in October 2026) recorded the platform behaviours below. They are observations, not Microsoft support statements — but every repository should design for them from day one.

## 5.1 Authoring and source

| # | Observed behaviour | Consequence for the factory |
|---|---|---|
| FE-01 | Agents created in the portal land in the Default solution with a generated publisher prefix unless a preferred solution is set; skills, workflow tools and connected-agent actions must be added to the agent solution explicitly | Set the preferred solution for every maker before the first save; the export pipeline checks that every component sits in the right solution |
| FE-02 | The schema name (publisher prefix) can only be set before the first save; the platform appends a suffix | Naming rule in the factory instructions; a policy test rejects foreign prefixes |
| FE-03 | Web search is enabled by default on new agents | Set it consciously per agent; a test enforces the declared value |
| FE-04 | Agent display names are limited to 30 characters; workflow names must start with a letter | Naming policy and validator |
| FE-05 | Native skills export as inline agent-skill bot components; skills, tools and connected-agent actions round-trip byte-identically once they are solution components | Skills live as SKILL.md source in Git and are compared against the export |
| FE-06 | Workflows can be generated as code (definition, designer graph and data file) and imported; the DEV export is byte-identical to the generator output. Patching workflows through the Web API is unsuitable | Prefer a deterministic workflow generator over hand-edited exports; drift test between generator output and export |
| FE-07 | Workflow condition nesting is limited to 8 levels; deeper nesting fails at activation | Generator and validator enforce the limit |
| FE-08 | Agents call workflows only through the agent-call (Skills) trigger with typed inputs; objects travel as JSON text | Workflow contracts define typed inputs, outputs and error codes |
| FE-09 | The rich-text instruction editor alters Markdown | Compare instructions as plain text in tests |
| FE-10 | Workflow file names contain component IDs | Source manifests use wildcards for ID-bearing paths |
| FE-11 | The solution "Both" unpack layout has no separate managed variants for agents, skills and workflows | Keep one unpacked tree; build managed and unmanaged packages from it |

## 5.2 Transport, import and publishing

| # | Observed behaviour | Consequence for the factory |
|---|---|---|
| FE-12 | Agent, native skill and workflow round-trip (delete → re-import → export) is identical except a time-zone system field; managed import and clean uninstall work | Solution transport is viable for these components; keep a probe gate for components not yet proven (memory, hooks, Work IQ/Foundry IQ, MCP tools) |
| FE-13 | Managed-imported workflows arrive as Draft | Post-import step activates workflows |
| FE-14 | Only published agents can be connected as connected agents; a description is mandatory; publishing is not sharing | Post-import publishes specialists first and the orchestrator last; sharing is a separate, gated step |
| FE-15 | Publishing is asynchronous | Poll publish status (the reference waits up to 180 s) before verifying |
| FE-16 | Managed agents can't be renamed after import | Stamp environment-specific names and icons into the package **before** packing |
| FE-17 | `--stage-and-upgrade` requires a higher solution version | Stamp `Major.Minor.<run>.<attempt>` on every pipeline run and assert the installed version after import |
| FE-18 | A managed upgrade cleanly removed a legacy agent from a test environment, with before/after guards confirming no collateral changes | Use upgrade (not delete) for removals, wrapped in read-only guards and a human gate |
| FE-19 | A missing table in the target broke the agent import | Import order platform/app solution → agent solution; preflight checks prerequisites |
| FE-20 | The Power Platform CLI below 2.13 failed on Code Apps in the app solution | Pin the pac version in every pipeline |

## 5.3 Identity and connections

| # | Observed behaviour | Consequence for the factory |
|---|---|---|
| FE-21 | Workflows using the connection in "invoker" mode returned Unauthorized; "embedded" works | Workflows that agents call run with an embedded, service-owned connection |
| FE-22 | Activation of imported workflows fails in the pipeline when the bound connection is owned by a user; the deployment principal also needs the connection shared with edit rights | Use service-principal-owned connections bound through deployment settings; share them with the deployment principal |
| FE-23 | A shared Dataverse connection reference served unrelated workflows, so rebinding it globally was unsafe | One connection reference per context (for example `<prefix>_Dataverse<Context>`), owned by the platform/app solution |
| FE-24 | A dedicated runtime principal with a minimal Dataverse role (one table; delete and unrelated tables denied) worked; WhoAmI and allow/deny probes confirmed it | Each agent context gets its own runtime principal, role and secret/credential per environment |
| FE-25 | Copilot Studio creates an Entra agent identity per agent per environment; Agent Builder agents have none, so identities can't be carried over when migrating | Plan Agent 365 registration, ownership and sharing per environment; migrations change identities |

## 5.4 Testing, evaluation and operations

| # | Observed behaviour | Consequence for the factory |
|---|---|---|
| FE-26 | The Evaluate tab offers only General quality and doesn't compare against expected answers; the CSV template is `conversationNumber,question,response`, max 20 conversations per file, 6 Q/A pairs per conversation, 1,000 characters per question, ≤ 5 MB | Generate CSV batches from Git; check expected and forbidden content with own deterministic graders; humans review safety cases |
| FE-27 | The evaluation API returned 403 `InsufficientDelegatedPermissions` without the delegated permission `CopilotStudio.MakerOperations.Read` | Add and consent the permission for the evaluation client before building the gate |
| FE-28 | The agent-call trigger can't be invoked through the Flow API; a read-only workflow path can be run through Power Automate "Run flow" | Workflow tests through designer, run history and "Run flow"; agent-level tests through the SDK client or preview |
| FE-29 | The Studio preview in a test environment failed to load because an external shell bootstrap was blocked (connection reset) | Always have a second invocation path (Agents SDK client, MCP channel) for agent tests |
| FE-30 | Environments without credit allocation or a billing plan block preview and testing | Allocate credits or link pay-as-you-go before the first build in every environment |
| FE-31 | DEV exports carry platform drift unrelated to the change | Review net content in the export PR; drift gates report rather than silently pass |

---

# 6. Gap analysis

| # | Gap | Impact | Factory mitigation | Evidence |
|---|---|---|---|---|
| G1 | No supported unattended behavioural evaluation for harness agents and workflows; Evaluate offers General quality only | No automated quality gate; expected/forbidden content unchecked | Evaluation sets in Git; CSV batches for the Evaluate tab; Eval Runner on the Agents SDK client with deterministic and LLM-judge graders; attended gate until proven | [S10, S19, S22, S23]; FE-26, FE-27 |
| G2 | Copilot Studio–specific operations need interactive identity | CI can't sync, publish or evaluate unattended | Split loops: interactive in DEV only; outer loop moves solutions with a federated service principal; publishing and activation by post-import scripts; governed test identity for evaluations; track app-only support | [S10, S12, S24] |
| G3 | Solution completeness for some harness components still unproven | Silent drift between environments | Agents, skills, workflows and connected agents are proven (FE-12); keep a probe gate for memory, hooks, Work IQ/Foundry IQ and MCP tools; post-deployment verification fails the release when components are missing | [S02, S63]; FE-12 |
| G4 | Settings outside solutions (channels, sharing, Application Insights, authentication, Direct Line security) | Manual steps, configuration drift | Post-deployment configuration as code, read back after each release | [S33] |
| G5 | Evaluation sets can't be created through an API; harness CSV import is UI-only | Test sets drift from Git | Git is the source; CSV generated per release; the Eval Runner reads Git directly | [S19, S22]; FE-26 |
| G6 | No production-to-backlog loop; short retention (28-day sessions, 89-day evaluation results) | Learning is lost | Feedback Harvester; export to Log Analytics and Dataverse; incidents become regression cases | [S21b, S51] |
| G7 | Telemetry in preview, delayed, authenticated-only and harness-dependent | Unreliable alerting | Normalisation layer (KQL functions), SLOs on aggregates, Dataverse process-state tables as primary audit | [S50] |
| G8 | Preview churn and schema changes | Broken builds | Pin pac, extension, plugin and MCP server versions; contract and drift tests; monthly drift check through Learn MCP | [S10, S61]; FE-20 |
| G9 | Azure Repos: no Copilot cloud agent; Azure Boards → cloud agent requires GitHub repositories | Less automation on Azure DevOps | Local autopilot on Dev Box/VM; Copilot code review for Azure Repos (preview); Azure DevOps MCP | [S69, S84] |
| G10 | Tool supply chain: unpinned or outdated Superpowers, plugins and MCP servers; content exclusion unreliable for agents | Supply-chain and injection risk | Pin exact versions (vendored with SHA manifest or plugin version); managed-settings allow-lists; hooks | [S75, S86, S87] |
| G11 | Credits consumed by building, testing and evaluating | Cost surprises | Tiered evaluation suites, budgets per environment and agent, evaluation cost per release | [S31]; FE-30 |
| G12 | Harness lock-in; upgrade drops knowledge, Power Fx and child agents; connected agents only harness-to-harness | Rework | Harness decision as an ADR per agent; skills as files; processes in workflows | [S02] |
| G13 | Agent tests depend on the Studio preview shell | Blocked proofs in test environments | Second invocation path (Agents SDK client, MCP channel); workflow-level proofs via run history | FE-29 |
| G14 | User-owned and shared connections | Pipeline activation failures; blast radius across unrelated workflows | Service-principal-owned connections; one connection reference per context; dedicated runtime principal and minimal role | FE-21–FE-24 |

---

# 7. Target concept: the Agent Factory

## 7.1 Overview: four loops, seven planes

**Figure 1 — The Agent Factory closed loop** (render as a circular four-stage diagram; arrows clockwise; the Learn arrow returns to Build):

| Loop | Cadence | Flow | Exit evidence |
|---|---|---|---|
| **1 BUILD** (inner loop) | Minutes to hours | Spec and declarations → evaluations written first → author agent, runtime skills, workflows and tools (portal in DEV, generators, or code-first tools) → export and normalise → preview and quick evaluation → commit and pull request | Passing local verification checklist with pasted command output |
| **2 VERIFY** (pull request) | Minutes | Structure, drift and policy checks → pack → solution checker → security and ID scanning → component tests → Copilot code review and CODEOWNERS approval | Green checks, approvals |
| **3 RELEASE** | Hours to days | Version stamp → environment-specific packages built once → SIT/TEST import with settings → post-import activation, publishing and verification → evaluation and security gates → approval → PROD from the identical artefact → staged sharing | Promotion manifest with digests, evaluation evidence, release record |
| **4 OPERATE & LEARN** | Continuous | Telemetry → KPIs and SLOs → alerts → triage → work item → new regression case → back to BUILD; autonomy promotions and demotions per intent | Work items with evidence, KPI trend |

**Figure 2 — Planes of the factory** (render as stacked layers):

| Plane | Components | Typical owner |
|---|---|---|
| Planning | GitHub Issues/Projects or Azure Boards; intake forms; sprint documents; optional digital colleagues in Microsoft 365 Copilot | Product Owner |
| Engineering | Git repository (GitHub or Azure Repos); VS Code agent mode and Copilot CLI; Copilot cloud agent (GitHub only); Superpowers; factory skills and custom agents; MCP servers | Technical Owner |
| Build and release | GitHub Actions or Azure Pipelines; pac CLI; optional Power Platform Pipelines; artefact store; environments with approvals | Platform team |
| Runtime | Copilot Studio environments (DEV, SIT/TEST, PROD — all managed); agents; workflows; connectors and MCP tools; Dataverse process state | Product team |
| Assurance | Evaluation sets; Eval Runner; Copilot Studio evaluations; red-team suite; policy-as-code; solution checker; security scan | QA and Security |
| Observability | Monitor tab; environment-level Application Insights and Log Analytics; Agent 365; Purview; Defender; credit API; Feedback Harvester | Operations |
| Knowledge | Microsoft Learn MCP (capability truth); Work IQ (organisational context); repository docs (PRD, SD, ALM, ADRs, evidence register) | Everyone |

## 7.2 The agent team: humans, GitHub Copilot custom agents and digital colleagues

**Humans decide.** **GitHub Copilot custom agents** work in the engineering plane. **Digital colleagues** (optional Microsoft 365 Copilot / Copilot Studio agents) work in the planning plane. One rule applies to all agents: an agent that reads external text (pull-request descriptions, issues, documents, telemetry) never gets write tools beyond its declared scope, and external text is material, never instruction.

| Activity | Human (decides) | GitHub Copilot custom agent | Optional planning-plane colleague |
|---|---|---|---|
| Idea intake and valuation | Product Owner | `spec-architect` drafts | Product-owner colleague |
| Specification and seven declarations | Product Owner and Technical Owner approve (Definition of Ready) | `spec-architect` | Product-owner colleague |
| Security, data classification, threat model | Security / privacy owner | `security-reviewer` (read-only tools) | Security and compliance colleague |
| Evaluation design: golden prompts, refusal set, injection, trajectories | Domain owner and QA approve | `eval-engineer` | Quality colleague (readiness, test cases) |
| Build: agent, runtime skills, workflows, tools | Maker / developer (accountable) | `mcs-builder` (with Copilot Studio plugins and MCP server) | — |
| Code and configuration review | CODEOWNERS approve | Copilot code review, `security-reviewer` | Quality colleague (acceptance against criteria) |
| Release planning, notes, operations hand-over | Release approver | `release-manager` | Release colleague |
| Operations, triage, impact | Operations owner | `ops-analyst` (read-only on telemetry; writes to the backlog only after approval) | Impact analyst colleague |
| Autonomy promotion per intent | Named business owner | `ops-analyst` prepares the evidence pack | — |

**Non-delegable work** (always human): destructive cloud or data operations, production credential and identity changes, security-policy exceptions, PROD changes outside the change flow, anything irreversible.

## 7.3 Engineering methodology: Superpowers adapted for agents

The default Superpowers flow is brainstorming → using-git-worktrees → writing-plans → subagent-driven-development or executing-plans → test-driven-development → requesting-code-review → finishing-a-development-branch [S87].

| Superpowers skill | Factory step | Artefact | Gate |
|---|---|---|---|
| using-superpowers | Session bootstrap; loads the factory skills | — | Always first |
| brainstorming | Use-case intake, harness decision, seven declarations, intent taxonomy | Spec/design, `declarations.yaml`, harness ADR | Product Owner and Technical Owner approval |
| using-git-worktrees | One isolated branch per change | Branch | — |
| writing-plans | Plan of skills, tools, workflows, knowledge, connection references, environment variables, evaluation cases, deployment settings (plans record decisions, not code) | Plan | Plan review |
| test-driven-development | **Eval-Driven Development**: write evaluation and policy cases first, watch them fail (RED), build until they pass (GREEN), then refactor instructions and skills (REFACTOR) | Evaluation sets, evidence | No build task without a failing case |
| subagent-driven-development, executing-plans, dispatching-parallel-agents | Parallel build of runtime skills, workflows and connectors, one fresh subagent per task | Commits | Task-level review |
| systematic-debugging, diagnosing-superpowers | Reproduce failures from transcripts, run history and telemetry; root cause before fix | Incident note, regression case | — |
| verification-before-completion | Local gate: pack succeeds, drift and policy pass, quick evaluation passes, no secrets or IDs | Pasted command output | Mandatory before PR |
| requesting-code-review, receiving-code-review | PR with evidence; Copilot code review plus CODEOWNERS | PR | Approvals |
| finishing-a-development-branch | Merge → release pipeline; release notes from linked work items | Release | — |
| writing-skills | Every recurring fix becomes a factory skill or a policy | `.github/skills/mcs-*` | Skill review |

**Operating rules that proved themselves (FE).**
- A **phase matrix per change type** states which Superpowers phases are mandatory; skipping a phase needs a recorded human approval.
- **Spec → plan → sprint document** chain with a tracking issue; one PR per slice; the merge is the gate.
- **PR contract with evidence**: what, why, validation evidence as pasted command output ("no pasted output = not done"), API, infrastructure, security, i18n and docs impact, linked issues. New tests are wired into CI in the same PR. Environment-bound items are marked "deferred (environment gate)".
- **Agents never flip a status to done**, never close multi-slice tracking issues and are never an approval authority.
- **Scripts are proven on every shell the pipeline uses** (for example PowerShell 7 and Windows PowerShell 5.1).

**Superpowers pinning.** Pin an exact version. Either vendor the full skill set under `.github/skills/` with a SHA-256 manifest and a verifier, or install the plugin from `obra/superpowers-marketplace` at a fixed version — and vendor at least the core skills the Copilot cloud agent needs. v7.0.0 rebuilt brainstorming and fixed Windows hook discovery; a fix since v6.3.0 stops `run-hook.cmd` from executing `bash`/`where` planted in the current directory [S87]. Vendoring skills alone skips the plugin's SessionStart hook, so repository instructions must require using-superpowers first [S88].

## 7.4 Eval-Driven Development and the evaluation pyramid

| Level | What is tested | Tools | When | Proposed gate |
|---|---|---|---|---|
| **L0 Structure and policy** | Pack succeeds; source-manifest drift; naming (prefix, ≤ 30-character agent names); policy-as-code (allowed connectors, MCP servers, models, channels, authentication, web search setting, data-class tags); no secrets or identifiers; evaluation coverage rules | pac, validators, secret/ID scan, GitHub Advanced Security | Every PR | 100% pass |
| **L1 Components** | Runtime-skill scripts; workflow generator drift and nesting limits; workflow contract tests; out-of-envelope negative tests; post-import scripts against local HTTP fakes | Pester, pytest, Jest; workflow designer node tests | PR (offline) and DEV | 100% pass |
| **L2 Behaviour** | Golden prompts for critical intents; refusal suite; non-activation; missing data; unknown entities; human-gate respect; escalation and self-identification; multi-turn; tool-use and trajectory assertions; grounding checks | Eval Runner (Agents SDK client + deterministic and LLM-judge graders); Evaluate tab (General quality) | SIT/TEST at release; nightly sample | Critical golden prompts 100%; General quality ≥ 80%; every safety and expected/forbidden case reviewed (proposals) |
| **L3 Safety and security** | Prompt injection including injected documents; unverified claims; data exfiltration; harmful content; over-permissioned tools | CAT Agent Red Team skill; PyRIT through a custom callback; corpus in Git | Release and monthly | Zero critical findings |
| **L4 Non-functional** | Latency, credits per conversation or run, load where a supported channel exists, capacity headroom | Monitor tab, Application Insights, credit API | Release and weekly | Within budget and SLO |
| **L5 Production assurance** | Sampled answer quality per intent, refusal precision, repeat contact, escalation with context | Answer-assurance workflow, aggregated | Continuous | Drives the autonomy ladder |

**Rules.** Synthetic data only below PROD. Evaluation sets are versioned with the agent (`agents/<role>/evals/prompts.json` or YAML) and carry kinds (non-activation, missing data, injection, unverified claim, human gate, unknown entity). Every production incident adds a regression case. Non-determinism is handled explicitly (several runs per case, majority or pass@k, agreed tolerance). Every run writes an evidence record: agent version, model, harness, environment, evaluation-set hash, thresholds, results and credit cost.

**Evaluate-tab constraints (FE-26).** Template header `conversationNumber,question,response`; at most 20 conversations per file, 6 question/answer pairs per conversation, 1,000 characters per question, file ≤ 5 MB; General quality only. A converter generates the batches from Git (one case per conversation, split by kind).

**Attended gate (Phase 1).** The maker uploads the batches in SIT/TEST or runs them through the Copilot Studio MCP server, exports results, and the pipeline verifies freshness (agent version, evaluation-set hash), applies thresholds and attaches the evidence. **Automated gate (Phase 2).** The Eval Runner drives the published agent through the Agents SDK client with a governed test identity; the evaluation API is added once the delegated permission is consented (FE-27).

## 7.5 Source model (proven two-layer pattern)

| Layer | Content | Produced by | Rules |
|---|---|---|---|
| **Deployable source** | DEV export unpacked with `pac solution unpack --packagetype Both`: bots, bot components, workflows, assets, solution metadata | Export pipeline (DEV → unpack → normalise → PR) | Never hand-edited except by generators and normalisers; `.mcs/` or sync metadata never edited |
| **Authored source ("harness" layer)** | Per agent: identity, instructions, icon, tool contract, evaluation prompts; native skills (SKILL.md); workflow contracts; source manifest listing approved components and forbidden patterns | Humans and GitHub Copilot in PRs | Reviewed like code; tests compare authored and deployable layers |
| **Generators** | Deterministic generators for workflows (definition, designer graph, data file, solution registration) | Code in the repository | Byte-identical with the DEV export; drift test |
| **Repo → DEV sync** | Script that writes authored instructions and skills into DEV, publishes (specialists first) and verifies | Interactive, DEV only | Plans by default; backs up before execute; never runs against SIT/PROD |

**Authoring accelerators.** `pac copilot` workspaces (CliCopilot), the VS Code extension and the Copilot Studio MCP server speed up authoring in DEV. Whatever tool is used, the result enters Git only through the DEV export → unpack → PR path, so there is exactly one canonical deployable format (P7). Don't mix Dataverse Git-integration YAML with the unpacked format for the same solution; Git-integration YAML can only be read by `pac solution pack` [S38].

**Solution split.** A platform/app solution owns tables, security roles, connection references and environment variables; the agent solution holds agents, skills and workflows on top of it. Import order: components → platform/app → agent. Connection references belong to the owning solution and are bound through its deployment settings (FE-19, FE-23).

## 7.6 Repository blueprint

```
AGENTS.md                              rules for repository-working agents (start with using-superpowers)
.github/
  copilot-instructions.md              decision order, scope guards per folder, phase matrix, contracts
  instructions/                        *.instructions.md with applyTo (agents, workflows, solutions, evals, bicep, powershell)
  agents/                              spec-architect, mcs-builder, eval-engineer, security-reviewer, release-manager, ops-analyst
  skills/                              Superpowers (pinned, SHA-256 manifest) + factory skills mcs-*
  hooks/                               preToolUse guards (deny push/import outside DEV, deny secret files)
  copilot/settings.json                enabled plugins and marketplaces
  agent-policy/                        AGENT_WORKFLOW, NON_DELEGABLE_WORK, KPI baseline, break-glass
  workflows/                           pipelines + copilot-setup-steps.yml   (Azure DevOps: pipelines/)
  CODEOWNERS, PULL_REQUEST_TEMPLATE.md, ISSUE_TEMPLATE/ (incl. copilot-slice)
.vscode/mcp.json, tasks.json           MCP servers (DEV only); "validate harness" task
docs/                                  PRD, SD, ALM, TEST, OPERATIONS, SECURITY, ADRs, specs/, plans/, sprints/, evidence register
<domain>/solutions/<platform-app>/src  unpacked platform/app solution (tables, roles, connection references, env variables)
<domain>/solutions/agent/src           unpacked agent solution (deployable source)
<domain>/solutions/agent/harness/      authored layer: agents/<role>/{identity,instructions,tools.contract,evals}, skills/, workflows/*.contract.json, tools/ (generators), source-manifest.json, scripts (validation, sync, post-import, guards)
config/deployment-settings/            <env>.<solution>.json — no secrets, no IDs beyond what the platform requires
tools/eval-runner/                     Agents SDK client, graders, evidence writer
tools/feedback-harvester/              KQL queries, exports, work-item writer
infra/                                 Bicep: Log Analytics, Application Insights, Key Vault, alerts; validation scripts (environment fingerprint)
data/                                  synthetic test data only
```

## 7.7 Factory skill pack and custom agents

| # | Skill | Purpose | Uses | Guardrail |
|---|---|---|---|---|
| 1 | `mcs-harness-decision` | Choose the harness per agent; record an ADR with a credit estimate | Learn MCP, credit estimator | No build without the ADR |
| 2 | `mcs-spec-declarations` | Seven declarations and intent taxonomy | Work IQ (decisions), Learn MCP | No personal data |
| 3 | `mcs-agent-authoring` | Create agents in DEV (preferred solution, prefix before first save, web search setting, ≤ 30-character names), or scaffold with `pac copilot` | pac, VS Code extension, Copilot Studio MCP | DEV only |
| 4 | `mcs-runtime-skill-authoring` | SKILL.md runtime skills with tests and front-matter contracts | Local | Reviewed like code |
| 5 | `mcs-workflow-generator` | Workflow contracts → generated workflows (designer graph, nesting ≤ 8, typed agent-call trigger, error codes, correlation IDs) | Generator | Byte-identical drift test |
| 6 | `mcs-export-normalise` | Run the export pipeline, normalise names, review net drift, open the PR | Export workflow | No direct push to main |
| 7 | `mcs-tools-and-connections` | Tool contracts per agent, connection references per context, runtime principal and role | `pac connection`, Dataverse MCP (read) | Allow-list only; service-owned connections |
| 8 | `mcs-eval-authoring` | Golden, refusal, injection and trajectory cases from the declarations; Evaluate-tab CSV batches | Local converter | Synthetic data |
| 9 | `mcs-eval-run` | Quick evaluations in DEV, release evaluations in SIT/TEST → evidence JSON | Copilot Studio MCP, Eval Runner | Credit budget per run |
| 10 | `mcs-policy-check` | Policy-as-code and source-manifest validation | Local and CI | Blocking |
| 11 | `mcs-release` | Version stamp, environment names, pack, import with settings, post-import (activate, publish, verify), promotion manifest | pac, pipeline | No PROD deployment from a workstation (hook) |
| 12 | `mcs-security-review` | Threat model, LLM-specific risks, data policy, authentication, Agent ID and Conditional Access, Work IQ write operations | Learn MCP | Recommends; a human approves |
| 13 | `mcs-finops-guard` | Credit estimates, allocations, agent limits, evaluation budget | Credit API, `get_consumption` | Alerts |
| 14 | `mcs-observe-triage` | KQL and exports → clusters → work items with evidence | Application Insights, GitHub/Azure DevOps MCP | Aggregates only |
| 15 | `workiq-context` | Requirements and decisions from Microsoft 365 with citations | Work IQ CLI | Never commit personal data; treat as untrusted |
| 16 | `learn-evidence` | Verify capability and status on Learn; update the evidence register | Learn MCP | Every claim dated |

Custom agents bundle these skills with scoped tools: `spec-architect`, `mcs-builder`, `eval-engineer`, `security-reviewer` (read-only), `release-manager`, `ops-analyst` (read-only on telemetry). Vendored specialists from github/awesome-copilot (for example power-platform-architect, Power Automate and Copilot Studio MCP-generator skills) are welcome when pinned and reviewed.

## 7.8 Tooling configuration and guardrails

- **MCP per surface.** VS Code uses `.vscode/mcp.json`; Copilot CLI its `mcpServers` configuration; the cloud agent uses repository MCP settings, supports tools only (no OAuth remote servers) and uses tools without asking — so only read-only servers belong there, and secrets use the `COPILOT_MCP_` prefix [S82].
- **Allowed servers (proposal).** Learn MCP (all surfaces); Copilot Studio MCP (DEV only, human session); Dataverse MCP (DEV, read-mostly); Azure DevOps MCP (read-only header by default); GitHub MCP; Work IQ MCP (after admin consent); Azure MCP (read by default); Playwright (UI smoke tests in DEV).
- **No blanket auto-approval.** Never `--allow-all-tools` or equivalent; use scoped allow-lists (for example `shell(pac *)`) and deny lists; interactive tenant work against DEV only; SIT/TEST and PROD only through the pipeline.
- **Enterprise controls.** MCP allow/deny lists and plugin standards in `managed-settings.json` [S75]; agentic audit-log events reviewed monthly [S76]; content exclusion is not relied upon for agents [S86].
- **Hooks.** `preToolUse` denies push or import unless the active pac profile is DEV, denies reading secret files and unapproved network targets [S73].
- **Pinned versions.** pac CLI (≥ 2.13, FE-20), Copilot Studio extension, plugins, Copilot Studio MCP server, Superpowers and every GitHub Action by commit SHA.
- **Portal automation.** Browser automation of the maker portal (for probes) stays outside the repository when it contains environment identifiers.

## 7.9 Reference pipeline (proven pattern)

| # | Stage | Trigger | Steps | Gate | Evidence |
|---|---|---|---|---|---|
| 1 | Intake and Definition of Ready | Issue / work item | Spec lint, declarations complete, data class, evaluation plan | Product Owner and Technical Owner | DoR record |
| 2 | Export from DEV | Manual dispatch | Export unmanaged and managed → unpack (Both) → normalise environment names → drift report → **PR** (never a direct push) | PR review | Export artefact, drift report |
| 3 | PR validation | Pull request | Repository verifier; lint; policy-as-code; manifest drift; secret/ID scan (whole repository); **full harness test suite**; pack; solution checker (no critical findings); CodeQL; dependency review; evaluation-set lint; Copilot code review | All green plus CODEOWNERS | Check runs |
| 4 | SIT/TEST deploy | Merge to main (path filters) | OIDC sign-in; environment fingerprint; version stamp `Major.Minor.<run>.<attempt>`; build components → app → agent; stamp SIT names, pack; stamp PROD names, pack; import with deployment settings (update, or stage-and-upgrade behind guards and a human gate); assert installed version; post-import (activate workflows, publish specialists then orchestrator, poll, verify names and icons) | Deployment verified | Promotion manifest (repo, workflow, run, SHA, SHA-256 per package) |
| 5 | Assurance | After SIT/TEST deploy; nightly | L2 behaviour; L3 red team; L4 latency and credits; read-back of security scan, data policy, Agent ID and Conditional Access | Thresholds met | Evaluation evidence JSON |
| 6 | PROD promotion | Manual dispatch with the SIT run ID; environment approval | Verify run (workflow, branch, success, SHA) and manifest digests; preflight (prerequisites, bindings); import the **identical** package with PROD settings; assert version; post-import; staged sharing; smoke test | Release approvers | Audit artefact (long retention), release record |
| 7 | Operate | Scheduled | KQL alerts; credit consumption; governance read-back; platform drift check through Learn MCP | SLO breach → incident | Dashboards |
| 8 | Learn | Weekly | Feedback Harvester → work items; regression cases; autonomy-ladder evidence | Product Owner triage | Backlog items |

**Rules.** PROD never rebuilds. Every write is preceded by an environment fingerprint check (expected Dataverse URL, organisation, Key Vault, client IDs and base language held as environment variables). Keep promotion artefacts long enough for the slowest approval (or attach them to a release). Removals use a guarded upgrade, not deletes. Rollback prefers rolling forward; the kill switch is the per-agent monthly limit with Stop usage [S31], unsharing or disabling the channel, and switching workflows off.

**GitHub vs Azure DevOps.** Stages are identical. GitHub uses Actions, environments with required reviewers and OIDC [S39]; Azure DevOps uses Azure Pipelines, environment approvals and Build Tools v2.0 with workload identity federation (Entra issuer) [S40, S92]. Power Platform Pipelines can replace stage 6 inside one tenant (delegated service-principal deployment, approvals, gated extensions) but can't deploy across tenants [S35–S37]. Copilot ALM Starter is a starting skeleton for both platforms [S42].

## 7.10 Environments and identity

| Environment | Type | Purpose | Data | Credits | Changed by | Identity |
|---|---|---|---|---|---|---|
| DEV | Managed, developer or sandbox | Inner loop; only interactive environment | Synthetic only | Fixed allocation or billing plan (FE-30); agent limits | Makers (portal, pac, VS Code, MCP) | Interactive user with MFA |
| BUILD (optional) | Managed sandbox | Import unmanaged → export managed; probes | None | Minimal | Pipeline only | Federated service principal |
| SIT/TEST | Managed sandbox | Integration, assurance, pilot group | Synthetic or approved test data | Evaluation budget | Pipeline only | Deployment principal; runtime principal per context; test identity for evaluations |
| PROD | Managed production | Live | Real, under restrictions | Production allocation; agent limits; budget alerts | Pipeline only | Deployment principal; runtime principal per context; Entra Agent ID per agent |

**Identity rules.**
- **Deployment principal per environment**, federated (OIDC/WIF) where pac and the Dataverse calls allow it; where a secret is unavoidable it lives only in that environment's Key Vault, is fetched at run time and is masked. One principal never spans DEV and PROD.
- **Runtime principal per agent context** with a minimal Dataverse role (only the tables it needs; delete and unrelated tables denied), its own credential per environment and a **service-principal-owned connection** bound through deployment settings and shared with the deployment principal (FE-21–FE-24).
- **Entra Agent ID** is created per agent per environment; plan Agent 365 registration, ownership, description and sharing for each [S26, S27]; FE-25.
- **Managed environments throughout** — required for Pipelines and Git integration, and for environment-level telemetry [S35, S38, S50]. Environment-group rules block unmanaged customizations in SIT/TEST and PROD, enforce solution checker, restrict knowledge sources, skills and sharing, disable external and preview models and stop drawing credits from the tenant pool [S44]. Data policies are strictest in DEV, with MCP and HTTP explicitly classified [S43, S49].

## 7.11 Security baseline by layer

| Layer | Controls |
|---|---|
| Developer tooling | Copilot policies; MCP and plugin allow-lists; hooks; pinned Superpowers and plugins; scoped tool allow-lists; no secrets or personal data in prompts; audit-log review |
| Repository | Rulesets (no direct pushes to main, also not from export workflows); **CODEOWNERS** for workflows, deployment settings, agent sources and infrastructure; secret scanning with push protection plus a repository-wide ID scan (GUIDs, tenant/app IDs, mailboxes, hostnames) — no identifiers in documentation; CodeQL; Dependabot; actions pinned by SHA |
| Pipeline | OIDC/WIF; environment approvals; least-privilege application users per environment; environment fingerprint before every write; one immutable artefact across stages; provenance and long-retention audit artefacts |
| Platform | Managed environments; data policies including MCP, HTTP and knowledge; environment-group rules; Entra Agent ID with Conditional Access; Purview DSPM, audit and labels; Defender real-time protection; credit controls |
| Agent design | Server-side write envelopes (workflow contracts, minimal runtime roles); content treated as data; refusal sets; human gates that agents can't trigger; escalation paths; Work IQ write operations reviewed per agent; telemetry without personal data; DPIA per agent where personal data is in scope |
| Assurance | Red-team suite; prompt-injection corpus; out-of-envelope negative tests; pre-publish security scan read-back [S48] |

## 7.12 Observability and the learning loop

**Signal chain.** Monitor tab, environment-level Application Insights, Agent 365, Dataverse process-state tables, reactions, workflow run history, credit API, Purview and Defender alerts → normalisation (KQL functions in Log Analytics) → KPIs → alerts → triage (`ops-analyst` drafts, the owner decides) → work item with evidence → regression case → release.

| KPI family | Measures |
|---|---|
| Agent quality (per intent) | Resolution rate (never deflection), refusal precision, repeat contact within 14 days, escalation with full context, tool error rate, latency, thumbs-down rate, credits per resolved session |
| Engineering (DORA) | Lead time from approved spec to PROD, deployment frequency, change failure rate, time to restore; share of releases through the pipeline (target 100%) |
| Assurance | Evaluation coverage per intent, pass rates per level, solution checker critical findings (target 0), secrets and identifiers detected (target 0) |
| Cost | Credits per environment and agent against budget; evaluation share of total credits |

**Autonomy ladder per intent.** Stage 0 Shadow → 1 Assist → 2 Supervised → 3 Autonomous → 4 Transactional. Promotion is a decision by a named owner on recorded evidence; demotion is an automatic trigger on a policy breach or a KPI floor; every stage change is an audit record. **Privacy:** evaluate answers, never people — aggregate per intent, minimum cohort sizes, no per-person score.

## 7.13 FinOps

- **What consumes credits.** AI-powered authoring, preview testing, evaluations and runtime; every workflow action consumes capacity, even without AI steps [S05, S31].
- **Prerequisite.** Each environment needs a credit allocation or a pay-as-you-go plan before the first build, otherwise preview and testing are blocked (FE-30).
- **Controls.** Fixed allocation per environment with no draw from the tenant pool; monthly limit per agent with Stop usage; Azure cost alerts for pay-as-you-go (alerts don't stop usage); monthly review through the Monitor tab and credit API [S30–S32].
- **Factory levers.** Author code-first with GitHub Copilot where practical and measure the net effect; keep L0/L1 offline; run full L2 at release and a budgeted sample nightly; re-run evaluations only when the agent version, model or evaluation set changed; report evaluation cost per release.

---

# 8. Adoption roadmap for any repository

## 8.1 Phases

| Phase | Typical duration | Deliverables | Exit criteria |
|---|---|---|---|
| **0 Foundation** | 3–4 weeks | ADRs F01–F07 decided; repository blueprint applied; Superpowers pinned; factory skills and agents v0.1; MCP and plugin allow-lists and hooks; CODEOWNERS and rulesets; managed DEV/SIT-TEST/PROD environments with credit allocations, agent limits and environment-level telemetry; deployment and runtime principals; spikes S1–S5 | Spikes documented in the evidence register; Definition of Ready met for the pilot agent |
| **1 Pilot** | 6–8 weeks | One agent and one workflow end to end: export → PR validation → SIT/TEST → attended evaluation gate → PROD pilot; FinOps and DORA baselines | 100% of releases through the pipeline; critical golden prompts 100%; zero critical security findings; evidence for every release |
| **2 Automated gates** | 6–8 weeks | Eval Runner in CI (L2), red-team suite (L3), complete policy-as-code, Feedback Harvester v1, governance read-back, nightly regression within budget | No manual step between merge and SIT/TEST evidence |
| **3 Closed loop at scale** | Ongoing | Autonomy ladder per intent; production regressions create work items and regression cases automatically; cloud-agent or autopilot remediation of low-risk changes with human approval; template repository | KPI targets met for two consecutive months |

## 8.2 Standard spikes

| Spike | Question | Method | Done when |
|---|---|---|---|
| S1 Solution round trip | Do the components this repository uses travel in solutions? | Probe agent with the components in scope (skills, workflows and connected agents are proven by FE-12; add memory, hooks, Work IQ/Foundry IQ and MCP tools when used) → pack → managed import into a sandbox → diff and functional check; record a GO/NO-GO decision. A NO-GO stops agent implementation | Component matrix recorded; approver decision in the repository |
| S2 Eval Runner hello world | Can CI drive a published SIT/TEST agent with a governed test identity? | Agents SDK client with three golden cases and one refusal case; evidence JSON | Repeatable evidence; identity approach approved by Security |
| S3 Secretless deployment | Which operations work with a federated principal? | OIDC/WIF: solution import with settings, post-import activation and publishing, Power Platform Pipelines deploy | Supported operations documented; secrets removed where possible |
| S4 Workflows as code | Does the workflow generator round-trip in this tenant? | Generate → pack → import → export → compare; run the agent-call path through the designer and a read-only "Run flow" | Byte-identical export; run history evidence |
| S5 Second invocation path | Can agents be tested without the Studio preview? | Agents SDK client or MCP channel against the published SIT/TEST agent | Prompt/response evidence from SIT/TEST |

---

# 9. Decisions (ADRs) every repository takes

| ADR | Decision | Options | Recommendation |
|---|---|---|---|
| F01 | Canonical source format | (a) Two-layer: unpacked DEV export + authored layer + generators; (b) `pac copilot` workspace only; (c) Dataverse Git-integration YAML | (a) — proven end to end; use (b) and the VS Code extension as authoring accelerators whose output is normalised through the export; (c) only for UI-first maker teams, never mixed with (a) |
| F02 | Release mechanism | (a) Pro-code pipeline (GitHub Actions / Azure Pipelines + pac) with promotion manifest; (b) Power Platform Pipelines with extensions | (a) as the default and for any cross-tenant hand-over; (b) where a single tenant prefers in-product governance |
| F03 | Harness and cost policy | Default harness per scenario; approval for GitHub Copilot harness agents | Copilot Chat harness for advisory agents, standard harness for rule-based flows, GitHub Copilot harness for reasoning plus tools — each with a credit estimate and an owner |
| F04 | Evaluation gate and identity | Attended gate; automated Eval Runner with a governed test identity; app-only when supported for authenticated agents | Attended in Phase 1, automated in Phase 2, app-only when documented; consent `CopilotStudio.MakerOperations.Read` for the evaluation API |
| F05 | Connections and runtime identity | User-owned vs service-principal-owned connections; shared vs per-context connection references | Service-principal-owned connections, one reference per context, dedicated runtime principal with a minimal role per environment |
| F06 | Developer-tool supply chain | Versions and allow-lists for Superpowers, plugins, MCP servers, pac, extension | Pin exact versions; review monthly; upgrade through PRs with verifier evidence |
| F07 | Telemetry, privacy and autonomy | Aggregation level, retention, works councils; per-intent autonomy ladder | Aggregate per intent only; minimum cohort size; adopt the ladder with evidence-based promotion and automatic demotion |

---

# 10. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Preview features change or are withdrawn | Rework | Replaceable adapters; monthly drift check; status recorded in the evidence register |
| Schema or export-format changes break the source model | Failed builds | Pinned tool versions; generator and drift tests; probe gate re-run after platform updates |
| Credit overrun from building, testing and evaluation | Budget breach | Environment allocations, agent limits, tiered evaluation suites, cost per release reported |
| User-owned or shared connections | Failed PROD activation; unintended blast radius | Service-principal-owned connections; per-context references; preflight checks |
| Interactive identity leaks into CI | Shadow credentials | No personal accounts in pipelines; governed test identity; secrets only in per-environment vaults |
| Studio preview or portal outages block proofs | Delays | Second invocation path; workflow-level proofs |
| Prompt injection through PR text, issues or documents into development agents | Unwanted changes | Read-only review agents; hooks; external text treated as material; human approval for writes |
| Identifiers committed to the repository | Exposure, audit findings | Repository-wide ID scan; push protection; evidence policy (only sanitised PASS/FAIL, hashes and versions in Git) |
| Harness lock-in | Rework on change | Harness ADR per agent; skills as files; processes in workflows |
| Tool sprawl and unclear ownership | Factory decay | Named factory owner; quarterly review of skills, agents and allow-lists |

---
# Appendix A — Glossary

| Term | Meaning |
|---|---|
| Harness | The runtime between the model and the agent or workflow: decides when to call the model, which components to send and which tools to call [S01] |
| GitHub Copilot harness | Copilot Studio harness for reasoning-heavy, multi-step agents and workflows; not the GitHub Copilot service [S01] |
| CliCopilot workspace | Local agent workspace created with `pac copilot init --authoring-mode cli-copilot` or `clone` [S11] |
| Runtime skill | SKILL.md package added to a Copilot Studio agent (as opposed to a development skill used by GitHub Copilot) [S07] |
| Eval-Driven Development (EDD) | Writing failing evaluation cases before building the agent behaviour |
| Golden prompts | Curated regression prompts with expected responses; final gate before production [S94] |
| Seven declarations | Write envelope, refusal set, escalation path, grounding sources, data classification, decision surface, measurement |
| Two-layer source model | Deployable layer (unpacked DEV export) plus authored layer (instructions, contracts, skills, evaluation prompts, manifest) and generators |
| Promotion manifest | Pipeline artefact binding repository, workflow, run, commit SHA and package digests, so PROD imports exactly what SIT/TEST verified |
| Environment fingerprint | Check of the target environment's identity (URL, organisation, vault, client IDs, language) before every pipeline write |
| Runtime principal | Service principal under which agent-called workflows access data, with a minimal role and its own connection per environment |
| FE | Field evidence: behaviour observed in a reference implementation, not a Microsoft support statement |
| Write envelope | The declared set of fields, conditions and refusals for any write, enforced server-side |
| Autonomy ladder | Per-intent stages from Shadow to Transactional with evidence-based promotion and automatic demotion |
| AB# | Azure Boards work-item reference in GitHub commits, PRs and issues |
| OIDC / WIF | Federated, secretless authentication from GitHub Actions or Azure Pipelines to Microsoft Entra |
| Managed environment | Power Platform environment with enhanced governance, required for Pipelines and Git integration |
| Deployment settings | Per-environment values for connection references and environment variables used at import [S13] |

# Appendix B — Evidence register (accessed 25 Oct 2026)

| ID | Source | URL |
|---|---|---|
| S01 | Harnesses in Copilot Studio | https://learn.microsoft.com/en-us/microsoft-copilot-studio/harnesses-overview |
| S02 | Agents powered by the GitHub Copilot Harness overview | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/overview |
| S03 | What's new in Copilot Studio, August 2026: GitHub Copilot harness (Microsoft Copilot Blog) | https://www.microsoft.com/en-us/copilot/blog/copilot-studio/new-and-improved-github-copilot-harness-agent-skills-and-richer-context/ |
| S04 | New and improved: build apps, extend agents and transform business processes (Microsoft Copilot Blog, 7 Oct 2026) | https://www.microsoft.com/en-us/copilot/blog/copilot-studio/new-and-improved-build-apps-extend-agents-and-transform-business-processes-in-microsoft-copilot-studio/ |
| S05 | Workflows overview | https://learn.microsoft.com/en-us/microsoft-copilot-studio/workflows-experience/flows-overview |
| S06 | Workflow designer | https://learn.microsoft.com/en-us/microsoft-copilot-studio/workflows-experience/flow-designer |
| S07 | Add existing skills | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/skills-add-existing |
| S08 | Hooks overview | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/hooks-overview |
| S09 | Add Work IQ to an agent | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/add-work-iq |
| S10 | Copilot Studio MCP server | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/copilot-studio-mcp |
| S11 | pac copilot command reference | https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/copilot |
| S12 | pac auth command reference | https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth |
| S13 | pac solution command reference | https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/solution |
| S14 | pac pipeline command reference | https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/pipeline |
| S15 | pac copilot-studio command reference (preview) | https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/copilot-studio |
| S16 | Power Platform CLI ❤️ Power Platform API (Power Platform dev blog) | https://devblogs.microsoft.com/powerplatform/power-platform-cli-%e2%9d%a4%ef%b8%8f-power-platform-api/ |
| S17 | Power Platform CLI on NuGet | https://www.nuget.org/packages/Microsoft.PowerApps.CLI.Tool |
| S18 | Copilot Studio extension for VS Code — releases | https://github.com/microsoft/vscode-copilotstudio/releases |
| S19 | Agent evaluation REST API | https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-rest-api |
| S20 | Automate agent evaluation with tools (connector) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-automate-tools |
| S21 | Agent evaluation (standard harness) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-intro |
| S21b | Agent evaluation results (retention, comparisons) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-results |
| S21c | Multi-turn agent evaluation | https://learn.microsoft.com/en-us/microsoft-copilot-studio/analytics-agent-evaluation-multi-turn |
| S22 | Agent evaluation (GitHub Copilot harness) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/analytics-agent-evaluation-intro |
| S23 | Copilot Studio SDK client for both harnesses (CAT blog, 20 Oct 2026) | https://microsoft.github.io/mcscatblog/posts/copilot-studio-sdk-both-harnesses/ |
| S24 | Copilot Studio client service-to-service documentation | https://github.com/microsoft/Agents/blob/main/docs/copilot-studio-client-s2s-doc.md |
| S25 | Publish an agent as MCP server or via A2A | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/publication-channels-mcp-agent-to-agent |
| S26 | Use Microsoft Entra agent identities | https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-use-entra-agent-identities |
| S27 | Microsoft Agent 365 overview | https://learn.microsoft.com/en-us/microsoft-agent-365/overview |
| S28 | Agent 365 agent registry | https://learn.microsoft.com/en-us/microsoft-agent-365/builder/agent-registry |
| S29 | Agent 365 observability | https://learn.microsoft.com/en-us/microsoft-agent-365/builder/observability |
| S30 | Copilot credit consumption API (CAT blog) | https://microsoft.github.io/mcscatblog/posts/copilot-credit-consumption-api/ |
| S31 | Manage usage of the GitHub Copilot harness | https://learn.microsoft.com/en-us/power-platform/admin/manage-usage-github-copilot-harness |
| S32 | Govern credit consumption | https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/govern-credit-consumption |
| S33 | Copilot Studio ALM guidance | https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/alm |
| S34 | Training: Implement ALM for agents | https://learn.microsoft.com/en-us/training/modules/implement-alm-agents-power-platform/ |
| S35 | Pipelines in Power Platform | https://learn.microsoft.com/en-us/power-platform/alm/pipelines |
| S36 | Delegated deployments | https://learn.microsoft.com/en-us/power-platform/alm/delegated-deployments-setup |
| S37 | Extend pipelines | https://learn.microsoft.com/en-us/power-platform/alm/extend-pipelines |
| S38 | Dataverse Git integration FAQ | https://learn.microsoft.com/en-us/power-platform/alm/git-integration/faqs |
| S39 | GitHub Actions with OIDC / federated credentials | https://learn.microsoft.com/en-us/power-platform/alm/tutorials/github-actions-oidc-fic |
| S40 | Power Platform Build Tools for Azure DevOps | https://learn.microsoft.com/en-us/power-platform/alm/devops-build-tools |
| S41 | GitHub Actions for Power Platform — releases | https://github.com/microsoft/powerplatform-actions/releases |
| S42 | Copilot ALM Starter | https://github.com/microsoft/copilot-alm-starter |
| S43 | Data policies for Copilot Studio | https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-data-loss-prevention |
| S44 | Environment-group rules | https://learn.microsoft.com/en-us/power-platform/admin/environment-groups-rules |
| S45 | Microsoft Purview for Copilot Studio | https://learn.microsoft.com/en-us/purview/ai-copilot-studio |
| S46 | External security provider (threat detection) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/external-security-provider |
| S47 | Defender real-time protection for AI agents | https://learn.microsoft.com/en-us/defender-xdr/security-for-ai/ai-agent-real-time-protection |
| S48 | Automatic security scan | https://learn.microsoft.com/en-us/microsoft-copilot-studio/security-scan |
| S49 | Security and governance guidance, phase 3 | https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/sec-gov-phase3 |
| S50 | Environment-level agent telemetry (Application Insights) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/advanced-environment-level-agent-telemetry |
| S51 | Analytics overview (GitHub Copilot harness) | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/analytics-overview |
| S52 | Review activity and feedback | https://learn.microsoft.com/en-us/microsoft-copilot-studio/agents-experience/authoring-review-activity |
| S53 | Monitor Copilot Studio in the Power Platform admin center | https://learn.microsoft.com/en-us/power-platform/admin/monitoring/monitor-copilot-studio |
| S54 | Evaluation triage and remediation | https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/evaluation-triage-overview |
| S55 | Agent Review Pipeline | https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/kit-agent-review-pipeline |
| S56 | Copilot Agent Kit (formerly Copilot Studio Kit) | https://github.com/microsoft/Power-CAT-Copilot-Studio-Kit |
| S57 | Performance testing guidance | https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/conversational-agents-performance-testing |
| S57b | Performance testing reference sample | https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/conversational-agents-reference-sample |
| S58 | Register external agents in Foundry | https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/register-external-agent |
| S59 | AI Red Teaming Agent | https://learn.microsoft.com/en-us/azure/foundry/how-to/develop/run-scans-ai-red-teaming-agent |
| S60 | Agent evaluation GitHub Action (Foundry) | https://learn.microsoft.com/en-us/azure/foundry/how-to/evaluation-github-action |
| S61 | Copilot Studio plugin (mcs-assistant) | https://github.com/microsoft/copilot-studio-plugin |
| S62 | New Harness, New Rules? CAT's Got You (CAT blog) | https://microsoft.github.io/mcscatblog/posts/new-orchestrator-resources/ |
| S63 | Copilot Studio technical guide and samples | https://github.com/microsoft/new-copilot-studio-tech-guide |
| S64 | CAT Agent Skills gallery | https://microsoft.github.io/cat-agent-skills/ |
| S65 | Skills for Copilot Studio | https://github.com/microsoft/skills-for-copilot-studio |
| S66 | Dataverse MCP server with VS Code | https://learn.microsoft.com/en-us/power-apps/maker/data-platform/data-platform-mcp-vscode |
| S67 | Microsoft Learn MCP server | https://github.com/microsoftdocs/mcp |
| S68 | Azure MCP Server | https://github.com/microsoft/mcp |
| S69 | Azure DevOps remote MCP server GA (Azure DevOps blog) | https://devblogs.microsoft.com/devops/azure-devops-remote-mcp-server-ga/ |
| S70 | Work IQ CLI and MCP | https://github.com/microsoft/work-iq |
| S71 | GitHub Copilot customization cheat sheet | https://docs.github.com/en/copilot/reference/customization-cheat-sheet |
| S72 | GitHub Copilot agent skills | https://docs.github.com/en/copilot/concepts/customizations/agent-skills |
| S73 | GitHub Copilot hooks | https://docs.github.com/en/copilot/concepts/agents/hooks |
| S74 | GitHub Copilot plugins | https://docs.github.com/copilot/concepts/agents/about-plugins |
| S75 | Plugin standards for enterprises | https://docs.github.com/en/copilot/concepts/enterprise/plugin-standards |
| S76 | Agentic audit-log events | https://docs.github.com/en/copilot/reference/enterprise-administrators/agentic-audit-log-events |
| S77 | GitHub Copilot CLI is generally available (changelog) | https://github.blog/changelog/2026-02-25-github-copilot-cli-is-now-generally-available/ |
| S78 | Delegate tasks from Copilot CLI | https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/delegate-tasks-to-cca |
| S79 | Dynamic workflows in Copilot CLI and the Copilot app (changelog) | https://github.blog/changelog/2026-10-01-dynamic-workflows-in-copilot-cli-and-the-copilot-app/ |
| S80 | Copilot SDK is generally available (changelog) | https://github.blog/changelog/2026-06-02-copilot-sdk-is-now-generally-available/ |
| S81 | Customize the cloud agent environment | https://docs.github.com/copilot/how-tos/use-copilot-agents/coding-agent/customize-the-agent-environment |
| S82 | Extend the cloud agent with MCP | https://docs.github.com/copilot/how-tos/use-copilot-agents/coding-agent/extend-coding-agent-with-mcp |
| S83 | Copilot code review | https://docs.github.com/copilot/concepts/agents/code-review |
| S84 | Copilot code reviews for Azure Repos (public preview) | https://devblogs.microsoft.com/devops/copilot-code-reviews-for-azure-repos-public-preview/ |
| S85 | Copilot Autofix for code scanning | https://docs.github.com/code-security/concepts/code-scanning/copilot-autofix-for-code-scanning |
| S86 | Excluding content from GitHub Copilot | https://docs.github.com/copilot/managing-copilot/configuring-and-auditing-content-exclusion/excluding-content-from-github-copilot |
| S87 | Superpowers releases | https://github.com/obra/superpowers/releases |
| S88 | Superpowers marketplace | https://github.com/obra/superpowers-marketplace |
| S89 | Build production-ready agents with the GitHub Copilot harness and Agent Framework | https://devblogs.microsoft.com/agent-framework/build-production-ready-agents-with-the-github-copilot-harness-and-agent-framework/ |
| S90 | Microsoft 365 Agents Toolkit CLI | https://learn.microsoft.com/en-us/microsoftteams/platform/toolkit/microsoft-365-agents-toolkit-cli |
| S91 | GitHub Advanced Security for Azure DevOps | https://learn.microsoft.com/en-us/azure/devops/repos/security/configure-github-advanced-security-features?view=azure-devops |
| S92 | Workload identity federation for Azure Pipelines | https://learn.microsoft.com/en-us/azure/devops/pipelines/release/configure-workload-identity |
| S93 | FlightCheck (ESS Agent Developer Kit) | https://learn.microsoft.com/en-us/microsoft-365/copilot/employee-self-service/flightcheck-standalone |
| S94 | Employee Self-Service deployment and ALM (golden prompts) | https://learn.microsoft.com/en-us/microsoft-365/copilot/employee-self-service/deploy-overview-alm |
| S95 | What's new in Copilot Studio | https://learn.microsoft.com/en-us/microsoft-copilot-studio/whats-new |
| S96 | GitHub rulesets | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository |
| S97 | awesome-copilot: power-platform-architect plugin | https://awesome-copilot.github.com/plugin/power-platform-architect/ |
| S98 | microsoft/skills | https://github.com/microsoft/skills |
| S99 | Fabric MCP servers | https://learn.microsoft.com/en-us/rest/api/fabric/articles/mcp-servers/fabric-mcp-servers-list |
