#!/usr/bin/env bash
# Shared by setup, resume, and non-interactive login shells.
nix_bin="$(command -v nix || true)"
for nix_env in \
  "${nix_bin%/bin/nix}/etc/profile.d/nix.sh" \
  /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
  "$HOME/.nix-profile/etc/profile.d/nix.sh" \
  "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/etc/profile.d/nix.sh"; do
  if [[ -f "$nix_env" ]]; then
    # shellcheck disable=SC1090
    source "$nix_env"
    break
  fi
done

nix_bin="$(command -v nix)" || return 1
# Resolve a previous ~/.local/bin/nix link before refreshing it.
nix_bin="$(readlink -f "$nix_bin")"
