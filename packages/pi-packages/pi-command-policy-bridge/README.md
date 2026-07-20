---
purpose: Explain deterministic command and jj-aware VCS enforcement in Pi.
applies_to: pi-command-policy-bridge behavior, policy, and tests.
entrypoint: Read index.ts and run the focused Bun tests.
verification: bun test pi-command-policy-bridge/index.test.ts.
update_when: Supported tools, policy states, or jj mutation rules change.
---

# pi-command-policy-bridge

Deterministic Pi guard for command-bearing tools and jj-aware VCS mutations.

## Command policy

The bridge extracts commands from `bash`, `process.start`, `interactive_shell`, and `herdr_run_in_pane`. It applies `permission.bash` rules from `PI_PERMISSION_SYSTEM_CONFIG_PATH` with last-match-wins wildcard ordering.

- `deny` blocks.
- `ask`, `allow`, and no match run without prompting.
- Unreadable policy remains fail-open for generic commands.

This is a deny-list guardrail, not an LLM classifier or approval UI.

## jj policy

The bridge resolves the tool call's working directory and walks parent directories for `.jj`. Inside a jj repository it blocks Git staging, history, cleanup, patch, pull, and push mutations with a jj-native replacement. Read-only Git inspection remains allowed.

`jj_vcs status` is allowed. `jj_vcs align_push` is blocked because the global `done` skill owns publication and remote-equality proof.

The Pi Nix module deploys this package at `~/.pi/agent/packages/pi-command-policy-bridge`; runtime behavior never depends on the mutable dotfiles checkout.

## Verify

```bash
cd packages/pi-packages
bun test pi-command-policy-bridge/index.test.ts
bun --filter pi-command-policy-bridge typecheck
```
