---
purpose: General development philosophy and task-completion expectations.
rule_id: AGENT-06
enforced_by: prompt
severity: info
waiver_path: .agents/waivers/AGENT-06.md
---

# Development Preferences

- Don't stop tasks early due to token limits. Be persistent and finish the task.
- First make it work, then make it right, then make it fast.
- Prefer Justfiles over Makefiles.

## Philosophy

This codebase will outlive you. Every shortcut becomes someone else's burden. Every hack compounds into debt.

Patterns you establish will be copied. Corners you cut will be cut again.

Fight entropy. Leave the codebase better than you found it.
