## Critical Instructions

- **ALWAYS write over the source file you're editing.** Don't make "\_enhanced", "\_fixed", "\_updated", or "\_v2" versions. We use Git/JJ for version control. If unsure, commit first then overwrite.
- Don't make "dashboards" or figures with a lot of plots in one image file. It's hard for AIs to figure out what all is going on.
- When the user requests code examples, setup or configuration steps, or library/API documentation use context7.

## Python Scripts

Use a uv shebang for Python scripts:

```
#!/usr/bin/env -S uv run --script
#
# /// script
# dependencies = [
#   "requests",
# ]
# [tool.uv]
# exclude-newer = "2025-08-23T00:00:00Z"
# ///
```

It can just be run with `uv run`

## Jujutsu (JJ) Version Control

This project uses jujutsu (jj) for version control, not git. The jj-workflow-plugin provides slash commands and skills that Claude will use automatically when working with commits.

For jj documentation, see `config/claude/plugins/jj-workflow-plugin/README.md`
