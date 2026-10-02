# Documentation Knowledge Architecture Migration Review

| Field | Value |
|---|---|
| **Version** | 1.2 |
| **Date** | 2026-10-02 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Active |
| **Scope** | Documentation knowledge architecture migration evidence |
| **References** | [Approved Cleanup Design](../specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md), [Migration Plan](../plans/2026-10-02-documentation-knowledge-architecture-cleanup-implementation.md), [Baseline Manifest](evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json) |

## Baseline

This review records point-in-time migration evidence at the execution baseline. It is not current documentation authority; normal discovery remains with the lifecycle and domain catalogues.

| Baseline field | Observed value |
|---|---|
| Execution commit | `de0f222db262a36242b6c50b30c0c49f1b1334df` |
| Execution branch | `feat/documentation-knowledge-architecture-cleanup` |
| Worktree state before Task 1 mutation | Clean; `git status --short` returned no output |
| Tracked Markdown files across `docs/`, `hr/`, `infra/`, and `data/` | 141 |
| Candidate files recorded in the baseline manifest | 458 |
| Synthetic corpus PDFs planned for byte-preserving movement | 48 |
| Immutable AI Builder evaluation-evidence PDFs retained in place | 7 |
| Inherited repaired full baseline | 984 discovered; 981 passed; 0 failed; 3 documented skips; repository safety passed |

The exact clean-baseline commands observed immediately before Task 1 mutation were:

```powershell
git status --short
git rev-parse HEAD
git branch --show-current
```

They returned a clean status, `de0f222db262a36242b6c50b30c0c49f1b1334df`, and `feat/documentation-knowledge-architecture-cleanup` respectively. The inherited full-suite result above is preflight evidence at the same commit; Task 1 does not reinterpret it as migration acceptance.

## Migration Register

The register preserves the planned baseline disposition recorded before mutation. Observed execution, hash, and validation results are recorded in the task sections below; Task 6 is the final acceptance authority. The grouped corpus row is permitted only with the explicit 48-file count and per-file comparison contract below.

| Old path | New path | Class | Pre-move SHA-256 | Post-move SHA-256 | Disposition | Active replacement | Validation |
|---|---|---|---|---|---|---|---|
| `docs/ideas/README.md` | `docs/ideas/README.md` | Central idea catalogue (Active (consolidated from current state)) | 0f42cccd05a2ba4839b1d8068c3b62ee21eb021b2e5143651e0dab430a6b94e4 | Not run - migration pending | Retain path; replace placeholder content | `docs/ideas/README.md` | Not run - migration pending |
| `docs/archive/` | `docs/archive/` | Historical archive root | Per-file hashes in baseline manifest (1 eligible file) | Not run - migration pending | Retain and populate canonical archive root | `docs/archive/README.md` | Not run - migration pending |
| `hr/docs/ideas/README.md` | `docs/ideas/README.md` | HR idea catalogue (Proposed Baseline) | 700be47952f69134cb6412a54e8f1360d15b1efe0cf0d57a28d348d6330ad235 | Not run - migration pending | Planned merge; remove old tracked catalogue | `docs/ideas/README.md` | Not run - migration pending |
| `hr/docs/ideas/hr-control-plane-mockup-idea.md` | `docs/ideas/hr-control-plane-mockup-idea.md` | Central idea artifact (Draft) | a45b7e1b81d9bfbd1bb17e8019732fb41040e0741fee5b960436fdd68a242a58 | Not run - migration pending | Planned move | `docs/ideas/hr-control-plane-mockup-idea.md` | Not run - migration pending |
| `hr/docs/ideas/hr-control-plane-mockup.html` | `docs/ideas/hr-control-plane-mockup.html` | Central idea artifact (HTML companion) | 9d86855de31495384f8c852d69cfb304e8629e757f802f1ad9f5217b64e73623 | Not run - migration pending | Planned move | `docs/ideas/hr-control-plane-mockup.html` | Not run - migration pending |
| `hr/docs/ideas/uc-0002-hr-policy-chat-assistant.md` | `docs/ideas/uc-0002-hr-policy-chat-assistant.md` | Central idea record (Proposed Baseline) | 72166839c393e8bc768c6d9095a959c50627e18fcc2ac5fabab3fe351ddcf645 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0002-hr-policy-chat-assistant.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0003-employee-self-service-assistant.md` | `docs/ideas/uc-0003-employee-self-service-assistant.md` | Central idea record (Proposed Baseline) | 4e48e3363ac2b70483ea55bdc8490ecbd2e64ccfed6ccfc12871c85ea8bd4db7 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0003-employee-self-service-assistant.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0004-hr-case-classification-bot.md` | `docs/ideas/uc-0004-hr-case-classification-bot.md` | Central idea record (Proposed Baseline) | c2b486c54fda4d77f29217b82c33262835c61b773475e8583c9c58c99d55a129 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0004-hr-case-classification-bot.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0005-onboarding-assistant.md` | `docs/ideas/uc-0005-onboarding-assistant.md` | Central idea record (Proposed Baseline) | 1dcb455831362bfff8e8ee0746b2d5224da16531c4149db36e0862afbcedd53d | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0005-onboarding-assistant.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0006-job-description-generator.md` | `docs/ideas/uc-0006-job-description-generator.md` | Central idea record (Proposed Baseline) | 36b11009da7b0a07a18c7c84672dd4990e065906189419e9b5252cad2bb0ae2b | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0006-job-description-generator.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0007-candidate-screening-summary.md` | `docs/ideas/uc-0007-candidate-screening-summary.md` | Central idea record (Proposed Baseline) | c531ff49c423e0f8249571709dfe2a7d694ef57dc00a8adb517b4424c81140d1 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0007-candidate-screening-summary.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0008-salary-benchmark-assistant.md` | `docs/ideas/uc-0008-salary-benchmark-assistant.md` | Central idea record (Proposed Baseline) | 04350e480c42139534ed3c49fd0b0436a9e2a8f2211a890df1701d729407e7d2 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0008-salary-benchmark-assistant.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0009-workforce-insights-assistant.md` | `docs/ideas/uc-0009-workforce-insights-assistant.md` | Central idea record (Proposed Baseline) | 0e573f60d46d237ab51b322830a638ecbda9d4bcf4d503cb9f673071ef9ea93e | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0009-workforce-insights-assistant.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0010-employee-data-validation-bot.md` | `docs/ideas/uc-0010-employee-data-validation-bot.md` | Central idea record (Proposed Baseline) | b932373f148b426e3bba84d03e9e9a4f628ec98aaea8724ac63e1369f6387883 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0010-employee-data-validation-bot.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0011-learning-recommendation-agent.md` | `docs/ideas/uc-0011-learning-recommendation-agent.md` | Central idea record (Proposed Baseline) | a4da6580adf7554853c66e96151ddbda361848f79c2959aa9a9af82b7f4bda06 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0011-learning-recommendation-agent.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0012-payroll-anomaly-detection.md` | `docs/ideas/uc-0012-payroll-anomaly-detection.md` | Central idea record (Proposed Baseline) | 6f5507ab86c0dded845ac385e79b0f7371338395c8bf14e1ad21e271802d79aa | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0012-payroll-anomaly-detection.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0013-performance-review-draft-assistant.md` | `docs/ideas/uc-0013-performance-review-draft-assistant.md` | Central idea record (Proposed Baseline) | f45043a9e6c35b61dbe91ee9462800a7753ce335cc36853f97f7b4b119598803 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0013-performance-review-draft-assistant.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0014-continuous-performance-insights.md` | `docs/ideas/uc-0014-continuous-performance-insights.md` | Central idea record (Proposed Baseline) | 7c7d5fa5707e646cb952e725e9681483258bd960caeafd441856d1480aa62c8e | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0014-continuous-performance-insights.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0015-leadership-pipeline-prediction.md` | `docs/ideas/uc-0015-leadership-pipeline-prediction.md` | Central idea record (Proposed Baseline) | a2d90649fbc396bd38e34a60b5dd8f00351f8246edd1e104e6e21012deef625f | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0015-leadership-pipeline-prediction.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0016-skills-inference-engine.md` | `docs/ideas/uc-0016-skills-inference-engine.md` | Central idea record (Proposed Baseline) | c1534b65a222ad6629b7b00b32f686df42e7825a588f30f3d3332b532dc03db2 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0016-skills-inference-engine.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0017-pre-hire-process-orchestration.md` | `docs/ideas/uc-0017-pre-hire-process-orchestration.md` | Central idea record (Proposed Baseline) | 653065f6a473adf18edeea137ad900c364c39cce59a4f96ed6df03747c70480f | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0017-pre-hire-process-orchestration.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0018-onboarding-checklist-rebuild.md` | `docs/ideas/uc-0018-onboarding-checklist-rebuild.md` | Central idea record (Proposed Baseline) | b09dc195a7a5480cfbd05ebd3c993c3d26c032578b349603f365f810e0d1542a | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0018-onboarding-checklist-rebuild.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0019-attrition-risk-insight-lite.md` | `docs/ideas/uc-0019-attrition-risk-insight-lite.md` | Central idea record (Proposed Baseline) | 47d32eb425a6d1194d07f7aa8ddaf4eed76dede89a760142b59c83297045b264 | Not run - migration pending | Planned byte-preserving move | `docs/ideas/uc-0019-attrition-risk-insight-lite.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/uc-0001-personal-master-data-completion-agent.md` | `docs/ideas/uc-0001-personal-master-data-completion-agent.md` | Central idea record (Proposed Baseline) | de085dd356b23c5c2f6c739cb522cf1e25c2fd1e8df2b6289bab230c8aca47c3 | Not run - migration pending | Planned move and graduation update | `docs/ideas/uc-0001-personal-master-data-completion-agent.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` | HR use-case detail (Draft) | 37af81712f71a9dfdb09fcdd9d12353018fa6f6bcb2703b96136f1f54756f65c | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md` | HR use-case detail (Draft) | 9581dc504b12ba483fae1b556e12ee610952d092e126e3384a704c7ea8683eb1 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md` | HR use-case detail (Draft) | bbc873d96a54ef981c6510b4928ed3ca02925681957b2c2f3105d7074a988a46 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_fixed.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_fixed.py` | HR use-case detail (Python generator) | 2780ee638efad3cc336bb75cd1e5f64e8e741b1c6c2a7c17839c6b4c2a2f633b | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_fixed.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_general.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_general.py` | HR use-case detail (Python generator) | 17f863c5586a55af537ba22e094d0b56e225dc121349cd5b17fbcd31d252902b | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_general.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_truth.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_truth.py` | HR use-case detail (Python generator) | a8a6c31f7d99afb692763e87615ea10ea2f2332be4dac5459d260c8ba05d9848 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/gen_truth.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/personas.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/personas.py` | HR use-case detail (Python generator) | f54e938631337a7c8e5d288f1ce476e76f593014aee69a6038ca6b41ee9c12ab | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/generators/personas.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/ground-truth.csv` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/ground-truth.csv` | HR use-case detail (CSV data artifact) | b9fee213b2574452d8202451324cb90825ca219490661b71ea62e06e40e9e4a8 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/ground-truth.csv` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/ground-truth.json` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/ground-truth.json` | HR use-case detail (JSON data artifact) | 5be4eca95fb84f196d4421e8c89eee621d07ccf7bc6549c3963949be4a8053ed | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/ground-truth.json` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/README.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/README.md` | HR use-case detail (Draft) | 1430e64bfe16ed4ebaa057a25f4682e3a93db58bfd5ecef237947ca6033c9166 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/README.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_fixed.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_fixed.py` | HR use-case detail (Python generator) | 11ec719c2e8e397fd8cfda7ed470e85fd0f741eb2f14bc173a6dcd78c0d87050 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_fixed.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_general.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_general.py` | HR use-case detail (Python generator) | 2865eaeef07501a827bbfdfc10dd87a1c25c2c83fcdf7e8d61e0284b1af22238 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_general.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_truth.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_truth.py` | HR use-case detail (Python generator) | 8354200ac2c2cffe6c826d0b92cd780741a3e1b1add637a32e141ae2abfff702 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/gen_truth.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/personas.py` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/personas.py` | HR use-case detail (Python generator) | f54e938631337a7c8e5d288f1ce476e76f593014aee69a6038ca6b41ee9c12ab | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/generators/personas.py` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/ground-truth.csv` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/ground-truth.csv` | HR use-case detail (CSV data artifact) | 4fdec89678a3a857c377f4c629891c9a2f9b83ea95693de425582f03ee89ec87 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/ground-truth.csv` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/ground-truth.json` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/ground-truth.json` | HR use-case detail (JSON data artifact) | 337773493b4fdeda71c87f4fcbaaa9b3920670e6f58b8d87311e4ec8a3188849 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/ground-truth.json` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/README.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/README.md` | HR use-case detail (Draft) | ddef36f96ee8921ce9fd86863d9d7915332a151ee3cf86f318c117148014e9f1 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/README.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/document-intake-architecture.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/document-intake-architecture.md` | HR use-case detail (Draft) | bc05ba262f2373aa2b3d89bacb280493922ab4775e055b290e4ce8face3fba57 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/document-intake-architecture.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md` | HR use-case detail (Proposed Baseline) | be17e53550d66823b3a142762df9319caaffe32c68762029fc3c6d6f5adcd4a5 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/README.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md` | HR use-case detail (Proposed Baseline) | a0d6e12367b96457b27ff455934c27b3250171ddaff3408df40d51de413d68e9 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/sharepoint-knowledge-vs-processing.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/sharepoint-knowledge-vs-processing.md` | HR use-case detail (Draft) | d0e68e166748252ffabcb07a6c1fda6e37e07e429aa601d334dafecba19cb174 | Not run - migration pending | Planned move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/sharepoint-knowledge-vs-processing.md` | Not run - migration pending |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/**/*.pdf (48 files)` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/**/*.pdf (48 files)` | Synthetic corpus PDFs (binary, grouped row) | 48 per-file hashes in baseline manifest | Not run - migration pending | Planned byte-preserving move | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/` | Not run - migration pending; compare all 48 target files to per-file baseline hashes |
| `docs/superpowers/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md` | `docs/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md` | Repository-wide plan (Draft) | 6baf1ed8d277e04162d73dc5485d5aaaa5c567ac97785c48b64e94d0f8fe69a1 | Not run - migration pending | Planned byte-preserving move | `docs/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md` | Not run - migration pending |
| `docs/superpowers/plans/2026-09-26-runbook-cloud-foundation.md` | `docs/plans/2026-09-26-runbook-cloud-foundation.md` | Repository-wide plan (Proposed Baseline) | d022fc916f0bbde92c9cb1486758a792631090bb07f52477204c71d29e58ce4d | Not run - migration pending | Planned byte-preserving move | `docs/plans/2026-09-26-runbook-cloud-foundation.md` | Not run - migration pending |
| `docs/superpowers/plans/2026-09-26-runbook-customer-handover.md` | `docs/plans/2026-09-26-runbook-customer-handover.md` | Repository-wide plan (Proposed Baseline) | d18979cb8887f06bc55636f2838ae132689aa5f95d0fa725ad71ce994aa54a5b | Not run - migration pending | Planned byte-preserving move | `docs/plans/2026-09-26-runbook-customer-handover.md` | Not run - migration pending |
| `docs/superpowers/plans/2026-09-26-runbook-foundation-workstation.md` | `docs/plans/2026-09-26-runbook-foundation-workstation.md` | Repository-wide plan (Proposed Baseline) | 24baf3775f0badae2ef2a3abaf8d4bcedd0a0afcf9b05768c0280fabe1320c7d | Not run - migration pending | Planned byte-preserving move | `docs/plans/2026-09-26-runbook-foundation-workstation.md` | Not run - migration pending |
| `docs/superpowers/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md` | `docs/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md` | Repository-wide plan (Draft) | 0f085a6105ca6e04892a01187fd3f1ff8e852af6bd953e2b8781ca0060b5cb71 | Not run - migration pending | Planned byte-preserving move | `docs/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md` | Not run - migration pending |
| `docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md` | `docs/specs/2026-09-25-tenant-2-ai-builder-models-design.md` | Repository-wide specification (Draft) | d8c31d2f5d56d49cf908222b8498dab5f578bcfc9356768252f122f84b0c6fdc | Not run - migration pending | Planned byte-preserving move | `docs/specs/2026-09-25-tenant-2-ai-builder-models-design.md` | Not run - migration pending |
| `docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md` | `docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md` | Repository-wide specification (Draft) | d9954cc0f4fa5a2b0bcde291626e7029534c180d72d6363a8615e58798aa4e2c | Not run - migration pending | Planned byte-preserving move | `docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md` | Not run - migration pending |
| `docs/operating-model/00-north-star.md` | `docs/archive/phase-2-operating-model/00-north-star.md` | Immutable historical snapshot (Superseded) | 3703b4e925594a7a3c18f317eaa876eb2feb8fa10d3ae5ded2c688dc951cfef4 | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/00-north-star.md` | Not run - migration pending |
| `docs/operating-model/01-prd.md` | `docs/archive/phase-2-operating-model/01-prd.md` | Immutable historical snapshot (Superseded) | 32693db435ebe9a75f9b33b641d6ab1bb48a9ab1d9c2cb93c84dac8d46ac0cf6 | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/01-prd.md` | Not run - migration pending |
| `docs/operating-model/02-system-design.md` | `docs/archive/phase-2-operating-model/02-system-design.md` | Immutable historical snapshot (Superseded) | 774403be1636ab8816e706e112ffd2b24745f91354af0cf99302f55539b378c6 | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/02-system-design.md` | Not run - migration pending |
| `docs/operating-model/03-agent-operating-model.md` | `docs/archive/phase-2-operating-model/03-agent-operating-model.md` | Immutable historical snapshot (Superseded) | 7e572ba85e309125bab3559c4a4f3cb2963d01889e7da4a052dc340ea5797c33 | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/03-agent-operating-model.md` | Not run - migration pending |
| `docs/operating-model/04-hitl-governance.md` | `docs/archive/phase-2-operating-model/04-hitl-governance.md` | Immutable historical snapshot (Superseded) | 9863ef687d48c8df7070c4ccfd23d1bb633206f8c7b4f971ce9556f94e5538e6 | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/04-hitl-governance.md` | Not run - migration pending |
| `docs/operating-model/05-implementation-roadmap.md` | `docs/archive/phase-2-operating-model/05-implementation-roadmap.md` | Immutable historical snapshot (Superseded) | c0b7ac25792ec3905e94fc19546d50befeec62b319d1e5114fca432789de7bbd | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/05-implementation-roadmap.md` | Not run - migration pending |
| `docs/90-microsoft-best-practice-evaluation.md` | `docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md` | Immutable historical snapshot (Superseded) | 00956bdea42e8642b19a3cfd0c44fbb0fd30458667bb65e34beac42fc8e49889 | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md` | Not run - migration pending |
| `hr/docs/20-hr-employee-journey.md` | `docs/archive/phase-2-operating-model/20-hr-employee-journey.md` | Immutable historical snapshot (Superseded) | 066ec9dfa5de630ca3856970b7e7fc200893ca4fdff559d490a798436a66c4e4 | Not run - migration pending | Planned byte-preserving archive move | `docs/archive/phase-2-operating-model/20-hr-employee-journey.md` | Not run - migration pending |
| `docs/brandkit/README.md` | — | Placeholder-only root (Active (consolidated from current state)) | 52545d4e352db87377872f2c507211d2588511c59cbce887777a1546aaa8f830 | Not run - migration pending | Planned removal | `docs/brand/` | Not run - migration pending |
| `docs/business/README.md` | — | Placeholder-only root (Active (consolidated from current state)) | 4ce0ae94eb0fb272623093fec07604ce66a3a642b508a3e0fa547e15c0ec15b4 | Not run - migration pending | Planned removal | `docs/README.md` | Not run - migration pending |
| `docs/delegation/README.md` | — | Placeholder-only root (Active (consolidated from current state)) | fcd3f93bc428754bcd4572f92af827c8528b8609e99b9ff743f83583a898e7f1 | Not run - migration pending | Planned removal | `docs/README.md` | Not run - migration pending |
| `docs/issues/README.md` | — | Placeholder-only root (Active (consolidated from current state)) | 242d67904e7ce4a02a51dca37bd0de02c2f1bed993aaa5348873c61abd49fa25 | Not run - migration pending | Planned removal | `docs/README.md` | Not run - migration pending |
| `docs/sprints/README.md` | — | Placeholder-only root (Active (consolidated from current state)) | 8ac34a9eb99fd7a09e66f4215a7788a179a95145a69b641a25f0ea481a71851e | Not run - migration pending | Planned removal | `docs/README.md` | Not run - migration pending |
| `docs/templates/README.md` | — | Placeholder-only root (Active (consolidated from current state)) | 542dbf2424fd6aa3cd1a85af4bb104cf8c5d714e9f4760b42e1b9e303cde8c69 | Not run - migration pending | Planned removal | `docs/README.md` | Not run - migration pending |
| `docs/brand/` | `docs/brand/` | Canonical brand root (5 tracked files; 2 baseline-manifest candidates) | Per-file hashes in baseline manifest for eligible README.md and HTML companion | Not run - migration pending | Retain canonical root | `docs/brand/` | Not run - migration pending |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20260930094537354Z-34bf8987/source/a01-CAND-2026-0411-brunner.pdf` | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20260930094537354Z-34bf8987/source/a01-CAND-2026-0411-brunner.pdf` | Immutable AI Builder evaluation-evidence PDF | 9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd | Not run - migration pending | Retain at current path | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20260930094537354Z-34bf8987/source/a01-CAND-2026-0411-brunner.pdf` | Not run - migration pending |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20261001110252111Z-ab4fa091/source/g01-arbeitsvertrag-CAND-2026-0411.pdf` | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20261001110252111Z-ab4fa091/source/g01-arbeitsvertrag-CAND-2026-0411.pdf` | Immutable AI Builder evaluation-evidence PDF | b38d977460a8d3f865662bb33a1af0342fb54975c37d18f8c54cf29ec41c0488 | Not run - migration pending | Retain at current path | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20261001110252111Z-ab4fa091/source/g01-arbeitsvertrag-CAND-2026-0411.pdf` | Not run - migration pending |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930114811428Z-ed0cd329/source/a06-CAND-2026-0416-gerber.pdf` | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930114811428Z-ed0cd329/source/a06-CAND-2026-0416-gerber.pdf` | Immutable AI Builder evaluation-evidence PDF | 4b1110d9c394a709fbcf6dc39c3ebf20846114e4bb2f818e7dad0118e52ac5db | Not run - migration pending | Retain at current path | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930114811428Z-ed0cd329/source/a06-CAND-2026-0416-gerber.pdf` | Not run - migration pending |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930123933155Z-211c905d/source/b06-CAND-2026-0422-schnyder.pdf` | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930123933155Z-211c905d/source/b06-CAND-2026-0422-schnyder.pdf` | Immutable AI Builder evaluation-evidence PDF | 2dd65e48932173a72cbfc0cad0f1bbe01b997e6a28eea60f5a2e8c5d2737a8b6 | Not run - migration pending | Retain at current path | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930123933155Z-211c905d/source/b06-CAND-2026-0422-schnyder.pdf` | Not run - migration pending |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930130912974Z-b30d5e0a/source/c06-CAND-2026-0428-frei.pdf` | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930130912974Z-b30d5e0a/source/c06-CAND-2026-0428-frei.pdf` | Immutable AI Builder evaluation-evidence PDF | dc512e6545293d6532effc196f56322f12cc1b2a89ef3eb31c46c90b1ddcece4 | Not run - migration pending | Retain at current path | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930130912974Z-b30d5e0a/source/c06-CAND-2026-0428-frei.pdf` | Not run - migration pending |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930131319261Z-e8d57452/source/d06-CAND-2026-0434-ochsner.pdf` | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930131319261Z-e8d57452/source/d06-CAND-2026-0434-ochsner.pdf` | Immutable AI Builder evaluation-evidence PDF | 5ccc73225f0b12c937ea46d1f0566c5869e38f2756c73dc0b648044203fa74fa | Not run - migration pending | Retain at current path | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930131319261Z-e8d57452/source/d06-CAND-2026-0434-ochsner.pdf` | Not run - migration pending |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/task6-retry-remote-source-mismatch.pdf` | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/task6-retry-remote-source-mismatch.pdf` | Immutable AI Builder evaluation-evidence PDF | 74c042e2419054136cc512c58ae252b9803f2a6cd7bdfc9d8acff2b04bc4b618 | Not run - migration pending | Retain at current path | `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/task6-retry-remote-source-mismatch.pdf` | Not run - migration pending |
| `docs/reviews/2026-09-17-architecture-baseline-source-inventory.json` | `docs/reviews/2026-09-17-architecture-baseline-source-inventory.json` | Immutable historical source inventory | b02025c290613173433d1c09ad9b2c459f01033983603ab677a87f7a09d5598d | Not run - migration pending | Retain unchanged at current path | `docs/reviews/2026-09-17-architecture-baseline-source-inventory.json` | Not run - migration pending |
| `infra/docs/20-tenant-trust-activation-runbook.md` | `infra/docs/20-tenant-trust-activation-runbook.md` | Operational stop notice (Superseded) | d0004594fb0763bb0e56b274b2e963a4c27b044b8d659c3864b6662bc5b4ff05 | Not run - migration pending | Retain at operational path | `infra/docs/20-tenant-trust-activation-runbook.md` | Not run - migration pending |
| `infra/docs/21-azure-boards-population-runbook.md` | `infra/docs/21-azure-boards-population-runbook.md` | Operational stop notice (Superseded) | 1b1e432ba88e7d5b961e0d8a3a92f97a2776290653de6adb1f45eaab69941d22 | Not run - migration pending | Retain at operational path | `infra/docs/21-azure-boards-population-runbook.md` | Not run - migration pending |
| `infra/docs/runbooks/02-cloud-service-foundation.md` | `infra/docs/runbooks/02-cloud-service-foundation.md` | Operational stop notice (Superseded) | feed34c42660e98b2ecbfb05f21046a070cfd200e39973ca10d54e737aac0415 | Not run - migration pending | Retain at operational path | `infra/docs/runbooks/02-cloud-service-foundation.md` | Not run - migration pending |

### Grouped and Retained-Root Evidence Contract

- The synthetic corpus group contains exactly 48 PDFs at baseline: 6 under each of the four fixed-template document families and 24 under the general-documents set. Tasks 2 and 6 must resolve every old path to its new use-case path and compare every target SHA-256 with the corresponding per-file value in the baseline manifest; an aggregate count alone is insufficient.
- `docs/brand/` contains five tracked files at baseline. The baseline manifest records the two files selected by the approved evidence extension filter (`README.md` and the HTML companion); `.gitkeep`, TypeScript, and CSS remain outside that manifest filter and are not migration-move candidates.
- `docs/archive/` is retained and populated. Its existing eligible `README.md` hash is in the baseline manifest; the eight incoming snapshots are recorded individually above.
- The seven evaluation-evidence PDFs, the source inventory JSON, and all three superseded operational stop notices are explicit retained controls and must remain at their listed paths.

## Validation Summary

| Command | Result |
|---|---|
| `Invoke-Pester` for `DocumentationMetadata.Tests.ps1` | Passed - combined run: 175 passed, 0 failed, 0 skipped, 0 not run |
| `Invoke-Pester` for `DocumentationLinks.Tests.ps1` | Passed - combined run: 175 passed, 0 failed, 0 skipped, 0 not run |
| `git diff --check` | Passed (exit 0) |
| Baseline manifest path and checkout-form hash audit | Passed - 458 sorted paths and lowercase SHA-256 values matched commit `de0f222db262a36242b6c50b30c0c49f1b1334df` |
| Tasks 2-6 post-move SHA-256 comparisons | Passed - 78 individual files matched; both protected manifests retained their pinned hashes |

## Rollback Evidence

The baseline manifest records the baseline commit plus the lowercase SHA-256 of every selected tracked candidate. Git commit `de0f222db262a36242b6c50b30c0c49f1b1334df` is the rollback source for every planned move, merge, or removal. Later tasks must stop on a collision or hash mismatch, restore the affected bounded slice from that commit, and record the failure here before proceeding. No rollback has been required at baseline.

## Exceptions and Failures

No exception or failure is recorded at baseline.

## Task 2 - Central Ideas and HR Use-Case Detail

Task 2 executed from clean Task 1 commit `53b07c0974b40b2d8b0046ab438c633f034f4ee3` on branch `feat/documentation-knowledge-architecture-cleanup`. The Task 1 baseline manifest at commit `de0f222db262a36242b6c50b30c0c49f1b1334df` remained unchanged.

### Disposition

- Replaced the placeholder `docs/ideas/README.md` with the single repository-wide idea lifecycle and catalogue.
- Merged the substantive HR portfolio guidance from `hr/docs/ideas/README.md`, then removed that retired catalogue and root.
- Moved 19 permanent `UC-nnnn` idea records and the HR Control Plane idea/HTML companion into `docs/ideas/`.
- Retained UC-0001 centrally, changed its metadata status to `Graduated`, and linked its HR detail, governing specification, and implementation plan without adding an Azure Boards ID.
- Moved the remaining 69-file UC-0001 package by identical relative suffix from `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/` to `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/`.
- Created `hr/docs/use-cases/README.md` as the HR detail catalogue.
- Updated active navigation, ownership, intake, metadata, safety, corpus, evidence, and operator consumers. `hr/evidence/ai-builder/` remained in place.
- Repaired active links in `docs/specs/2026-09-25-azure-boards-population-design.md`, `docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md`, and the moved SharePoint guidance after the link contract identified them as move-coupled consumers.
- Did not change Azure Boards configuration or execution code, GitHub workflows, vendored `.github/skills/`, live systems, or the baseline manifest.

Git recognized 90 renames: 21 central idea/mockup moves and 69 UC-0001 package moves. The retired HR catalogue is one deletion. The central catalogue is one in-place rewrite. The new navigation test and HR use-case catalogue are additions.

### Central move hashes

Changed Markdown hashes are expected and reviewed because each moved record required a relative-link repair; UC-0001 also required its graduation metadata and successor links. The HTML companion moved byte-identically.

| Old path | New path | Baseline SHA-256 | Task 2 SHA-256 |
|---|---|---|---|
| `hr/docs/ideas/hr-control-plane-mockup-idea.md` | `docs/ideas/hr-control-plane-mockup-idea.md` | `a45b7e1b81d9bfbd1bb17e8019732fb41040e0741fee5b960436fdd68a242a58` | `404e59d8f3334e8198e4082b9d0646bb1e1d55657a91798055d151ab26aedae5` |
| `hr/docs/ideas/hr-control-plane-mockup.html` | `docs/ideas/hr-control-plane-mockup.html` | `9d86855de31495384f8c852d69cfb304e8629e757f802f1ad9f5217b64e73623` | `9d86855de31495384f8c852d69cfb304e8629e757f802f1ad9f5217b64e73623` |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/uc-0001-personal-master-data-completion-agent.md` | `docs/ideas/uc-0001-personal-master-data-completion-agent.md` | `de085dd356b23c5c2f6c739cb522cf1e25c2fd1e8df2b6289bab230c8aca47c3` | `f526c280a221d5e8aa1c11c50bf80cca4540206d860d7e6cba2afa89e6f29448` |
| `hr/docs/ideas/uc-0002-hr-policy-chat-assistant.md` | `docs/ideas/uc-0002-hr-policy-chat-assistant.md` | `72166839c393e8bc768c6d9095a959c50627e18fcc2ac5fabab3fe351ddcf645` | `789297fbbb486905bfc9e817fc4610cd160eb0a2cd0cbbae7d4c305fa14063a5` |
| `hr/docs/ideas/uc-0003-employee-self-service-assistant.md` | `docs/ideas/uc-0003-employee-self-service-assistant.md` | `4e48e3363ac2b70483ea55bdc8490ecbd2e64ccfed6ccfc12871c85ea8bd4db7` | `ded05234b95af3283ff11434a5be331a997cda15e3dd655d09a942b08c11a391` |
| `hr/docs/ideas/uc-0004-hr-case-classification-bot.md` | `docs/ideas/uc-0004-hr-case-classification-bot.md` | `c2b486c54fda4d77f29217b82c33262835c61b773475e8583c9c58c99d55a129` | `aa87cd15486c30861a5773524371c91eaec23459cd07726cb43a6ca1a4c251a8` |
| `hr/docs/ideas/uc-0005-onboarding-assistant.md` | `docs/ideas/uc-0005-onboarding-assistant.md` | `1dcb455831362bfff8e8ee0746b2d5224da16531c4149db36e0862afbcedd53d` | `41b5fc744a0f7663b18c2aa51fb5a44d997ece2121b1fcb5e05798ae0306c4ef` |
| `hr/docs/ideas/uc-0006-job-description-generator.md` | `docs/ideas/uc-0006-job-description-generator.md` | `36b11009da7b0a07a18c7c84672dd4990e065906189419e9b5252cad2bb0ae2b` | `5a8401179aac2087468f263c6bee72f3c0b6474c0db129397f7bfa61fc118e62` |
| `hr/docs/ideas/uc-0007-candidate-screening-summary.md` | `docs/ideas/uc-0007-candidate-screening-summary.md` | `c531ff49c423e0f8249571709dfe2a7d694ef57dc00a8adb517b4424c81140d1` | `e6f57bf4d40a1ce91cd0ef8cabc42f31b5a36083392edb441d8c9179364797a6` |
| `hr/docs/ideas/uc-0008-salary-benchmark-assistant.md` | `docs/ideas/uc-0008-salary-benchmark-assistant.md` | `04350e480c42139534ed3c49fd0b0436a9e2a8f2211a890df1701d729407e7d2` | `9b3380fc57e4b68493a2bff5f58cdd1d5962be647bb7bef6408d352acfccb894` |
| `hr/docs/ideas/uc-0009-workforce-insights-assistant.md` | `docs/ideas/uc-0009-workforce-insights-assistant.md` | `0e573f60d46d237ab51b322830a638ecbda9d4bcf4d503cb9f673071ef9ea93e` | `52459ec842499564a4369fa134851691dfc4e2e26808456e8f7f3bcaa3daa5f8` |
| `hr/docs/ideas/uc-0010-employee-data-validation-bot.md` | `docs/ideas/uc-0010-employee-data-validation-bot.md` | `b932373f148b426e3bba84d03e9e9a4f628ec98aaea8724ac63e1369f6387883` | `75e5e8aff724c55d34e00cff9317ea9d364f47f29ad3cf796c2dcf2b4bef08a7` |
| `hr/docs/ideas/uc-0011-learning-recommendation-agent.md` | `docs/ideas/uc-0011-learning-recommendation-agent.md` | `a4da6580adf7554853c66e96151ddbda361848f79c2959aa9a9af82b7f4bda06` | `cae8d66d3a8ab05bfc33176f4e607587fee370931be9bed858b37fd045a047a2` |
| `hr/docs/ideas/uc-0012-payroll-anomaly-detection.md` | `docs/ideas/uc-0012-payroll-anomaly-detection.md` | `6f5507ab86c0dded845ac385e79b0f7371338395c8bf14e1ad21e271802d79aa` | `476fd033660afa4ad6f20024f3f1d5d3a52433788bf3c1e614a9331e2ec43e95` |
| `hr/docs/ideas/uc-0013-performance-review-draft-assistant.md` | `docs/ideas/uc-0013-performance-review-draft-assistant.md` | `f45043a9e6c35b61dbe91ee9462800a7753ce335cc36853f97f7b4b119598803` | `4c93714cf5d23b1121a14c5aaaed382a3c32ba190a98cea079fe084092e16ca9` |
| `hr/docs/ideas/uc-0014-continuous-performance-insights.md` | `docs/ideas/uc-0014-continuous-performance-insights.md` | `7c7d5fa5707e646cb952e725e9681483258bd960caeafd441856d1480aa62c8e` | `3475453e0c3571ede569c301eed9eb290c57da17aecb33f98065d4f33a229998` |
| `hr/docs/ideas/uc-0015-leadership-pipeline-prediction.md` | `docs/ideas/uc-0015-leadership-pipeline-prediction.md` | `a2d90649fbc396bd38e34a60b5dd8f00351f8246edd1e104e6e21012deef625f` | `eda34467a82cee159da116a57606204574e3bae983cc1edcadecd40d4555eadc` |
| `hr/docs/ideas/uc-0016-skills-inference-engine.md` | `docs/ideas/uc-0016-skills-inference-engine.md` | `c1534b65a222ad6629b7b00b32f686df42e7825a588f30f3d3332b532dc03db2` | `0e0d643623777e72bad31950aed7321484088cfe4f73b6bd4d08350b77b9ec75` |
| `hr/docs/ideas/uc-0017-pre-hire-process-orchestration.md` | `docs/ideas/uc-0017-pre-hire-process-orchestration.md` | `653065f6a473adf18edeea137ad900c364c39cce59a4f96ed6df03747c70480f` | `97c8dc7499b1075e4a6c129c25c59990b37f5452af13b609c9440e8bcd351465` |
| `hr/docs/ideas/uc-0018-onboarding-checklist-rebuild.md` | `docs/ideas/uc-0018-onboarding-checklist-rebuild.md` | `b09dc195a7a5480cfbd05ebd3c993c3d26c032578b349603f365f810e0d1542a` | `23972508d262ab4608215df16817693d7f0e93afa07de37532a331971827b7e4` |
| `hr/docs/ideas/uc-0019-attrition-risk-insight-lite.md` | `docs/ideas/uc-0019-attrition-risk-insight-lite.md` | `47d32eb425a6d1194d07f7aa8ddaf4eed76dede89a760142b59c83297045b264` | `b954e0f6941042a20b4733f350f04e688de22a44bcbdde381304f961aeeaf440` |

The rewritten `docs/ideas/README.md` has Task 2 SHA-256 `e3c399035beda41f1c2d6f83f6abf9e83f0117c780fbf5a85b4130920ffb926f`. The new `hr/docs/use-cases/README.md` has SHA-256 `49ad2f0f99df14bca18a24deebd2a9d02cd2c921dde56db0e90973e7e11f1b76`.

### UC-0001 package move and hashes

All 69 package files moved by retaining the suffix below the old and new roots. Sixty non-Markdown artifacts were compared individually to the Task 1 manifest: 48 PDFs, 2 CSV files, 2 JSON files, and 8 Python generators all matched. Four Markdown files also matched their baseline bytes:

| New path | Verified SHA-256 |
|---|---|
| `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/README.md` | `1430e64bfe16ed4ebaa057a25f4682e3a93db58bfd5ecef237947ca6033c9166` |
| `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/README.md` | `ddef36f96ee8921ce9fd86863d9d7915332a151ee3cf86f318c117148014e9f1` |
| `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/document-intake-architecture.md` | `bc05ba262f2373aa2b3d89bacb280493922ab4775e055b290e4ce8face3fba57` |
| `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/prd-0001-personal-master-data-completion-agent.md` | `be17e53550d66823b3a142762df9319caaffe32c68762029fc3c6d6f5adcd4a5` |

Five moved Markdown files changed only for approved navigation, metadata-scope, or reference repairs:

| Old path | New path | Baseline SHA-256 | Task 2 SHA-256 |
|---|---|---|---|
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/README.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/README.md` | `a0d6e12367b96457b27ff455934c27b3250171ddaff3408df40d51de413d68e9` | `450f84b4d9c74607483aa9ebaf2bb078c2f48224e1e6410e8d4822a07d639faf` |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/ai-builder-model-setup.md` | `37af81712f71a9dfdb09fcdd9d12353018fa6f6bcb2703b96136f1f54756f65c` | `d7e39c869127ab6603a241ca45cb7997055f7d14be27e12d4b44d7ce1dffbb4d` |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0001-peopledoc-master-data-ai-builder-fields.md` | `9581dc504b12ba483fae1b556e12ee610952d092e126e3384a704c7ea8683eb1` | `d4303d922f6eeee5f1e9bc29efed431f46da8d3b424ecac3785d808b37546168` |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/bom-0002-ai-builder-test-inputs-and-outcomes.md` | `bbc873d96a54ef981c6510b4928ed3ca02925681957b2c2f3105d7074a988a46` | `8cce7470551ad66efffc330535471a943d29592d5ebb34c62505f53fe72de68e` |
| `hr/docs/ideas/uc-0001-personal-master-data-completion-agent/sharepoint-knowledge-vs-processing.md` | `hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/sharepoint-knowledge-vs-processing.md` | `d0e68e166748252ffabcb07a6c1fda6e37e07e429aa601d334dafecba19cb174` | `23306dfb8873e963e6e5a81de0046b2b9a5aaa91f3eb899b723a2978c427c5b1` |

### Retained immutable evidence PDFs

| Retained path | Verified SHA-256 | Disposition |
|---|---|---|
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20260930094537354Z-34bf8987/source/a01-CAND-2026-0411-brunner.pdf` | `9c7ebe8d706b5b6ee98d779bcd83a578f8dff44b9b6bd7d02bff2b64e2ba67bd` | Verified in place |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/cap-20261001110252111Z-ab4fa091/source/g01-arbeitsvertrag-CAND-2026-0411.pdf` | `b38d977460a8d3f865662bb33a1af0342fb54975c37d18f8c54cf29ec41c0488` | Verified in place |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930114811428Z-ed0cd329/source/a06-CAND-2026-0416-gerber.pdf` | `4b1110d9c394a709fbcf6dc39c3ebf20846114e4bb2f818e7dad0118e52ac5db` | Verified in place |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930123933155Z-211c905d/source/b06-CAND-2026-0422-schnyder.pdf` | `2dd65e48932173a72cbfc0cad0f1bbe01b997e6a28eea60f5a2e8c5d2737a8b6` | Verified in place |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930130912974Z-b30d5e0a/source/c06-CAND-2026-0428-frei.pdf` | `dc512e6545293d6532effc196f56322f12cc1b2a89ef3eb31c46c90b1ddcece4` | Verified in place |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/capture/fixed-holdout/cap-20260930131319261Z-e8d57452/source/d06-CAND-2026-0434-ochsner.pdf` | `5ccc73225f0b12c937ea46d1f0566c5869e38f2756c73dc0b648044203fa74fa` | Verified in place |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/task6-retry-remote-source-mismatch.pdf` | `74c042e2419054136cc512c58ae252b9803f2a6cd7bdfc9d8acff2b04bc4b618` | Verified in place |

### Task 2 validation results

| Command or gate | Outcome |
|---|---|
| RED: `DocumentationNavigation.Tests.ps1` plus `DocumentationMetadata.Tests.ps1` | Expected failure observed: 174 passed, 4 failed; missing new root, retained old root/records, and unsupported `Graduated` were all detected |
| Focused `Graduated` metadata test | Passed: 1 passed, 0 failed |
| Task 1 hash comparison for moved `.pdf`, `.csv`, `.json`, and `.py` files | Passed: 60 of 60 matched (`.pdf` 48, `.csv` 2, `.json` 2, `.py` 8) |
| Task 1 hash comparison for retained evidence PDFs | Passed: 7 of 7 matched at unchanged paths |
| First full targeted run | 422 passed, 1 failed; the documentation-link test identified ten stale links across five move-coupled files |
| Focused documentation-link rerun after root-cause repair | Passed: 1 passed, 0 failed |
| Required targeted eight-file Pester run | Passed: 423 passed, 0 failed, 0 skipped, 0 not run |
| `.github/cli/verify-repository-safety.ps1` | Passed: `Repository safety validation passed.` |
| `git diff --check` | Passed (exit 0) |
| VS Code problem diagnostics for changed PowerShell files | No errors found |
| Protected-surface diff from `53b07c0` | Passed: no changes under `.github/workflows`, `infra/src/config`, `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1`, or the baseline manifest |

No rollback was required. The one non-green full targeted run was retained as diagnostic evidence, repaired at the active source links, and followed by a complete green rerun.

## Task 3 - Canonical Specifications and Plans

Task 3 removed the repository-owned `docs/superpowers/` documentation root and consolidated its two specifications and five implementation plans under the canonical roots. The Task 3 start hashes below were observed at `b6c7920fbb762946320e1d76bcbd6ad267d8364d`, after Task 2 link repairs and before these moves. Result hashes include only move-coupled canonical path and relative-link repairs.

| Old path | Canonical path | Task 3 start SHA-256 | Task 3 result SHA-256 | Disposition |
|---|---|---|---|---|
| `docs/superpowers/specs/2026-09-25-tenant-2-ai-builder-models-design.md` | `docs/specs/2026-09-25-tenant-2-ai-builder-models-design.md` | `9121f564fcd401dc7a583486d99bebe23625a35890355b643d288094e1179710` | `2ab1fee0c019ccd126fd267b8b1bb7d77ce51015251c2aa97b42d95f2c7b91a5` | Moved; repaired canonical ADR, specification, PRD, and BoM links. |
| `docs/superpowers/specs/2026-09-29-ai-builder-evaluation-capture-design.md` | `docs/specs/2026-09-29-ai-builder-evaluation-capture-design.md` | `d9954cc0f4fa5a2b0bcde291626e7029534c180d72d6363a8615e58798aa4e2c` | `76ec75e6352e44a884f286153b54bdc1d04f04ed267fcaacba83051b10b6440a` | Moved; repaired canonical ADR and retained-evidence links. |
| `docs/superpowers/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md` | `docs/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md` | `6baf1ed8d277e04162d73dc5485d5aaaa5c567ac97785c48b64e94d0f8fe69a1` | `191f7aab8824c5e20d28626ee1caf38d257f7890b687cf5d1f7356b923b06556` | Moved; replaced the explicit legacy specification label with the canonical path. |
| `docs/superpowers/plans/2026-09-26-runbook-cloud-foundation.md` | `docs/plans/2026-09-26-runbook-cloud-foundation.md` | `d022fc916f0bbde92c9cb1486758a792631090bb07f52477204c71d29e58ce4d` | `03c8b4aa8903d41fe82fef8a85c8b8800da02dc5d59c6b91f2111922bcb83d97` | Moved; repaired metadata links for the canonical plan depth. |
| `docs/superpowers/plans/2026-09-26-runbook-customer-handover.md` | `docs/plans/2026-09-26-runbook-customer-handover.md` | `d18979cb8887f06bc55636f2838ae132689aa5f95d0fa725ad71ce994aa54a5b` | `a61988b808ac5e38384bdf9a881a06ed4ee1965051352d54d62e58583fe1b3ad` | Moved; repaired metadata links and the plan's explicit self-path. |
| `docs/superpowers/plans/2026-09-26-runbook-foundation-workstation.md` | `docs/plans/2026-09-26-runbook-foundation-workstation.md` | `24baf3775f0badae2ef2a3abaf8d4bcedd0a0afcf9b05768c0280fabe1320c7d` | `471d2d85e5decb49b364a396b784ebe81a0748e63199a2c6ae5e0a5ce405c886` | Moved; repaired metadata links for the canonical plan depth. |
| `docs/superpowers/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md` | `docs/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md` | `0f085a6105ca6e04892a01187fd3f1ff8e852af6bd953e2b8781ca0060b5cb71` | `dad0d1e34f38a12c29f8d19249c3a0bb4cb54dec2c2686a17c0f67a5d26934fc` | Moved; repaired the documentation-policy link and explicit specification path. |

Active AI Builder consumers now reference `docs/specs/` and the already canonical `hr/docs/use-cases/` BoMs. `DocsAgentContract.Tests.ps1` reads the moved AI Builder design from `docs/specs/`. The repository-owned placement override is recorded in `.github/copilot-instructions.md` and referenced from `AGENTS.md`; vendored skills remain unchanged.

The specification catalogue lists all 18 direct Markdown children other than `README.md` exactly once. The plan catalogue lists all 21 direct Markdown children other than `README.md` exactly once. Catalogue statuses match the documents' metadata, and every row records purpose, authority, and a linked successor or next stage.

### Task 3 validation results

| Command or gate | Outcome |
|---|---|
| RED: `DocumentationNavigation.Tests.ps1` | Expected failure observed: 3 passed, 2 failed; the legacy root still existed and canonical targets were absent. |
| First GREEN attempt | 4 passed, 1 failed; all seven canonical targets existed, but empty physical `docs/superpowers/plans/` and `docs/superpowers/specs/` directories remained after `git mv`. |
| Focused GREEN rerun after verified empty-directory removal | Passed: 5 passed, 0 failed. |
| Catalogue completeness and status comparison | Passed: 18 specifications and 21 plans, each listed exactly once with matching metadata status. |
| Required four-file Pester run | Passed: 186 passed, 0 failed, 0 skipped, 0 not run. |
| `git diff --check` | Passed (exit 0). |
| VS Code problem diagnostics for changed PowerShell tests | No errors found. |
| Protected-surface diff | Passed: no changes below `.github/skills/`, `.github/workflows/`, `docs/archive/`, `infra/src/config/`, or the baseline manifest. |

No Azure Boards configuration, workflow, live system, corpus binary, immutable evidence binary, archive path, or baseline-manifest content was changed.

## Task 4 - Immutable Phase 2 Archive and Governance Routing

Task 4 executed from clean Task 3 commit `363d61bfb1f2026a1ff777ee7ef132e704fcebbe` on branch `feat/documentation-knowledge-architecture-cleanup`. The Task 1 migration baseline remained unchanged with `baselineCommit` `de0f222db262a36242b6c50b30c0c49f1b1334df`.

### Archived snapshots

The source inventory remains an immutable record of the eight originally imported Phase 2 bytes at their original paths. The on-disk archive contract separately pins the bytes present at the Task 1 migration baseline. Each file moved with `git mv`; no snapshot metadata, content, or internal link was edited.

| Original path | Archive path | Source-inventory SHA-256 | Task 1 pre-move and Task 4 post-move SHA-256 |
|---|---|---|---|
| `docs/operating-model/00-north-star.md` | `docs/archive/phase-2-operating-model/00-north-star.md` | `7be5151f04031f4f36e58b80d741ad40c8beb2b26a4dd5ddf8363f318fe9f025` | `3703b4e925594a7a3c18f317eaa876eb2feb8fa10d3ae5ded2c688dc951cfef4` |
| `docs/operating-model/01-prd.md` | `docs/archive/phase-2-operating-model/01-prd.md` | `7fdc213f864cff3cd0e4755e073b0a23fbf797953132b8a94fab55e8548204a3` | `32693db435ebe9a75f9b33b641d6ab1bb48a9ab1d9c2cb93c84dac8d46ac0cf6` |
| `docs/operating-model/02-system-design.md` | `docs/archive/phase-2-operating-model/02-system-design.md` | `e0b6ff1c43ae0954bb51edf1993ddd9a6d81376834849a756335034bdd1d88e6` | `774403be1636ab8816e706e112ffd2b24745f91354af0cf99302f55539b378c6` |
| `docs/operating-model/03-agent-operating-model.md` | `docs/archive/phase-2-operating-model/03-agent-operating-model.md` | `556efcd4af83d221fbe055bbea468d20585112e8d302a4b8ada28514867888a7` | `7e572ba85e309125bab3559c4a4f3cb2963d01889e7da4a052dc340ea5797c33` |
| `docs/operating-model/04-hitl-governance.md` | `docs/archive/phase-2-operating-model/04-hitl-governance.md` | `8c98c9d1d839d92711b01d651b8277cdd67bf61bb81c29c1defb9a5d6eb1de2b` | `9863ef687d48c8df7070c4ccfd23d1bb633206f8c7b4f971ce9556f94e5538e6` |
| `docs/operating-model/05-implementation-roadmap.md` | `docs/archive/phase-2-operating-model/05-implementation-roadmap.md` | `8698e90d24f7f2809c7c4208769395e9296f39fe4323f8edbe33b4ec0fb2c509` | `c0b7ac25792ec3905e94fc19546d50befeec62b319d1e5114fca432789de7bbd` |
| `docs/90-microsoft-best-practice-evaluation.md` | `docs/archive/phase-2-operating-model/90-microsoft-best-practice-evaluation.md` | `fb4d29d4cf75f7cb659c71b21f83e900a484257e8d2cc06e1a006ec40f1b6031` | `00956bdea42e8642b19a3cfd0c44fbb0fd30458667bb65e34beac42fc8e49889` |
| `hr/docs/20-hr-employee-journey.md` | `docs/archive/phase-2-operating-model/20-hr-employee-journey.md` | `49d6988c476b9866bc3ca6b70cae3d84b48a5e4c6e2918426c5b2b1614464bca` | `066ec9dfa5de630ca3856970b7e7fc200893ca4fdff559d490a798436a66c4e4` |

The maintained `docs/archive/phase-2-operating-model/README.md` is the discovery entry point. It records each snapshot's original purpose and current replacement. The eight exact snapshot paths retain their original internal links and are excluded from live-link traversal; the archive catalogue, archive root, and every other archive artifact remain validated.

### Current governance routing

- Frontier intake now routes proposals into the central repository idea lifecycle and does not promise Azure Boards creation.
- Issue-form contacts route the idea portfolio to `docs/ideas/README.md`.
- Privacy, employment-decision, platform-administration, and escalation rules route to `.github/agent-policy/NON_DELEGABLE_WORK.md`.
- Active infrastructure and HR solution documentation route journey ownership to `docs/hr-journey-and-raci.md`.
- The pull request template uses a repository idea, specification, plan, or verified Azure Boards item as its governing record. `Fixes AB#<id>` is conditional on a later rebuilt and verified synchronization.
- No Azure Boards configuration, GitHub workflow, live system, operational stop notice, vendored skill, corpus byte, or evidence byte changed.

### Task 4 validation results

| Command or gate | Outcome |
|---|---|
| RED: `Phase2SourceContract.Tests.ps1` plus `DocumentationLinks.Tests.ps1` | Expected failure observed: 4 passed, 3 failed; all failures identified missing archive targets before the moves. |
| RED: `DocumentationNavigation.Tests.ps1` plus `IssueFormContract.Tests.ps1` | Expected failure observed: 13 passed, 6 failed; failures identified the legacy directory, missing archive catalogue, retired governance routes, and mandatory Boards wording. |
| Task 1 baseline comparison for the eight moved snapshots | Passed: 8 of 8 post-move SHA-256 values matched their pre-move manifest entries. |
| Exact live-link exclusion audit | Passed: exactly the eight immutable snapshot paths are excluded; neither archive README is excluded. |
| Required five-file Pester run | Passed: 201 passed, 0 failed, 0 skipped, 0 not run. |
| `git diff --check` | Passed (exit 0). |
| VS Code problem diagnostics for changed PowerShell tests | No errors found. |
| Task 1 migration-baseline file | Unchanged; SHA-256 `4001f033a1e683a5a689f18c8b7cd91999a81594dfaf5510fbb77d73cd3ad2b3`. |
| Immutable source-inventory file | Unchanged; SHA-256 `b02025c290613173433d1c09ad9b2c459f01033983603ab677a87f7a09d5598d`. |

No rollback was required.

## Task 5 - Placeholder Retirement and Complete Knowledge Catalogues

Task 5 executed from clean Task 4 commit `1a9dd82d9fabed33b32d8946f545836aef4de8f2` on branch `feat/documentation-knowledge-architecture-cleanup`. The Task 1 migration baseline and the immutable architecture source inventory remained unchanged.

### Disposition

- Removed only the six approved placeholder-only roots: `docs/brandkit/`, `docs/business/`, `docs/delegation/`, `docs/issues/`, `docs/sprints/`, and `docs/templates/`.
- Confirmed that the previously retired `docs/superpowers/`, `docs/operating-model/`, and `hr/docs/ideas/` roots remain absent.
- Completed authoritative direct-child catalogues for `docs/ideas/`, `docs/specs/`, `docs/plans/`, `docs/reviews/`, `docs/adr/`, `docs/brand/`, `docs/archive/`, `docs/archive/phase-2-operating-model/`, `hr/docs/use-cases/`, and `infra/docs/`.
- Added `infra/docs/README.md` as the infrastructure documentation catalogue and updated the platform, HR, infrastructure, and data domain entry points to state purpose, placement, reading order, lifecycle, domain links, and Board synchronization.
- Preserved the eight immutable Phase 2 snapshots byte-for-byte. Their maintained archive READMEs remain active link-validation surfaces.
- Updated repository setup validation to require only canonical documentation roots while preserving the existing `.github/*` entries and protected `.github/skills` handling.
- Reconciled three stale issue-template SHA-256 pins and the stale pull-request heading assertion in the setup validator with the Task 4 artifacts already present at the Task 5 base. No issue template or pull request template changed in Task 5.
- Strengthened the Docs Agent contract so placement, direct-child catalogue maintenance, successor/archive routing, and `Deferred - not synchronized` are mandatory outputs.
- Documented the durable Windows convention `%LOCALAPPDATA%\CaldovaHR\wt\<repository>\<short-task-id>` with a current-user write/delete probe and a checkout path budget below 240 characters. The guidance does not enable `core.longpaths`, change ACLs, or require administrator rights.
- Did not change GitHub workflows, vendored `.github/skills/`, operational stop notices, corpus or evidence bytes, live systems, Azure Boards configuration, the Task 1 baseline manifest, or the immutable source inventory.

### Task 5 validation results

| Command or gate | Outcome |
|---|---|
| RED: `DocumentationNavigation.Tests.ps1` | Expected failure observed: 10 passed, 15 failed, 0 container failures; failures identified incomplete catalogues, the missing infrastructure catalogue, and the six approved placeholder roots. |
| RED: `DocsAgentContract.Tests.ps1` | Expected failure observed: 5 passed, 1 failed; the new mandatory-output contract was absent. |
| Focused GREEN: navigation and Docs Agent contracts | Passed: 31 passed, 0 failed, 0 skipped, 0 not run. |
| Required four-file Pester run | Passed: 207 passed, 0 failed, 0 skipped, 0 not run. |
| First repository setup validation | Failed on three stale Task 4 issue-template hash pins and the stale `## Work item` requirement; investigation confirmed all four governed files were byte-identical to Task 5 HEAD. |
| Repository setup validation after contract repair | Passed: `Repository setup validation passed.` |
| `git diff --check` | Passed (exit 0). |

No rollback was required. The one setup-validation failure was retained as diagnostic evidence, repaired at the stale validation contract, and followed by a successful rerun.

## Task 6 - Retired-Path Boundaries and Full Acceptance

Task 6 executed from clean Task 5 commit
`0f09ff074547dd38e2b9b69575461c65d75b7470` on branch
`feat/documentation-knowledge-architecture-cleanup`. The migration range uses
merge base `6e82b041225794581ed5dc8d015c89481d515b23`. The final acceptance commit is
the commit containing this Active review with subject
`test: verify documentation knowledge migration`; the external Task 6 report
records its resolved SHA-1 after commit creation.

### Final dispositions

| Path or surface | Final disposition |
|---|---|
| `.github/copilot-instructions.md` | Modernized the repository-owned specification and plan placement rule without retaining the literal retired documentation prefix; vendored skills remain unchanged. |
| `docs/plans/2026-09-25-tenant-2-ai-builder-models-implementation.md` | Modernized every forward-slash and backslash-form HR idea package path to the canonical central idea or HR use-case location. |
| `docs/plans/2026-09-29-ai-builder-evaluation-capture-implementation.md` | Modernized every forward-slash and backslash-form HR idea package path to the HR use-case location. |
| `docs/specs/2026-10-01-caldova-branding-migration-design.md` | Modernized the active branding package path to the HR use-case location. |
| `infra/src/scripts/Initialize-AzureDevOpsWorkItems.ps1` | Changed only the default local population source from the retired HR idea root to repository `docs\ideas`; Azure DevOps request, configuration, identifier, and mutation behavior are unchanged. |
| `infra/tests/pester/AzureBoardsPopulation.Tests.ps1` | Added portfolio-only coverage that omits `-IdeasRoot`, verifies all 19 central records, and returns before any Azure DevOps capability query or mutation path. |
| `hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-summary.md` | Restored byte-for-byte to immutable SHA-256 `7b6826dad33d2575a2abd55bc10bd3e38a8f6e07f0c2387d6bd4a75f85a28dd2`; retained as an exact retired-path exception because the historical evidence records the original location. |
| `.github/cli/config/branding-evidence-exceptions.json` | Unchanged; its existing summary hash already equals the immutable baseline value. |
| `infra/README.md` | Retained direct links to the active Tenant 1 runbook, operational runbook package, developer workstation and customer handover procedures, and all three safety-critical superseded stop notices. |
| `infra/docs/README.md` | Unchanged as the complete infrastructure documentation catalogue. |
| `.github/cli/tests/Phase2SourceContract.Tests.ps1` | Unchanged maintained historical-source contract; retained as an exact retired-path exception. |
| `docs/reviews/evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json` | Unchanged immutable Task 1 manifest; retained as an exact retired-path exception. |

The fail-closed scan recognizes both `/` and `\` path separators. This caught
six remaining executable examples in the two AI Builder plans that a
forward-slash-only scan missed; those already ruled active files were
modernized rather than allowlisted.

### RED and GREEN evidence

| Stage | Discovered | Passed | Failed | Skipped | Inconclusive | Not run | Result |
|---|---:|---:|---:|---:|---:|---:|---|
| Focused RED: Board population, branding, cloud-foundation safety, and runbook documentation | 64 | 56 | 8 | 0 | 0 | 0 | Expected failures: five Board default-path cases, one branding hash contract, and two infrastructure root-link contracts. |
| Focused GREEN plus final navigation | 96 | 96 | 0 | 0 | 0 | 0 | Passed after the ruled code, immutable-byte, README, dual-separator scan, and exact allowlist changes. |
| Final navigation contract | 32 | 32 | 0 | 0 | 0 | 0 | Passed with no unallowlisted retired path and no unused exception. |

### Final exact retired-path allowlist

Files below `.github/skills/` remain separately excluded as vendored,
immutable content. The repository-owned exact allowlist is:

```text
.github/cli/tests/Phase2SourceContract.Tests.ps1
docs/plans/2026-09-15-repository-superpowers-implementation.md
docs/plans/2026-09-17-governance-github-intake-implementation.md
docs/plans/2026-09-17-product-hr-operating-model-intake-implementation.md
docs/plans/2026-09-24-hr-solution-functional-design-intake-implementation.md
docs/plans/2026-09-25-azure-boards-population-implementation.md
docs/plans/2026-10-01-caldova-branding-migration-implementation.md
docs/reviews/2026-09-17-architecture-baseline-source-inventory.json
docs/reviews/2026-09-17-phase-2-product-hr-operating-model-intake.md
docs/reviews/2026-09-24-phase-4-hr-solution-functional-design-intake.md
docs/reviews/evidence/2026-10-02-documentation-knowledge-architecture/migration-baseline.json
hr/evidence/ai-builder/tenant-2/DEV/t2-dev-20260925-001/evaluation-summary.md
docs/specs/2026-09-17-architecture-baseline-intake-design.md
docs/specs/2026-09-24-hr-solution-functional-design-intake-design.md
docs/specs/2026-10-02-documentation-knowledge-architecture-cleanup-design.md
docs/plans/2026-10-02-documentation-knowledge-architecture-cleanup-implementation.md
docs/reviews/2026-10-02-documentation-knowledge-architecture-migration-review.md
docs/archive/phase-2-operating-model/20-hr-employee-journey.md
```

### Final hash acceptance

Every selected file was compared individually with its Task 1 baseline entry.
Aggregate SHA-256 values are calculated over sorted
`target-relative-path|individual-sha256` lines.

| Group | Files | Expected aggregate SHA-256 | Actual aggregate SHA-256 | Verdict |
|---|---:|---|---|---|
| Synthetic corpus PDFs | 48 | `becea6c2e0b7a24cd1ee530722e42b00fb75dd9d24c11b780e19de534c9a0fb6` | `becea6c2e0b7a24cd1ee530722e42b00fb75dd9d24c11b780e19de534c9a0fb6` | Pass |
| CSV and JSON truth files | 4 | `ff177838e11bc0365456116b8363494fa7556fbe5f02a94af6f4f088052926ff` | `ff177838e11bc0365456116b8363494fa7556fbe5f02a94af6f4f088052926ff` | Pass |
| Python generators | 8 | `bb4fedd6637dd004fc2344b129c5929a056420ed047dc96e59c011995ed348cb` | `bb4fedd6637dd004fc2344b129c5929a056420ed047dc96e59c011995ed348cb` | Pass |
| Unchanged package READMEs | 2 | `83230a5e9540ec7816b940890c0e6e44d71379e5e94b678b7cbb54452da1cdc1` | `83230a5e9540ec7816b940890c0e6e44d71379e5e94b678b7cbb54452da1cdc1` | Pass |
| Immutable evidence PDFs | 7 | `490a8581cb50062f95ca9676b79b24327c10dcfc4e9174351570608d4c0127e7` | `490a8581cb50062f95ca9676b79b24327c10dcfc4e9174351570608d4c0127e7` | Pass |
| Archived Phase 2 snapshots | 8 | `8478541e77df59f42bd638dd00953bc33788eadb742a426ac55996ce05c1ccef` | `8478541e77df59f42bd638dd00953bc33788eadb742a426ac55996ce05c1ccef` | Pass |
| Immutable evaluation summary | 1 | `f8a8843713b0b32b7eed31d7efa893e24170429a8c9fbb1a49d3b785d885f9e0` | `f8a8843713b0b32b7eed31d7efa893e24170429a8c9fbb1a49d3b785d885f9e0` | Pass |

The 78 individual checks passed. The immutable evaluation summary itself is
SHA-256
`7b6826dad33d2575a2abd55bc10bd3e38a8f6e07f0c2387d6bd4a75f85a28dd2`.
The protected Task 1 manifest remains
`4001f033a1e683a5a689f18c8b7cd91999a81594dfaf5510fbb77d73cd3ad2b3`,
and the protected architecture source inventory remains
`b02025c290613173433d1c09ad9b2c459f01033983603ab677a87f7a09d5598d`.

### Full acceptance

| Command or gate | Outcome |
|---|---|
| Fresh dual-separator retired-path scan | Passed: 446 match lines across 23 paths; 18 exact historical paths and 5 vendored skill paths; 0 unexpected and 0 unused. |
| Complete maintained Pester discovery | Passed: 1,020 discovered; 1,017 passed; 0 failed; 3 skipped; 0 inconclusive; 0 not run; duration 00:17:42.5436572. |
| `.github/cli/verify-repository-safety.ps1` | Passed: `Repository safety validation passed.` |
| Comprehensive `.github/cli/verify-repository-setup.ps1` | Passed: `Repository setup validation passed.` |
| Explicit recursive `az bicep build --stdout` | Passed: 5 of 5 `.bicep` files; 0 failed. |
| Migration-range and working-tree `git diff --check` | Passed. |
| Workflow-neutral checks | Passed: 0 migration-range changes and 0 Task 6 working-tree changes below `.github/workflows/`. |
| Branch and scope checks | Passed on `feat/documentation-knowledge-architecture-cleanup`; 0 forbidden Task 6 changes. |
| Board-neutral checks | Passed: central idea rows remain deferred or not applicable; no central idea contains an `AB#` identifier; no Board operation or configuration changed. |
| Protected change boundaries | Passed: no vendored skill, baseline, source inventory, archive, corpus, workflow, Board configuration, or other evidence file changed. |

## Final Exceptions and Failures

The exact historical allowlist above is the only repository-owned retired-path
exception set. The immutable evaluation summary is the only Task 6 evidence
file changed, and its bytes were restored to the already approved manifest
value. Unresolved failures: `None`.

## Final whole-branch review corrections

### Findings

1. Consolidated the complete approved authority and conflict order in the
   [documentation knowledge map](../README.md) and replaced the divergent
   repository-instruction summary with a link to that section.
2. Marked the maintained
   [Phase 2 archive catalogue](../archive/phase-2-operating-model/README.md)
   and its [parent catalogue row](../archive/README.md) `Active` while
   retaining all eight snapshots as `Superseded`.
3. Replaced the nonexistent environment-setup route with the maintained
   [infrastructure documentation catalogue](../../infra/docs/README.md).
4. Replaced the partial canonical tree with the approved repository routing
   tree and distinguished central `uc-` idea records from detailed HR
   use-case packages.

### Changed files

- [Documentation navigation contract](../../.github/cli/tests/DocumentationNavigation.Tests.ps1)
- [Repository Copilot instructions](../../.github/copilot-instructions.md)
- [Documentation knowledge map](../README.md)
- [Archive catalogue](../archive/README.md)
- [Phase 2 archive catalogue](../archive/phase-2-operating-model/README.md)
- This migration review

### Verification and outcome

| Stage or command | Observed result |
|---|---|
| RED: `DocumentationNavigation.Tests.ps1` | 37 discovered; 32 passed; 5 expected contract failures; 0 skipped, inconclusive, or not run. |
| GREEN: `DocumentationNavigation.Tests.ps1` | 37 discovered; 37 passed; 0 failed, skipped, inconclusive, or not run. |
| GREEN: navigation, metadata, links, and Docs Agent contract suites | 219 discovered; 219 passed; 0 failed, skipped, inconclusive, or not run. |
| `git diff --check` | Passed with no whitespace errors. |

All four final-review findings are corrected. No workflow, Board
configuration or identifier, vendored skill, immutable snapshot, migration
baseline, source inventory, corpus, evidence, or live-system surface changed.
Unresolved concerns: `None`.
