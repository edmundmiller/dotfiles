# Global OpenCode Rules

## Critical Instructions

- In all interactions, plans, and commit messages, be extremely concise and sacrifice grammar for the sake of concision.
- **ALWAYS write over the source file you're editing.** Don't make "\_enhanced", "\_fixed", "\_updated", or "\_v2" versions. We use JJ for version control. If unsure, commit first then overwrite.
- Don't make "dashboards" or figures with a lot of plots in one image file. It's hard for AIs to figure out what all is going on.
- When the user requests code examples, setup or configuration steps, or library/API documentation, search the web for current docs.

## Version Control

This repo uses jujutsu (jj) for version control, not git.

### JJ Quick Reference

- `jj status` - Show working copy status
- `jj log` - Show commit history
- `jj describe -m "message"` - Set commit message
- `jj new` - Create new empty commit
- `jj squash` - Move changes to parent commit
- `jj split -p <file>` - Split commit by file

**Important:** Never run jj commands that open an editor (like bare `jj describe` or `jj split`). Always use `-m` flag or `JJ_EDITOR="echo 'message'"` prefix.

## Code Search

You are operating in an environment where `ast-grep` is installed. For any code search that requires understanding of syntax or code structure, you should default to using `ast-grep --lang [language] -p '<pattern>'`. Adjust the `--lang` flag as needed for the specific programming language.

## Testing Philosophy

Write two kinds of tests:

1. **Spec tests** - Document intended feature behavior (what the feature should do)
2. **Regression tests** - Reproduce and prevent actual bugs that occurred

**Skip:** Hypothetical edge cases and exhaustive coverage that bloat context windows.

Tests are living documentation of what should work and what broke before, not comprehensive safety nets for every possibility.

## Python Scripts

Use UV shebang for standalone Python scripts:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
```

## Agent Context Engineering

### AGENTS.md Files

When working in a project, consider creating `AGENTS.md` files in subdirectories to provide context for future agents. See https://agents.md/ for the specification.

- Place AGENTS.md in directories with complex/non-obvious patterns
- Document domain-specific conventions, gotchas, preferred approaches
- Keep concise - agents have limited context windows

### Skills

When you notice repetitive patterns in user workflows, suggest creating a skill to automate them. Skills live in `config/opencode/skills/` and follow the format at https://agentskills.io/

Signs a skill would help:
- User asks for same type of task repeatedly
- Multi-step workflow with consistent structure
- Domain-specific knowledge that could be encoded
