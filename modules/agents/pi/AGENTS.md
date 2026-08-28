---
purpose: Route changes to Pi package, runtime config, extensions, and prompts.
applies_to: Files under modules/agents/pi.
entrypoint: Edit default.nix or the matching source under config/pi.
verification: Run the Pi settings test, rebuild, and inspect managed runtime files.
update_when: Pi ownership, generated paths, or runtime behavior changes.
---

# Pi module

This directory owns host wiring for Pi.

Use this module for the wrapped Pi package, Home Manager links, generated
`~/.pi/agent/*` files, secrets preflight, shell integration, and module-gated
package injection. Keep host-dependent choices here, especially packages tied to
tmux, Herdr, MCP, computer-use, git tooling, status UI, context memory, or
Honcho.

Do not edit generated runtime files under `~/.pi/agent/`. They are Nix-managed
symlinks or mutable Pi caches. Edit sources in this repo, then run `hey re`.
The global `~/.pi/agent/AGENTS.md` is the bounded `config/agents/core.md`;
procedures live in discovered skills and Pi prompt templates.

Do not put Pi binary version bumps here. Those belong in `overlays/pi/`.

Do not put broad user package defaults here unless they depend on a Nix module.
Broad Pi defaults belong in `config/pi/settings.jsonc`.

After changing settings generation or module-managed packages, run:

```sh
bash modules/agents/pi/test-settings-json.sh
./bin/hey help
```

A warning-only `pi-runtime-drift` prek pre-push hook checks mutable `~/.pi/agent` state for dirty git extension caches and obvious binary/settings drift. It must never mutate runtime state; fix drift with `hey re` or `pi update --extensions`.
