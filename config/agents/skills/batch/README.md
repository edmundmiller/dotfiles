# Batch Skill

Extracted from Claude Code's built-in `/batch` slash command (added v2.1.63).

## Adaptations from original

| Location                    | Original                     | Skill             | Reason                          |
| --------------------------- | ---------------------------- | ----------------- | ------------------------------- |
| User instruction section    | `${T}` (runtime arg)         | Explanatory note  | Skill args handled differently  |
| Phase 1 intro               | `` `${TGT}` ``               | `EnterPlanMode`   | Template var → resolved name    |
| Phase 1, step 2             | `${j0A}`                     | `5`               | Template var → literal value    |
| Phase 1, step 2             | `${W0A}`                     | `30`              | Template var → literal value    |
| Phase 1, step 3             | `` `${kf}` ``                | `AskUserQuestion` | Template var → resolved name    |
| Phase 1, step 5             | `` `${GI}` ``                | `ExitPlanMode`    | Template var → resolved name    |
| Phase 2                     | `` `${uA}` ``                | `Agent`           | Template var → resolved name    |
| Worker instructions         | `${PY4}` (separate variable) | Inlined verbatim  | Template var → literal block    |
| Worker instructions, step 1 | `` `${Hz}` ``                | `Skill`           | Template var → resolved name    |
| Throughout                  | `\u2014`                     | `—`               | Unicode escape → actual em dash |
| Throughout                  | `\u2013`                     | `–`               | Unicode escape → actual en dash |
| Throughout                  | `` \` ``                     | `` ` ``           | JS escape artifact removed      |

Content is otherwise verbatim. Verified 2025-03-06 against v2.1.70.

## Registration metadata

```
description: "Research and plan a large-scale change, then execute it in parallel
              across 5–30 isolated worktree agents that each open a PR."
whenToUse:   "Use when the user wants to make a sweeping, mechanical change across
              many files (migrations, refactors, bulk renames) that can be decomposed
              into independent parallel units."
```

Note: Claude Code appends user arguments as `${T}` inline in the template.
Pi skills handle arguments differently so the User Instruction section uses
an explanatory note instead.
