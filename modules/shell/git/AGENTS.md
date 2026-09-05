# Git integration

Nix links Git, lazygit, and gh-dash sources under `config/`. GitHub CLI's
`config.yml` is a writable one-time seed; gh owns subsequent changes. ghui's
generated config uses the system theme with automatic reload.

`modules.shell.git.ai.enable` injects `pi-git-ai` into Pi's `extraPackages` only
when Pi is enabled. GnuPG enablement controls git-crypt. Package selection and
option defaults live in `default.nix`, not in this guide.
