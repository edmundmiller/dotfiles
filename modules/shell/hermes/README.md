# Hermes Module

Hermes CLI setup for laptop-first, editor-style use.

## What it does

- installs `hermes` from `llm-agents.nix`
- exports `HERMES_HOME` (default: `$XDG_CONFIG_HOME/hermes`)
- seeds `$HERMES_HOME/SOUL.md` from `config/hermes/SOUL.md`
- seeds the base config from `config/hermes/config.yml`
- materializes provider API keys into `$HERMES_HOME/.env` from 1Password references
- merges any declarative Nix overlays into `$HERMES_HOME/config.yaml`
- preserves user-added config keys that Nix does not manage
- migrates an existing `~/.hermes` directory to the configured `HERMES_HOME`

## Why merge instead of symlink?

Hermes expects `$HERMES_HOME/config.yaml` to stay writable for commands like
`hermes model` and `hermes config set`. This module keeps a declarative base,
but writes the merged result to a normal file so local CLI workflows still
work. Edit `config/hermes/config.yml` to tweak the starter config while the
setup is still evolving.

The module also writes selected provider secrets to `$HERMES_HOME/.env` from
1Password references so Hermes can use the same fallback providers as the
OpenClaw workspace without committing plaintext API keys. OpenAI Codex itself
still authenticates via Hermes/Codex OAuth and can import existing
`~/.codex/auth.json` credentials automatically.
