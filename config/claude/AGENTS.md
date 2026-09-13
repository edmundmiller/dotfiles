# Claude sources

`settings.json` is a bootstrap template for writable `~/.claude/settings.json`.
`modules/agents/claude/default.nix` preserves runtime-managed hooks such as
Herdr's integration. Claude Code plugins and marketplace declarations are retired.

Shared instructions and modes come from `config/agents/`; global skills come
from `skills/catalog/`. Claude loads the core as `~/.claude/CLAUDE.md` while
project `CLAUDE.md` files remain scoped.
