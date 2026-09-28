# SharePoint setup — separating Knowledge Base from Document Processing

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-09-25 |
| **Author** | DAAI and HR Operations |
| **Status** | Draft |
| **Scope** | Separation of SharePoint knowledge and HR document-processing sites |
| **References** | [Document intake architecture](document-intake-architecture.md), [ADR-0007](../../../../docs/adr/0007-dataverse-process-state-boundary.md) |

IT owns provisioning and Security/Privacy own the controls. This proposal corrects the over-applied "no personal data in metadata" rule in [Document intake architecture §5](document-intake-architecture.md). Acceptance would require a newly allocated ADR number; ADR-0008 is already assigned to another decision.

---

## 1. The correction

An earlier draft carried this rule:

> ~~"No personal data in any folder name, file name or column."~~

**That rule is wrong as stated, and applying it would make document processing impossible.** It took [ADR-0007](../../../../docs/adr/0007-dataverse-process-state-boundary.md) — which is about *Dataverse process state* — and generalised it to all SharePoint content. Those are different problems.

The real distinction is not *where the data sits*. It is **what the library is for**:

| Purpose | Personal data | Must be discoverable by Copilot |
|---|---|---|
| **Knowledge Base** — grounding for agents | **Never. Not in content, not in metadata** | **Yes** — that is its entire function |
| **Document Processing** — employee documents | **Required.** A Personalblatt without personal data is a blank form | **Never** |

These two purposes have **opposite requirements on both axes**. That is precisely why they cannot share a container, and why separating them is an architectural decision rather than a naming convention.

---

## 2. The failure mode this prevents

State it plainly, because it is the reason the whole design exists:

> An employee asks the HR Policy Chat Assistant: *"What is the notice period for a permanent contract?"*
>
> The agent grounds on SharePoint. If a processing library is in its grounding scope, the retrieval can return **Tobias Ochsner's Personalblatt** — his AHV number, his address, his salary account — because it contains the words "contract" and "permanent".
>
> The agent then quotes it. To a colleague. In Teams.

Nothing was hacked. Permissions were not bypassed. Somebody simply pointed an agent at a site that contained both policy documents and employee records, and Copilot did exactly what it was built to do.

**This is the single highest-consequence mistake available in an HR agent deployment**, and it is a configuration error, not an attack.

---

## 3. Two sites, not two libraries

```text
┌─ SITE 1 ──────────────────────────────────────────────────────────┐
│  GF HR Knowledge          /sites/gf-hr-knowledge                  │
│                                                                   │
│  PURPOSE   Grounding source for Copilot agents                    │
│  CONTENT   Policies, guides, FAQ, process descriptions            │
│  PII       NONE — content or metadata. Enforced, not requested    │
│  INDEXED   YES. RCD off. This site is meant to be found           │
│  WRITES    Humans only. UC-0020 proposes; a named human publishes │
│                                                                   │
│  Libraries:  Policies · Guides · FAQ · Drafts (not indexed)       │
└───────────────────────────────────────────────────────────────────┘
                              ▲
                              │  approved knowledge only
                              │  (UC-0020, propose-only)
                              │
┌─ SITE 2 ──────────────────────────────────────────────────────────┐
│  GF HR Document Operations   /sites/gf-hr-docops                  │
│                                                                   │
│  PURPOSE   Intake and processing of employee documents            │
│  CONTENT   Personalblatt, Anmeldung, contracts, certificates      │
│  PII       REQUIRED in content. Minimised in metadata (§6)        │
│  INDEXED   NO. NoCrawl + RCD + sensitivity label + DLP (§4)       │
│  WRITES    Channels in, agent processes, HR Ops resolves          │
│                                                                   │
│  Libraries:  Intake · Processing · Archive · Exceptions           │
└───────────────────────────────────────────────────────────────────┘
```

### Why separate sites rather than separate libraries in one site

| Reason | Detail |
|---|---|
| **The strongest controls are site-scoped** | Restricted Content Discovery applies to **sites**, not libraries. The control you most want is unavailable at library level |
| **A blast radius you can reason about** | One site is grounding material and one is never grounding material. "Which libraries in this site are safe to index?" is a question nobody should have to answer under time pressure |
| **Permissions stay simple** | Different populations, different lifecycles, no broken inheritance gymnastics |
| **Retention is opposite** | Knowledge is reviewed and refreshed; documents are retained to a statutory clock and then destroyed |
| **It survives a mistake** | Someone will eventually point an agent at a site. Make the wrong site impossible to reach rather than merely inadvisable |

---

## 4. Enforcing the boundary — four independent controls

**No single control here is a security boundary.** Microsoft says so explicitly about Restricted Content Discovery: it *"doesn't change existing permissions"* and users retain direct access to content they already have. So the design layers four controls that fail differently.

| # | Control | Scope | What it does | Honest limitation |
|---|---|---|---|---|
| **1** | **Permissions** | Site + library | **The only actual security boundary** | Nothing else substitutes for getting this right |
| **2** | **`NoCrawl`** | Site **or library** | Removes content from the search index. Copilot depends on enterprise search, so un-indexed content cannot be grounded on | Also removes it from ordinary SharePoint search — users cannot find documents by searching. **For a processing library that is a feature, not a cost** |
| **3** | **Restricted Content Discovery** | **Site only** | Removes content from Copilot responses and org-wide search; **removes AI entry points** — no Copilot button, no "Create an agent" on that site | Microsoft positions it as a **temporary** governance control, and it **does not remove content from the index**. Requires SharePoint Advanced Management + a Copilot licence |
| **4** | **Sensitivity label + DLP for Microsoft 365 Copilot** | Content | A Purview DLP policy with Copilot as the location, conditioned on the label, set to restrict Copilot from processing the file. **Travels with the file** | Requires Purview configuration and label adoption |

### The recommended stack for the processing site

Apply **all four**. They are cheap relative to the failure in §2.

1. **Permissions** — agent identity and HR Operations only. No tenant-wide groups, ever
2. **`NoCrawl` on every processing library** — the deterministic control. `Set-PnPList -Identity "Intake" -NoCrawl`
3. **RCD on the site** — removes the "Create an agent" button, which is the specific action that turns a document library into a grounding source by accident
4. **Sensitivity label `HR-Personal-Data`** applied at library level, with a DLP policy restricting Copilot processing

> **Control 3 is doing quiet but important work.** RCD removes the AI entry points from the site — including *Create an agent*. Most oversharing incidents are not malicious; they are a helpful person building an agent over a library they legitimately have access to. Removing the button removes the temptation.

> **A retirement to know about:** Restricted SharePoint Search — the 100-site allow-list approach — is **retiring, with new enablement blocked from 31 July 2026**. Microsoft directs organisations to RCD instead. Do not build on RSS.

### And for the knowledge site — the opposite

| Setting | Value |
|---|---|
| `NoCrawl` | **Off.** It must be indexed |
| RCD | **Off.** It must be discoverable |
| Sensitivity label | `HR-Knowledge-Internal` — not Copilot-restricted |
| Grounding scope | **Explicitly named** in each agent's knowledge configuration |

**Agents name their grounding source explicitly.** Never "all of SharePoint", never a hub, never a broad search scope. An agent's knowledge configuration lists the specific libraries it may use — which means adding a new source is a reviewed change rather than an emergent one.

---

## 5. The Knowledge Base site in detail

```text
/sites/gf-hr-knowledge
├── Policies/          approved HR policy — the primary grounding source
├── Guides/            how-to content for employees and managers
├── FAQ/               question/answer pairs derived from resolved cases
└── Drafts/            ← NoCrawl ON. Not yet approved, must not ground
```

**`Drafts/` is the one library on this site that is not indexed.** The UC-0020 Knowledge Curation candidate proposes candidates into it; a named human reviews, approves and moves the item into `Policies/`, `Guides/` or `FAQ/`. **The move into an indexed library is the act of publishing** — which is exactly the propose-only control UC-0020 requires, expressed as architecture rather than as a promise.

### Metadata

| Column | Purpose |
|---|---|
| `gf_Jurisdiction` | **Mandatory.** CH · DE · AT · IT · FR · ES · Global. No default |
| `gf_ContentOwner` | Named human. Content without an owner is content nobody trusts |
| `gf_ReviewDate` | Unreviewed items expire out of grounding scope |
| `gf_ApprovedBy` · `gf_ApprovedOn` | The audit trail for publication |
| `gf_IntentTags` | Links to the intent taxonomy in the closed-loop model |

### The PII rule that does apply here — absolutely

> **No personal data on this site. Not in a document, not in an example, not in a screenshot, not in a column.**
>
> This is where the original rule belongs, and here it is not negotiable: **everything on this site is, by design, retrievable by an agent and quotable to whoever asks.**
>
> The trap is the well-meant worked example. *"For instance, Tobias Ochsner's parental leave was calculated as…"* in a guide is now permanently answerable by an agent, to anyone, forever. **Worked examples use obviously fictional names**, and the knowledge review checks for this specifically.

---

## 6. The processing site — what the metadata rule actually is

Content carries personal data. That is the point. The remaining question is metadata, and the honest answer is **minimise, do not prohibit**:

| Approach | Metadata | Trade-off |
|---|---|---|
| **A — reference only** *(recommended default)* | `gf_PackageRef`, `gf_RunRef`, channel, jurisdiction, type, hash | Clean. Requires the control plane app for human work, because SharePoint alone shows only references |
| **B — minimal identifying** *(Exceptions library only)* | Adds `gf_EmployeeDisplay` — surname and initial, snapshot at intake | HR Operations can work the queue directly in SharePoint. More exposure |

**Recommendation: A everywhere, B permitted on `Exceptions/` only** — that is the one library where a human works items directly and needs to know whose document they are resolving without opening each file.

Two conditions on B:

1. **It is a snapshot, never authoritative.** The name in metadata is what the document said at intake. It drifts the moment someone marries. **Workday is the system of record** ([ADR-0005](../../../../docs/adr/0005-workday-as-system-of-record.md)); the control plane resolves names live. Metadata is a label to help a human find a row, not a source of truth.
2. **Surname + initial, not full identity.** `Ochsner, T.` is enough to work a queue. Date of birth, AHV number, address and IBAN never appear in metadata under any option — they are in the document, where permissions and labels protect them.

> **Why this is safe here and was not safe as a blanket rule:** the processing site is `NoCrawl`'d, RCD-enabled and DLP-protected. Its metadata is not indexed tenant-wide and not reachable by an agent. The knowledge site, which *is* reachable, carries no personal data at all.
>
> **The control is the site boundary, not the column.**

---

## 7. The one-way flow between them

```text
  Processing site  ──────╳──────►  Knowledge site        NEVER directly
  (personal data)                  (no personal data)

  Resolved cases  ──►  UC-0020  ──►  Drafts/  ──►  human  ──►  Policies/
                       patterns       PII gate      approves     indexed
                       not transcripts
```

Three rules govern the only permitted path:

1. **Derived from resolution *patterns*, never case transcripts or documents.** A transcript is one person's specifics; a pattern across twelve cases is not
2. **A PII gate runs before a human sees the draft** — not as a reviewer instruction. A reviewer who has seen personal data has already been exposed to it
3. **No automated copy, sync or move from the processing site to the knowledge site.** Ever. If someone proposes a flow that does this, it is a design error

---

## 8. Provisioning checklist

**Knowledge site**
- [ ] Create `/sites/gf-hr-knowledge` (communication site)
- [ ] Libraries: `Policies`, `Guides`, `FAQ`, `Drafts`
- [ ] **`NoCrawl` ON for `Drafts` only**; off elsewhere
- [ ] RCD **off** — this site must be discoverable
- [ ] Site columns: jurisdiction, owner, review date, approver, intent tags
- [ ] Sensitivity label `HR-Knowledge-Internal`
- [ ] **PII review before any content is added**, worked examples included

**Processing site**
- [ ] Create `/sites/gf-hr-docops`
- [ ] Libraries: `Intake`, `Processing`, `Archive`, `Exceptions`
- [ ] **`NoCrawl` ON for all four**
- [ ] **RCD ON** for the site — removes the *Create an agent* entry point
- [ ] Sensitivity label `HR-Personal-Data` at library level
- [ ] **DLP policy: Copilot location, restrict processing of that label**
- [ ] Permissions: agent identity + HR Operations, scoped by jurisdiction. **No tenant-wide groups**
- [ ] Retention labels per jurisdiction

**Verification — prove it, do not assume it**
- [ ] Place a file with a unique nonsense phrase in `Archive`. Ask Copilot about that phrase from an account with site access. **It must not be returned**
- [ ] Repeat for `Intake`, `Processing`, `Exceptions`
- [ ] Confirm the *Create an agent* action is absent on the processing site
- [ ] Confirm the same phrase in `Policies/` **is** returned — the knowledge path must work
- [ ] Re-run after any site, label or DLP change

> **That first test is the one that matters**, and it is the one most often skipped. Run it before the first real document arrives, and again whenever the configuration changes. Indexing changes take time to propagate — allow hours, not minutes, before concluding the control works.

---

## 9. What this changes in the existing documents

| Document | Change |
|---|---|
| [`document-intake-architecture.md`](document-intake-architecture.md) §5 | The blanket "no personal data in metadata" rule is replaced by §6 above |
| UC-0020 | The `Drafts/` → indexed-library move **is** the propose-only control, now architectural |
| [UC-0002](../uc-0002-hr-policy-chat-assistant.md) | Grounding scope names the knowledge libraries explicitly — never a hub or a broad scope |
| [Solution Design §4.5](../../../../docs/solution-design.md) | SharePoint Advanced Management is a **licensing prerequisite** for RCD, alongside the Copilot licence |

---

## 10. Open decisions

| ID | Question | Owner |
|---|---|---|
| **KB-01** | Is **SharePoint Advanced Management** licensed? RCD requires it. If not, controls 1, 2 and 4 must carry the load | IT |
| **KB-02** | Option A or B metadata on `Exceptions/` — does HR Operations work the queue in the control plane app, or directly in SharePoint? | HR Operations |
| **KB-03** | Knowledge source of truth — this site or the Workday Help KB? **Still open from the closed-loop analysis.** Maintaining both guarantees drift | HRIS / DAAI |
| **KB-04** | Does a second jurisdiction get its own knowledge site, or jurisdiction-scoped libraries within one? | HR Operations / Legal |
| **KB-05** | Who runs the §8 verification test, and on what cadence after go-live? | Security |

---

## 11. Proposed ADR-0008

If GF accepts this, it is a decision worth recording rather than a configuration note:

> **ADR-0008 — Knowledge and personal-data content are separated at site level**
>
> HR knowledge used for agent grounding and HR documents containing personal data live in **separate SharePoint sites** with opposite discovery settings. The knowledge site is indexed and carries no personal data in any form. The processing site carries personal data in content, is excluded from indexing and Copilot grounding by four independent controls, and is never a grounding source for any agent. The only permitted path between them is human-approved knowledge curation over resolution patterns.

---

## 12. The short version

The earlier rule conflated two different problems. **Knowledge content must be discoverable and must contain no personal data. Processing content must contain personal data and must never be discoverable.** Opposite requirements, therefore separate sites — enforced by permissions, `NoCrawl`, Restricted Content Discovery and a Purview DLP policy, because none of those is a security boundary on its own.

And the test worth running before anything else: **put a nonsense phrase in the archive and ask Copilot about it.** If it comes back, nothing else in this document matters yet.
