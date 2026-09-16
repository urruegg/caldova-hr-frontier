# Repository Superpowers Integration Design

## Objective

Bundle Superpowers directly in this repository so every contributor can use the same pinned workflows with GitHub Copilot in VS Code and GitHub Copilot CLI after cloning the repository. The setup must not depend on a contributor's machine-level plugin installation.

## Scope

- Vendor the Superpowers v6.3.0 runtime skills from `obra/superpowers`.
- Use GitHub Copilot's native project-skill discovery path.
- Add repository-level bootstrap instructions for VS Code and Copilot CLI.
- Record the upstream source, release, and MIT license attribution.
- Create the approved `.github` and `docs` base folders.
- Add a `README.md` to every approved base folder describing its purpose and expected content.
- Document deliberate upgrade and verification procedures.

The requested folder README requirement applies to the approved base folders listed below. Vendored Superpowers skill directories remain unchanged from upstream and retain their own `SKILL.md` and referenced resources.

## Repository Structure

```text
.
|-- AGENTS.md
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
|   |-- issue-templates/
|   |   `-- README.md
|   |-- skills/
|   |   |-- README.md
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

The design intentionally excludes `.github/ISSUE_TEMPLATE/` and `docs/storyboard/`. The lowercase `.github/issue-templates/` folder is a project content area, not GitHub's active issue-template directory; its README will state that distinction.

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

The root `README.md` will explain that Superpowers is bundled, identify the pinned version, describe automatic discovery in VS Code and Copilot CLI, show how to confirm skill availability, and link to the source and license.

## Attribution and Integrity

The existing repository license remains unchanged. The upstream Superpowers MIT license is stored as `.github/skills/LICENSE.superpowers`, and source/version metadata is stored alongside it.

Vendored skill content is not rewritten for project preferences. Repository-specific behavior belongs in `AGENTS.md`, `.github/copilot-instructions.md`, or separate project-owned skills so future upstream comparisons remain reviewable.

## Validation

Implementation is complete when all of these checks pass:

1. Every approved base folder exists and contains a non-empty `README.md`.
2. The two explicitly excluded folders do not exist.
3. Every vendored skill has a `SKILL.md` whose `name` matches its parent directory.
4. Files referenced by vendored `SKILL.md` documents exist in the copied runtime.
5. `using-superpowers` is discoverable under `.github/skills/`.
6. `AGENTS.md` and `.github/copilot-instructions.md` point Copilot to the project skills and do not require a machine-level installation.
7. Version metadata identifies v6.3.0 and its exact upstream commit.
8. The upstream MIT license text is present.
9. Git reports no malformed patches or whitespace errors.
10. VS Code customization diagnostics show the repository skills without metadata errors; Copilot CLI lists or invokes `using-superpowers` from the repository checkout.

The first nine checks are repository-automated or command-line verifiable. The final check is an integration smoke test in the two target Copilot hosts.

## Non-Goals

- Supporting agent hosts other than GitHub Copilot in VS Code and Copilot CLI.
- Bundling upstream tests, evaluation harnesses, marketplace manifests, or agent-specific plugin hooks.
- Installing or modifying contributor-level configuration.
- Automatically downloading code during normal repository use.
- Creating product source code or application architecture as part of this setup.
