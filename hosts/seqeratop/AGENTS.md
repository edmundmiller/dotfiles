# Seqeratop

Work nix-darwin host, user/`primaryUser` `edmundmiller`. Hardware hostname
`L19W56QXR4` aliases `darwinConfigurations.Seqeratop`. Package/module selection
is in `default.nix`; Homebrew inventory is in `homebrew.nix`.

- Homebrew supports ARM + Rosetta, auto-migration, and mutable taps.
- QMD is Nix-managed; activation removes stale bun/npm shims.
- Credentials use 1Password/work SSO. This host has no Tailscale access to NUC.
- `hey re` requires interactive sudo; provide an attached terminal for the user
  rather than assuming passwordless activation. Rollback: `hey rollback`.
