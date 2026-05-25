# pi-command-policy-bridge

Applies the existing `pi-permissions.jsonc` bash command policy to command-bearing extension tools that spawn shell commands, currently:

- `process` with `action: "start"`
- `interactive_shell` with `command`
- `herdr_run_in_pane` with `command`

This lets those tools be allowed at the tool level while preserving deterministic bash-policy guardrails for dangerous commands.

## Behavior

For supported tool calls, the extension extracts the embedded command and evaluates it against `bash` rules in `pi-permissions.jsonc` using last-match-wins wildcard ordering:

- `deny` blocks the tool call
- `ask` prompts the user
- `allow` lets the tool call proceed
- no matching rule prompts the user

This is intentionally deterministic; it is not an LLM classifier.
