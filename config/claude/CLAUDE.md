## Critical Instructions

- **ALWAYS write over the source file you're editing.** Don't make "\_enhanced", "\_fixed", "\_updated", or "\_v2" versions. We use JJ for version control. If unsure, commit first then overwrite.
- Don't make "dashboards" or figures with a lot of plots in one image file. It's hard for AIs to figure out what all is going on.
- When the user requests code examples, setup or configuration steps, or library/API documentation use context7.

## Version Control

This repo uses jujutsu (jj) for version control, not git. Use `/jj:*` commands or `jj:*` skills from the jj plugin when working with commits.

See `config/claude/plugins/jj/README.md` for detailed jj documentation.

## Code Search

You are operating in an environment where `ast-grep` is installed. For any code search that requires understanding of syntax or code structure, you should default to using `ast-grep --lang [language] -p '<pattern>'`. Adjust the `--lang` flag as needed for the specific programming language. Avoid using text-only search tools unless a plain-text search is explicitly requested.

## Testing Philosophy

Write two kinds of tests:

1. **Spec tests** - Document intended feature behavior (what the feature should do)
2. **Regression tests** - Reproduce and prevent actual bugs that occurred

**Skip:** Hypothetical edge cases and exhaustive coverage that bloat context windows.

Tests are living documentation of what should work and what broke before, not comprehensive safety nets for every possibility.

## Skills

Specialized guidance is available in `config/claude/skills/`:

- **python-scripts**: UV shebang templates for standalone Python scripts
- **test-claude-hooks**: Testing patterns for Claude Code plugin hooks with pytest
- Your context window will be automatically compacted as it approaches its limit, allowing you to continue working indefinitely from where you left off. Therefore, do not stop tasks early due to token budget concerns. As you approach your token budget limit, save your current progress and state to memory before the context window refreshes. Always be as persistent and autonomous as possible and complete tasks fully, even if the end of your budget is approaching. Never artificially stop any task early regardless of the context remaining.