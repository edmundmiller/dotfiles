# Shared Agent Skills

This directory contains global skills in skills.sh format. Each skill lives in its own directory:

```text
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── references/       # Optional: documentation loaded on demand
├── templates/        # Optional: copyable starter files
├── evals/            # Optional: Vitest Evals templates/scenarios
├── scripts/          # Optional: executable helpers
├── assets/           # Optional: static resources
└── ...               # Optional: additional supporting files/directories
```

## Skill Creation Convention

When creating or revising a skill, do not default to a single large `SKILL.md` without considering the full directory shape first.

Before writing content, decide explicitly:

- **`SKILL.md` only** — use when the skill is short, mostly procedural, and under the 500-line guideline.
- **`references/`** — use for longer runbooks, troubleshooting notes, command references, examples, or background documentation that should not be loaded every time.
- **`templates/`** — use for copyable starter files the agent can adapt directly.
- **`evals/`** — use for self-contained skill-eval templates and scenarios, preferably built with `vitest-evals` `describeEval` plus the Pi harness (`@vitest-evals/harness-pi-ai`) when evaluating Pi-compatible agents or skill use.
- **`scripts/`** — use for repeatable validation, generation, migration, or inspection tasks that are actually runnable via an explicit interpreter (`node`, `python3`, `sh`) instead of described manually.
- **`assets/`** — use for sample configs, fixtures, images, fonts, or other static resources.

Keep `SKILL.md` focused on trigger conditions, principles, quick workflows, and pointers to supporting files. Prefer progressive disclosure over putting every detail in the main file.

## Skill Eval Convention

When adding `evals/`, prefer executable templates over prose-only scenarios:

- Keep evals out of `SKILL.md`; point to them from an `Additional Resources` section.
- Use a separate Vitest config and command in the consuming project, e.g. `vitest run --config vitest.evals.config.ts`.
- Use `describeEval` from `vitest-evals` for cases and judges.
- Use `piAiHarness` from `@vitest-evals/harness-pi-ai` when the target is a Pi agent, toolset, or runtime-compatible `run(input, runtime)` entrypoint.
- Keep expected behavior in the eval row; pass judge criteria explicitly where used.
- Include install/config notes beside templates, not in every skill body.

## Format Requirements

Every skill must include `SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: Specific action + key terms + when to use
---
```

Use lowercase hyphenated names. Preserve existing style and organization when editing existing skills.
