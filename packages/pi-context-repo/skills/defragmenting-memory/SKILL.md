---
name: defragmenting-memory
description: >
  Decomposes and reorganizes agent memory files into focused, single-purpose
  components. Use when memory has large multi-topic blocks, redundancy, or
  poor organization. Trigger phrases: "defrag memory", "reorganize memory",
  "clean up memory files", "split memory blocks".
---

# Memory Defragmentation

> **Requires context-repo extension** with memory at `.pi/memory/`

Splits large, multi-purpose memory blocks into focused single-purpose files
with hierarchical `/` naming.

## When to Use

- Memory blocks have redundant information
- Files mix multiple unrelated topics
- Memory lacks structure (walls of text)
- After major project milestones
- Every 50-100 conversation turns

## Workflow

### Step 1: Backup (MANDATORY)

Use the `memory_backup` tool before proceeding. This is your safety net.

### Step 2: Analyze Current Memory

```bash
find .pi/memory -name '*.md' | while read f; do
  echo "=== $f ($(wc -l < "$f") lines) ==="
  head -5 "$f"
  echo
done
```

For each file, determine:

- Does it serve 2+ distinct purposes? → needs splitting
- Is it >40 lines? → candidate for splitting
- Does it overlap with another file? → consolidate

### Step 3: Decompose

Split multi-purpose blocks into focused files using hierarchical naming:

**Before:**

```
system/project.md  (80 lines mixing overview, tooling, conventions, gotchas)
```

**After:**

```
system/project/overview.md
system/project/tooling.md
system/project/conventions.md
system/project/gotchas.md
```

Use `memory_write` for each new file, then delete the original:

```bash
rm .pi/memory/system/project.md
```

### Step 4: Clean Up

For each file (new and existing):

- Add markdown structure (headers, bullets)
- Remove redundancy across files
- Remove speculation ("probably", "maybe")
- Keep only actionable, concrete information
- Resolve contradictions

### Step 5: Commit

```
memory_commit({ message: "refactor: defragment memory — split N files into M focused blocks" })
```

### Step 6: Report

Provide a summary:

- Files created (new decomposed blocks)
- Files modified (what changed)
- Files deleted (if any, explain why)
- Before/after file counts and line counts

## Evaluation Criteria

1. **DECOMPOSITION** — Each file has ONE clear purpose described by its filename
2. **STRUCTURE** — Headers, bullets, scannable at a glance
3. **CONCISENESS** — No redundancy, no speculation, only unique value
4. **CLARITY** — Contradictions resolved, plain language, actionable
5. **ORGANIZATION** — General to specific within files, important first

## Naming Rules

- Use `/` hierarchy: `project/tooling/testing.md` (not `project-tooling-testing.md`)
- 2-3 levels of nesting
- ~40 lines max per file
- Descriptive frontmatter descriptions

## What to Preserve

- User preferences (sacred — never delete)
- Project conventions discovered through experience
- Important context for future sessions
- Learnings from past mistakes

## Rollback

If something goes wrong:

```
/memory-backups     # list available backups
/memory-restore <backup-name>
```
