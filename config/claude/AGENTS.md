# Claude sources

`settings.json` is a bootstrap template for writable `~/.claude/settings.json`.
`modules/agents/claude/default.nix` preserves runtime-managed hooks such as
Herdr's integration, and plugin entries that are absent from this template.
Template plugin keys win. Pstack uses the Nix-pinned local `cursor-plugins` marketplace and
native plugin loading. Do not restore retired plugin declarations. The bootstrap
drops those entries when an old settings file still has them. See
[pstack integration](../../docs/agents/pstack.md).

Shared instructions and modes come from `config/agents/`; global skills come
from `skills/catalog/`. Claude loads the core as `~/.claude/CLAUDE.md` while
project `CLAUDE.md` files remain scoped.

Use `hey check config/claude modules/agents/claude` for template or wiring
changes. Live `~/.claude/settings.json` is mutable state and is not verification
of the repository template.
