# Repository Clean-Up Runbook

| Field | Value |
|---|---|
| **Version** | 1.0 |
| **Date** | 2026-09-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Proposed Baseline |
| **Scope** | Infrastructure (all tenants) |
| **References** | [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md), [Customer Repository Export and Handover design](../../docs/specs/2026-09-27-customer-repository-export-and-handover-design.md), [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md) |

This runbook removes every other tenant's configuration manifest, discovery evidence, and Bicep parameter file from a freshly seeded copy of this repository, using `infra/src/scripts/Remove-OtherTenantArtifacts.ps1`. It is tenant-agnostic -- the tenant alias to keep is a parameter, not something baked into the runbook -- and is reused by every tenant onboarded under [ADR-0012](../../docs/adr/0012-per-tenant-github-repository-and-account-topology.md), not written as a one-time script for any single tenant.

## Who Can Run This

- Anyone with a local clone of the freshly seeded destination repository and PowerShell 7 or Windows PowerShell 5.1. No Azure, Azure DevOps, or GitHub credentials are required -- this runbook only ever touches files already present in the local working tree.
- Run this **after** seeding the destination repository (Step 2 of the [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md)) and **before** committing anything to the new repository's history.

## Prerequisites Checklist

- [ ] You are working in the **destination** repository's local clone -- not this source repository. Removing another tenant's files from the wrong repository is not reversible by this runbook.
- [ ] You know the tenant alias to keep (for example `caldova25668747` for Tenant 2). Confirm it matches `infra/src/config/tenants/<alias>.psd1`'s own `TenantAlias` field before proceeding.
- [ ] `-RepositoryRootOverride` points the script at a non-default repository root. Most operators running this runbook from their own repository root will not need it; it is mainly for testing and CI overrides.
- [ ] `Invoke-Pester -Path infra/tests/pester/RemoveOtherTenantArtifacts.Tests.ps1 -Output Detailed -CI` passes in the destination repository before you begin.

## Steps

1. **Review what would be removed, with zero mutation.**

   ```powershell
   .\infra\src\scripts\Remove-OtherTenantArtifacts.ps1 -TenantAliasToKeep '<your-tenant-alias>' -WhatIf
   ```

   Confirm every listed file belongs to a *different* tenant than the one you are keeping. If a file you expected to see is missing, or a file you did not expect appears, stop and investigate before continuing -- do not proceed on a plan you do not fully understand.

2. **Execute the removal.**

   ```powershell
   .\infra\src\scripts\Remove-OtherTenantArtifacts.ps1 -TenantAliasToKeep '<your-tenant-alias>' -Confirm:$false
   ```

   This is a local file deletion, not a Git operation -- nothing is committed yet. If you make a mistake here, `git checkout -- .` (before staging anything) restores every removed file from the last commit.

3. **Review the remaining tenant-scoped references this runbook does not remove.**

   `Remove-OtherTenantArtifacts.ps1` only ever deletes whole files: tenant config manifests, discovery evidence, and Bicep parameter files. It is a file-removal script, not a text-substitution tool, and it does not know about every place a tenant's alias, name, or URL appears in prose or in other tenant-agnostic-looking files. The artifact list this runbook removes is **not exhaustive of every tenant-scoped reference in the repository** -- it is exhaustive only of the three removable file types listed above. The following files are known to carry a Tenant-1-scoped reference and are **not removed** by this runbook; each must be manually reviewed and adapted for the destination tenant before that reference is trusted:

   | File | What it hard-codes |
   |---|---|
   | `.github/cli/verify-repository-setup.ps1` | A hard-coded list of required tenant manifest files, including Tenant 1's alias |
   | `.github/workflows/bootstrap-tenant.yml` | Tenant-specific paths/values used by the bootstrap workflow |
   | `.github/workflows/discover-tenant.yml` | Tenant-specific paths/values used by the discovery workflow |
   | `.github/ISSUE_TEMPLATE/config.yml` | A link to Tenant 1's Azure DevOps organization |
   | `.github/cli/tests/IssueFormContract.Tests.ps1` | A reference to Tenant 1's alias |
   | `hr/tests/pester/SolutionLifecycle.Tests.ps1` | A reference to Tenant 1's alias |
   | `hr/src/scripts/README.md` | A reference to Tenant 1's alias |
   | root `README.md` | A reference to Tenant 1's alias |

   Fully automating these into tenant-agnostic form is **out of scope for this runbook** -- it is a separate, larger piece of work. This runbook documents a manual, reviewed handover, not a zero-touch pipeline. Confirm each file above has been reviewed and, where it names a tenant, updated to name the destination tenant instead, before treating the clean-up as complete.

   `infra/tests/pester/TenantBlueprintVerification.Tests.ps1` is a related but separate case: it is Tenant-1-specific and now skips gracefully (rather than failing) once Tenant 1's manifest and evidence files are removed by Step 2 above, so it is not a blocker to clean-up. The destination repository may eventually want its own equivalent verification suite for its own tenant, but writing one is not required by this runbook.

   You may still use `git grep` to locate any other occurrence of the removed tenant's alias for your own awareness:

   ```powershell
   git grep -l '<removed-tenant-alias>' -- . ':!docs' ':!infra/docs'
   ```

   `docs/` and `infra/docs/` describe the whole multi-tenant family's design and correctly continue to mention every tenant by name; they are never scrubbed per-repository. Any match outside those two folders and outside the checklist above may be a tenant-scoped reference this runbook does not yet document -- treat it as a possible gap in this checklist, not a script defect to silently patch around.

4. **Run the full test suite to prove nothing broke.**

   ```powershell
   Invoke-Pester -Path .github/cli/tests,infra/tests/pester -Output Detailed -CI
   ```

   Expected: all tests pass. A failure here means the clean-up removed something the destination repository's own tooling still depends on -- do not commit until this is green.

5. **Commit the clean-up as its own commit**, separate from any manifest configuration changes made later in the Handover Runbook:

   ```powershell
   git add -A
   git commit -m "chore: remove other-tenant configuration and evidence"
   ```

## What This Runbook Does Not Do

| Not covered here | Where it lives instead |
|---|---|
| Creating the destination repository or seeding it with this repository's content | [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md), Step 2 |
| Correcting the kept tenant's own manifest fields (for example `GitHub.Owner`) | [Customer Repository Export and Handover Runbook](./23-customer-repository-export-and-handover-runbook.md), Step 4 |
| Removing prose mentions of other tenants from `docs/` or `infra/docs/` | Deliberately out of scope -- those documents describe the shared multi-tenant design and remain identical across every tenant's repository |
| Rewriting `.github/cli/verify-repository-setup.ps1`, the `bootstrap-tenant.yml`/`discover-tenant.yml` workflows, or `.github/ISSUE_TEMPLATE/config.yml` to be dynamically tenant-agnostic | Not automated by any runbook today -- Step 3's checklist above lists what must be manually reviewed and adapted per tenant; making these tenant-agnostic is a separate, larger piece of work |

## Troubleshooting

- **The script lists a file you did not expect.** `Remove-OtherTenantArtifacts.ps1` only ever looks at `infra/src/config/tenants/*.psd1`, `infra/evidence/discovery/*.json`, and `infra/src/bicep/params/*.bicepparam`. If you see an unexpected file, check whether a new tenant-scoped artifact type has been added to the repository since this runbook was last reviewed -- that is a real gap to fix in the script, not something to remove by hand and move on.
- **`Test-Path` still shows the other tenant's file after Step 2.** Confirm you ran the script without `-WhatIf` and answered any `ShouldProcess` prompt with `Y` (or passed `-Confirm:$false`, as shown above, for a fully unattended run in an already-reviewed context).
- **Step 4's test run fails after removal.** Do not attempt to patch the failure by re-adding the removed file -- first read the failing test's name and message; it usually names exactly what still depends on the removed tenant's data. `infra/tests/pester/TenantBlueprintVerification.Tests.ps1` is expected to *skip* (not fail) once Tenant 1's manifest and evidence are removed; a failure there, rather than a skip, is a real regression to investigate.
- **You found a tenant-scoped reference not listed in Step 3's checklist.** The checklist is a best-effort inventory as of this runbook's last review, not a guaranteed-exhaustive scan of every file in the repository. Add the file to the checklist (as a documentation fix) and review it for the current handover; this runbook does not attempt to auto-discover every possible reference.
