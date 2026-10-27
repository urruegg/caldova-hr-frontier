# Agent Factory Slice A: Superpowers v7.0.1 Implementation Plan

| Field | Value |
|---|---|
| **Version** | 1.1 |
| **Date** | 2026-10-27 |
| **Author** | docs-agent (Voice of Knowledge) |
| **Status** | Draft |
| **Scope** | Agent Factory Slice A: upgrade the vendored Superpowers runtime from v6.3.0 to v7.0.1 and the validator contracts that pin it |
| **References** | [Agent Factory Foundation Design](../specs/2026-10-26-agent-factory-foundation-design.md), [Repository Superpowers Integration Implementation Plan](2026-09-15-repository-superpowers-implementation.md), [Agent Factory Part 1 Idea Record](../ideas/agent-factory-common-setup.md), [Root README](../../README.md), [Agent Skills](../../.github/skills/README.md) |

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the vendored Superpowers v6.3.0 runtime with the reviewed v7.0.1 release, with every integrity contract updated first, shown failing, and then shown passing.

**Architecture:** The repository verifier pins the skill inventory, the manifest hash, the executable-mode list, and the version metadata. This plan changes those contracts first, proves they fail against the old tree, then vendors the upstream tag with a script that asserts every reviewed value (commit, tag object, file count, manifest hash) and re-verifies the result against a second clone.

**Tech Stack:** Windows PowerShell 5.1, Pester 5.7.1, Git, `gh`, the repository verifier `.github/cli/verify-repository-setup.ps1`.

**Spec:** [`docs/specs/2026-10-26-agent-factory-foundation-design.md`](../specs/2026-10-26-agent-factory-foundation-design.md), section 6. The spec is a Proposed Baseline.

## Status and Authority

This is a draft for owner review alongside the foundation design. It does not record approval, authorize execution, or prove that a task ran. Before Preparation, record the owner's approval of the written design and confirm that the docs-only review package has merged to `main`. Until then, leave every execution step unstarted.

## Global Constraints

- Pin upstream release `v7.0.1`, published 2026-10-21, tag object `cfd50a286baea35041505ed068c878d389ca9f7f`, commit `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b`. Upstream v7.0.0 is superseded and is not used.
- The vendored runtime has 15 skills, 84 runtime files, and 9 executable scripts. The manifest file `SUPERPOWERS_SHA256SUMS` has SHA-256 `20a384e5e26fde283ac09d0465b5b5b099cb5e2c793828b150b1d632f73a1ca0`.
- The upstream `LICENSE` is byte-identical to `LICENSE.superpowers` (SHA-256 `a37e0e9697144819e1d965176ac4ae5bc3fa02d11e7812036bbcadf6dafe2400`); it is not refreshed.
- Never edit a vendored file. Generate the manifest from the upstream tag by script, never by hand.
- Show the contracts failing against the v6.3.0 tree before vendoring, then passing after.
- Create or change no GitHub Actions workflow, Azure DevOps pipeline, or `copilot-setup-steps.yml`.
- Leave historical specifications and plans that describe the v6.3.0 vendoring unchanged.
- Run Windows PowerShell 5.1 with exact Pester 5.7.1. Use `-ExecutionPolicy Bypass` on the process only; never change a persistent policy.
- This workstation sets `core.autocrlf=true`. Every clone used to derive or verify hashes must use `-c core.autocrlf=false -c core.eol=lf`, because line-ending conversion changes the hashes.
- Work in a sibling worktree under `Source\urruegg\wt\`, on branch `chore/vendor-superpowers-v7.0.1`, with a checkout path below 240 characters.
- Documentation is English and UTF-8, and every eligible Markdown file keeps its six-field header.
- Each commit ends with the trailer `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Do not push or open a pull request unless the owner directs it.
- Report a check that was not run as "Not run"; never as passed.

**Prerequisite.** Start only after the docs-only pull request that contains the foundation design and these plans has merged to `main`, because the new README text links to the design. Spec open item 3 (whether upgrading an existing dependency needs a Capability Admission Record before the record schema exists) is unresolved. This plan assumes the root README update procedure governs, as the design states, and records that assumption in the pull request.

---

## Preparation (not a task)

- [ ] **Step 1: Create the worktree from the merged `main`**

```powershell
Set-Location -LiteralPath 'C:\Users\urruegg\Source\urruegg\caldova-hr-frontier'
git fetch origin --prune
$worktree = 'C:\Users\urruegg\Source\urruegg\wt\superpowers-v7'
if (Test-Path -LiteralPath $worktree) { throw "Worktree path already exists: $worktree" }
git worktree add $worktree -b chore/vendor-superpowers-v7.0.1 origin/main
if ($LASTEXITCODE -ne 0) { throw 'git worktree add failed' }
Set-Location -LiteralPath $worktree
git --no-pager log -1 --format='%h %s'
```

Expected: a new worktree on `chore/vendor-superpowers-v7.0.1` whose latest commit includes `docs/specs/2026-10-26-agent-factory-foundation-design.md`. Confirm that with `Test-Path docs\specs\2026-10-26-agent-factory-foundation-design.md`. Prove the current-user write/delete probe and the sub-240-character path budget using the [external worktree prerequisite](../../infra/docs/runbooks/01-developer-workstation.md#external-worktree-prerequisite) with task directory `superpowers-v7`.

- [ ] **Step 2: Fix the change date once**

```powershell
(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
```

Call the output `<change-date>`. Use that exact literal everywhere `<change-date>` appears below and record it in the pull request, because the verifier requires `SUPERPOWERS_VERSION` and its contract to carry the same `vendored=` date.

---

### Task 1: Pin the v7.0.1 contracts first and show them failing

**Files:**
- Modify: `.github/cli/verify-repository-setup.ps1`
- Modify: `.github/cli/tests/Phase2SourceContract.Tests.ps1`
- Modify: `README.md`

**Interfaces:**
- Consumes: the reviewed values in Global Constraints.
- Produces: verifier contracts that Task 2 must satisfy, and a README that states the new pin.

- [ ] **Step 1: Record the green baseline**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild
```

Expected: `Repository setup validation passed.` and exit code `0`. If it fails, stop and report the existing failure; do not continue on a red baseline.

- [ ] **Step 2: Update the skill inventory in the verifier**

In `.github/cli/verify-repository-setup.ps1`, replace

```powershell
$skillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
```

with

```powershell
$skillNames = @(
    'brainstorming', 'diagnosing-superpowers', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
```

- [ ] **Step 3: Update the pinned manifest hash**

Replace

```powershell
$expectedManifestHash = 'be8b1626ea290a4cc0a99ccf0e4878fcf8c5ca7d238094be3d23b59563d28f1c'
```

with

```powershell
$expectedManifestHash = '20a384e5e26fde283ac09d0465b5b5b099cb5e2c793828b150b1d632f73a1ca0'
```

- [ ] **Step 4: Update the executable-mode inventory**

The replacement excerpts in Steps 4 and 5 are literal text fragments, not standalone PowerShell commands. Replace

```text
foreach ($relativePath in @(
    'brainstorming/scripts/start-server.sh', 'brainstorming/scripts/stop-server.sh',
    'subagent-driven-development/scripts/review-package', 'subagent-driven-development/scripts/sdd-workspace',
```

with

```text
foreach ($relativePath in @(
    'brainstorming/scripts/start-server.sh', 'brainstorming/scripts/stop-server.sh',
    'executing-plans/scripts/task-done', 'executing-plans/scripts/task-start',
    'subagent-driven-development/scripts/review-package', 'subagent-driven-development/scripts/sdd-workspace',
```

Leave the following lines (`task-brief`, `find-polluter.sh`, `render-graphs.js`) unchanged. The list now has nine paths.

- [ ] **Step 5: Update the version-metadata and README contracts**

In the `Test-RequiredContent '.github/skills/SUPERPOWERS_VERSION'` block, replace these five lines and the `included-skills` line:

```text
    'release=v6.3.0',
    'version=6.3.0',
    'tag-object=86babb696875227929e85420f287d6309374b93f',
    'commit=b36e0829c6d0140e93cfef2ca599b1b07d4a7797',
    'vendored=2026-09-15',
```

with

```text
    'release=v7.0.1',
    'version=7.0.1',
    'tag-object=cfd50a286baea35041505ed068c878d389ca9f7f',
    'commit=2ce8aa15d05bd57213e6f746f953aafb7ded7a8b',
    'vendored=<change-date>',
```

and replace the `included-skills=` line with

```powershell
    'included-skills=brainstorming,diagnosing-superpowers,dispatching-parallel-agents,executing-plans,finishing-a-development-branch,receiving-code-review,requesting-code-review,subagent-driven-development,systematic-debugging,test-driven-development,using-git-worktrees,using-superpowers,verification-before-completion,writing-plans,writing-skills'
```

Then replace

```powershell
Test-RequiredContent 'README.md' @('Superpowers', 'v6.3.0', '.github/skills', 'verify-repository-setup.ps1')
```

with

```powershell
Test-RequiredContent 'README.md' @('Superpowers', 'v7.0.1', '.github/skills', 'verify-repository-setup.ps1')
```

- [ ] **Step 6: Update the Phase 2 source contract test**

In `.github/cli/tests/Phase2SourceContract.Tests.ps1`, inside the `$requiredConcepts` list of the test named `preserves the repository workflow, and the Phase 2 deliverable is superseded on disk, not deleted`, replace the line `'v6.3.0'` with `'v7.0.1'`.

- [ ] **Step 7: Update the root README**

In `README.md`:

1. In the header table, change `| **Version** | 1.6 |` to `| **Version** | 1.7 |` and the `Date` row to `<change-date>`.
2. In the paragraph that begins `This repository bundles [Superpowers]`, change `v6.3.0` to `v7.0.1`.
3. Under **Pinned Version and License**, replace the sentence with

```markdown
The vendored runtime is pinned to upstream release v7.0.1 at commit `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b`.
```

4. Under **Updating Superpowers**, replace steps 2 to 4 with

```markdown
2. Replace only the 15 vendored skill directories with the newer release's `skills/` content.
3. Review and update `.github/cli/verify-repository-setup.ps1` fixed contracts for the new upstream release: the expected 15-skill inventory, nine-path executable mode inventory, source release/version/tag/commit, manifest hash, manifest name and metadata, and license attribution checks.
4. Regenerate `SUPERPOWERS_SHA256SUMS` from every file in the 15 reviewed upstream runtime directories using forward-slash relative paths, ordinal path sorting, and lowercase SHA-256 hashes. Generate it from a clone made with `-c core.autocrlf=false -c core.eol=lf`; line-ending conversion changes the hashes.
```

- [ ] **Step 8: Run the contracts and watch them fail (RED)**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild
```

Expected: exit code `1` and exactly these three `ERROR:` lines. The version file is checked as an exact line list, so its failure reads "does not match the pinned metadata contract":

```text
ERROR: Missing skill directory: diagnosing-superpowers
ERROR: Pinned manifest hash mismatch: .github/skills/SUPERPOWERS_SHA256SUMS
ERROR: .github/skills/SUPERPOWERS_VERSION does not match the pinned metadata contract.
```

If the verifier passes, a contract was not changed; fix the edit before continuing. Keep this output as the RED evidence.

- [ ] **Step 9: Commit the contracts**

```powershell
git add -- .github/cli/verify-repository-setup.ps1 .github/cli/tests/Phase2SourceContract.Tests.ps1 README.md
git commit -m 'test(superpowers): pin v7.0.1 integrity contracts' -m 'Update the skill inventory, manifest hash, executable-mode list, version metadata, and README contracts for Superpowers v7.0.1. The verifier is intentionally red at this commit and is made green by the vendoring commit that follows.' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

---

### Task 2: Vendor the v7.0.1 runtime and make the contracts pass

**Files:**
- Modify: `.gitattributes`
- Replace: `.github/skills/<15 skill directories>/**`
- Replace: `.github/skills/SUPERPOWERS_SHA256SUMS`
- Replace: `.github/skills/SUPERPOWERS_VERSION`
- Modify: `.github/skills/README.md`

**Interfaces:**
- Consumes: the contracts from Task 1.
- Produces: a vendored tree whose files, manifest, modes, and metadata satisfy the verifier.

- [ ] **Step 1: Mark the new skill as a non-normalized path**

In `.gitattributes`, insert this line between the `brainstorming` and `dispatching-parallel-agents` lines:

```text
/.github/skills/diagnosing-superpowers/** -text
```

Verify it before any file is added:

```powershell
git check-attr text -- .github/skills/diagnosing-superpowers/SKILL.md
```

Expected: `.github/skills/diagnosing-superpowers/SKILL.md: text: unset`.

- [ ] **Step 2: Vendor the upstream tag**

Save the following as `vendor-superpowers.ps1` in a scratch location outside the repository (for example `$env:TEMP`), then run it from the repository root with `powershell -NoProfile -ExecutionPolicy Bypass -File <path>`.

```powershell
$ErrorActionPreference = 'Stop'

$release = 'v7.0.1'
$expectedCommit = '2ce8aa15d05bd57213e6f746f953aafb7ded7a8b'
$expectedTagObject = 'cfd50a286baea35041505ed068c878d389ca9f7f'
$expectedManifestSha256 = '20a384e5e26fde283ac09d0465b5b5b099cb5e2c793828b150b1d632f73a1ca0'
$expectedRuntimeFileCount = 84
$replacedSkillNames = @(
    'brainstorming', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$skillNames = @(
    'brainstorming', 'diagnosing-superpowers', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$utf8NoBom = [Text.UTF8Encoding]::new($false)

$repositoryRoot = (Resolve-Path (git rev-parse --show-toplevel)).Path.TrimEnd('\')
$skillsRoot = Join-Path $repositoryRoot '.github\skills'
if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) { throw "Missing $skillsRoot" }

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("superpowers-$release-" + [guid]::NewGuid().ToString('N'))
try {
    # This workstation sets core.autocrlf=true; the clone must not convert line endings.
    git -c core.autocrlf=false -c core.eol=lf -c advice.detachedHead=false clone --quiet --depth 1 --branch $release https://github.com/obra/superpowers.git $tempRoot
    if ($LASTEXITCODE -ne 0) { throw "Unable to clone Superpowers $release." }

    $resolvedCommit = git -C $tempRoot rev-parse HEAD
    $resolvedTagObject = git -C $tempRoot rev-parse $release
    if ($resolvedCommit -cne $expectedCommit) { throw "Unexpected commit: $resolvedCommit" }
    if ($resolvedTagObject -cne $expectedTagObject) { throw "Unexpected tag object: $resolvedTagObject" }

    $upstreamSkillsRoot = Join-Path $tempRoot 'skills'
    $upstreamNames = @(Get-ChildItem -LiteralPath $upstreamSkillsRoot -Directory -Force | ForEach-Object Name | Sort-Object)
    if (($upstreamNames -join ',') -cne (($skillNames | Sort-Object) -join ',')) {
        throw "Upstream skill set differs from the reviewed 15-skill list: $($upstreamNames -join ',')"
    }
    if (@(Get-ChildItem -LiteralPath $upstreamSkillsRoot -File -Force).Count -ne 0) {
        throw 'Upstream skills/ contains files outside a skill directory.'
    }

    $upstreamLicense = (Get-FileHash -LiteralPath (Join-Path $tempRoot 'LICENSE') -Algorithm SHA256).Hash.ToLowerInvariant()
    $pinnedLicense = (Get-FileHash -LiteralPath (Join-Path $skillsRoot 'LICENSE.superpowers') -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($upstreamLicense -cne $pinnedLicense) {
        throw 'Upstream license differs from LICENSE.superpowers. Refresh it and update the license hash contract before continuing.'
    }

    foreach ($skillName in @($replacedSkillNames + $skillNames | Select-Object -Unique)) {
        $target = Join-Path $skillsRoot $skillName
        if (-not (Test-Path -LiteralPath $target)) { continue }
        $item = Get-Item -LiteralPath $target -Force
        if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Refusing to remove a non-directory or reparse point: $target"
        }
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    foreach ($skillName in $skillNames) {
        Copy-Item -LiteralPath (Join-Path $upstreamSkillsRoot $skillName) -Destination $skillsRoot -Recurse
    }

    $hashes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($skillName in $skillNames) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $skillsRoot $skillName) -File -Recurse -Force) {
            $relativePath = $file.FullName.Substring($skillsRoot.Length + 1).Replace('\', '/')
            $hashes.Add($relativePath, (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant())
        }
    }
    $manifestPaths = [string[]]$hashes.Keys
    [Array]::Sort($manifestPaths, [StringComparer]::Ordinal)
    $manifestContent = (($manifestPaths | ForEach-Object { "$($hashes[$_])  $_" }) -join "`n") + "`n"
    $manifestFile = Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'
    [IO.File]::WriteAllText($manifestFile, $manifestContent, $utf8NoBom)

    $actualManifestSha256 = (Get-FileHash -LiteralPath $manifestFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($manifestPaths.Count -ne $expectedRuntimeFileCount) { throw "Expected $expectedRuntimeFileCount runtime files, found $($manifestPaths.Count)." }
    if ($actualManifestSha256 -cne $expectedManifestSha256) { throw "Manifest SHA-256 differs from the reviewed value: $actualManifestSha256" }
    Write-Output "Vendored Superpowers ${release}: $($manifestPaths.Count) runtime files, manifest SHA-256 $actualManifestSha256"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
```

Expected output (a `refs/tags/v7.0.1 ... is not a commit` warning from Git about the annotated tag is normal):

```text
Vendored Superpowers v7.0.1: 84 runtime files, manifest SHA-256 20a384e5e26fde283ac09d0465b5b5b099cb5e2c793828b150b1d632f73a1ca0
```

The script removes only the 14 named v6.3.0 skill directories before copying the 15 reviewed ones, so files that upstream removed or moved (seven top-level reference files) do not linger. It throws on any mismatch, leaving the failing state visible.

- [ ] **Step 3: Record the source metadata**

Replace the whole content of `.github/skills/SUPERPOWERS_VERSION` with the following, using the real `<change-date>`:

```text
name=Superpowers
source=https://github.com/obra/superpowers
release=v7.0.1
version=7.0.1
tag-object=cfd50a286baea35041505ed068c878d389ca9f7f
commit=2ce8aa15d05bd57213e6f746f953aafb7ded7a8b
vendored=<change-date>
upstream-path=skills/
destination=.github/skills/
manifest=SUPERPOWERS_SHA256SUMS
included-skills=brainstorming,diagnosing-superpowers,dispatching-parallel-agents,executing-plans,finishing-a-development-branch,receiving-code-review,requesting-code-review,subagent-driven-development,systematic-debugging,test-driven-development,using-git-worktrees,using-superpowers,verification-before-completion,writing-plans,writing-skills
```

Keep the file's existing line-ending style (the working copy is CRLF on this workstation because of `core.autocrlf=true`; Git normalizes it on add). View the file before replacing it and match it. The verifier compares lines, not bytes, but do not introduce mixed endings.

- [ ] **Step 4: Update the skills README**

In `.github/skills/README.md`, change the header `Version` to `1.1`, the `Date` to `<change-date>`, and add `[Agent Factory Foundation Design](../../docs/specs/2026-10-26-agent-factory-foundation-design.md)` to the `References` field. Then replace the two body paragraphs with:

```markdown
This folder contains project skills discovered by GitHub Copilot in VS Code and Copilot CLI.

Superpowers is vendored here unchanged from its pinned upstream release, currently v7.0.1; see [Pinned Version and License](../../README.md#pinned-version-and-license). Do not edit vendored skill content directly; update it through a reviewed release replacement.

Project-owned skills do not belong in this folder. The repository verifier rejects any tracked path under `.github/skills/` that is not part of the pinned Superpowers runtime. The Proposed location for factory skills is `.agents/skills/` (see the [Agent Factory Foundation Design](../../docs/specs/2026-10-26-agent-factory-foundation-design.md)); discovery there is not yet verified.
```

- [ ] **Step 5: Stage the runtime and set the executable bits**

```powershell
git add -- .gitattributes .github/skills
$executablePaths = @(
    '.github/skills/brainstorming/scripts/start-server.sh',
    '.github/skills/brainstorming/scripts/stop-server.sh',
    '.github/skills/executing-plans/scripts/task-done',
    '.github/skills/executing-plans/scripts/task-start',
    '.github/skills/subagent-driven-development/scripts/review-package',
    '.github/skills/subagent-driven-development/scripts/sdd-workspace',
    '.github/skills/subagent-driven-development/scripts/task-brief',
    '.github/skills/systematic-debugging/find-polluter.sh',
    '.github/skills/writing-skills/render-graphs.js'
)
git update-index --chmod=+x -- $executablePaths
if ($LASTEXITCODE -ne 0) { throw 'git update-index failed' }
$staged = git ls-files -s -- .github/skills
$executable = @($staged | Where-Object { $_ -match '^100755 ' } | ForEach-Object { ($_ -split "`t")[1] } | Sort-Object)
Write-Output ("tracked files under .github/skills: {0}; executable: {1}" -f @($staged).Count, $executable.Count)
(Compare-Object $executable ($executablePaths | Sort-Object)) | ForEach-Object { throw "Executable set differs: $($_.InputObject)" }
```

Expected: `tracked files under .github/skills: 88; executable: 9` (84 runtime files plus `README.md`, `LICENSE.superpowers`, `SUPERPOWERS_SHA256SUMS`, and `SUPERPOWERS_VERSION`) and no thrown difference.

- [ ] **Step 6: Verify the tree independently against a second clone**

Save the following as `verify-vendored-superpowers.ps1` in the same scratch location and run it from the repository root.

```powershell
$ErrorActionPreference = 'Stop'

$release = 'v7.0.1'
$expectedCommit = '2ce8aa15d05bd57213e6f746f953aafb7ded7a8b'
$skillNames = @(
    'brainstorming', 'diagnosing-superpowers', 'dispatching-parallel-agents', 'executing-plans',
    'finishing-a-development-branch', 'receiving-code-review', 'requesting-code-review',
    'subagent-driven-development', 'systematic-debugging', 'test-driven-development',
    'using-git-worktrees', 'using-superpowers', 'verification-before-completion',
    'writing-plans', 'writing-skills'
)
$utf8NoBom = [Text.UTF8Encoding]::new($false)

$repositoryRoot = (Resolve-Path (git rev-parse --show-toplevel)).Path.TrimEnd('\')
$skillsRoot = Join-Path $repositoryRoot '.github\skills'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("superpowers-verify-" + [guid]::NewGuid().ToString('N'))
$differences = [Collections.Generic.List[string]]::new()
try {
    git -c core.autocrlf=false -c core.eol=lf -c advice.detachedHead=false clone --quiet --depth 1 --branch $release https://github.com/obra/superpowers.git $tempRoot
    if ($LASTEXITCODE -ne 0) { throw "Unable to clone Superpowers $release." }
    if ((git -C $tempRoot rev-parse HEAD) -cne $expectedCommit) { throw 'Unexpected upstream commit.' }

    $upstreamSkillsRoot = (Resolve-Path (Join-Path $tempRoot 'skills')).Path.TrimEnd('\')
    $expectedHashes = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($skillName in $skillNames) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $upstreamSkillsRoot $skillName) -File -Recurse -Force) {
            $relativePath = $file.FullName.Substring($upstreamSkillsRoot.Length + 1).Replace('\', '/')
            $expectedHashes.Add($relativePath, (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant())
        }
    }
    $expectedPaths = [string[]]$expectedHashes.Keys
    [Array]::Sort($expectedPaths, [StringComparer]::Ordinal)
    $expectedManifest = Join-Path $tempRoot 'SUPERPOWERS_SHA256SUMS.expected'
    [IO.File]::WriteAllText($expectedManifest, ((($expectedPaths | ForEach-Object { "$($expectedHashes[$_])  $_" }) -join "`n") + "`n"), $utf8NoBom)
    $expectedBytes = [IO.File]::ReadAllBytes($expectedManifest)
    $actualBytes = [IO.File]::ReadAllBytes((Join-Path $skillsRoot 'SUPERPOWERS_SHA256SUMS'))
    $manifestMatches = ([Convert]::ToBase64String($expectedBytes) -ceq [Convert]::ToBase64String($actualBytes))

    foreach ($skillName in $skillNames) {
        $difference = @(git -c core.autocrlf=false diff --no-index --stat -- (Join-Path $upstreamSkillsRoot $skillName) (Join-Path $skillsRoot $skillName) 2>&1)
        if ($LASTEXITCODE -gt 1) { throw "Unable to compare vendored skill: $skillName" }
        if ($LASTEXITCODE -eq 1) { $differences.AddRange([string[]]$difference) }
    }
    $extraDirectories = @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force | ForEach-Object Name | Where-Object { $_ -cnotin $skillNames })
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
if (-not $manifestMatches) { throw "Manifest differs from the pinned Superpowers $release skills tree." }
if ($differences.Count -gt 0) { $differences; throw "Vendored runtime differs from Superpowers $release." }
if ($extraDirectories.Count -gt 0) { throw "Unexpected directories under .github/skills: $($extraDirectories -join ', ')" }
Write-Output "Vendored runtime matches Superpowers $release byte for byte; manifest matches; no unexpected directories."
```

Expected: `Vendored runtime matches Superpowers v7.0.1 byte for byte; manifest matches; no unexpected directories.` The script fails if any vendored byte is changed or any runtime file is missing.

- [ ] **Step 7: Run the verifier and watch it pass (GREEN)**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1 -SkipIntegratedTests -SkipBicepBuild
```

Expected: `Repository setup validation passed.` and exit code `0`.

- [ ] **Step 8: Commit the runtime**

```powershell
git commit -m 'build: vendor Superpowers v7.0.1' -m 'Replace the vendored runtime with upstream v7.0.1 (commit 2ce8aa15d05bd57213e6f746f953aafb7ded7a8b): 15 skills, 84 runtime files, 9 executable scripts. Add diagnosing-superpowers, regenerate the SHA-256 manifest from the tag, record the source metadata, and point the skills README at the factory skill location.' -m 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
```

---

### Task 3: Full validation, discovery smoke tests, and evidence

**Files:**
- No file changes unless a check fails and the cause is found.

**Interfaces:**
- Consumes: the committed branch from Tasks 1 and 2.
- Produces: pasted evidence for the pull request.

- [ ] **Step 1: Run the complete repository verifier**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

Expected: `Repository setup validation passed.` and exit code `0`. This runs the integrated Pester suites and the Bicep build, so it needs exact Pester 5.7.1 and Azure CLI with the Bicep command. If Azure CLI or Bicep is absent, run it with `-SkipBicepBuild` and record "Bicep build: Not run (tool absent)".

- [ ] **Step 2: Run every maintained Pester suite, as the repository validation does**

```powershell
$validation = @'
$ErrorActionPreference = 'Stop'
Import-Module Pester -RequiredVersion 5.7.1 -Force
$githubTests = @(Get-ChildItem -LiteralPath '.github\cli\tests' -Filter '*.Tests.ps1' -File | ForEach-Object FullName)
$result = Invoke-Pester -Path @($githubTests + @('infra\tests\pester', 'hr\tests\pester')) -Output Normal -CI -PassThru
$result | Select-Object TotalCount, PassedCount, FailedCount, SkippedCount, Result | Format-List
if ($result.Result -ne 'Passed') { exit 1 }
'@
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $validation
```

The single-quoted here-string keeps the outer shell from expanding the inner variables.

Expected: `FailedCount : 0` and `Result : Passed`. A failure unrelated to this change is reported with its cause, not hidden. Use the existing dependencies first. Only if this validation fails because Python schema dependencies are missing, restore them with `python -m pip install --requirement hr/tests/requirements.txt`, check that restoration succeeds, and rerun the same validation command. A missing dependency is an environment failure, not RED evidence.

- [ ] **Step 3: Confirm the diff touched no workflow or pipeline**

```powershell
git diff --name-only origin/main...HEAD -- .github/workflows
git diff --name-only origin/main...HEAD | Select-String -Pattern 'pipeline|copilot-setup-steps'
```

Expected: no output from either command.

- [ ] **Step 4: Check for stale references**

```powershell
git grep -n -e '6\.3\.0' -e 'b36e0829' -e '14 vendored' -e '14-skill' -- . ':(exclude)docs/plans' ':(exclude)docs/specs' ':(exclude)docs/archive' ':(exclude)docs/reviews' ':(exclude)docs/ideas'
```

Expected: no output. Matches inside `docs/plans`, `docs/specs`, `docs/archive`, and `docs/reviews` are historical, and `docs/ideas` holds the author's concept text; all are intentionally unchanged. A match inside vendored upstream skill text, if one appears, is upstream content and is not edited.

- [ ] **Step 5: Run the discovery smoke tests**

In VS Code, open **Chat: Open Customizations** from this worktree and confirm 15 project skills appear without metadata errors, including `diagnosing-superpowers`, and that `using-superpowers` shows the path `.github/skills/using-superpowers/SKILL.md`.

If the Copilot CLI is installed, run:

```powershell
copilot --no-auto-update -C . skill list --json
```

Expected: 15 entries with `source` equal to `project`, including `diagnosing-superpowers`. If `copilot` is not installed (it was not on this workstation's PATH when the plan was written), record "Copilot CLI smoke test: Not run (tool absent)". Record the VS Code result as observed, or as "Not run" if it was not performed.

- [ ] **Step 6: Assemble the evidence and stop for review**

Collect the pasted outputs of Task 1 Step 8 (RED), Task 2 Steps 2, 5, 6 and 7, and Task 3 Steps 1 to 5, with the `<change-date>`. Note the unresolved spec open item 3 and the assumption recorded in the Prerequisite. Do not push or open a pull request unless the owner directs it. When directed, push `chore/vendor-superpowers-v7.0.1` and open the pull request with the repository template `.github/pull_request_template.md`, preserving its headings and checklist, citing this plan and the design as the governing record, and leaving `Board synchronization: Deferred - not synchronized` as written.

---

## Completion Criteria

- The verifier passes in full and all maintained Pester suites pass.
- Required VS Code and Copilot CLI discovery checks show the 15 project skills. An unavailable host or skipped check is reported as `Not run` and leaves that acceptance item outstanding; it is not a pass.
- Any failed required check, including an unrelated baseline failure, is reported with its cause and blocks completion until resolved.
- The vendored tree, manifest, executable modes, and metadata match upstream v7.0.1 exactly, proven by the independent clone check.
- No workflow, pipeline, or historical document changed.
- The RED evidence from Task 1 and the GREEN evidence from Task 2 are both preserved.

## Plan Verification Record

When this plan was written (2026-10-26), Tasks 1 and 2 were dry-run end to end in a throwaway worktree off the design branch, applying the exact edits and scripts above with `<change-date>` set to `2026-10-26`. The dry run produced exit code `1` with exactly the three `ERROR:` lines in Task 1 Step 8, then the vendor script output in Task 2 Step 2, `88` tracked files with `9` executable, the Step 6 match message, and exit code `0` in Step 7. The throwaway worktree was removed. This record describes the plan's own check; it is not evidence that the plan has been executed, and the full Pester suites (Task 3) were not part of the dry run.
