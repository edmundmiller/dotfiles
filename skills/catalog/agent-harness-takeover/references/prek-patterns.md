# prek Patterns for Agent Harnesses

These are starting points. Match the exact schema and command style to the installed `prek` version before committing.

## Principles
- Keep harness checks in `prek.toml` so agents have one place to inspect.
- Prefer `pass_filenames = false` for whole-repo metadata checks like skill lock sync.
- Prefer changed-file hooks for format/lint when the tool supports it.
- Keep slow checks at pre-push or manual stages.
- Use `AGENT=1` for concise output when supported.

## Python checks

```toml
[hooks.ruff-format]
command = "uv run ruff format --check"
files = "\\.py$"

[hooks.ruff-check]
command = "uv run ruff check"
files = "\\.py$"

[hooks.ty]
command = "uv run ty check"
files = "\\.py$"
stages = ["pre-push"]
```

## JS/TS checks

Use the repo's package manager.

```toml
[hooks.oxlint]
command = "pnpm exec oxlint"
files = "\\.(js|jsx|ts|tsx)$"

[hooks.oxfmt]
command = "pnpm exec oxfmt --check"
files = "\\.(js|jsx|ts|tsx|json|jsonc)$"
```

For Bun repos, use `bunx` or package scripts if that is the repo convention.

```toml
[hooks.oxlint]
command = "bunx oxlint"
files = "\\.(js|jsx|ts|tsx)$"
```

## Nix / polyglot formatting

```toml
[hooks.treefmt]
command = "treefmt --fail-on-change"
pass_filenames = false
```

If the repo already uses flakes, a push-stage check can call:

```toml
[hooks.nix-flake-check]
command = "nix flake check"
pass_filenames = false
stages = ["pre-push"]
```

## Skills lock sync

```toml
[hooks.skills-lock-sync]
command = "./scripts/check-skills-lock"
pass_filenames = false
always_run = true
```

The script should exit 0 when no skill files changed, and exit 1 with a clear message when `.agents/skills/` changed without `skills-lock.json` or the repo's equivalent lock update.

## Large-file guard

```toml
[hooks.large-file-detection]
command = "./scripts/check-large-files"
stages = ["pre-commit"]
```

Allow expected lock files and binary assets. Reject accidental logs, caches, model files, or build artefacts.
