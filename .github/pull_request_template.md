## What changed

<!-- One or two sentences. What is different after this merge? -->

## Why

<!-- Link the decision, requirement or open item this serves: ADR-nnnn, FR-nnnn, D-nn, UC-nnnn -->

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

## If this touches a use case

- [ ] The seven declarations are still answerable (`docs/hr-journey-and-raci.md` §9)
- [ ] Status fields are accurate — *idea*, *in MVP scope*, *specified* mean different things
