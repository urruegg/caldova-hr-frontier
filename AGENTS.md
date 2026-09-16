# Agent Instructions

## Superpowers Workflow

- This repository bundles agent skills in `.github/skills/`; no machine-level Superpowers installation is required.
- Before responding or taking any action, load and follow the `using-superpowers` skill from `.github/skills/using-superpowers/SKILL.md`.
- Check for a relevant skill before clarifying, exploring, planning, implementing, debugging, reviewing, or claiming completion.
- When a skill applies, follow it as the controlling workflow. Process skills determine the approach before implementation skills are used.
- User and repository instructions take precedence over a conflicting skill instruction.
- Keep vendored Superpowers files unchanged. Put repository-specific guidance in this file, `.github/copilot-instructions.md`, `.github/instructions/`, or a separate project-owned skill.
