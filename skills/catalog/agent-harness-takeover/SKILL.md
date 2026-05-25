---
name: agent-harness-takeover
description: Audits and installs an agent-friendly repo harness for taking over a codebase. Use when the user asks to check my agent harness, take over a codebase, add AGENTS.md, set up .agents/skills, skills lock files, prek.toml hooks, uv/pnpm/bun/mise/nix/treefmt tooling, or standardize ruff/ty/oxlint/oxfmt for agents. Do not use for normal feature work unless harness setup or repo onboarding is the task.
---

# Agent Harness Takeover

## Purpose
Create or audit the small set of repo conventions that let coding agents work safely and repeatably: instructions, skills, deterministic checks, package/runtime entry points, and one obvious command path for validation.

## Critical rules
- Put agentic harness enforcement in `prek.toml` when the repo uses or accepts prek. Do not scatter agent-only checks across ad-hoc shell scripts, README ritual, or unmanaged git hooks.
- Preserve the repo's existing toolchain first. Add `uv`, `pnpm`, `bun`, `mise`, Nix flakes, or `treefmt` only when they fit the codebase or the user asks for them.
- Prefer fast, changed-file checks at commit time and heavier whole-repo checks at push/CI time.
- Ask before adding high-blast-radius infrastructure such as a new Nix flake, replacing package managers, or mass-formatting the whole repo.

## When to use
- The user says “check my agent harness,” “take over this codebase,” “make this repo agent-friendly,” or “set up the harness.”
- A repo needs `AGENTS.md`, `.agents/skills/`, skill lock/update checks, or agent-specific validation commands.
- The user wants `prek.toml` to orchestrate lint/type/format hooks.
- The repo should standardize Python checks with `ruff` and `ty`, or JS/TS checks with `oxlint` and `oxfmt`.

## Do not use when
- The request is just to fix a bug or implement a feature and the harness is already adequate.
- The user only wants project documentation, not executable validation.
- The repo has a strict existing platform/runbook where adding another harness would create confusion.

## Inputs expected
### Required
- Target repo path or current working directory.
- Whether the user wants audit-only or actual changes. If obvious from wording, proceed.

### Optional
- Preferred package manager: `uv`, `pnpm`, `bun`, or existing.
- Whether `mise`, Nix flakes, or `treefmt` should be introduced.
- Skills source policy: local `.agents/skills` only, shared catalog, or pinned remote skills.

## Workflow
1. **Inspect and classify the repo before changing it.**
   - Run `python scripts/audit-harness.py <repo>` from this skill when available, or copy the script into a temp location and run it against the target repo. Use `--json` if machine-readable output would help.
   - Read the files the script flags: top-level `AGENTS.md`, `README*`, package manifests, lock files, `pyproject.toml`, `package.json`, `mise.toml`, `flake.nix`, `treefmt.*`, `.pre-commit-config.yaml`, and existing `prek.toml`.
   - Identify languages, existing commands, local skills, locks, and hook layers. Trust current project files over memory or preference.

2. **Decide what the audit missed.**
   - The script is a deterministic first pass, not a substitute for judgement. Check unusual monorepo layouts, generated config, CI-only commands, or project-specific skill sync mechanisms manually.

3. **Choose the least surprising tool layer.**
   - If `prek.toml` exists, extend it.
   - If pre-commit exists and the user asked for prek, migrate only the harness-relevant parts carefully.
   - If neither exists, start from `assets/prek.toml` when adding `prek.toml` as the harness orchestrator. Copy it to the repo root, uncomment only relevant hooks, and run `prek validate-config prek.toml`.
   - Keep package manager commands native: `uv` for Python, `pnpm` or `bun` for JS/TS, Nix/treefmt when already present or explicitly desired.

4. **Write or update `AGENTS.md`.**
   - Include: repo purpose, source layout, package manager, install command, common checks, test commands, coding conventions, and “do not” rules.
   - Keep it operational. Avoid duplicating the whole README.
   - Add scoped `AGENTS.md` only where a subtree truly needs different rules.

5. **Add skills deliberately.**
   - For repo-local skills, create `.agents/skills/<name>/SKILL.md`.
   - Add or update a skill lock file when skills are copied, generated, pinned, or synced from remote sources.
   - Add a `prek.toml` check that fails when skill source changes without the corresponding lock update.

6. **Consolidate harness checks in `prek.toml`.**
   - Put agentic checks there: skill lock sync, AGENTS.md validation, large-file guard, tech-debt report, formatter/linter/typecheck wrappers, generated-file freshness.
   - Prefer commands that work from a fresh checkout and print concise agent-readable failures.
   - Use `AGENT=1` for commands that support agent-friendly output.

7. **Layer language checks.**
   - Python: prefer `uv run ruff format --check`, `uv run ruff check`, and `uv run ty check` when the project is on `uv` or can reasonably use it.
   - JS/TS: prefer existing package scripts; use `pnpm exec oxlint` / `bunx oxlint` and `pnpm exec oxfmt --check` / `bunx oxfmt --check` where appropriate.
   - Nix/mixed repos: prefer `treefmt --fail-on-change` or `nix flake check` when already configured; do not introduce flakes just to run a formatter without asking.

8. **Validate with the repo's normal path.**
   - Run the narrow checks affected by your changes.
   - If hook config changed, run the relevant prek command.
   - If locks changed, verify lock freshness and that repeated runs are idempotent.

9. **Report the takeover state.**
   - Summarize what exists, what changed, how to run checks, and any follow-up risks.
   - Call out intentionally skipped tools, especially if the user mentioned them but the repo did not justify them.

## Validation
- `AGENTS.md` exists and gives agents enough information to install, test, lint, and avoid footguns.
- Harness checks live in `prek.toml` unless the repo has a stronger existing convention.
- Skill files are valid `SKILL.md` files with lean frontmatter.
- Skill sources and lock files cannot drift silently.
- Tool choices match observed project files.
- The final check command has been run or the reason it could not run is explicit.

## Error handling
### Error: existing toolchain conflicts with the requested tool
Action: do not replace it silently. Explain the conflict and either adapt to the existing toolchain or ask before migration.

### Error: no package manager is obvious
Action: use read-only audit output first, then suggest the smallest setup. Ask before adding `uv`, `pnpm`, `bun`, `mise`, or Nix.

### Error: hook is too slow for pre-commit
Action: move it to pre-push/manual stage and keep a changed-file or metadata check at pre-commit.

### Error: formatter rewrites many unrelated files
Action: stop, report the blast radius, and ask before continuing.

## Output contract
Return:
- Harness status: `missing`, `partial`, or `ready`.
- Files created or changed.
- Commands added or standardized.
- Validation run and result.
- Follow-ups, especially high-blast-radius choices that need user approval.

## Examples
### Example 1
User says: “Take over this Python repo and check my agent harness.”
Expected behaviour:
1. Inspect `pyproject.toml`, locks, existing hooks, README, and `AGENTS.md`.
2. Add or update `AGENTS.md`.
3. Add `prek.toml` hooks for `uv run ruff format --check`, `uv run ruff check`, and `uv run ty check` if compatible.
4. Run the new prek checks and report status.

### Example 2
User says: “Make sure our local skills can’t drift.”
Expected behaviour:
1. Inspect `.agents/skills` and existing lock files.
2. Add/update a skills lock mechanism.
3. Add a `prek.toml` check that detects skill changes without lock updates.
4. Validate by running the hook.

### Example 3
User says: “Add oxlint and oxfmt to this TypeScript codebase.”
Expected behaviour:
1. Detect whether the repo uses `pnpm`, `bun`, npm, or yarn.
2. Add package scripts or direct prek hooks using the existing package manager.
3. Avoid changing package managers unless requested.
4. Run the JS/TS checks.

## Supporting files
- `scripts/audit-harness.py`: dependency-free repo audit that replaces the static checklist and reports harness status, detected tools, findings, and next steps.
- `assets/prek.toml`: starter `prek.toml` template for AGENTS.md presence, skill shape validation, and optional language/tool hooks.
- `references/prek-patterns.md`: notes and snippets for adapting `prek.toml` hook patterns.
