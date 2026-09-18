# Phase 1 Governance and GitHub Intake Review

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../specs/2026-09-17-architecture-baseline-intake-design.md), [Source Inventory](./2026-09-17-architecture-baseline-source-inventory.json) |

## Review Boundary

This review covers exactly the first 15 entries in the checked-in source inventory, from `.github/CODEOWNERS` through root `README.md`. A live SHA-256 comparison normalized each calculated hash to lowercase and confirmed `ALL_15_MATCH=True` before this review was written.

The dispositions distinguish evidence available at the Task 5 checkpoint:

- **Completed in Task 5** means the reviewed target transformation is present in the Task 5 working tree and remains subject to the Task 5 commit gate.
- **Completed earlier as governed semantic merge** means an earlier reviewed task preserved the repository baseline and added only compatible current guidance. It does not mean the broader source file was copied.
- **Scheduled for Task 6** means the source is pinned but no Task 6 target change is claimed here.
- **Deferred to its owning later phase** means the source content belongs to a later reviewed intake boundary and has not been applied.

Task 5 creates `.github/agent-policy/BREAK_GLASS.md` directly from the approved design and implementation plan. It has no source-package row and is therefore not added to the 15-row inventory table.

## Collision Rule

The repository baseline wins every collision. The collision paths `.github/copilot-instructions.md`, `AGENTS.md`, `.gitignore`, `.github/agents/README.md`, `.github/ISSUE_TEMPLATE/config.yml` (the issue chooser), and root `README.md` use reviewed semantic merge and are never overwritten.

Only `Add` and `Merge` appear below because those are the classifications required for this Phase 1 intake slice. `Add` creates a validated target that does not currently carry a governed target contract. `Merge` preserves the existing target and applies only compatible, reviewed meaning.

## Validation Commands

The table refers to these command-level checkpoints:

- **Source hash:** calculate `(Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()` and compare it case-sensitively with the exact checked-in inventory value.
- **Metadata:** `Invoke-Pester .github/cli/tests/DocumentationMetadata.Tests.ps1 -Output Detailed` under isolated Pester 5.7.1.
- **Docs agent:** `Invoke-Pester .github/cli/tests/DocsAgentContract.Tests.ps1 -Output Detailed` under isolated Pester 5.7.1.
- **Task 5 links:** run the read-only Markdown link-resolution check across the eight owned Task 5 paths, including links in tables.
- **Repository validator:** `powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1`.
- **Task 5 whitespace:** `git diff --check --` followed by the eight explicit Task 5 pathspecs.
- **Task 6 contracts:** run the issue-form, documentation-link, repository-validator, and scoped diff checks defined by Task 6 after those tests and targets are created.

## Phase 1 Inventory Disposition

| Source path | Source SHA-256 | Target path | Classification | Applied transformation | Validation checkpoint | Disposition |
|---|---|---|---|---|---|---|
| `.github/CODEOWNERS` | `f34231d50fb8514af02c30704247c2623f31d3d5db9f827cded5656883429df6` | `.github/CODEOWNERS` | Add | Adapt ownership only to targets that exist in this phase or a scheduled later phase; retain the reviewed default owner. No target is added by Task 5. | Source hash confirmed; Task 6 contracts are scheduled. | Scheduled for Task 6 |
| `.github/ISSUE_TEMPLATE/config.yml` | `6913de0ee9863fce0c24df504fb706a88c38b090617a3071fe207fd8f9ec6cbb` | `.github/ISSUE_TEMPLATE/config.yml` | Merge | Preserve `blank_issues_enabled: false` and semantically add only reviewed contact links. Never overwrite the existing issue chooser. No target change is applied by Task 5. | Source hash confirmed; Task 6 issue-form and link contracts are scheduled. | Scheduled for Task 6 |
| `.github/ISSUE_TEMPLATE/intake.yml` | `d2b5eb7227c3040f65e9787c7575ca27fcd8546750a2b4ccc8977b4cdd81d06e` | `.github/ISSUE_TEMPLATE/03-frontier-intake.yml` | Add | Rename the source form to the ordered active target, retain the prohibition on personal and special-category data, and add it without replacing the existing bug and feature forms. No target is added by Task 5. | Source hash confirmed; Task 6 raw-byte, issue-form, and link contracts are scheduled. | Scheduled for Task 6 |
| `.github/agent-policy/AGENT_WORKFLOW.md` | `a09a2530ea93166cb7f4b79c3ee6403ab3811e9369dd9003a4c642336890685b` | `.github/agent-policy/AGENT_WORKFLOW.md` | Add | Preserve the lifecycle, gates, evidence, escalation, and rollback meaning; add standard Proposed Baseline metadata; repair links; state future Azure Boards, pipeline, agent, and cloud-control behavior as proposed rather than active. | Source hash confirmed; Metadata, Task 5 links, repository validator, and Task 5 whitespace apply. | Completed in Task 5 |
| `.github/agent-policy/KPI_BASELINE.md` | `e88d86d810e99af8fcd6c20c7b5e00df56f9619da161f86e7dd20364a710d92a` | `.github/agent-policy/KPI_BASELINE.md` | Add | Preserve metric definitions and absolute governance targets; add standard Proposed Baseline metadata; make collection sources provisional; prohibit personal evaluation, personal data, secrets, skipped validation, and unsupported autonomy. | Source hash confirmed; Metadata, Task 5 links, repository validator, and Task 5 whitespace apply. | Completed in Task 5 |
| `.github/agent-policy/NON_DELEGABLE_WORK.md` | `5095e9b6693b8b8853af0372ccafe7ffcc7037176c10ccc6e43753e90d610481` | `.github/agent-policy/NON_DELEGABLE_WORK.md` | Add | Preserve absolute employment, tenant, identity, production, destructive, publication, governance, and communication boundaries; add standard Proposed Baseline metadata; remove unverified administrator and control-state claims. | Source hash confirmed; Metadata, Task 5 links, repository validator, and Task 5 whitespace apply. | Completed in Task 5 |
| `.github/agents/README.md` | `11aecc7ae08aef9e4cb38112cd176cd6366c00b80172dd4b86fecdb002ff9bf9` | `.github/agents/README.md` | Merge | Preserve current valid metadata and the one-role-per-file contract; add only the three agents that exist after Task 5; do not import the source roster of absent agents or runtime products. | Source hash confirmed; Metadata, Docs agent, Task 5 links, repository validator, and Task 5 whitespace apply. | Completed in Task 5 |
| `.github/agents/cloud-solution-architect.agent.md` | `560dc12f27d11f6874b15229cc58f715546311650af9ba1bc6f305c94370a077` | `.github/agents/cloud-solution-architect.agent.md` | Add | Add the exact approved VS Code frontmatter and standard Proposed Baseline metadata; preserve useful framework facts and assessment guidance; limit behavior to read-only advice and current artifacts. | Source hash confirmed; Metadata, agent diagnostics, Task 5 links, repository validator, and Task 5 whitespace apply. | Completed in Task 5 |
| `.github/agents/ux-designer.agent.md` | `3563f94a163414cb913459fd11acbb4f78c7c0d25ce769e52807083655a53ca1` | `.github/agents/ux-designer.agent.md` | Add | Add the exact approved VS Code frontmatter and standard Proposed Baseline metadata; preserve useful Fluent, accessibility, content, and conversation guidance; restrict edits to approved repository-owned design documentation. | Source hash confirmed; Metadata, agent diagnostics, Task 5 links, repository validator, and Task 5 whitespace apply. | Completed in Task 5 |
| `.github/copilot-instructions.md` | `7c7e60f3c09c2d62c8964f8d95808cc67603976aea0b33ac88047b9e6e265a30` | `.github/copilot-instructions.md` | Merge | Preserve repository Superpowers activation and add the current documentation-policy anchor. Broad source assumptions about absent agents, product areas, pipelines, work items, and cloud controls were not imported. | Source hash confirmed; the earlier Docs agent contract and repository validator cover the governed merge. | Completed earlier as governed semantic merge |
| `.github/dependabot.yml` | `883b95e3be554fbadd92b315e4a8c6ea6ca688b64924e22dd61222b07f683507` | `.github/dependabot.yml` | Add | Retain the reviewed GitHub Actions ecosystem and weekly cadence after a Task 6 source-hash check. No target is added by Task 5. | Source hash confirmed; Task 6 contracts are scheduled. | Scheduled for Task 6 |
| `.github/pull_request_template.md` | `4fe405603ae22e1ef7b1f38fa5d98485ac831b57ef6943f4e320913d9e100b19` | `.github/pull_request_template.md` | Add | Add standard metadata and preserve scope, governance, validation evidence, documentation, impact, and review sections while aligning data rules with the approved specification. No target is added by Task 5. | Source hash confirmed; Task 6 documentation-link and repository-validator contracts are scheduled. | Scheduled for Task 6 |
| `.gitignore` | `c42519142b36d54a524c8b21808edfdb36b687a7f0f39ea25700b00a29bc74f5` | `.gitignore` | Merge | Preserve `.wt/` and all governed target exclusions; semantically add only still-applicable source exclusions. Never overwrite the target. No target change is applied by Task 5. | Source hash confirmed; Task 6 scoped diff and repository-validator contracts are scheduled. | Scheduled for Task 6 |
| `AGENTS.md` | `defb5c714379940cd7137e7a375da9142fa1a265ebb072fd6fb0c4c91fb1415a` | `AGENTS.md` | Merge | Preserve the repository Superpowers workflow and add only the current documentation-policy ownership anchor. Source claims about absent roles, systems, pipelines, and product surfaces were not imported. | Source hash confirmed; the earlier Docs agent contract and repository validator cover the governed merge. | Completed earlier as governed semantic merge |
| `README.md` | `5035ac2b1c59ce776de359ac9592483bf0b9e20572dd1bee8a5aae2638ab8605` | `README.md` | Merge | Preserve the current repository workflow, verification, version, license, and update guidance. The source product and architecture map remains unapplied until its owning content phase can add it with resolving targets. Never overwrite the root guide. | Source hash confirmed; the later owning phase must run metadata, link, validator, and scoped diff checks. | Deferred to its owning later phase |

## Checkpoint Truthfulness

Task 5 imports the three reviewed policy sources, two custom-agent sources, and a governed semantic merge of the existing agent catalogue. It also adds the specification-derived break-glass contract and this review.

Task 6 collaboration controls are not applied or validated by Task 5. The source pins for `.github/CODEOWNERS`, the issue chooser, Frontier intake form, Dependabot, pull request template, and `.gitignore` are recorded here only so Task 6 can recheck and transform them within its own commit boundary.

The source product and architecture content in root `README.md` remains deferred. Its later merge must preserve the current repository workflow and may link only to targets that exist at that checkpoint.
