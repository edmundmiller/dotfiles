# Pin OpenClaw gateway to release v2026.3.22 + keep local dependency workaround.
# Remove the sourceInfo override once nix-openclaw updates its pin.
#
# Bug: baileys@7.0.0-rc.9 imports `long` (ESM) but pnpm strict mode
# doesn't hoist it into baileys' scoped node_modules/. The package
# exists in .pnpm/long@5.3.2/ but Node can't resolve it at runtime,
# causing "Cannot find package 'long'" on incoming messages.
#
# This mirrors the existing workarounds in nix-openclaw's
# gateway-install.sh (strip-ansi, combined-stream, hasown) — find
# the package in the pnpm store and symlink it where it's needed.
#
# Remove once upstream nix-openclaw adds this to gateway-install.sh.
# Tracking: dotfiles-2sc7
_final: prev:
let
  sourceInfo = {
    owner = "openclaw";
    repo = "openclaw";
    rev = "e7d11f6c33e223a0dd8a21cfe01076bd76cef87a"; # v2026.3.22
    hash = "sha256-Dx4Khi0FxpC+ykiH/bXlX9cctDAHngBDCttV46iIvnQ=";
    pnpmDepsHash = "sha256-B5qoJvp+FxsvnEL5UONS9FPAChh4jG236R1FvQI8I2I=";
  };

  pinnedGateway = prev.openclaw-gateway.override {
    inherit sourceInfo;
    inherit (sourceInfo) pnpmDepsHash;
  };
in
{
  openclaw-gateway = pinnedGateway.overrideAttrs (old: {
    installPhase = old.installPhase + ''

      # -- local fix: link missing `long` dep for baileys (dotfiles-2sc7) --
      long_src="$(find "$out/lib/openclaw/node_modules/.pnpm" \
        -path "*/long@*/node_modules/long" -print | head -n 1)"
      baileys_pkgs="$(find "$out/lib/openclaw/node_modules/.pnpm" \
        -path "*/node_modules/@whiskeysockets/baileys" -print)"

      if [ -n "$long_src" ]; then
        # Top-level node_modules fallback
        if [ ! -e "$out/lib/openclaw/node_modules/long" ]; then
          ln -s "$long_src" "$out/lib/openclaw/node_modules/long"
        fi
        # Scoped into each baileys instance
        if [ -n "$baileys_pkgs" ]; then
          for pkg in $baileys_pkgs; do
            if [ ! -e "$pkg/node_modules/long" ]; then
              mkdir -p "$pkg/node_modules"
              ln -s "$long_src" "$pkg/node_modules/long"
            fi
          done
        fi
      fi
    '';
  });
}
