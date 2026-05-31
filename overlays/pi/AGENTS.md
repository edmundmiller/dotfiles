# Pi Overlay

This directory owns the Nix package override for the Pi binary.

Keep Pi version bumps here when upstream `llm-agents.nix` has not caught up.
Update the tarball hash, `package-lock.json`, `npmDepsHash`, and `npmDeps`
together. If the npm tarball ships `npm-shrinkwrap.json`, keep removing it so
the repo-local lockfile is the source of truth.

Do not put runtime Pi package choices here. Pi extension/package lists belong in
`config/pi/settings.jsonc`, and host/module-driven package injection belongs in
`modules/agents/pi/default.nix`.

Do not patch Pi behavior here unless the change must affect the packaged Pi
binary itself. Prefer public Pi extension points in `config/pi/extensions/` or a
package under `packages/pi-packages/`.
