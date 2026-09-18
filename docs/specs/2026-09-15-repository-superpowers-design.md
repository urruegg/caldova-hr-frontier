# Repository Superpowers Integration Design

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | docs/specs |
| **References** | [Approved Architecture Baseline Intake Design](2026-09-17-architecture-baseline-intake-design.md) |


## Objective

Bundle Superpowers directly in this repository so every contributor can use the same pinned workflows with GitHub Copilot in VS Code and GitHub Copilot CLI after cloning the repository. The setup must not depend on a contributor's machine-level plugin installation.

## Scope

- Vendor the Superpowers v6.3.0 runtime skills from `obra/superpowers`.
- Use GitHub Copilot's native project-skill discovery path.
- Add repository-level bootstrap instructions for VS Code and Copilot CLI.
- Record the upstream source, release, and MIT license attribution.
- Create the approved `.github` and `docs` base folders.
- Add a `README.md` to every approved base folder describing its purpose and expected content.
- Add active GitHub issue forms for reproducible bugs and outcome-focused feature requests, with blank issues disabled.
- Preserve the active issue forms as portable, raw-byte contracts across Git EOL settings.
- Document deliberate upgrade and verification procedures.

The requested folder README requirement applies to the approved base folders listed below. Vendored Superpowers skill directories remain unchanged from upstream and retain the exact pinned runtime snapshot, including each `SKILL.md` and its supporting files.

## Repository Structure

```text
.
|-- AGENTS.md
|-- .gitattributes
|-- .github/
|   |-- copilot-instructions.md
|   |-- agent-policy/
|   |   `-- README.md
|   |-- agents/
|   |   `-- README.md
|   |-- cli/
|   |   `-- README.md
|   |-- instructions/
|   |   `-- README.md
|   |-- ISSUE_TEMPLATE/
|   |   |-- 01-bug.yml
|   |   |-- 02-feature.yml
|   |   `-- config.yml
|   |-- issue-templates/
|   |   `-- README.md
|   |-- skills/
|   |   |-- README.md
|   |   |-- SUPERPOWERS_SHA256SUMS
|   |   |-- SUPERPOWERS_VERSION
|   |   |-- LICENSE.superpowers
|   |   `-- <vendored Superpowers skill directories>
|   `-- workflows/
|       `-- README.md
`-- docs/
    |-- adr/
    |   `-- README.md
    |-- archive/
    |   `-- README.md
    |-- brandkit/
    |   `-- README.md
    |-- business/
    |   `-- README.md
    |-- delegation/
    |   `-- README.md
    |-- ideas/
    |   `-- README.md
    |-- issues/
    |   `-- README.md
    |-- plans/
    |   `-- README.md
    |-- reviews/
    |   `-- README.md
    |-- specs/
    |   |-- README.md
    |   `-- 2026-09-15-repository-superpowers-design.md
    |-- sprints/
    |   `-- README.md
    `-- templates/
        `-- README.md
```

The uppercase `.github/ISSUE_TEMPLATE/` directory contains the GitHub-active issue forms and chooser configuration. Those three active files use exact case-sensitive Git paths and are ordinary stage-0 mode `100644` index entries; filesystem checks alone are not authoritative on case-insensitive platforms. The lowercase `.github/issue-templates/` folder remains a project-owned content area for drafts, shared wording, planning material, and promotion guidance. Root `.gitattributes` contains exactly one `/.gitattributes -text` rule and exactly one `/.github/ISSUE_TEMPLATE/*.yml -text` rule. Git therefore reports effective `text: unset` for `.gitattributes` and all three forms and does not convert their pinned raw bytes. The only explicitly excluded folder is `docs/storyboard/`.

## Copilot Integration

Superpowers skill directories will be copied unchanged into `.github/skills/`. This is a native project-skill location supported by GitHub Copilot in VS Code and GitHub Copilot CLI.

`AGENTS.md` will establish the repository-wide workflow: Copilot must check for relevant skills before responding or acting and must follow an applicable skill. `.github/copilot-instructions.md` will reinforce the same bootstrap for VS Code without duplicating the complete skill content.

The `using-superpowers` skill remains the entry point. Other skills are loaded on demand through their `name` and `description` frontmatter.

## Versioning and Updates

The bundled runtime is pinned to upstream release v6.3.0. `SUPERPOWERS_VERSION` will record:

- upstream repository URL;
- release tag and semantic version;
- exact upstream commit SHA;
- vendoring date;
- the set of copied runtime paths.

Updates are deliberate. A maintainer reviews a newer upstream release, replaces the vendored runtime as one changeset, updates the metadata and license if needed, and reruns validation. The repository does not track upstream `main`, use a submodule, or update automatically.

## Documentation

Each approved base folder gets a concise `README.md` covering:

- the folder's purpose;
- content that belongs there;
- content that does not belong there where ambiguity is likely;
- naming or lifecycle guidance relevant to that folder.

Active issue forms live in `.github/ISSUE_TEMPLATE/`. Supporting source material remains in `.github/issue-templates/`, where changes can be reviewed before promotion to the active forms and corresponding validator contract.

The public bug form warns contributors not to include secrets, personal data, or vulnerability details. The repository has no verified private reporting channel, so no private route is invented and `config.yml` intentionally omits security contact links. A security contact link can be added only after a verified private reporting channel exists.

The root `README.md` will explain that Superpowers is bundled, identify the pinned version, describe automatic discovery in VS Code and Copilot CLI, show how to confirm skill availability, and link to the source and license.

## Attribution and Integrity

The existing repository license remains unchanged. The upstream Superpowers MIT license is stored as `.github/skills/LICENSE.superpowers`, and source/version metadata is stored alongside it.

Vendored skill content is not rewritten for project preferences. Repository-specific behavior belongs in `AGENTS.md`, `.github/copilot-instructions.md`, or separate project-owned skills so future upstream comparisons remain reviewable.

`SUPERPOWERS_SHA256SUMS` is itself pinned by raw SHA-256 digest `be8b1626ea290a4cc0a99ccf0e4878fcf8c5ca7d238094be3d23b59563d28f1c` at exact-case stage-0 mode `100644`. Its 51 ordinally sorted entries define both the allowed runtime paths and their hashes. The validator reconciles that manifest with the forced working-file inventory and the complete Git index classification beneath `.github/skills/`, rather than trusting a count or a filesystem-only view.

Integrity is a coherent-snapshot property. The manifest plus all 51 runtime paths must match their raw working-tree and index object IDs (`52/52`), while `.gitattributes` plus the three active issue forms must do the same (`4/4`). The runtime modes are fixed at 44 files with mode `100644` and seven with mode `100755`. The complete upstream license is pinned by SHA-256 digest `a37e0e9697144819e1d965176ac4ae5bc3fa02d11e7812036bbcadf6dafe2400`, and `SUPERPOWERS_VERSION` must match its exact ordered metadata contract.

## Validation

The shipped integration remains valid only while all of these checks pass:

1. The 19 approved base folders exist with non-empty `README.md` files, and `docs/storyboard/` is absent.
2. `.github/skills/` contains exactly the 14 expected skill directories and 51 forced, recursively enumerated runtime files. Every skill has valid frontmatter whose `name` matches its directory.
3. `SUPERPOWERS_SHA256SUMS` has raw digest `be8b1626ea290a4cc0a99ccf0e4878fcf8c5ca7d238094be3d23b59563d28f1c`; its exact ordinal path set and per-file hashes match the working runtime.
4. The complete Git index classification beneath `.github/skills/` rejects unknown or case-variant skill paths, extra paths under expected skills, unexpected root files, and conflict stages. Outside the skill directories, only exact root files `README.md`, `LICENSE.superpowers`, `SUPERPOWERS_SHA256SUMS`, and `SUPERPOWERS_VERSION` are permitted.
5. The manifest is exact-case stage-0 mode `100644`; the 51 runtime entries are exact-case stage-0 records split into 44 mode-`100644` and seven mode-`100755` files. Raw index and working-tree object IDs match for all 52 protected manifest/runtime paths.
6. Hidden entries and reparse points cannot bypass runtime enumeration. The full license hash and exact ordered `SUPERPOWERS_VERSION` metadata remain pinned.
7. `.github/ISSUE_TEMPLATE/` contains exactly the ordinary files `01-bug.yml`, `02-feature.yml`, and `config.yml`, with exact uppercase Git casing and one stage-0 mode `100644` record each. Their raw SHA-256 hashes are respectively `8f2c31b169477b86d85e60f9d1c91eed349fae829f1071b8b42dc93624d8879a`, `748e69155e9e60acd16f5cbb93b6398fd5853905951829080a9c440ed5c0e7a4`, and `1f103c6a9dd07cd13a9a6f17ace6b813f47747eb9cb7e00488cb2073caaf91bb`.
8. The pinned form bytes encode the approved GitHub schema, required duplicate/reproduction/outcome fields, `blank_issues_enabled: false`, public-data warning, and intentional omission of labels, assignees, and unverified security contact links. VS Code reports no YAML or issue-form schema diagnostics.
9. `.gitattributes` is an ordinary exact-case stage-0 mode `100644` file containing exactly one `/.gitattributes -text` and exactly one `/.github/ISSUE_TEMPLATE/*.yml -text`; `git check-attr text` returns exactly one effective `unset` result for it and each form.
10. The filesystem and exact Git path sets for the forms contain no extras, case variants, conflict stages, or reparse points. Raw index and working-tree object IDs match for all four protected attribute/form paths.
11. `AGENTS.md` and `.github/copilot-instructions.md` point Copilot to the project skills without requiring a machine-level installation, and `using-superpowers` remains part of the exact runtime snapshot.
12. Git reports no malformed patches or whitespace errors in the aggregate branch diff from its merge base with `main`.
13. Clean temporary checkouts with both `core.autocrlf=true` and `core.autocrlf=false` retain the two exact attribute rules, effective `text: unset`, pinned hashes, coherent index/working snapshots, exact sole validator success line, and clean status.
14. Copilot CLI lists exactly the 14 expected enabled project skills with repository provenance and loads `using-superpowers` when explicitly requested in a prompt containing `/using-superpowers`, while the VS Code **Skills** view manually confirms the same repository provenance without metadata diagnostics.

The repository structure, issue-form contract, integrity, and Git checks are automated or command-line verifiable. The final host-discovery check is an integration smoke test in the two target Copilot hosts.

## Non-Goals

- Supporting agent hosts other than GitHub Copilot in VS Code and Copilot CLI.
- Bundling upstream tests, evaluation harnesses, marketplace manifests, or agent-specific plugin hooks.
- Installing or modifying contributor-level configuration.
- Automatically downloading code during normal repository use.
- Creating product source code or application architecture as part of this setup.
