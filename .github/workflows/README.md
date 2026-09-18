# Workflows

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |


This folder contains GitHub Actions workflow definitions for continuous integration and repository automation.

Use descriptive YAML file names, grant least-privilege permissions, pin third-party actions to reviewed versions, and document required secrets without committing their values.

## Repository Validation

[validate-repository.yml](validate-repository.yml) runs for pull requests, pushes to `main`, and manual `workflow_dispatch` requests. Its `validate` job uses `windows-2025` with a 15-minute timeout.

The workflow grants only global `contents: read`. It requests no write or identity-token permission, consumes no secrets, and pins checkout to commit `11bd71901bbe5b1630ceea73d27597364c9af683`. Pester is installed at exact version 5.7.1.

The job performs these checks in order:

1. Checks out the complete Git history with `fetch-depth: 0`.
2. Runs the repository validator.
3. Runs `Invoke-Pester .github/cli/tests -Output Detailed -CI` so failed tests fail the job.
4. Runs `git diff --check origin/main...HEAD` to reject branch whitespace errors.
