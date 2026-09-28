# Workflows

| Field | Value |
|---|---|
| **Version** | 2.0 |
| **Date** | 2026-09-28 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active (consolidated from current state) |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../../docs/specs/2026-09-17-architecture-baseline-intake-design.md) |


This folder contains the repository's single GitHub Actions validation workflow.

Use descriptive YAML file names, grant least-privilege permissions, pin third-party actions to reviewed versions, and document required secrets without committing their values.

## Repository Validation

[validate-repository.yml](validate-repository.yml) runs for pull requests, pushes to `main`, and manual `workflow_dispatch` requests. Its `validate` job uses `windows-2025` with a 15-minute timeout.

The workflow grants only global `contents: read`. It requests no write or identity-token permission, consumes no secrets, and pins its only third-party action to the reviewed SHA in [action-pins.json](../../infra/src/config/github/action-pins.json). Pester is installed at exact version 5.7.1.

The job performs these checks in order:

1. Checks out the complete Git history with `fetch-depth: 0`.
2. Runs every maintained `.github/cli/tests`, infrastructure, and HR Pester test.
3. Runs the repository safety validator against the real checkout.
4. Builds every maintained Bicep file without deploying resources.
5. Resolves the branch merge base and runs `git diff --check` across the complete branch change.

The workflow performs validation only. It does not authenticate to live services or mutate tenant, Azure, Power Platform, or GitHub state.
