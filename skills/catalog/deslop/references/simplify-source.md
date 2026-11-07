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

Original extraction recorded verification against v2.1.70 on 2025-03-06.
The local guide subsequently gained portable tool routing and explicit
delegation boundaries. It is now a reference of `deslop`, not a separate skill.

Note: Claude Code appends user arguments as an `## Additional Focus` section.
Pi skills handle arguments differently so this isn't replicated.

The former `agents/openai.yaml` disabled implicit invocation of the standalone
`simplify` entrypoint. That entrypoint no longer exists; `deslop` now owns
discovery and scope for both requested cleanup and review-readiness.
