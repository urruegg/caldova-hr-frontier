# caldova-hr-frontier

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](docs/specs/2026-09-17-architecture-baseline-intake-design.md) |


## Caldova HR Frontier Proposed Baseline

Caldova HR Frontier is a human-led, agent-operated HR operating-system showcase. This repository documents the desired outcome and control model as a Proposed Baseline; it is not evidence that the product, tenant configuration, Azure resources, Power Platform solutions, pipelines, agents, apps, seed data, or runtime controls have been deployed.

The proposed operating loop is:

```text
Insight -> Decision -> Delivery -> Outcome -> Learning -> Insight
```

Signals from employee experience are structured by agents, reviewed by people, planned as work, delivered through governed change, measured for outcome, and fed back into the next improvement cycle. Agents can draft, summarize, triage, and recommend, but humans remain accountable for decisions.

### Audiences and Use Cases

| Audience | Proposed baseline value |
|---|---|
| Employees and new joiners | Guided journey tasks and HR answers grounded in approved sources. |
| People managers | Visibility into team journey work and escalation paths. |
| HR practitioners | Coordinated journey operations with exceptions surfaced for human handling. |
| Engineering and platform teams | Reviewable ALM, documentation, and governance patterns for a Microsoft tenant. |

The MVP is intentionally limited to three use cases: onboarding journey orchestration, an onboarding assistant, and offboarding checklist/access-revocation handover. Hire, Enable, Change, Work IQ intake, outcome measurement, and broader agent mesh patterns remain Horizon 2 unless a later reviewed implementation proves otherwise.

### Proposed Control Plane

The Phase 2 Proposed Baseline describes intended relationships among Teams, Microsoft 365, Copilot, Work IQ, Azure DevOps, GitHub, Power Platform, and Dataverse. Those references are architecture intent only. DEV, TEST, and PROD refer to the intended Power Platform ALM stages, not to verified environments in this repository.

### Ground Rules

- No personal data is committed here; demo data must be synthetic.
- No secrets are committed here; credentials and tenant-specific values stay outside the public repository.
- agents never decide employment matters, including hiring, performance, compensation, discipline, termination, or other individual employment outcomes.
- Production changes require managed deployment, recorded approval, and reviewable evidence before claims.
- Phase 2 imported documentation only, and no Azure resources, Power Platform solutions, pipelines, seed data, or tenant controls were deployed or provisioned.

### Domain Map

| Area | Current role |
|---|---|
| `docs/` | Cross-cutting operating model, ADR candidates, reviews, specifications, and repository documentation policy. |
| `data/` | Synthetic demo data guidance; no seed JSON is present in Phase 2. |
| `hr/` | HR domain documentation and solution-source guidance; no Power Platform solution payload is present in Phase 2. |
| future `infra/` | Infrastructure detail is planned for Phase 3. No `infra/` target is linked from this Phase 2 map until that import exists. |

### Phase 2 Documentation Map

| Document | Phase 2 status |
|---|---|
| [docs/operating-model/00-north-star.md](docs/operating-model/00-north-star.md) | Proposed Baseline operating loop and north star. |
| [docs/operating-model/01-prd.md](docs/operating-model/01-prd.md) | Proposed Baseline product requirements. |
| [docs/operating-model/02-system-design.md](docs/operating-model/02-system-design.md) | Proposed Baseline system shape and integrations. |
| [docs/operating-model/03-agent-operating-model.md](docs/operating-model/03-agent-operating-model.md) | Proposed Baseline agent responsibilities and boundaries. |
| [docs/operating-model/04-hitl-governance.md](docs/operating-model/04-hitl-governance.md) | Proposed Baseline human-in-the-loop governance. |
| [docs/operating-model/05-implementation-roadmap.md](docs/operating-model/05-implementation-roadmap.md) | Proposed Baseline MVP and Horizon 2 sequencing. |
| [docs/adr/0001-azure-devops-as-engineering-control-plane.md](docs/adr/0001-azure-devops-as-engineering-control-plane.md) | Proposed Baseline candidate, not an accepted decision. |
| [docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md](docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md) | Proposed Baseline candidate, not an accepted decision. |
| [docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md](docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md) | Proposed Baseline candidate, not an accepted decision. |
| [docs/adr/0004-domain-solution-architecture-and-publisher.md](docs/adr/0004-domain-solution-architecture-and-publisher.md) | Proposed Baseline candidate, not an accepted decision. |
| [docs/90-microsoft-best-practice-evaluation.md](docs/90-microsoft-best-practice-evaluation.md) | Proposed Baseline Microsoft best-practice assessment. |
| [data/README.md](data/README.md) | Synthetic demo data guidance; no seed JSON or personal data. |
| [hr/README.md](hr/README.md) | HR domain catalogue and current no-payload boundary. |
| [hr/docs/20-hr-employee-journey.md](hr/docs/20-hr-employee-journey.md) | Proposed Baseline HR employee journey. |
| [hr/src/solutions/README.md](hr/src/solutions/README.md) | Solution-source guidance; no Power Platform solution payload. |

### Current Status and Getting Started

The repository governance and validation foundation exists: repository instructions, bundled Superpowers, documentation metadata validation, source-contract tests, and the repository verifier are present. Azure, Power Platform, Azure DevOps, agent, and product implementation remain planned or not yet verified unless a later reviewed artifact proves otherwise. Phase 2 contains documentation only, with no seed JSON, no solution payload, and no tenant deployment evidence.

Start with [docs/operating-model/00-north-star.md](docs/operating-model/00-north-star.md), then read [docs/operating-model/02-system-design.md](docs/operating-model/02-system-design.md), [docs/operating-model/04-hitl-governance.md](docs/operating-model/04-hitl-governance.md), [hr/docs/20-hr-employee-journey.md](hr/docs/20-hr-employee-journey.md), and the repository workflow below. Use [data/README.md](data/README.md) and [hr/src/solutions/README.md](hr/src/solutions/README.md) to understand the current no-data and no-payload boundaries.


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
