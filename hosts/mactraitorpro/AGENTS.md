# MacTraitor-Pro

Personal nix-darwin host, user `emiller`. `default.nix` owns enabled modules;
`homebrew.nix` owns casks/formulae. `hey re` is passwordless for this user;
`hey rollback` restores the previous generation.

- Homebrew is ARM-only, Rosetta disabled, with mutable taps and auto-migration.
  Activation does not auto-update, upgrade, or clean up Homebrew.
- QMD comes from `pkgs.llm-agents.qmd`; activation removes stale bun/npm shims.
  Zele comes from `pkgs.my.zele`, not a global Bun install.
- `modules.agents.hermes-local` owns local Hermes profiles. `hey hermes-local`
  rebuilds and checks profile/login/gateway/dispatcher health; NUC is separate.
- Nix-managed open-source tailscaled is the sole tunnel owner. GUI variants and
  the Homebrew formula conflict with it. Login and enabling Tailscale SSH are
  one-time state changes; see [Tailscale](../../docs/tailscale.md).
- Host credentials use 1Password. A new terminal picks up `$DOTFILES_BIN`
  if `hey` is missing after activation.

Workload routing: [workload-placement.md](workload-placement.md).
