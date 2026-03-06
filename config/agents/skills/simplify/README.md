# Simplify Skill

Extracted from Claude Code's built-in `/simplify` slash command (added v2.1.63).

## Adaptations from original

| Location          | Original              | Skill              | Reason                          |
| ----------------- | --------------------- | ------------------ | ------------------------------- |
| Phase 2 intro     | `${uA}`               | `subagent tool`    | Template var → generic          |
| Agent 1, bullet 1 | `${b$}`               | `grep/search`      | Template var → generic          |
| Phase 2 intro     | `in a single message` | `in a single call` | Minor wording                   |
| Throughout        | `\`git diff\``        | `` `git diff` ``   | JS escape artifact removed      |
| Throughout        | `\u2014`              | `—`                | Unicode escape → actual em dash |

Content is otherwise verbatim. Verified 2025-03-06 against v2.1.70.

Note: Claude Code appends user arguments as an `## Additional Focus` section.
Pi skills handle arguments differently so this isn't replicated.
