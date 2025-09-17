# Jujutsu (jj) Commands for Claude Code

## Overview

Complete command set for jujutsu workflows, built from the official tutorials and optimized for AI-assisted development.

**Key Resources:**
- [Squash Workflow Tutorial](https://steveklabnik.github.io/jujutsu-tutorial/real-world-workflows/the-squash-workflow.html)
- [Edit Workflow Tutorial](https://steveklabnik.github.io/jujutsu-tutorial/real-world-workflows/the-edit-workflow.html)
- [Jujutsu Tutorial Recap](https://steveklabnik.github.io/jujutsu-tutorial/hello-world/recap.html)

## Two Main Workflows

### The Squash Workflow ⭐ **RECOMMENDED**

**Pattern**: Describe → New → Implement → Squash

Perfect for focused development and AI-assisted coding:

```bash
jj describe -m "feat: implement user auth"  # 1. Describe intent
jj new                                      # 2. Create workspace
# Make your changes...                     # 3. Implement
jj squash                                   # 4. Complete work
```

**Why it's ideal for Claude Code:**
- Maps to task-oriented AI development
- Creates focused, reviewable commits
- Simple linear progression
- Safe by default (everything undoable)

### The Edit Workflow 🔧 **ADVANCED**

**Pattern**: Dynamic navigation and insertion between changes

Best for complex features requiring multiple related commits:

```bash
jj new -m "feat: start feature"           # Start work
jj new -B @ -m "feat: add prerequisite"   # Insert dependency
jj edit <change-id>                       # Navigate to any change
jj next --edit                            # Move through sequence
```

**When to use:**
- Complex features needing multiple commits
- When you discover prerequisites mid-development
- Building layered functionality

## Complete Command Set

### Workflow Commands
- **`@squash-workflow`** - Complete guided squash workflow with intelligent state detection
- **`@edit-workflow`** - Advanced multi-commit workflow for complex features
- **`@new`** - Start new work (with workflow recommendations)
- **`@status`** - Enhanced status with workflow context and next-action suggestions

### Core Operations
- **`@squash`** - Complete current work (final step of squash workflow)
- **`@describe`** - Write commit messages (emphasizes describing intent first)
- **`@split`** - Split mixed changes into focused commits
- **`@navigate`** - Move between and edit changes in history
- **`@abandon`** - Safely discard unwanted changes
- **`@undo`** - Safety net (everything is undoable)
- **`@rebase`** - Reorganize commits (conflicts don't block)

### Key Features

✨ **Intelligent guidance**: Commands analyze your current state and suggest next actions
🧠 **Tutorial-based**: Built from official jujutsu tutorials and best practices
🛡️ **Safety-first**: Emphasizes jj's "everything is undoable" philosophy
🎯 **Workflow-aware**: Commands understand where you are in the squash/edit workflows

## Complete Workflow Examples

### Squash Workflow (Recommended)

**Traditional approach:**
```bash
@describe "feat: implement user authentication"    # 1. Describe intent
@new                                              # 2. Create workspace
# Implement your changes...                      # 3. Build what you described
@squash                                           # 4. Complete work
```

**Guided approach:**
```bash
@squash-workflow "feat: implement user authentication"  # All-in-one guided workflow
# Follow the step-by-step guidance provided
```

**Auto-guidance:**
```bash
@squash-workflow auto    # Analyzes current state and suggests next step
@status                  # Enhanced status with workflow recommendations
```

### Edit Workflow (Advanced)

**For complex multi-commit features:**
```bash
@edit-workflow start                    # Begin complex feature
@edit-workflow insert                   # Add prerequisite changes
@edit-workflow navigate                 # Move between changes
```

### Recovery and Safety

**Everything is undoable:**
```bash
@undo                          # Undo last operation
@undo <operation-id>           # Restore to specific point
@status                        # Get current state and recommendations
```

## Philosophy and Best Practices

### Jujutsu's Core Principles

🛡️ **Everything is undoable**: No operation is ever destructive
🔄 **Automatic rebasing**: Descendants follow when you edit parents
🚀 **Conflicts don't block**: Operations always succeed, conflicts stored safely
🎯 **Describe intent first**: Plan what you'll build before building it
📝 **Focused commits**: Each commit tells one clear story

### For AI-Assisted Development

1. **Start with intent**: Use `@describe` or `@squash-workflow` to clarify goals
2. **Let Claude implement**: AI excels at focused, described tasks
3. **Use safety freely**: `@undo` any mistakes immediately
4. **Split when mixed**: Separate concerns for cleaner history
5. **Complete workflows**: Follow through to polished commits

### Common Patterns

**Quick fixes:**
```bash
@squash-workflow "fix: resolve login timeout"  # Describe → implement → squash
```

**Feature development:**
```bash
@squash-workflow "feat: add user dashboard"    # For focused features
@edit-workflow start                           # For complex multi-commit work
```

**Mixed changes:**
```bash
@split              # Separate concerns
@describe "fix: ..." # Describe each part
@navigate next       # Move to next change
@describe "feat: ..."
```

**Recovery:**
```bash
@undo               # Fix immediate mistakes
@status             # Get guidance on current state
```

## Integration Tips

### With Development Tools
- Run tests before `@squash` to ensure quality
- Use `@split` to separate implementation from tests when reviewing
- Leverage `@status` for project state awareness
- Use `@undo` freely during experimentation

### With Claude Code
- Commands provide contextual guidance based on current state
- Intelligent workflows adapt to where you are in the process
- Safety-first design encourages experimentation
- Tutorial-based approach teaches jj philosophy alongside commands

## Why These Workflows Matter

**For AI Development:**
- Clear intent → better AI understanding
- Focused commits → easier code review
- Safety nets → confident experimentation
- Workflow guidance → consistent patterns

**For Code Quality:**
- Describe-first approach creates intentional commits
- Split functionality keeps changes focused
- Automatic rebasing maintains clean history
- Everything undoable encourages iteration

---

*These commands implement the official jujutsu tutorial workflows, optimized for AI-assisted development with Claude Code.*