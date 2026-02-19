---
name: initializing-memory
description: >
  Comprehensive guide for initializing or reorganizing agent memory into a
  deeply hierarchical file structure. Use when running /memory-init, when
  user asks to set up memory, or when memory needs a major reorganization.
  Trigger phrases: "initialize memory", "set up memory", "populate memory",
  "build my memory", "memory init".
---

# Memory Initialization

Initialize persistent memory into a deeply hierarchical structure of 15-25
small, focused files in `.pi/memory/`.

## Target Output

| Metric              | Target                                   |
| ------------------- | ---------------------------------------- |
| Total files         | 15-25 (aim for ~20)                      |
| Max lines per file  | ~40 (split if larger)                    |
| Hierarchy depth     | 2-3 levels using `/` naming              |
| Nesting requirement | Every file MUST be nested under a parent |

**Anti-patterns:**

- ❌ Only 3-5 large files
- ❌ Flat naming (all files at top level)
- ❌ Mega-files with 10+ sections

## Example Target Structure

```
system/
├── human/
│   ├── identity.md
│   ├── context.md
│   └── prefs/
│       ├── communication.md
│       ├── coding_style.md
│       └── workflow.md
├── project/
│   ├── overview.md
│   ├── architecture.md
│   ├── conventions.md
│   ├── gotchas.md
│   └── tooling/
│       ├── testing.md
│       └── linting.md
└── persona/
    ├── role.md
    └── behavior.md
```

## What to Remember

### 1. Procedures (Rules & Workflows)

- "Never commit directly to main"
- "Always run lint before tests"
- "Use conventional commits"

### 2. Preferences (Style & Conventions)

- "Never use try/catch for control flow"
- "Prefer functional components"
- "Use early returns"

### 3. History & Context

- Key refactors, past bugs, architectural decisions
- Project evolution, deprecated patterns

## Workflow

### Step 1: Backup existing memory

Use `memory_backup` tool first.

### Step 2: Ask upfront questions (bundle in one message)

1. **Research depth**: Standard (~5-20 tool calls) or deep (~100+)?
2. **Identity**: Which contributor are you? (check `git shortlog -sn`)
3. **Communication**: Terse or detailed responses?
4. **Rules**: Any rules I should always follow?

### Step 3: Research the project

**Standard research:**

- README, package.json/config files, AGENTS.md, CLAUDE.md
- `git log --oneline -20` — recent history
- `git log --format="%s" -50 | head -20` — commit conventions
- Explore key directories

**Deep research (if chosen):**

- Everything above, plus:
- `git shortlog -sn --all | head -10` — contributors
- `git branch -a` — branching strategy
- Deep dive into architecture, patterns, CI config
- Analyze multiple directories

### Step 4: Create hierarchical file structure

Use `memory_write` for each file. Every file needs:

- Proper frontmatter (description, limit)
- Hierarchical `/` naming
- Focused, single-purpose content

Write findings as you go — don't wait until the end.

### Step 5: Checkpoint

```bash
find .pi/memory/system -name '*.md' | wc -l
```

**If count < 15, split more aggressively.**

### Step 6: Reflect and review

Before finishing, verify:

- [ ] 15-25 files total
- [ ] All files use `/` naming (2-3 levels deep)
- [ ] No file exceeds ~40 lines
- [ ] Each file has one concept
- [ ] Every file has real content (no placeholders)
- [ ] human/ updated with user identity + preferences
- [ ] persona/ updated with behavioral rules
- [ ] No redundancy across files

### Step 7: Commit

```
memory_commit({ message: "init: populate memory with N files from project research" })
```

## Memory Scope Guide

**system/** (always in context):

- Current work context, active preferences
- Project conventions needed constantly
- Agent behavior rules

**reference/** (on-demand via read tool):

- Historical information, archived decisions
- Detailed reference material
- Completed investigations

**Rule of thumb**: Need it every response? → `system/`. Look it up occasionally? → `reference/`.

## Writing Good Memory Files

**Descriptions** are critical — write as if explaining to a future self with zero context:

- ✅ "User's coding style preferences applied to all code I write or review"
- ❌ "Preferences"

**Content** should be:

- Well-organized with headers and bullets
- Scannable at a glance
- Pruned of outdated info
- Concrete and actionable (no "probably" or "maybe")
