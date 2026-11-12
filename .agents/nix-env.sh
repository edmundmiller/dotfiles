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

nix_bin="$(command -v nix || true)"
if [[ -z "$nix_bin" ]]; then
  # A restored orb can retain the Nix store while its profile links are broken.
  # Prefer the newest version if previous Nix builds are also present.
  nix_bin="$(
    for candidate in "${NIX_STORE_DIR:-/nix/store}"/*-nix-*/bin/nix; do
      [[ -x "$candidate" ]] || continue
      nix_package="${candidate%/bin/nix}"
      printf '%s\t%s\n' "${nix_package##*-nix-}" "$candidate"
    done | LC_ALL=C sort -V | tail -n 1 | cut -f 2-
  )"
  [[ -n "$nix_bin" ]] || return 1
  export PATH="${nix_bin%/nix}:$PATH"
fi
# Resolve a previous ~/.local/bin/nix link before refreshing it.
nix_bin="$(readlink -f "$nix_bin")"
