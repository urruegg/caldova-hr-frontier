# Caldova HR Operations Agent - Idea

| Field | Value |
|---|---|
| **Version** | 0.3 |
| **Date** | 2026-10-29 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | Caldova project/demo; GF source/customer context: functional package: Switzerland PeopleDoc-to-Workday proposal process |
| **References** | [Specification](../specs/2026-10-28-caldova-hr-operations-agent-design.md), [Sprint](../plans/2026-10-28-caldova-hr-operations-agent-sprint.md), [Package index](../README.md#caldova-draft-packages) |

## Caldova project and GF source boundary

This is a Caldova project/demo document using the explicitly identified GF source/customer scenario. GF facts, approvals, requirements and trademarks remain GF-scoped; project renaming does not establish Caldova corporate policy or runtime acceptance. See the [source and authority boundary](../README.md#caldova-project-and-gf-source-boundary). Existing stable IDs are retained for traceability, not reassigned.

## Status and provenance

Section 5 of the supplied GF build brief v1.0 has been reviewed. It describes E14/E15/E16 requirements and rules, but those originals, the mapping workbook and sample PDFs have not been inspected. This source-grounded Caldova project package remains distinct from Caldova UC-0001.

The user approved detailing the full process while keeping writes blocked until stakeholder decisions and safety evidence are complete. See the [source register](../README.md#caldova-project-and-gf-source-boundary).

## Problem and expected value

Reduce manual re-keying of approved new-joiner fields from exported PeopleDoc PDFs into Workday without overwrites or duplicate updates. Time/volume baselines are not supplied. The brief's safety criterion is zero unsafe writes, not an accuracy claim already achieved.

## Confirmed idea

| Canvas element | Refined draft |
|---|---|
| Agent | D2-A01, HR Operations Agent - Switzerland |
| Users | HR Operations Switzerland; process/HRIS owners govern rules and access |
| Trigger | Authorized manual run after the basic Workday profile exists; later scheduling remains open |
| Inputs | Approved non-identity PDF packages, approved mapping rules and live Workday comparison |
| Reasoning | Extract permitted fields with source/confidence and explain exceptions; workflow owns grouping, gates, audit and movement |
| Proposed actions | Exactly-one-profile comparison; propose blank-field additions; governed add-only actions only after all write gates close |
| Outputs | Added/Already exists/Missing/System error field statuses; Success/Partial success/Exception packages; follow-up and weekly validation |
| Platform | Copilot Studio, GitHub Copilot runtime harness; connector held only by a separate governed Access Layer |

The current boundary is propose-only. No identity documents/fields, profile creation, overwrites, guessed matches or duplicate writes are allowed. A designated synthetic test-profile write still requires separate Workday-owner authorization.

## Source intake

| Expected material | Availability | Required review |
|---|---|---|
| E14/E15/E16 PRD, BOM and SOP | Summarized in brief; originals pending | Matching, approval, field/action and exception rules |
| C3.01 approved mapping workbook | Reported partial/TBC in brief | Column C fields selected by column E; remove identity fields; resolve all TBC entries |
| W3.01-W3.04 intake, non-identity PDFs, Complete and optional Exceptions | Paths/types not verified | Separate work items from knowledge; synthetic DEV/TEST material only |
| T3.01/T3.02 test pack and approved minimized samples | Missing/approval-gated | Extraction and safety evidence, no production data copied into this repository |

This agent has no general answer-knowledge library. The workbook is a controlled rule source; employee PDFs are untrusted transactional input, not reusable knowledge.

## Open decisions and next review

Resolve the matching-key conflict (Employee ID versus name/postal code), approval before writes versus weekly review, allowed documents/fields, target object/API, confidence threshold, write identity, privacy/transient processing, recovery, file disposition and report ownership. No numeric extraction threshold is agreed.

See the [specification diagrams](../specs/2026-10-28-caldova-hr-operations-agent-design.md#2-process-and-interactions). CAT Agent Evaluation Designer can inform synthetic negative tests; PDF Table Data Conversion does not satisfy this schema/confidence/add-only contract and is not recommended as the extraction engine. No assessed CAT skill replaces the Workday Access Layer.

## Board synchronization

Deferred - not synchronized.
