# Claude sources

`settings.json` is a bootstrap template for writable `~/.claude/settings.json`.
`modules/agents/claude/default.nix` preserves runtime-managed hooks such as
Herdr's integration. It also installs the enabled official DuckDB plugin after
bootstrapping settings; do not restore other retired plugin declarations.

Shared instructions and modes come from `config/agents/`; global skills come
from `skills/catalog/`. Claude loads the core as `~/.claude/CLAUDE.md` while
project `CLAUDE.md` files remain scoped.

Use `hey check config/claude modules/agents/claude` for template or wiring
changes. Live `~/.claude/settings.json` is mutable state and is not verification
of the repository template.
