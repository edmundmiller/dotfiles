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

The bridge extracts commands from `bash`, `exec_command`, `process.start`, `interactive_shell`, `herdr_run_in_pane`, and `herdr_pane.run`. It applies `permission.bash` rules from `PI_PERMISSION_SYSTEM_CONFIG_PATH`. Allow/deny exceptions use last-match-wins ordering, but an allow cannot cancel a matching approval requirement. Wildcards span newlines. `exec_command.workdir` participates in jj repository detection.

`apply_patch` and nonempty `write_stdin` are blocked because they bypass path or command checks. Empty stdin polling remains available. The default package list omits Codex conversion so standard Pi edit/write tools remain available with their path hooks.

- `deny` blocks.
- `ask` requires explicit UI confirmation, even with upstream `yoloMode` enabled. Headless sessions block it.
- `allow` and no match run without prompting.
- Unreadable policy remains fail-open for generic commands.

The repository policy requires approval for `hey` and `mise`, since any project
can define their tasks. The substring patterns deliberately also prompt for
inspection commands and text mentioning those names. They cover literal paths,
quoted names, and compound commands, but are not a shell sandbox against encoded
commands or arbitrary scripts.

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
