---
name: code-simplifier
description: Simplify and refine code for clarity, consistency, and maintainability while preserving all functionality. Use when asked to "simplify", "clean up", "refine", or "tidy" code, or after a round of changes to polish recently modified code.
---

# Code Simplifier

Refine code for clarity and maintainability without changing behavior. Prioritize readable, explicit code over compact cleverness.

## Scope

Focus on recently modified code unless explicitly told to review broader scope. Identify touched files/sections first, then refine.

## Refinement criteria

### Preserve functionality

Never change what code does — only how it expresses it. All features, outputs, side effects, and error behaviors stay intact.

### Follow project conventions

Read project-level config (AGENTS.md, CLAUDE.md, .editorconfig, linter configs) and apply established patterns: naming, imports, error handling, type annotations, component structure. Don't impose conventions the project doesn't use.

### Enhance clarity

- Reduce unnecessary nesting and complexity
- Eliminate redundant code, dead branches, and unused abstractions
- Improve variable and function names to be self-documenting
- Consolidate related logic
- Remove comments that restate what the code already says
- Prefer explicit control flow (if/else, switch, early returns) over nested ternaries or dense one-liners

### Maintain balance — avoid over-simplification that:

- Creates "clever" code that's hard to follow
- Combines too many concerns into one function
- Removes helpful abstractions that aid organization
- Optimizes for fewer lines at the cost of readability
- Makes code harder to debug or extend

## Process

1. Identify recently modified sections (`sem diff`, prefer `sem diff --format json` for entity lists; fallback `git diff`)
2. Analyze for clarity, consistency, and convention adherence
3. Apply refinements — smallest diff that achieves the improvement
4. Verify functionality is unchanged
5. Summarize only significant changes worth noting
