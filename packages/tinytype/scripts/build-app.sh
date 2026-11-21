#!/usr/bin/env bash
# Downloads build inputs, builds locally, and leaves activation to the user.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "Usage: build-app.sh /absolute/path/to/TinyType.app" >&2
  exit 2
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
case "$1" in
/*.app) ;;
*)
  echo "TinyType needs an absolute output path ending in .app" >&2
  exit 2
  ;;
esac
if [ -e "$1" ]; then
  echo "TinyType output already exists: $1" >&2
  exit 1
fi
# Use the same pinned compiler as default.nix, not the older host cargo/rustc.
toolchains="$(TINYTYPE_FLAKE_ROOT="$(cd "$root/../.." && pwd)" nix build \
  --no-link --no-write-lock-file --print-out-paths --impure --expr '
    let
      flake = builtins.getFlake (builtins.getEnv "TINYTYPE_FLAKE_ROOT");
      packages = import flake.inputs.nixpkgs-jj.outPath {
        system = builtins.currentSystem;
        config = {};
        overlays = [];
      };
    in [ packages.cargo packages.rustc ]
  ')"
while IFS= read -r toolchain; do export PATH="$toolchain/bin:$PATH"; done <<< "$toolchains"
export RUSTC="$(command -v rustc)"
export CC=/usr/bin/clang CXX=/usr/bin/clang++ AR=/usr/bin/ar
export CARGO_TARGET_AARCH64_APPLE_DARWIN_LINKER=/usr/bin/clang
export MACOSX_DEPLOYMENT_TARGET=15.0
export DEVELOPER_DIR="$(/usr/bin/xcode-select -p)"
export SDKROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP=none
profile="${TINYTYPE_PROFILE:-dev}"
cargo build --manifest-path "$root/Cargo.toml" --locked --profile "$profile"
binary_profile="$profile"
if [ "$profile" = dev ]; then binary_profile=debug; fi
/usr/bin/xcrun swiftc -O -parse-as-library "$root/native/FocusedText.swift" \
  "$root/native/AccessibilityGuide.swift" -o "$root/target/focused-text"
npm --prefix "$root/engine" ci --ignore-scripts --no-audit --no-fund
node "$root/engine/download-models.mjs" "$root/engine/.models"
bash "$root/scripts/bundle-app.sh" "$root/target/$binary_profile/tinytype" \
  "$root/target/focused-text" "$(command -v node)" "$root/engine" "$root/engine/.models" "$1"
