# caldova-hr-frontier

## Repository Agent Workflow

This repository bundles [Superpowers](https://github.com/obra/superpowers) v6.3.0 for GitHub Copilot. Contributors receive the same agent workflows by cloning the repository; no machine-level Superpowers installation is required.

GitHub Copilot discovers the skills under `.github/skills/` in:

- Visual Studio Code chat and agent mode;
- GitHub Copilot CLI when launched from this repository.

Repository instructions require Copilot to begin with the `using-superpowers` skill and load other skills when relevant.

### Verify the Bundle

From the repository root on Windows, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .github/cli/verify-repository-setup.ps1
```

The command succeeds with `Repository setup validation passed.` when the folder structure, skill metadata, exact runtime file set and SHA-256 hashes, executable Git modes, bootstrap instructions, version metadata, and license are valid.

In VS Code, open **Chat: Open Agent Customizations** and confirm the workspace skills appear without metadata errors. In Copilot CLI, start `copilot` from the repository root and invoke or ask it to use `using-superpowers`.

### Pinned Version and License

The vendored runtime is pinned to upstream release v6.3.0 at commit `b36e0829c6d0140e93cfef2ca599b1b07d4a7797`.

- Source metadata: [`.github/skills/SUPERPOWERS_VERSION`](.github/skills/SUPERPOWERS_VERSION)
- Runtime SHA-256 manifest: [`.github/skills/SUPERPOWERS_SHA256SUMS`](.github/skills/SUPERPOWERS_SHA256SUMS)
- Upstream MIT license: [`.github/skills/LICENSE.superpowers`](.github/skills/LICENSE.superpowers)

### Updating Superpowers

Updates are deliberate and reviewed. To update:

1. Review the newer upstream release and release notes.
2. Replace only the 14 vendored skill directories with the newer release's `skills/` content.
3. Regenerate `SUPERPOWERS_SHA256SUMS` from every file in the 14 reviewed upstream runtime directories using forward-slash relative paths, ordinal path sorting, and lowercase SHA-256 hashes.
4. Preserve the upstream executable Git modes and update the validator's fixed executable path contract if upstream changes it.
5. Refresh `LICENSE.superpowers` if the upstream license changed.
6. Update `SUPERPOWERS_VERSION` with the release, tag object, commit, date, manifest name, and included skill list.
7. Run the repository verifier and smoke-test discovery in VS Code and Copilot CLI.
8. Commit the runtime replacement, manifest, metadata, and any required bootstrap compatibility changes together.

Do not track upstream `main`, use a submodule, or edit vendored skill files for repository-specific behavior.