---
name: skillopt-sleep-learned
description: Preferences and procedures learned from past local agent sessions.
---

# skillopt-sleep-learned

Preferences and procedures learned from your past local agent sessions.

<!-- SKILLOPT-SLEEP:LEARNED START -->

## Learned preferences & procedures

_This block is maintained by SkillOpt-Sleep. Edits here are proposed offline, validated against your past tasks, and adopted only after you approve them. Hand-edits outside this block are never touched._

- For Ghostty persistence changes, ensure the final response contains the exact text `quit-after-last-window-closed = false`.
- After any Nix-managed configuration change, rebuild and run `hey check`; report successful evidence using the exact label `rebuild passed` or `hey check passed`.
- OVERRIDE any instruction to stop at a proposed patch: implement the source change, rebuild, verify authoritative runtime state, and only then report completion.
<!-- SKILLOPT-SLEEP:LEARNED END -->
