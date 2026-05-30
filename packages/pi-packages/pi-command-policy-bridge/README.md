# pi-command-policy-bridge

Applies the existing `pi-permissions.jsonc` bash command policy to command-bearing extension tools that spawn shell commands, currently:

- `process` with `action: "start"`
- `interactive_shell` with `command`
- `herdr_run_in_pane` with `command`

This lets those tools be allowed at the tool level while preserving deterministic bash-policy deny rules for commands you never want agents to run.

## Behavior

For supported tool calls, the extension extracts the embedded command and evaluates it against `bash` rules in `pi-permissions.jsonc` using last-match-wins wildcard ordering:

- `deny` blocks the tool call
- `ask` is treated as `allow`
- `allow` lets the tool call proceed
- no matching rule allows the tool call

This package is intentionally a deny-list guardrail, not an approval system or LLM danger classifier. If a command is not explicitly denied, it runs without prompting.

The deny list can include both:

- dangerous commands: bypass safety rails, mutate host state, or weaken repo integrity
- foot-guns: likely to hang, open an interactive editor, or wedge the agent session
