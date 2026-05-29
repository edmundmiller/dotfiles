# pi-command-policy-bridge

Applies the existing `pi-permissions.jsonc` bash command policy to command-bearing extension tools that spawn shell commands, currently:

- `process` with `action: "start"`
- `interactive_shell` with `command`
- `herdr_run_in_pane` with `command`

This lets those tools be allowed at the tool level while preserving deterministic bash-policy guardrails for dangerous commands.

Also adds jj-aware VCS guardrails:

- Blocks Git mutating commands when running inside a jj repo (`.jj/` present) with concrete jj remediation guidance.
- Requires explicit approval for mutating jj tool actions:
  - `jj_vcs.align_push`
  - `jj_stack_pr_flow.{publish,sync,close,init}`
  - `jj_workspace.{create,squash,delete}`

## Behavior

For supported tool calls, the extension extracts the embedded command and evaluates it against `bash` rules in `pi-permissions.jsonc` using last-match-wins wildcard ordering:

- `deny` blocks the tool call
- `ask` prompts the user
- `allow` lets the tool call proceed
- no matching rule prompts the user

This is intentionally deterministic; it is not an LLM classifier.
