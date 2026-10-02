# Caldova Branding Migration Design

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-10-01 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Approved |
| **Scope** | Current tracked repository tree |
| **References** | [Documentation Policy](../README.md), [Specifications Catalogue](README.md), [Brand Guidance](../brand/README.md), [Tenant 1 Configuration Review Design](2026-09-28-tenant-1-engineering-platform-configuration-review-design.md) |

## Status and Authority

Approved on **2026-10-01**.

This specification is the authority for migrating the current tracked repository tree to Caldova branding. It defines the required outcome and acceptance boundary. It does not implement the migration, authorize a deployment or live-system change, rename an external source file, or rewrite repository history.

The inventory baseline is commit `63e7900edd431cc810a8396a24b19c17ef4999d1`. Counts in this document describe that pre-design baseline and are not expected to include this specification or its catalogue update.

## Objective

Remove the legacy customer identity from the maintained repository while preserving technical meaning, document status, synthetic test truth, accessibility semantics, and immutable review evidence. The resulting tree presents Caldova consistently in prose, identifiers, paths, generated documents, tests, and catalogues.

The migration is one repository change on one feature branch and is small enough for one implementation plan. A later implementation plan may sequence the approved work but may not widen this design.

## Legacy Pattern Vocabulary

This specification avoids reintroducing the strings that the completed migration must prohibit. The following labels are exact within this design:

| Label | Meaning at the baseline commit |
|---|---|
| `L1` | The legacy customer's two-word full name with its separating space. |
| `L2` | The same full name concatenated without a space. |
| `L3` | The uppercase initials of that full name when used as a standalone customer abbreviation. |
| `L4` | The lowercase initials, Unicode code points `U+0067 U+0066`, followed by a hyphen. |
| `L5` | The same lowercase initials followed by an underscore. |
| `L6` | The lower-camel identifier prefix formed from `U+0067 U+0066` immediately followed by an uppercase identifier character. |
| `L7` | The Pascal-case identifier prefix formed from `U+0047 U+0066` immediately followed by an uppercase identifier character. |

These labels are documentation shorthand only. The implementation contract must construct the prohibited values without storing them literally in its own source.

## Scope

### Included

- Every path and file tracked at the baseline commit, plus every migration artifact added on the feature branch, including maintained source, tests, generators, synthetic data, generated PDFs, application labels, mockups, catalogues, and repository-owned Markdown.
- The current tracked copies of ADRs, plans, specifications, reviews, READMEs, and agent instructions, regardless of their lifecycle status.
- All imports, links, references, tests, catalogues, schemas, prefixes, CSS names, and TypeScript symbols affected by a branding rename.
- All 48 tracked PDFs in branded paths and the generators and truth data that maintain them.
- A fail-closed branding regression contract for the current tracked tree.

Historical status and meaning remain intact when current document text is updated. Git history, not an obsolete name in the current copy, preserves the earlier record.

### Excluded

- Git history rewriting, including rebases or filter-based removal of old content.
- Backups, local session artifacts, ignored files, other worktrees, remote systems, and external source files.
- Claims that an original external source filename was renamed when the repository does not own that source.
- Generated review evidence, including manifests and test-result evidence, and the six sanitized Azure DevOps screenshots.
- New corporate-identity decisions, colour changes, accessibility redesign, or a claim that the inherited palette is official Caldova branding.
- Live systems, tenant configuration, infrastructure mutation, application deployment, and remote repository changes.

## Known Evidence

The following inventory was established against the baseline commit:

| Surface | Baseline evidence |
|---|---:|
| Tracked files | 475 |
| Lines containing `L1` or `L2` | 33 lines across 16 text files |
| Lines containing customer-use `L3` | 476 lines across 72 text files |
| Lines containing `L4` or `L5` branded forms | 325 lines across 30 files |
| Branded tracked paths | 64 |
| Tracked PDFs below branded paths | 48 |
| PDFs containing embedded legacy full-name text | 24 |
| Sanitized Azure DevOps screenshots that already show Caldova only | 6 |

Line categories can overlap and are not additive occurrence counts. The six screenshots are the files under `docs/reviews/evidence/2026-09-28-tenant-1-engineering-platform/` numbered `01` through `06`.

Every identified legacy-name, abbreviation, and branded-prefix use is approved as legacy customer branding, not as a technical false positive. Implementation must still review each match in context to select the correct transformation and protect its meaning. An ambiguous transformation blocks completion until it is adjudicated explicitly; ambiguity does not reopen the branding classification.

## Approved Decisions

### Prose and source attribution

- Visible `L1`, `L2`, and customer-use `L3` become **Caldova**.
- Descriptions of original external source files become neutral descriptions, such as “the customer-supplied use-case workbook” or “the source Workday presentation.”
- Repository text must not state or imply that an external file, backup, or source package was renamed.
- Current documents are scrubbed without changing their approval state, supersession state, evidential meaning, stable requirement identifiers, or architectural decisions.

### Identifiers and paths

The migration applies the following mapping consistently:

| Legacy form | Caldova form |
|---|---|
| Path or filename slug beginning with `L4` | `caldova-*` |
| Schema or prefix identifier beginning with `L5` | `caldova_*` |
| CSS custom property beginning with two hyphens and `L4` | `--caldova-*` |
| CSS class beginning with a dot and `L4` | `.caldova-*` |
| Lower-camel TypeScript symbol beginning with `L6` | `caldova...` |
| Pascal-case TypeScript symbol beginning with `L7` | `Caldova...` |

Every import, link, test expectation, generated reference, and catalogue entry must follow its renamed target. Partial aliasing is not allowed because it would preserve two active brand vocabularies.

The required path outcomes include:

- the current Fluent theme asset becomes `docs/brand/caldova-fluent-theme.ts`;
- the current token stylesheet becomes `docs/brand/caldova-tokens.css`; and
- both AI Builder package directories below `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/` replace their legacy slug with `caldova-aib-*`.

At the baseline commit, each source path is derived by replacing `caldova` in the target with the lowercase code-point pair defined in `L4`, without its trailing hyphen.

### Product palette

The inherited palette is an **interim product palette pending an approved Caldova design standard**. Maintained guidance must not call it an official Caldova corporate identity or imply corporate approval.

This branding migration renames tokens and reframes provenance; it does not change colour values. Existing contrast and semantic-state behavior are preserved unless a separate approved design explicitly authorizes colour changes.

### Synthetic corpus

- Generators use a fictional Caldova entity and a clearly fictional, non-customer address.
- Synthetic-person disclaimers and candidate truth data remain intact.
- All 48 PDFs are regenerated so that all 24 embedded legacy references are removed and every PDF lives below its renamed path.
- CSV and JSON truth remain semantically equivalent. A brand field may change only when the implementation documents that field and its old and new values explicitly.
- Generator output, checked-in PDFs, and checked-in truth data must agree. Hand-editing generated PDFs is not an acceptable migration method.

### Screenshots and review evidence

The six sanitized Azure DevOps screenshots remain byte-for-byte unchanged because they already display Caldova only. Their hashes are compared with the baseline commit during acceptance. Historical generated review evidence is also unchanged.

Review narrative Markdown remains in scope for text migration. This distinction preserves immutable evidence while preventing the current documentation from continuing to teach legacy branding.

## Implementation Requirements

### Branding contract

Implementation adds `.github/cli/tests/BrandingContract.Tests.ps1` as a maintained current-tree contract. It must:

1. enumerate tracked paths with Git rather than relying on a filesystem walk;
2. scan every tracked filename and every scannable tracked text file for exact `L1` through `L7` forms;
3. construct prohibited patterns from code points or separated fragments so its own source does not contain a prohibited value literally;
4. fail closed when Git enumeration, decoding, classification, or file reading fails;
5. report each offending path and pattern class without silently skipping a match;
6. reject broad path, extension, or directory allowlists; and
7. treat binary classification, symbolic-link behavior, or link-target drift as an explicit result rather than an implicit exclusion.

PDF embedded text remains a separate, explicit local acceptance check. The maintained generators plus the tracked source-and-path contract prevent ordinary reintroduction without adding an unpinned PDF dependency to CI.

### Post-baseline main integration and immutable AI Builder evidence

The implementation branch integrates `origin/main` commit `402f42ff01e662dcb6762d44e9a5fec09b3484cd` after the original migration baseline. That integration adds the governed AI Builder evaluation subsystem and its point-in-time Tenant 2 DEV evidence. Current guidance, scripts, tests, fixtures, BoMs, and plans remain mutable and follow the Caldova migration. Seven evidence files are different: three raw model responses contain one `L3` OCR occurrence each, and the evaluation summary plus three training-capture records contain one `L4` occurrence each.

Those seven occurrences are source evidence produced by the live model and its governed capture process. Rewriting their bytes would make the retained model output, hashes, and replay record false; truthful remediation would require a separately authorized live rerun, which this repository-only migration neither performs nor authorizes. The files therefore remain byte-for-byte equal to `origin/main`.

`.github/cli/config/branding-evidence-exceptions.json` is the only exception authority. Each record binds one normalized tracked path below `hr/evidence/ai-builder/` to its lowercase SHA-256, exact pattern class, exact count of one, and non-sensitive provenance and rationale. The scanner validates the manifest's exact schema, tracked regular-file status, root, uniqueness, hash, class, count, and absence of extra matches before suppressing an occurrence. A declared path must itself contain no `L1`-`L7` match: approvals apply to content only, and path findings are never suppressible. Invalid or changed records fail closed, and unknown occurrences remain normal findings. There are no directory, extension, wildcard, or broad path exceptions.

The integrated tree has exactly 55 tracked PDFs. The two exact Caldova corpus roots contain 48 generated PDFs; those files remain subject to embedded-text migration acceptance. The remaining seven PDFs are point-in-time AI Builder input evidence below `hr/evidence/ai-builder/`. Evidence PDFs may retain historical branding because rewriting captured inputs would break their provenance. They are governed separately by readability plus Git-blob and SHA-256 equality to integrated main commit `402f42ff01e662dcb6762d44e9a5fec09b3484cd`, not by content rewriting. No tracked PDF may exist outside those three classifications.

### Migration sequence

Implementation follows this order:

1. Write the failing branding contract and demonstrate that it detects the baseline.
2. Rename branded assets and directories.
3. Update prose, identifiers, imports, links, tests, and catalogue references.
4. Update synthetic corpus generators.
5. Regenerate all 48 corpus PDFs under renamed paths.
6. Update affected tests and contracts without weakening their assertions.
7. Run the complete acceptance set.

Renames precede reference repair so stale destinations can be detected. Generator changes precede PDF regeneration so generated output has one reproducible source.

### Error handling

- An ambiguous `L3`, identifier, or prefix transformation stops the migration until its context and disposition are recorded in the implementation review.
- A generator failure, PDF read failure, page text-extraction failure, or generator/truth mismatch blocks acceptance.
- No scanner, generator, or verifier may convert an error into a warning or silently skip a file.
- An unexpected binary change, screenshot hash change, symlink, broken link, or rename without a matching reference update is reported explicitly and blocks completion.
- A count discrepancy triggers a fresh inventory and explanation; counts are not adjusted merely to make acceptance pass.

## Acceptance Criteria

The migration is accepted only when all of the following are true:

1. The branding contract reports zero unapproved findings in tracked paths and scannable tracked text, exactly seven approved immutable-evidence occurrences, and complete tracked-file accounting. Only the seven exact hash-bound AI Builder evidence records may be approved; there is no broad exception.
2. Local `pypdf` verification reports exactly 55 tracked PDFs partitioned into 48 corpus PDFs below the two exact Caldova corpus roots and 7 evidence PDFs below `hr/evidence/ai-builder/`, with no other tracked PDFs. All 48 corpus PDFs are readable with zero extraction errors and zero prohibited embedded matches. All 7 evidence PDFs are readable and byte-identical by Git blob and SHA-256 to integrated main commit `402f42ff01e662dcb6762d44e9a5fec09b3484cd`; their historical embedded-match classes and counts are reported but do not fail acceptance.
3. SHA-256 values for all six sanitized screenshots equal the values of the corresponding files at baseline commit `63e7900edd431cc810a8396a24b19c17ef4999d1`.
4. `npm run lint` and `npm run build` pass from `hr/src/apps/hr-control-plane`.
5. Regenerating the synthetic corpus produces the checked-in PDFs, and candidate truth remains equivalent except for explicitly documented brand fields.
6. All repository-owned Markdown has valid metadata and all tracked local Markdown links resolve.
7. Repository safety validation passes without contacting or mutating a live system.
8. The complete maintained Pester suite passes under Windows PowerShell 5.1 with exact Pester 5.7.1.
9. `git diff --check` reports no whitespace errors, and the final diff contains only approved repository changes.
10. No deployment, tenant mutation, history rewrite, backup edit, screenshot edit, or external-source edit occurred.

The full maintained Pester command is:

```powershell
Import-Module Pester -RequiredVersion 5.7.1 -Force
$paths = @(
    (Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File |
        Sort-Object FullName |
        Select-Object -ExpandProperty FullName)
    'infra\tests\pester'
    'hr\tests\pester'
)
Invoke-Pester -Path $paths -Output Detailed -CI
```

Repository safety is verified separately:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-safety.ps1
```

### Explicit PDF embedded-text verification

This acceptance command uses the operator's local `pypdf` installation. It does not add or resolve a CI dependency.

```powershell
@'
from collections import Counter
from hashlib import sha256
from pathlib import Path
import re
import subprocess
import sys

from pypdf import PdfReader

integrated_main = "402f42ff01e662dcb6762d44e9a5fec09b3484cd"
first = "".join(chr(value) for value in (71, 101, 111, 114, 103))
second = "".join(chr(value) for value in (70, 105, 115, 99, 104, 101, 114))
initials = first[0] + second[0]
patterns = {
    "L1": re.compile(re.escape(first + " " + second), re.IGNORECASE),
    "L2": re.compile(re.escape(first + second), re.IGNORECASE),
    "L3": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials)}(?![A-Za-z0-9])",
        re.IGNORECASE,
    ),
    "L4": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}-",
        re.IGNORECASE,
    ),
    "L5": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}_",
        re.IGNORECASE,
    ),
    "L6": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials.lower())}(?=[A-Z])"
    ),
    "L7": re.compile(
        rf"(?<![A-Za-z0-9]){re.escape(initials[0] + initials[1].lower())}(?=[A-Z])"
    ),
}

raw = subprocess.check_output(["git", "ls-files", "-z", "--", "*.pdf"])
paths = [Path(value) for value in raw.decode("utf-8").split("\0") if value]
use_case_root = "hr/docs/ideas/uc-0001-personal-master-data-completion-agent/"
corpus_roots = (
    use_case_root + "caldova-aib-fixed-template/documents/",
    use_case_root + "caldova-aib-general-documents/documents/",
)
corpus = [
    path for path in paths
    if path.as_posix().startswith(corpus_roots)
]
evidence = [
    path for path in paths
    if path.as_posix().startswith("hr/evidence/ai-builder/")
]
other = [
    path for path in paths
    if path not in corpus and path not in evidence
]

def inspect(group):
    readable = 0
    extraction_errors = []
    matches = []
    for path in group:
        try:
            text = "\n".join(
                (page.extract_text() or "") for page in PdfReader(path).pages
            )
            readable += 1
        except Exception as exc:
            extraction_errors.append(
                f"{path}: {type(exc).__name__}: {exc}"
            )
            continue
        for label, pattern in patterns.items():
            matches.extend([label] * len(pattern.findall(text)))
    return readable, extraction_errors, matches

corpus_readable, corpus_errors, corpus_matches = inspect(corpus)
evidence_readable, evidence_errors, evidence_matches = inspect(evidence)
blob_mismatches = []
sha256_mismatches = []
for path in evidence:
    relative = path.as_posix()
    main_blob = subprocess.check_output(
        ["git", "rev-parse", f"{integrated_main}:{relative}"],
        text=True,
    ).strip()
    worktree_blob = subprocess.check_output(
        ["git", "hash-object", "--", relative],
        text=True,
    ).strip()
    main_bytes = subprocess.check_output(
        ["git", "cat-file", "blob", main_blob]
    )
    worktree_bytes = path.read_bytes()
    if main_blob != worktree_blob:
        blob_mismatches.append(relative)
    if sha256(main_bytes).hexdigest() != sha256(worktree_bytes).hexdigest():
        sha256_mismatches.append(relative)

evidence_classes = ",".join(
    f"{label}:{count}"
    for label, count in sorted(Counter(evidence_matches).items())
)
print(
    f"PDF inventory: total={len(paths)}; corpus={len(corpus)}; "
    f"evidence={len(evidence)}; other={len(other)}"
)
print(
    f"Corpus PDF verification: readable={corpus_readable}; "
    f"extraction_errors={len(corpus_errors)}; "
    f"legacy_matches={len(corpus_matches)}"
)
print(
    f"Evidence PDF verification: readable={evidence_readable}; "
    f"extraction_errors={len(evidence_errors)}; "
    f"blob_mismatches={len(blob_mismatches)}; "
    f"sha256_mismatches={len(sha256_mismatches)}"
)
print(
    f"Evidence historical matches: count={len(evidence_matches)}; "
    f"classes={evidence_classes}"
)

if (
    len(paths) != 55
    or len(corpus) != 48
    or len(evidence) != 7
    or other
    or corpus_readable != 48
    or corpus_errors
    or corpus_matches
    or evidence_readable != 7
    or evidence_errors
    or blob_mismatches
    or sha256_mismatches
):
    sys.exit(1)
'@ | python -
```

The command fails unless the exact 48/7/0 partition, corpus content gate, evidence readability, and evidence byte-equality gates all pass. Historical evidence match counts are reported by class without disclosing matched content and do not authorize rewriting those files.

## Migration Risks

| Risk | Consequence | Required control |
|---|---|---|
| A short branding abbreviation is replaced at the wrong text or identifier boundary | Legacy branding remains or adjacent technical syntax is changed | Review every match in context; ambiguity blocks rather than creating an allowlist. |
| A rename leaves stale imports or links | Builds, tests, or documentation navigation fail | Rename once, update all consumers, then run build, Pester, metadata, and link validation. |
| Current historical documents are left untouched | The maintained tree continues to present conflicting identities | Update current copies while preserving status and meaning; rely on Git history for prior wording. |
| External source descriptions imply a source rename | Traceability becomes false | Replace filenames with neutral source descriptions and state no external rename. |
| Palette wording becomes an unsupported identity claim | Readers treat provisional colours as approved corporate branding | Call the palette interim and preserve semantic/accessibility behavior. |
| Generated PDFs diverge from generators or truth data | Checked-in evidence cannot be reproduced | Change generators first, regenerate all PDFs, and compare output and truth. |
| A PDF cannot be read or yields no trustworthy extraction result | Embedded legacy text may remain undetected | Fail the explicit PDF check; do not skip or waive the file. |
| Sanitized evidence changes incidentally | Point-in-time review evidence loses integrity | Compare all six screenshot hashes with the baseline and reject drift. |
| The regression contract exempts its own repository areas | Legacy branding can return unnoticed | Scan Git-tracked paths and scannable text, construct patterns indirectly, and prohibit broad allowlists. |

## Rollback

The migration is delivered on a single feature branch through one pull request. If it is rejected before merge, abandon that branch and retain the current `main` tree. If a merged migration must be reversed, use a reviewed revert that restores the pre-migration tree.

Rollback does not rewrite Git history, edit backups, mutate remote services, or attempt to rename external source files. No live-system rollback exists because this migration performs no deployment or live mutation.
