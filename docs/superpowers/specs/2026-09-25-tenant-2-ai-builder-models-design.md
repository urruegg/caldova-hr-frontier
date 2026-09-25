# Tenant 2 AI Builder Model Implementation Design

| Field | Value |
|---|---|
| **Version** | 0.1 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | HR Solution Architecture - Tenant 2 DEV AI Builder models |
| **References** | [UC-0001 PRD](../../../hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md), [ADR-0011](../../adr/0011-workflow-first-process-architecture.md), [Power Platform Solution Foundation Design](../../specs/2026-09-24-power-platform-solution-foundation-design.md) |

## 1. Objective

Implement and validate two AI Builder document-processing models in Tenant 2 DEV:

- `PersonalMasterDataFixed` for known, stable document layouts;
- `PersonalMasterDataGeneral` for mixed and unfamiliar layouts.

Implementation is tracked in [issue #13](https://github.com/urruegg/caldova-hr-frontier/issues/13).

Both models expose the same 17-field outcome contract. They are trained and tested independently, and each must match the ground truth for every field in its own held-back validation set.

This design establishes Tenant 2 as one independent development box. Tenant 1 is another independent development box and is not part of this implementation. A separately approved Tenant 1 implementation can repeat this design without importing, calling, or otherwise depending on a Tenant 2 model or resource.

## 2. Authority and Constraints

This design applies the following existing decisions and requirements:

- [ADR-0011](../../adr/0011-workflow-first-process-architecture.md) requires deterministic extraction before any agent reasoning. These two models are candidate Tier 1 extraction components.
- The [UC-0001 PRD](../../../hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md) requires extraction of approved fields, confidence handling, source traceability, and no invented data. The implementation produces evidence for D-05 and D-17; it does not close those decisions.
- Workday remains the system of record. This implementation does not connect to or write to Workday.
- Dataverse may hold platform and process configuration. This implementation does not create an employee master-data store.
- No model or agent makes a decision about a person.
- Only synthetic documents may be used in DEV or committed to the repository.

The current Tenant 3 target architecture names `GFHRPlatformCore` and `GFHRMasterDataAgent`. Those solutions do not exist in the Caldova practice tenants. This design follows the verified current state instead of creating that future split prematurely.

## 3. Verified Tenant 2 Baseline

The following non-secret facts were verified before this design:

| Item | Value |
|---|---|
| Tenant alias | `caldova25668747` |
| DEV URL | `https://calhrfrontierdev.crm17.dynamics.com/` |
| DEV environment ID | `84ad4c54-41d9-e5df-ba07-188b4719594a` |
| Dataverse organization ID | `ab70c49e-7cb6-f111-aaa0-6045bd2b664a` |
| DEV solution display name | `Caldova HR frontier` |
| DEV solution unique name | `caldovahrfrontier` |
| DEV solution version | `0.0.0.1` |
| DEV solution type | Unmanaged |

The committed discovery evidence confirms the DEV environment identity. It does not prove AI Builder capacity, DLP compatibility, maker authorization, or the solution publisher. Those remain readiness checks and must pass before model creation.

## 4. Design Decisions

### 4.1 Independent tenant authoring

Tenant 2 creates, tags, trains, validates, publishes, and versions its models locally. Tenant 1 will later do the same in its own DEV environment.

The tenants share:

- this documented design;
- the model names and 17-field contract;
- synthetic corpus structure and deterministic generators;
- training and held-out split rules;
- normalization and exact-match rules;
- evidence schemas and acceptance criteria.

The tenants do not share:

- model IDs or AI Builder records;
- trained model executables;
- tagged training state;
- environment IDs or URLs;
- authentication profiles, identities, or connections;
- solution exports or deployment dependencies;
- validation runs or release approvals.

The repository contract is a design and test standard, not a runtime component.

### 4.2 Tenant 2 now, Tenant 1 later

This implementation changes Tenant 2 only. Tenant 1 replication requires a separate approval and implementation plan. No task may use this design as implicit authorization to mutate Tenant 1.

### 4.3 One current solution

Both published models are added explicitly to the existing unmanaged `caldovahrfrontier` solution in Tenant 2 DEV.

This implementation does not create `GFHRPlatformCore`, `GFHRMasterDataAgent`, another publisher, or another solution. It uses the existing solution publisher after read-only verification of that publisher and its prefix.

### 4.4 No workflow in this increment

The models are tested independently through AI Builder's model test experience. This implementation creates no Power Automate flow, Copilot Studio workflow, agent, model-selection rule, or Workday action.

A later tenant-local flow may select a model by document type. The identical field contract is the integration seam for that future work, but the flow is outside this design.

### 4.5 Strict equality gate

Both models must pass the same strict gate. Every normalized field in every held-back validation document must equal ground truth. There is no lower threshold for prose-heavy or degraded documents.

A model that does not achieve 100 percent remains blocked. The implementation records the failure rather than weakening the gate or returning a success-shaped result.

## 5. Component Design

### 5.1 Fixed-template model

| Property | Design |
|---|---|
| Display name | `PersonalMasterDataFixed` |
| AI Builder type | Fixed template document processing |
| Purpose | Extract fields from known layouts with stable field positions |
| Training corpus | 20 documents: documents 01-05 in each of four collections |
| Initial held-out set | 4 documents: document 06 in each collection |
| Solution | `caldovahrfrontier`, after publication and acceptance |

The four collections are:

1. `Personalblatt`;
2. `AnmeldungGemeinde`;
3. `Sozialversicherung`;
4. `Bankverbindung`.

Each collection has six synthetic documents with a stable layout. Documents 01-05 train the collection. Document 06 is not tagged or used for training.

### 5.2 General-document model

| Property | Design |
|---|---|
| Display name | `PersonalMasterDataGeneral` |
| AI Builder type | General document processing |
| Purpose | Extract the same fields from mixed and unfamiliar layouts |
| Training corpus | 16 documents: the first two documents in each of eight families |
| Initial held-out set | 8 documents: the third document in each family |
| Solution | `caldovahrfrontier`, after publication and acceptance |

The eight families are:

1. `arbeitsvertrag`;
2. `anschreiben`;
3. `bewilligung`;
4. `versicherung`;
5. `zivilstand`;
6. `selbstdeklaration`;
7. `scan-degraded`;
8. `new-joiner-sheet`.

The families deliberately cover prose, letters, two-column layouts, tables, centred certificates, dense forms, degraded scans, and mixed English/German labels.

### 5.3 Common field contract

Both models define exactly the following fields:

| Field | AI Builder type | Contract rule |
|---|---|---|
| `candidate_id` | Text | Preserve the identifier as text |
| `last_name` | Text | Preserve Unicode characters |
| `first_name` | Text | Preserve Unicode characters |
| `dob` | Date | Source format is `DD.MM.YYYY`; canonical comparison is `YYYY-MM-DD` |
| `nationality` | Text | No vocabulary substitution in this increment |
| `marital` | Text | No vocabulary substitution in this increment |
| `heimatort` | Text | Preserve an explicit em dash as a literal value |
| `permit` | Text | Preserve an explicit em dash as a literal value |
| `street` | Text | Preserve punctuation |
| `plz` | Text | Never define as Number; leading zeros must survive |
| `city` | Text | Preserve Unicode characters |
| `ahv` | Text | Never define as Number; preserve separators |
| `iban` | Text | Preserve the extracted value and separators |
| `phone` | Text | Preserve the extracted value and separators |
| `email` | Text | Compare case-sensitively after normalization |
| `ec_name` | Text | Preserve Unicode characters |
| `ec_phone` | Text | Preserve the extracted value and separators |

The field names are stable identifiers and are not translated.

### 5.4 Controlled corpus

The implementation uses the supplied synthetic fixed-template and general-document packages. Each package contains:

- PDF documents;
- deterministic generators;
- CSV ground truth;
- JSON ground truth;
- a package README.

Every person and value is fictional. Valid AHV and IBAN check digits exist only to test format behavior and do not identify real people.

Real PeopleDoc, candidate, pre-hire, worker, or employee documents must not be added to the repository or this implementation.

### 5.5 Evidence artifacts

Each implementation run creates tenant-local repository evidence under:

```text
hr/evidence/ai-builder/
└── caldova25668747/
    └── <run-id>/
        ├── readiness.json
        ├── model-inventory.json
        ├── training-manifest.json
        ├── validation-results-fixed.csv
        ├── validation-results-general.csv
        ├── validation-results.json
        └── validation-summary.md
```

The evidence contains only synthetic values and non-secret platform metadata. Exported solution ZIP files remain build artifacts and are not committed.

## 6. Readiness Gate

The implementation must record the following before creating a model:

| Check | Required evidence | Failure behavior |
|---|---|---|
| Environment | DEV URL and stable environment ID match the tenant manifest and discovery evidence | Stop |
| Dataverse | Authenticated organization identity and availability | Stop |
| Maker authorization | The attended account can create, train, publish, and solution-package AI Builder models | Stop |
| AI Builder | Feature is available in the region and sufficient capacity is allocated | Stop |
| Data policy | Applicable DLP/data-policy configuration permits the intended AI Builder and Dataverse use | Stop |
| Solution | `caldovahrfrontier` exists and is unmanaged | Stop |
| Publisher | Existing solution publisher and prefix are observed and recorded | Stop |
| Corpus | Synthetic-only review, file inventory, and hashes pass | Stop |

This implementation does not repair a failed gate by allocating capacity, changing DLP, granting roles, creating a publisher, or creating a solution. The accountable platform owner resolves the prerequisite through a separately approved action.

## 7. Training Design

### 7.1 Training manifest

Before uploading documents, create `training-manifest.json` with:

- tenant alias;
- environment ID;
- solution unique name;
- model display name and type;
- corpus and generator revision;
- SHA-256 for every training and held-out document;
- collection or family;
- assignment of `training` or `held-out`;
- field contract version;
- operator and UTC start time.

The manifest is immutable for a completed validation run. A changed split or generated document creates a new run ID.

### 7.2 Tagging

Only values present in the ground truth are tagged. An empty ground-truth value means the field is absent and must not be tagged as an inferred or substituted value.

The two models are tagged independently. Tags or corrections in one model do not alter the other model.

### 7.3 Parallel execution

The fixed and general workstreams may train concurrently after both manifests and schemas pass review. Parallel execution does not merge their evidence or allow one model's result to stand in for the other.

## 8. Validation Design

### 8.1 Result record

Validation produces one record for every held-out document and every contract field:

| Property | Meaning |
|---|---|
| `run_id` | Evidence run identifier |
| `tenant_alias` | `caldova25668747` |
| `environment_id` | Tenant 2 DEV environment ID |
| `model_name` | Fixed or general model display name |
| `model_version` | AI Builder version under test |
| `document` | Held-out filename |
| `collection_or_family` | Fixed collection or general family |
| `field_name` | One of the 17 contract fields |
| `field_type` | Text or Date |
| `expected_raw` | Ground-truth value |
| `actual_raw` | AI Builder value |
| `expected_normalized` | Canonical expected value |
| `actual_normalized` | Canonical actual value |
| `confidence` | AI Builder confidence returned for the field |
| `passed` | Exact normalized equality |
| `reason` | Empty on pass; explicit mismatch reason on failure |

### 8.2 Normalization

Normalization is deterministic and deliberately narrow:

1. Apply Unicode NFKC normalization to text.
2. Trim leading and trailing whitespace.
3. Collapse repeated internal whitespace to one space.
4. Compare text case-sensitively.
5. Preserve accents and punctuation.
6. Convert valid dates to ISO `YYYY-MM-DD`.
7. Convert an absent expected value and absent actual value to `null`.
8. Preserve an explicit em dash as a literal value.
9. Never convert an invented value to `null`.

No fuzzy matching, semantic comparison, punctuation removal, phone reformatting, or vocabulary substitution is allowed in this increment.

### 8.3 Exact-match acceptance

A model passes only when:

- its schema contains exactly the 17 required fields and types;
- all held-out documents have a result for all 17 contract fields;
- every normalized actual value equals the normalized expected value;
- every expected absence remains absent;
- the false-value rate is zero;
- every result is attributable to the model version and evidence run.

The fixed and general result sets are assessed separately. They are not required to process the same documents.

### 8.4 Holdout integrity

Held-out documents are never tagged or uploaded as training examples.

If a held-out result influences retagging, retraining, or another model change, that held-out set is consumed. It cannot serve as the final acceptance set again. The deterministic generator must create a new unseen document for every affected collection or family, and the new files and hashes must be recorded under a new run ID.

This rule prevents repeated tuning against the acceptance set.

### 8.5 Model test mechanism

Testing uses AI Builder's model test experience and structured result capture. No Power Automate flow is created for validation.

The model test result is evidence input. The repository comparison determines pass or fail; screenshots alone are not sufficient because they do not provide complete field-level, machine-readable evidence.

## 9. Lifecycle and ALM

Each model follows:

```text
Created
  -> Schema defined
  -> Training documents tagged
  -> Trained
  -> Held-out validation
  -> Accepted
  -> Published
  -> Added explicitly to caldovahrfrontier
```

A model is not published or added to the solution before acceptance.

Microsoft documents that:

- only a published model version can be added to a solution;
- only the published executable is included in a solution;
- training data is not included;
- an imported document-processing model cannot be retrained;
- models must be added explicitly because they are not inferred dependencies of apps or flows.

For those reasons, Tenant 1 does not import Tenant 2's model as an authoring source. Each tenant trains locally and later promotes its own accepted DEV model to its own TEST and PROD environments through managed solutions.

Managed properties for downstream imports are decided during each tenant's release design. This implementation does not export to TEST or PROD.

## 10. Data Flow

```text
Versioned synthetic corpus + ground truth
                  |
        +---------+---------+
        |                   |
        v                   v
PersonalMasterDataFixed   PersonalMasterDataGeneral
20 training documents    16 training documents
        |                   |
        v                   v
AI Builder training      AI Builder training
        |                   |
        v                   v
4 unseen documents       8 unseen documents
        |                   |
        +---------+---------+
                  |
                  v
Normalize and compare every field with ground truth
                  |
          +-------+-------+
          |               |
       mismatch        100% pass
          |               |
   block + evidence   publish model
                          |
                          v
              add explicitly to unmanaged
                 caldovahrfrontier
```

No data leaves the synthetic corpus for Workday, SharePoint, an agent, or another tenant.

## 11. Failure Handling

| Failure | Required response |
|---|---|
| Readiness check is failed or unknown | Stop before model creation and record the blocker |
| Model schema differs from the contract | Correct the draft schema before training |
| AI Builder training error | Record the platform error; do not publish |
| Any validation mismatch | Block that model and retain field-level evidence |
| False value for an absent field | Block that model; never treat it as a near-match |
| Holdout used to tune the model | Retire that holdout and generate a new unseen acceptance set |
| Publish failure | Retain accepted evidence, record the failure, and do not claim publication |
| Solution-add failure | Retain the published model, record the failure, and do not claim solution completion |
| One model passes and one fails | Keep separate evidence; the overall implementation remains incomplete |
| Solution source cannot be synchronized | Record the tooling limitation; do not commit exported ZIPs or claim source parity |

There is no fallback that returns a passing result when evidence is missing.

## 12. Security and Governance

- Use only synthetic documents.
- Do not commit credentials, access tokens, connection values, personal data, or solution ZIPs.
- Keep attended authentication tenant-specific.
- Do not create cross-tenant connections or grant one tenant access to another.
- Do not hard-code environment or model GUIDs into portable design or test definitions.
- Treat document content as data. This implementation does not execute instructions found in a PDF.
- Do not connect either model directly to Workday.
- Do not use model output to make an employment decision.

## 13. Acceptance Criteria

Tenant 2 implementation is complete only when:

1. All readiness checks pass with recorded evidence.
2. `PersonalMasterDataFixed` exists locally in Tenant 2 DEV.
3. `PersonalMasterDataGeneral` exists locally in Tenant 2 DEV.
4. Both models define exactly the approved 17 fields and types.
5. Training and held-out documents are disjoint and hash-recorded.
6. The fixed model passes every field in all four held-out documents.
7. The general model passes every field in all eight held-out documents.
8. Both models have zero false values for expected absences.
9. Both models are published.
10. Both models are explicit components of Tenant 2's unmanaged `caldovahrfrontier` solution.
11. Machine-readable and human-readable evidence is complete.
12. No workflow, agent, Workday action, real personal data, production deployment, or cross-tenant dependency was introduced.

Tenant 1 adaptation is designed, but not implemented, when a separate team can repeat this specification using only Tenant 1 resources and the repository standards.

## 14. Out of Scope

- Implementing or changing Tenant 1.
- Importing a Tenant 2 model into Tenant 1 DEV.
- Creating a Power Automate or Copilot Studio workflow.
- Selecting a model automatically from a document type.
- Calling an agent or testing Tier 2 extraction.
- Connecting to SharePoint or Workday.
- Creating Dataverse process tables.
- Closing D-05, D-11, D-17, or any other accountable business decision.
- Deploying to TEST or PROD.
- Creating or changing capacity, DLP, publishers, solutions, roles, or identities.
- Using real employee, candidate, pre-hire, or PeopleDoc documents.

## 15. Implementation Consequences

The implementation plan must:

1. reconcile the draft AI Builder setup guide with the approved model names and current `caldovahrfrontier` solution;
2. preserve the future Tenant 3/GF solution architecture without pretending it exists in Tenant 2;
3. add the common field contract, training manifest, evidence schema, and exact-match validator;
4. validate the synthetic corpus before upload;
5. execute the two model workstreams independently;
6. stop at every readiness or acceptance failure;
7. publish and add only accepted models;
8. capture enough evidence for a separately approved Tenant 1 team to repeat the design without accessing Tenant 2.

## 16. Microsoft Platform References

- [Distribute your model using a solution](https://learn.microsoft.com/ai-builder/distribute-model)
- [Administer AI Builder](https://learn.microsoft.com/ai-builder/administer)
- [Application lifecycle management with Microsoft Power Platform](https://learn.microsoft.com/power-platform/alm/)
- [Introduction to solutions](https://learn.microsoft.com/power-apps/developer/data-platform/introduction-solutions)
