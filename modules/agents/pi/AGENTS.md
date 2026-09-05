# Pi module

Owns the wrapped package, Home Manager links, generated runtime files, secrets
preflight, shell integration, and module-gated package injection. General Pi
settings/packages belong in `config/pi/settings.jsonc`; binary pins belong in
`overlays/pi/`. The installed core is `config/agents/core.md`.

Runtime files under `~/.pi/agent` include managed symlinks and mutable Pi caches;
change the repository source for durable defaults. Settings/package-generation
check: `bash modules/agents/pi/test-settings-json.sh`.

`pi-runtime-drift` is a warning-only, read-only pre-push hook. Authorized repairs
use `hey re` or `pi update --extensions`; the hook does not repair state itself.
