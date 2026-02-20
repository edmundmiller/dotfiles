---
name: initializing-memory
description: >
  Comprehensive guide for initializing or reorganizing agent memory into a
  deeply hierarchical file structure. Use when running /init, when
  user asks to set up memory, or when memory needs a major reorganization.
  Trigger phrases: "initialize memory", "set up memory", "populate memory",
  "build my memory", "memory init".
---

# Memory Initialization

Initialize persistent memory into a deeply hierarchical structure of 15-25
small, focused files in `.pi/memory/`.

Run `/init` again after major project changes or when you want to re-analyze.

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
reference/
├── README.md
└── history/
    └── decisions.md
```

## What to Remember

### 1. Procedures (Rules & Workflows)

- Commit conventions, branching strategy
- Build/test/lint commands and order
- Review process, CI requirements

### 2. Preferences (Style & Conventions)

- Coding style rules (formatting, patterns, anti-patterns)
- Communication preferences (terse vs detailed)
- Tool preferences (which tools, how to use them)

### 3. History & Context

- Key refactors, past bugs, architectural decisions
- Project evolution, deprecated patterns
- Ongoing work and current priorities

## Workflow

### Step 1: Backup existing memory

Use `memory_backup` tool first if memory already has content.

### Step 2: Ask upfront questions (bundle in one message)

1. **Research depth**: Standard (~5-20 tool calls) or deep (~100+)?
2. **Identity**: Which contributor are you? (check git context from /init)
3. **Related repos**: Other repositories you should know about?
4. **Historical sessions**: If prior agent sessions were detected, ask:
   "I found prior Claude Code / Pi / Codex sessions. Should I analyze them
   to learn your preferences and project context?"
5. **Communication**: Terse or detailed responses?
6. **Rules**: Any rules I should always follow?

**Don't ask things you can find by reading files.** Be autonomous during execution.

### Step 3: Research the project

**Standard research:**

- README, AGENTS.md, CLAUDE.md, CONTRIBUTING.md
- Package manifests (package.json, Cargo.toml, pyproject.toml, go.mod)
- Config files (tsconfig, eslint, prettier, etc.)
- `git log --oneline -20` — recent history
- `git log --format="%s" -50 | head -20` — commit conventions
- Explore key directories and understand structure

**Deep research (if chosen):**

- Everything above, plus:
- `git shortlog -sn --all | head -10` — contributors
- `git branch -a` — branching strategy
- `git log --format="%an <%ae>" | sort -u` — deduplicate contributors by email
- Deep dive into architecture, patterns, CI config
- Analyze multiple source directories
- Read key source files to understand patterns
- Cross-reference findings, resolve ambiguities

**Think like a new team member**: What would you want to know on your first day?

### Step 4: Analyze prior sessions (if approved)

If the user approved session history analysis:

**Claude Code sessions** (`~/.claude/projects/`):

- Each project dir contains session JSONL files
- Look for the project matching the current working directory
- Extract: user preferences, communication style, project knowledge, conventions

**Pi sessions** (`~/.pi/agent/sessions/`):

- Session directories named by project path
- Read recent session files for patterns and preferences

**Codex sessions** (`~/.codex/`):

- `history.jsonl` contains session history
- Extract coding preferences, project context

Focus on extracting:

- **User identity and preferences** → `system/human/`
- **Behavioral rules discovered** → `system/persona/`
- **Project knowledge** → `system/project/`
- **Working patterns** → `system/human/prefs/`

### Step 5: Create hierarchical file structure

Use `memory_write` for each file. Every file needs:

- Proper frontmatter (description, limit)
- Hierarchical `/` naming (e.g. `system/project/tooling/testing.md`)
- Focused, single-purpose content (~40 lines max)

**Write findings as you go — don't wait until the end.**

Memory scope guide:

- **system/** (always in context): Active preferences, project conventions, agent behavior
- **reference/** (on-demand): Historical info, archived decisions, detailed reference

### Step 6: Checkpoint

```bash
find .pi/memory/system -name '*.md' | wc -l
```

**If count < 15, split more aggressively.**

### Step 7: Reflect and review

Before finishing, verify:

- [ ] 15-25 files total
- [ ] All files use `/` naming (2-3 levels deep)
- [ ] No file exceeds ~40 lines
- [ ] Each file has one concept
- [ ] Every file has real content (no placeholders)
- [ ] human/ updated with user identity + preferences
- [ ] persona/ updated with behavioral rules
- [ ] No redundancy across files

Ask the user: "I've completed initialization with N files. Want me to refine anything?"

### Step 8: Commit and sync

```
memory_commit({ message: "init: populate memory with N files from project research" })
```

If a remote is configured, push: `git -C .pi/memory push`

## Writing Good Memory Files

**Descriptions** are critical — write as if explaining to a future self with zero context:

- ✅ "User's coding style preferences applied to all code I write or review"
- ❌ "Preferences"

**Content** should be:

- Well-organized with headers and bullets
- Scannable at a glance
- Pruned of outdated info
- Concrete and actionable
