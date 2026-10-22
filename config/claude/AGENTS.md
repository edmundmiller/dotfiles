# Claude sources

`settings.json` is a bootstrap template for writable `~/.claude/settings.json`.
`modules/agents/claude/default.nix` preserves runtime-managed hooks such as
Herdr's integration. Pstack uses the Nix-pinned local `cursor-plugins` marketplace and
native plugin loading. Do not restore retired plugin declarations. See
[pstack integration](../../docs/agents/pstack.md).

Shared instructions and modes come from `config/agents/`; global skills come
from `skills/catalog/`. Claude loads the core as `~/.claude/CLAUDE.md` while
project `CLAUDE.md` files remain scoped.

`session-budget-hook.py` is the warning-only session budget hook. It exits 0 on
every path, prints nothing when it has nothing to say, and stays silent on
malformed input. Keep it that way: it must never block a prompt or a turn.
`modules/agents/claude/default.nix` registers it, and template `hooks` entries do
not reach a settings file that already carries runtime hooks.

Use `hey check config/claude modules/agents/claude` for template or wiring
changes. Live `~/.claude/settings.json` is mutable state and is not verification
of the repository template.
