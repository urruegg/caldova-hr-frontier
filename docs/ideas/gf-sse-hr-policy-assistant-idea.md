# GF SSE HR Policy Assistant - Idea

| Field | Value |
|---|---|
| **Version** | 0.2 |
| **Date** | 2026-10-28 |
| **Author** | Copilot |
| **Status** | Draft |
| **Scope** | GF functional package: SSE HR Policy assistant |
| **References** | [Specification](../specs/2026-10-28-gf-sse-hr-policy-assistant-design.md), [Sprint](../plans/2026-10-28-gf-sse-hr-policy-assistant-sprint.md), [Package index](../README.md#gf-draft-packages) |

## Status and provenance

This is a separate GF draft package, not graduation of Caldova UC-0002. The supplied *MVP 1-3 agent canvases, processes, audiences and SharePoint BOM*, v1.0, section 3, has been reviewed. Its underlying SOP, FAQ workbook and policies have not. Evidence IDs below are references reported by that brief, not independently verified originals. See the [source and reuse register](../README.md#gf-source-basis-and-publication-boundary).

## Problem and expected value

Make approved policy guidance easier to find and reduce repetitive HR queries. The brief cites an earlier 30% HR-ticket reduction target (E06 OLD), not an achieved result or a confirmed sprint commitment. The current baseline is missing.

## Confirmed idea

| Canvas element | Refined draft |
|---|---|
| Agent | D3-A01, SSE HR Policy assistant |
| Users | Switzerland employees and HR for the MVP; exact group and pilot licensing/access remain open |
| Goal | Concise, cited answers from approved Swiss policy PDFs; no reliable answer means a Workday Help Center handoff |
| Trigger and input | Signed-in employee asks a policy question; retrieval uses approved, applicable sources and effective caller permissions |
| Reasoning | Explain relevant policy without inventing conditions, deciding individual eligibility or choosing between unresolved source conflicts |
| Human responsibility | HR owns policy meaning and individual decisions; policy/content owners approve source changes; IT owns access |
| Platform | Copilot Studio, GitHub Copilot runtime harness; ESS is out of MVP scope by user decision |
| Output | Source/section citation, official-source disclaimer or support handoff; no automatic case creation |

The user confirmed Switzerland-only MVP scope while requiring future regional onboarding. Each region needs separately approved sources, audience permissions, applicability/hierarchy rules, languages, owners, escalation and evaluation. Shared versus separate regional agents is not yet decided. A region tag is not an authorization control.

Employee-record access, HR transactions, employment decisions, legal advice, web/general-knowledge answers and other-country policies are excluded from the Swiss MVP.

## Source intake

| Expected material | Availability | Required review |
|---|---|---|
| K1.01-K1.13 policy PDF inventory | Listed in brief section 3.6; files not inspected | Owner approval, current versions, applicable population, language and access |
| K1.14 further policies | Explicitly missing in the brief | HR-approved scope and owner |
| E41 SOP / W1.01 version tracker | Described by brief; originals pending | Content lifecycle and exact fallback/support route |
| E42 / W1.02 FAQ, 66 questions | Reported received by brief's author; workbook not inspected here | Evaluation only, never answer knowledge; confirm references and expected meanings |

Keep current knowledge, archive, incoming versions and evaluation material separate. Source classification and actual permission checks remain release gates. The brief's internal-data description does not prove that every document is employee-visible.

## Open decisions and next review

Resolve named policy owners, the production source location, support URL, supported languages, CEA-versus-policy conflicts, transcript handling and regional deployment topology. The brief's CEA hierarchy statement is reported guidance, not authority to resolve the cases it explicitly leaves open.

The [specification](../specs/2026-10-28-gf-sse-hr-policy-assistant-design.md#2-process-and-interactions) owns process/interaction diagrams; the sprint owns dependency gates. CAT Knowledge Readiness and Agent Evaluation Designer are conditional preparation aids; Knowledge Source Router is a future-region pattern requiring permission-preserving adaptation, not a ready-made connector. See the [CAT assessment](../README.md#cat-reuse-assessment).

## Board synchronization

Deferred - not synchronized.
