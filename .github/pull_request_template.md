# Pull Request

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-17 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [Approved Architecture Baseline Intake Design](../docs/specs/2026-09-17-architecture-baseline-intake-design.md), [Phase 1 Governance and GitHub Intake Review](../docs/reviews/2026-09-17-phase-1-governance-github-intake.md) |

<!-- markdownlint-configure-file { "MD060": false } -->

## Work item

AB#

## Journey stage

<!-- Hire | Onboard | Enable | Change | Offboard | Cross-cutting -->

## MVP or Horizon 2

<!-- MVP use case 1/2/3, or H2-x. If H2, say why it is being built now. -->

## What changed

## Environments affected

The DEV, TEST, and PROD checkboxes describe Power Platform ALM impact, not Azure infrastructure environments.

- [ ] DEV
- [ ] TEST
- [ ] PROD

---

## Completion contract

Do not mark ready for review unless every box is ticked.

### Scope

- [ ] Limited to the approved work item scope and allowed folders
- [ ] Unrelated file edits excluded or explicitly approved

### Governance

- [ ] No secrets, credentials, access tokens, personal HR data, or unreviewed tenant values introduced
- [ ] Any committed tenant identifier or service URL is approved non-secret metadata covered by the tenant manifest and evidence policy
- [ ] Data classification of added content stated: `public` / `internal` / `personal` / `sensitive`
- [ ] Agent instruction, knowledge source, or escalation changes carry governance evidence

### Validation evidence

Paste real command output, not a claim.

- [ ] Build, lint, test, and Solution Checker run for affected areas
- [ ] TDD evidence (RED to GREEN), or the acceptance-check equivalent for low-code artifacts

### Documentation

- [ ] Affected documentation updated in this pull request, or a stated reason why not

### Impact

- [ ] Solution portability: connection references, environment variables, dependencies
- [ ] Deployment order respected: infrastructure before HR
- [ ] Governance impact stated (`none` is a valid answer; state it explicitly)

### Review handoff

- [ ] Residual risks and open questions listed
- [ ] What should be reviewed first, in one line

## Evidence

```text
Paste command output here.
```

## Review first

<!-- One line. -->