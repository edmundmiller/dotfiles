# Bugster Module

NixOS service module for Bugster — syncs issues from GitHub/Jira/Linear into Obsidian TaskNotes via dagster + dlt.

## Key Facts

- **Runs as dagster code location** on gRPC port 4000
- **Python deps via uv** — `uv sync --frozen` at service start, not Nix-packaged
- **Private repo** — cloned via SSH (emiller's key) to `/var/lib/dagster/bugster`
- **Config** — `bugster.toml` generated from Nix options, tokens via `${ENV_VAR}` expansion
- **Vault access** — dagster user gets ACL write perms on TaskNotes dir
- **Depends on** dagster module (auto-enabled), postgresql

## Services

- `bugster-setup` — oneshot, git clone/pull + config + ACLs (runs as root)
- `dagster-code-bugster` — gRPC code server via dagster module's code location support

## Files

- `default.nix` — module definition
- `README.md` — human docs
- `AGENTS.md` — this file

## Related

- `modules/services/dagster/default.nix` — parent dagster module
- `packages/dagster.nix` — dagster package (webserver/daemon, NOT used by code server)
- `hosts/nuc/secrets/bugster-env.age` — API tokens
- `~/src/personal/bugster` — source repo
