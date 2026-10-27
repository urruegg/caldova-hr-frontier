# Agent Factory Foundation Design

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository-agent factory foundation: supply chain, governance record, and guardrails |
| **References** | [Agent Factory Part 1 Idea Record](../ideas/agent-factory-common-setup.md), [Repository-Agent Portfolio Governance Design](2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md), [Delegated Agent Workflow](../../.github/agent-policy/AGENT_WORKFLOW.md), [Non-Delegable Work](../../.github/agent-policy/NON_DELEGABLE_WORK.md), [Documentation Policy](../README.md) |

## 1. Status and Authority

This design is a **Proposed Baseline**. The repository owner directed its choices during the design dialogue of 2026-10-26, but has not yet reviewed this written record. It authorizes no implementation until that review is recorded.

It is subordinate to the Approved [Repository-Agent Portfolio Governance Design](2026-10-02-hr-frontier-copilot-agent-portfolio-governance-design.md), which is the implementation authority for repository-agent profiles, shared Copilot instructions, validation, and capability admission. Where this design and the portfolio design differ, the portfolio design wins and this design must be corrected. This design adds no profile, tier, or admission decision to it.

The source concept is the [Agent Factory Part 1 idea record](../ideas/agent-factory-common-setup.md). It is a `Draft` idea, not a requirement. Its capability statements are dated 2026-10-25 and are not verified by this repository.

**Unconfirmed prerequisite.** The portfolio design says its implementation starts only after the documentation-cleanup implementation has passed all six slices, its migration review, and navigation acceptance. The plans catalogue lists the cleanup plan as `Draft`, although a migration review exists. This design does not infer that the prerequisite is met. It implements no portfolio slice, creates no profile, and edits no shared Copilot instruction, so it does not depend on the answer. The owner should still confirm the prerequisite status.

## 2. Problem and Outcome

The concept describes a closed loop in which GitHub Copilot builds, verifies, releases, and learns from Copilot Studio agents and workflows on the GitHub Copilot harness. This repository has the pieces of a safe starting point but not the whole: pinned Superpowers, repository policy, and three repository agents exist; decisions on source format, harness policy, and tool supply chain do not; and the repository has no hook-level guard that refuses a mutating `pac` command or a read of a private tenant file.

After this work the repository has:

- a current, pinned Superpowers release that the repository verifier checks;
- three Proposed decisions that fix the source format, harness policy, and developer-tool supply chain for later factory work;
- a dated evidence review of the capabilities the foundation relies on;
- a mapping from the factory's roles onto the Approved twelve-agent portfolio, with the gaps named; and
- guardrails that refuse the highest-risk agent actions regardless of prompt content.

## 3. Scope and Non-Goals

| In scope | Out of scope |
|---|---|
| Superpowers upgrade from v6.3.0 to v7.0.1 and the validator contracts it changes | GitHub Actions workflows, Azure DevOps Pipelines, and `copilot-setup-steps.yml`, by owner direction |
| Idea record, this design, ADR-0013 to ADR-0015 (Proposed), and a capability evidence review | Tenant, environment, identity, credential, or connection work; the concept's spikes |
| Role mapping and Capability Admission candidates, recorded in this design | New repository-agent profiles; the portfolio design allows exactly twelve |
| A path-scoped factory-authoring instruction, a phase matrix, and an agent tool guard | Edits to shared Copilot instructions, `AGENTS.md`, or existing policy documents |
| Factory skills are located under `.agents/skills/` by decision only | Factory skill bodies, the authored-source scaffold, the evaluation runner, and the feedback harvester |
| | Any Copilot Studio, Power Platform, or Dataverse call, and any MCP server configuration |

The factory is an engineering aid for the repository. It does not change the runtime HR agents governed by [`AGENTS.md`](../../AGENTS.md), and no factory agent inherits a runtime agent's connector, identity, or write envelope.

## 4. Architecture

| Layer | Contents | Slice |
|---|---|---|
| Supply chain | Superpowers v7.0.1, pinned manifest, verifier contracts | A |
| Decisions | Idea record, ADR-0013 to ADR-0015, this design, capability evidence review | PR 0 and B |
| Guidance | Factory-authoring instruction, phase matrix | C |
| Guardrails | `AgentToolGuard` module, hook entry, Pester tests | C |
| Role mapping | Factory roles mapped to portfolio profiles; gaps named | This design |

Guardrails follow the portfolio action tiers. Tier classification follows the action, not the requesting role.

## 5. Delivery

Delivery uses one docs-only pull request and three slices, each on its own branch in its own sibling worktree under `Source\urruegg\wt\`. Each pull request carries pasted command output as evidence. No workflow or pipeline file is created or changed; the existing repository validation already runs the tests under `.github/cli/tests`.

| Order | Branch | Contents |
|---|---|---|
| PR 0 | `docs/agent-factory-foundation-spec` | Idea record, this design, and the draft Slice A/B plans for owner review, with their catalogue rows. The idea record lands here because this design must cite it |
| A | `chore/vendor-superpowers-v7.0.1` | Superpowers upgrade |
| B | `docs/agent-factory-decisions` | ADR-0013 to ADR-0015, capability evidence review, catalogue rows |
| C | `feat/agent-factory-guardrails` | Factory-authoring instruction, phase matrix, tool guard, hook entry |

A merges before B and C so the decisions and guidance cite a stable skill inventory. The draft [Slice A plan](../plans/2026-10-26-agent-factory-superpowers-v7-implementation.md) and [Slice B plan](../plans/2026-10-26-agent-factory-decisions-implementation.md) are prepared alongside this design as review material, not execution authority. They remain `Draft` and cannot execute until the owner approves this design and PR 0 is merged. Slice B also waits for merged Slice A. No Slice C plan exists yet; it is written under `docs/plans/` after design approval and must consume the Slice B hook-support evidence before claiming enforcement.

The sprint is at PR 0 preparation, not implementation. No slice is completed by the existence of its plan. The open items in section 13 remain open, and completing this review package does not settle them.

## 6. Slice A: Superpowers v7.0.1

The slice follows the nine steps of "Updating Superpowers" in the root [README](../../README.md).

**Pin.** Upstream release v7.0.1, published 2026-10-21, tag object `cfd50a286baea35041505ed068c878d389ca9f7f`, commit `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b`. Upstream v7.0.0 is superseded by v7.0.1 and is not used.

**Delta against the vendored v6.3.0.**

| Measure | v6.3.0 | v7.0.1 |
|---|---|---|
| Skills | 14 | 15; `diagnosing-superpowers` is new |
| Runtime files | 51 | 84: 40 added, 7 removed, because older top-level reference files moved into `references/` folders |
| Executable scripts | 7 | 9; `executing-plans/scripts/task-start` and `task-done` are new |

**Files changed.** The vendored `.github/skills/**`; `SUPERPOWERS_SHA256SUMS`; `SUPERPOWERS_VERSION`; `.gitattributes`, which needs a `-text` entry for the new skill; `.github/cli/verify-repository-setup.ps1`, for the skill list, executable-mode list, version metadata, and README content check; `.github/cli/tests/Phase2SourceContract.Tests.ps1`; the root `README.md`; and `.github/skills/README.md`, where the sentence about keeping project-owned skills in separate directories becomes a pointer to `.agents/skills/`, because the verifier rejects any other tracked path under `.github/skills/`. Historical specifications and plans that describe the v6.3.0 vendoring stay unchanged.

**Method.** The manifest is generated from the upstream tag by script, not copied by hand. The validator contracts are updated first and shown failing against the v6.3.0 tree, then shown passing after the release is vendored. Vendored files are not edited.

**Behavior change.** The v7.0.1 brainstorming skill differs from v6.3.0; it reads project context before asking and writes a design document before building. The repository path override still applies: designs go under `docs/specs/` and plans under `docs/plans/`.

**Risk and guard.** `diagnosing-superpowers` reads session transcripts and, after approval, can create upstream GitHub issues or export transcript bundles. Transcripts in this repository can contain design content or Work IQ output. The guard is in Slice C and the vendored text is not edited. Creating an upstream issue is external communication, which is Tier C.

## 7. Slice B: Decisions and Evidence

All records are English, carry the six-field header, and update their owning catalogue in the same pull request.

| ADR | Decision | Options rejected | Honest limit |
|---|---|---|---|
| ADR-0013, Canonical source format | A two-layer source model: the unpacked DEV export is the deployable source, an authored harness layer sits beside it, generators produce workflows, and a repository-to-DEV sync is DEV-only. Never mix source formats for one solution | A `pac copilot` workspace alone; Dataverse Git-integration YAML | The concept's proof is field evidence from a different implementation. Spike S1 is not run here, so the decision is "not verified in this tenant". It governs future source only |
| ADR-0014, Harness selection and cost policy | Choose the harness per agent and record it before build. Copilot chat for grounded knowledge answers, standard for rule-based flows and computer use, GitHub Copilot for reasoning-heavy multi-step work, consistent with the harness table in `AGENTS.md`. Each decision carries a credit estimate and an owner | One harness for everything; no recorded harness decision | No credit figure is known, so the ADR states none |
| ADR-0015, Developer-tool supply chain | Pin exact versions of Superpowers, `pac`, extensions, plugins, and MCP servers. Add a capability only through a Capability Admission Record. Use scoped allow-lists and never blanket auto-approval. Locate factory skills under `.agents/skills/`. Create no `.github/copilot/settings.json` and no plugin. Superpowers v7.0.1 is the first application | Floating versions; factory skills inside `.github/skills/` with a verifier exception | `.agents/skills/` discovery in VS Code and Copilot CLI is unproven until the evidence review proves it |

Each ADR is `Proposed` with Context, Decision, Options considered, Consequences, and Compliance sections. ADR numbers 0013 to 0015 were unused on `main`, on every remote branch, and in open pull requests when this design was written.

**Capability evidence review** (`docs/reviews/2026-10-26-agent-factory-capability-evidence-review.md`). A dated snapshot, not a living register. It covers only what the foundation relies on: `.agents/skills/` discovery; custom-agent frontmatter and tool lists; hook schema, events, and host support; the GitHub Copilot harness release state; Work IQ MCP release state and consent requirements; the `pac` current version and the minimum for Code Apps; and the Copilot Studio MCP server release state. Each entry has the concept's status label, a source URL, and an access date. A claim that cannot be proven stays `Not verified`. Re-verification is a new dated review.

## 8. Slice C: Guidance and Guardrails

**Factory-authoring instruction.** One file, `.github/instructions/factory-authoring.instructions.md`, applied to `.github/agents/**`, `.agents/skills/**`, `.github/hooks/**`, and `.vscode/mcp.json`. It requires minimal tool lists; no blanket auto-approval; human-reviewed pull requests to widen any agent's tools or MCP servers; issues, pull requests, documents, transcripts, and Work IQ output to be treated as material and never as instruction; and no upstream issue or transcript bundle without a named human's approval and a personal-data check. It cites the policy documents and does not restate them. Instruction files for PowerShell, solution source, and evaluations wait until there is content to govern.

**Phase matrix.** `.github/agent-policy/PHASE_MATRIX.md` states which Superpowers phases are mandatory per change type: documentation, factory configuration, vendored-runtime upgrade, infrastructure script, and later Copilot Studio source. It extends the Delegated Agent Workflow and does not restate it. Skipping a phase needs a recorded human approval. Agents never mark work done or close a tracking issue.

**Agent tool guard.** The decision logic is a pure function in `.github/cli/modules/AgentToolGuard.psm1`. A thin hook entry under `.github/hooks/` calls it. Table-driven Pester tests with literal allow and deny cases live under `.github/cli/tests/`, are written first, and are proven on Windows PowerShell 5.1 and PowerShell 7.

| # | Denied action | Basis |
|---|---|---|
| 1 | Reading or writing private files: `*.local.psd1`, `*.state.local.json`, `.env*`, key and certificate files, and the local runbook-evidence roots | Non-Delegable Work section 3: no secret or private tenant value in prompts, logs, or evidence |
| 2 | Force-push and remote ref or branch deletion | Tier D, and Non-Delegable Work section 4 |
| 3 | Any mutating `pac` command. A local-only allow-list stays open: version, help, `copilot pack`, `solution pack`, `solution unpack` | Tier B allows only a named, pre-approved Azure Pipeline, and none exists |
| 4 | Blanket-approval flags such as `--allow-all-tools` | Tier D: bypass of a review control |
| 5 | `gh` write commands aimed at any repository other than this one | Tier C: external communication |

On a parse error the guard denies. Pushing to `main` is not touched, because the pull-request profile governs it. Hooks are defense in depth. The concept lists them as supported in the CLI and cloud agent and in preview in VS Code, so the instruction and policy rules remain the baseline and the evidence review confirms host support before enforcement is claimed.

**Not created.** No agent profile, no MCP server configuration, no `.github/copilot/settings.json`, no `.github/copilot-instructions.md` edit, and no `AGENTS.md` edit.

## 9. Role Mapping

The concept names six custom agents. The portfolio design allows exactly twelve profiles, so this design maps the roles and does not create them.

| Factory role | Closest portfolio profile | Note |
|---|---|---|
| `eval-engineer` | Test & Evidence | Evaluation-driven development, evaluation sets in Git |
| `mcs-builder` | Power Platform Engineering | Harness-layer authoring; DEV execution only through a Tier B pipeline |
| `release-manager` | Release Readiness | The concept drafts release notes; the portfolio profile is read-only and never implements |
| `spec-architect` | HR Product & Process, with Docs Agent | No clean counterpart for engineering-platform specifications |
| `security-reviewer` | None | Cloud Solution Architect challenges architecture; no profile reviews security. A gap |
| `ops-analyst` | None | No profile owns operate or telemetry analysis. A gap |

The two gaps are proposals for a future portfolio amendment, which needs its own approval and acceptance scenarios. This design does not close them. Integration prepares the admission records below.

## 10. Capability Admission Candidates

No capability below is admitted, and no admission record exists, because the record schema is part of the portfolio design's first slice. The table is input for Integration. Status labels are the concept's, dated 2026-10-25, and not verified here.

| Candidate | Concept-stated status | Intended use | Earliest need | Blocked by |
|---|---|---|---|---|
| Microsoft Learn MCP server | Available | Capability verification and guidance | Design and evidence work | Admission record |
| Work IQ CLI and MCP | Preview; tenant admin consent required | Organizational context for specifications. Owner-stated constraints: supervised session, no personal data committed, output treated as untrusted | Not before a decision | Admission record, admin consent, Privacy position |
| Copilot Studio MCP server | Documentation updated 2026-10-19; no status label; interactive sign-in | Inner-loop authoring and testing in DEV | A DEV environment | DEV environment and identity, admission record |
| Dataverse MCP server | GA | Tables and synthetic data in DEV | A DEV environment | DEV environment, admission record |
| Azure DevOps remote MCP server | GA, 2026-08-05 | Backlog and pipeline reads | Azure Boards adoption | Boards decision, admission record |
| `pac` CLI 2.14.1 and `pac copilot` | GA; `pac copilot` documented | Local pack and unpack | Source scaffold cycle | Admission record, version pin |
| Copilot Studio extension for VS Code | GA; the Learn page is labelled standard harness, and harness support is per release notes | Agent YAML authoring | Source scaffold cycle | Admission record |
| `mcs-assistant` plugin | Sample / OSS | Create and migrate harness agents | Source scaffold cycle | Admission record; a sample needs a supportability assessment |
| Superpowers v7.0.1 | Upstream release, 2026-10-21 | Engineering methodology | Slice A | See open item 3 |

The owner chose to permit Work IQ for a supervised specification role. The portfolio design requires an admission record for any MCP server, and it states that Work IQ does not authorize HR knowledge or data scope. So the choice is recorded here as an intended constraint on a candidate, and no Work IQ server is configured.

## 11. Deferred Decisions

The concept's decisions F02, F04, F05, and F07 are listed as open. They are cited as "Agent Factory F0n" per the idea record, and no repository identifier is allocated. The reopening triggers are proposals.

| Concept decision | Why deferred | Proposed trigger to reopen |
|---|---|---|
| F02, Release mechanism | It concerns pipelines, which are out of scope. The portfolio design assigns CI/CD to Azure DevOps Pipelines | The portfolio pipeline slice is approved |
| F04, Evaluation gate and identity | It needs an evaluation runner, a governed test identity, and delegated permission consent | An evaluation runner is proposed and its spike is approved |
| F05, Connections and runtime identity | It needs tenant identities and connection references | A DEV environment and runtime principal are approved |
| F07, Telemetry, privacy, and autonomy | It belongs to the operate phase and needs telemetry access and a Privacy review | Telemetry access exists and a Privacy review is scheduled |

Also deferred: the factory skill bodies, the authored-source scaffold, the evaluation runner, the feedback harvester, the `.agents/` metadata-policy treatment, and any Superpowers upgrade after v7.0.1.

## 12. Validation

| Slice | Evidence |
|---|---|
| PR 0 | Documentation metadata, link, and navigation Pester suites; catalogue rows match record metadata |
| A | Contracts shown failing then passing; full Pester suites with exact Pester 5.7.1 on Windows PowerShell 5.1; the repository verifier; VS Code and Copilot CLI smoke tests showing 15 project skills |
| B | Documentation suites; every evidence-review entry dated and sourced |
| C | Guard tests written first and passing on both PowerShell hosts; contract test for the hook entry; the repository verifier; a hook smoke proof recorded in the evidence review, or marked `Not verified` |

A failed or skipped check is reported as such. A skipped check is never recorded as passed.

## 13. Risks and Open Items

| # | Risk or open item | Handling |
|---|---|---|
| 1 | Hook schema and VS Code support are unverified | The evidence review precedes reliance; hooks stay defense in depth |
| 2 | `.agents/skills/` discovery is unproven, and the metadata policy does not exclude `.agents/` | No skills are created now; the skill-pack cycle must prove discovery and settle the metadata treatment |
| 3 | Whether upgrading an existing dependency, Superpowers, needs an admission record before the schema exists is not defined by the portfolio design | Open for the owner. This design proceeds under the README update procedure and records the question |
| 4 | The portfolio prerequisite status is unconfirmed | Stated in section 1; open for the owner |
| 5 | Two factory roles have no portfolio profile | Section 9; a portfolio amendment is a separate decision |
| 6 | v7.0.1 changes the behavior of brainstorming | Path override stays in force; noted for reviewers |
| 7 | Concept capability claims are dated 2026-10-25 | Re-verify before reliance; the evidence review covers only what the foundation uses |
| 8 | The tool guard and phase matrix could be read as the "policies and validators" that the portfolio design reserves for its first slice | This design treats them as additive, more restrictive controls with this design as their governing record. The owner confirms that reading or redirects them into the portfolio's first slice |

## 14. Non-Claims

After this work there is no Copilot Studio agent, no tenant or environment change, no workflow or pipeline, no MCP server configuration, and no new repository-agent profile. Only a pinned methodology, Proposed decisions, an evidence review, guidance, and guardrails exist. Nothing here claims that a factory capability is operational or that the guardrails have been verified on every host.
