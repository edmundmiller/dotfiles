# OpenCode V2 sources

`opencode.jsonc` and `command/` are deployed by `modules/agents/opencode/` to
read-only `~/.config/opencode2/opencode/`. Core instructions and modes come from
`config/agents/`. Shared skills use `~/.agents/skills`; targeted skills use
the compatibility alias `~/.config/opencode/skills`.

The module does not deploy `tool/`, `package.json`, `node_modules/`, or local
plugins. A local plugin needs explicit V2-compatible wiring and registration;
the incompatible V1 plugin tree is not an installation path.

Activation removes the V1 config directory and establishes the V2 compatibility
alias, preserving plugin caches and user-managed content.
