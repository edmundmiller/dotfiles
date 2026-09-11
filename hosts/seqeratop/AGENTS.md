# Seqeratop

Work nix-darwin host, user/`primaryUser` `edmundmiller`. Hardware hostname
`L19W56QXR4` aliases `darwinConfigurations.Seqeratop`. Package/module selection
is in `default.nix`; Homebrew inventory is in `homebrew.nix`.

- Homebrew supports ARM + Rosetta, auto-migration, and mutable taps.
- QMD is Nix-managed; activation removes stale bun/npm shims.
- Credentials use 1Password/work SSO. This host has no Tailscale access to NUC.
- `hey re` requires interactive sudo; provide an attached terminal for the user
  rather than assuming passwordless activation. Rollback: `hey rollback`.

### Agent observability

`agento11y.nix` installs Grafana agento11y and the Pi package, registers the
native Codex plugin, and merges Cursor's hooks during `hey re`. Versions are
pinned in that file and `packages/agento11y/default.nix`. Other hosts are
unaffected. Codex requires a one-time `/hooks` review to trust the five plugin
hooks after installation; restart existing agent sessions after rebuilding.

`config/agento11y/config.env.tpl` is the source for the private mode-0600
`~/.config/agento11y/config.env`. Activation resolves its 1Password references
with `op inject`; unlock 1Password before rebuilding. The item's `username`
field holds the ingest URL and `credential` holds the token. The tenant and
OTLP endpoint come from its setup notes; update the template if the stack moves.
Capture is metadata-only, with guards and local full-content storage disabled.
The template sets `AGENTO11Y_TAGS=user=edmund` for attribution in the shared stack.

Verify configuration and all three export routes with `agento11y doctor --json`.
Then complete one turn in each client and check Grafana Agent Observability;
the doctor's empty requests prove connectivity, not delivery of client turns.
For removal, run `agento11y cursor uninstall` and
`codex plugin remove agento11y-codex@agento11y`, remove the host import, and
rebuild. The private config can be deleted when no integration uses it.
