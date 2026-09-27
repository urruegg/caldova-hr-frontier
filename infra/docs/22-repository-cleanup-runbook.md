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

3. **Verify nothing else references the removed tenant.**

   ```powershell
   git grep -l '<removed-tenant-alias>' -- . ':!docs' ':!infra/docs'
   ```

   Expect no output outside `docs/` and `infra/docs/` -- those folders describe the whole multi-tenant family's design and correctly continue to mention every tenant by name; they are never scrubbed per-repository. Any match outside those two folders is a genuinely tenant-scoped reference this runbook's script did not yet know to remove -- treat it as a defect in this runbook or the script, not something to silently work around.

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

## Troubleshooting

- **The script lists a file you did not expect.** `Remove-OtherTenantArtifacts.ps1` only ever looks at `infra/src/config/tenants/*.psd1`, `infra/evidence/discovery/*.json`, and `infra/src/bicep/params/*.bicepparam`. If you see an unexpected file, check whether a new tenant-scoped artifact type has been added to the repository since this runbook was last reviewed -- that is a real gap to fix in the script, not something to remove by hand and move on.
- **`Test-Path` still shows the other tenant's file after Step 2.** Confirm you ran the script without `-WhatIf` and answered any `ShouldProcess` prompt with `Y` (or passed `-Confirm:$false`, as shown above, for a fully unattended run in an already-reviewed context).
- **Step 4's test run fails after removal.** Do not attempt to patch the failure by re-adding the removed file -- first read the failing test's name and message; it usually names exactly what still depends on the removed tenant's data.
