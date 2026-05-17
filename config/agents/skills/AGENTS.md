# Shared Agent Skills

This directory contains global/shared skills in skills.sh format. Each skill lives in its own directory:

```text
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
├── assets/           # Optional: templates, resources
└── ...               # Optional: additional supporting files/directories
```

## Skill Creation Convention

When creating or revising a skill, do not default to a single large `SKILL.md` without considering the full directory shape first.

Before writing content, decide explicitly:

- **`SKILL.md` only** — use when the skill is short, mostly procedural, and under the 500-line guideline.
- **`references/`** — use for longer runbooks, troubleshooting notes, command references, examples, or background documentation that should not be loaded every time.
- **`scripts/`** — use for repeatable validation, generation, migration, or inspection tasks that should be executable instead of described manually.
- **`assets/`** — use for templates, sample configs, prompt skeletons, fixtures, or static resources.

Keep `SKILL.md` focused on trigger conditions, principles, quick workflows, and pointers to supporting files. Prefer progressive disclosure over putting every detail in the main file.

## Format Requirements

Every skill must include `SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: Specific action + key terms + when to use
---
```

Use lowercase hyphenated names. Preserve existing style and organization when editing existing skills.
