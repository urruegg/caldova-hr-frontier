# Pull Request

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-24 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Repository |
| **References** | [HR Solution Functional Design Intake](../docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md) |

<!-- markdownlint-configure-file { "MD060": false } -->

## What changed

<!-- One or two sentences. What is different after this merge? -->

## Why

<!-- Link the decision, requirement or open item this serves: ADR-nnnn, FR-nnnn, D-nn, UC-nnnn -->

## Work item

AB#

## Environments affected

The DEV, TEST, and PROD checkboxes describe Power Platform ALM impact, not Azure infrastructure environments.

- [ ] DEV
- [ ] TEST
- [ ] PROD

---

## Checks

- [ ] **No Accepted ADR is contradicted.** If one is, this PR supersedes it with a new ADR rather than editing it
- [ ] **No platform requirement is weakened.** A use case may add to `docs/prd.md`, never subtract
- [ ] **Reasoning is not placed where a rule would do** (FR-0013)
- [ ] **No write path bypasses the Workday Access Layer**, and no component is given the Workday connector directly (FR-0006, FR-0007)
- [ ] **No employee master data is placed outside Workday** — apply the ADR-0007 test: *if Workday were restored from backup, would this be wrong?*
- [ ] **No real personal data** is added anywhere in this repository
- [ ] **Open decisions stay open.** Nothing marked TBD has been resolved by inference
- [ ] Identifiers cited rather than prose; new numbers allocated, never reused
- [ ] Links resolve
- [ ] No secrets, credentials, access tokens, personal HR data, or unreviewed tenant values introduced
- [ ] Deployment order respected: infrastructure before HR
- [ ] Build, lint, test, and Solution Checker run for affected areas; evidence pasted below rather than claimed
- [ ] Advisory baseline audit is green, or reviewer acceptance and rationale are recorded

```text
Paste command output here.
```

## If this touches a use case

- [ ] The seven declarations are still answerable (`docs/hr-journey-and-raci.md` §9)
- [ ] Status fields are accurate — *idea*, *in MVP scope*, *specified* mean different things
