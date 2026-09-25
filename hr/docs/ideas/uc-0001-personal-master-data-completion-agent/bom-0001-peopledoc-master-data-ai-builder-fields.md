# PeopleDoc Master Data AI Builder Field BoM

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-09-25 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | UC-0001 AI Builder field design, implementation and verification traceability |
| **References** | [Tenant 2 AI Builder Model Implementation Design](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md), [UC-0001 PRD](prd-0001-personal-master-data-completion-agent.md) |

## 1. Purpose and Authority

This repository-owned Build of Materials (BoM) traces the 17-field AI Builder contract from design through implementation and verification. It is the authoritative record for each field's model stage, verification status and implementation evidence.

The [Tenant 2 AI Builder Model Implementation Design](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md) remains authoritative for field names, types and contract rules. This BoM does not change that contract.

This document is this package's assessment. It is not the GF-supplied `BOM_Artefacts_Personal_Master_Data_Completion_Agent_Switzerland_Draft_0.1`, which is a broader artefact inventory. The GF-approved field source, `Personalstammdaten_Felder_DE_EN.xlsx`, is referenced by the source material but is not present in this repository. PeopleDoc source labels therefore remain explicitly unverified rather than being inferred.

## 2. Controlled Statuses

### 2.1 Design status

| Status | Meaning |
|---|---|
| `Draft` | The field is specified in a draft design but is not yet approved |
| `Approved` | The field contract has received the required design approval |
| `Superseded` | The row is retained for history but a later BoM row replaces it |

### 2.2 Model stage

Model stages follow this sequence:

```text
Not started
  -> Created
  -> Schema defined
  -> Tagged
  -> Trained
  -> Evaluated
  -> Published
  -> Added to solution
```

`Blocked` may replace the next expected stage when evidence records a readiness, corpus, contract, training, safety, publication or solution-add failure. A stage advances only when the required evidence exists.

### 2.3 Verification status

| Status | Meaning |
|---|---|
| `Not evaluated` | No complete field-level evaluation evidence exists |
| `Evaluated - no findings` | Complete evidence contains no extraction-quality or safety finding for the field |
| `Evaluated - quality findings` | Complete evidence contains one or more missing or incorrect present-field values |
| `Blocked - safety failure` | The model returned a value where the field was expected to be absent |
| `Evidence incomplete` | A result is claimed but cannot be traced to complete field-level evidence |

An evaluated field is not thereby approved for a future automated write path. That approval remains outside this implementation and depends on the decisions and safeguards identified in the model design.

## 3. Field Lifecycle Matrix

| BoM ID | Contract field | PeopleDoc source label | AI Builder type | Designed contract | Design reference | Design status | Tenant 2 fixed-model stage | Tenant 2 fixed verification | Tenant 2 general-model stage | Tenant 2 general verification | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `BOM-0001-F01` | `candidate_id` | Unverified - GF field workbook unavailable | Text | Preserve the identifier as text | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F02` | `last_name` | Unverified - GF field workbook unavailable | Text | Preserve Unicode characters | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F03` | `first_name` | Unverified - GF field workbook unavailable | Text | Preserve Unicode characters | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F04` | `dob` | Unverified - GF field workbook unavailable | Date | Source format is `DD.MM.YYYY`; canonical comparison is `YYYY-MM-DD` | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F05` | `nationality` | Unverified - GF field workbook unavailable | Text | No vocabulary substitution in this increment | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F06` | `marital` | Unverified - GF field workbook unavailable | Text | No vocabulary substitution in this increment | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F07` | `heimatort` | Unverified - GF field workbook unavailable | Text | Preserve an explicit em dash as a literal value | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F08` | `permit` | Unverified - GF field workbook unavailable | Text | Preserve an explicit em dash as a literal value | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F09` | `street` | Unverified - GF field workbook unavailable | Text | Preserve punctuation | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F10` | `plz` | Unverified - GF field workbook unavailable | Text | Never define as Number; leading zeros must survive | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F11` | `city` | Unverified - GF field workbook unavailable | Text | Preserve Unicode characters | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F12` | `ahv` | Unverified - GF field workbook unavailable | Text | Never define as Number; preserve separators | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F13` | `iban` | Unverified - GF field workbook unavailable | Text | Preserve the extracted value and separators | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F14` | `phone` | Unverified - GF field workbook unavailable | Text | Preserve the extracted value and separators | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F15` | `email` | Unverified - GF field workbook unavailable | Text | Compare case-sensitively after normalization | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F16` | `ec_name` | Unverified - GF field workbook unavailable | Text | Preserve Unicode characters | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |
| `BOM-0001-F17` | `ec_phone` | Unverified - GF field workbook unavailable | Text | Preserve the extracted value and separators | [Design Section 5.3](../../../../docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md#53-common-field-contract) | `Draft` | `Not started` | `Not evaluated` | `Not started` | `Not evaluated` | None - implementation not started |

## 4. Evidence Rules

An implementation or verification status must link to an evidence run. Its `run-manifest.json` identifies:

- `run_id`;
- `tenant_key`, `power_platform_environment_id` and `environment_stage`;
- solution and model identities and versions;
- the held-out documents and their hashes;
- the field-level expected and actual values;
- the applicable quality and safety result.

Field-level result records reference this deployment context through `run_id`; they do not repeat or hard-code tenant and environment values. Missing evidence is recorded as missing evidence. It must not be represented as an implemented, evaluated or passing result.

## 5. Tenant 1 Adaptation

Tenant 1 reuses the BoM IDs, field names, types, contract rules and status definitions. It does not reuse Tenant 2 model stages, model versions, run IDs, verification results or evidence.

A separately approved Tenant 1 implementation adds tenant-local status and evidence without overwriting the Tenant 2 record. Tenant 1 models are created, trained, evaluated and published locally; Tenant 2 completion is not evidence of Tenant 1 completion.

## 6. Maintenance Rules

1. BoM IDs are allocated once and never reused.
2. A contract change updates the model design and this BoM in the same change.
3. A model stage advances only after its evidence is available.
4. Verification status reflects complete field-level results, not screenshots or operator recollection.
5. Present-field extraction mismatches remain quality findings.
6. A value returned for an expected-absent field is a blocking safety failure.
7. Superseded rows remain in the BoM for historical traceability.
