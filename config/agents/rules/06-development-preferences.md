---
purpose: General development philosophy and task-completion expectations.
---

# Development Preferences

- Don't stop tasks early due to token limits. Be persistent, complete fully. Save progress to memory if approaching budget.
- First make it work, then make it right, then make it fast.
- Prefer Justfiles over Makefiles.

## Model switching (pi-model-switch)

When `switch_model` is available:

- Intent/requirements discussion: switch to model in `PI_MODEL_SWITCH_INTENT`
- Active implementation/coding: switch to model in `PI_MODEL_SWITCH_CODING`
- After coding is done: switch to model in `PI_MODEL_SWITCH_DONE`

Resolve values from env before switching (for host-specific defaults), e.g. with bash:
`printf '%s\n' "$PI_MODEL_SWITCH_INTENT" "$PI_MODEL_SWITCH_CODING" "$PI_MODEL_SWITCH_DONE"`

If a target is unavailable, run `switch_model action="list"` and choose the closest available equivalent.

## Philosophy

This codebase will outlive you. Every shortcut becomes someone else's burden. Every hack compounds into debt.

Patterns you establish will be copied. Corners you cut will be cut again.

Fight entropy. Leave the codebase better than you found it.
