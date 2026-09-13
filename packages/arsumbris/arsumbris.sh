#!/usr/bin/env bash
# The writable sibling checkout layout is part of upstream's runtime contract.
set -euo pipefail

case "${1:---help}" in
  --help|-h)
    echo 'Usage: arsumbris setup | dev'
    echo 'setup: clone/build 0.0.1-alpha in ~/arsumbris and seed ~/.arsumbris.'
    echo 'dev: launch the installed host with the pinned Node/pnpm toolchain.'
    echo 'Setup downloads and executes upstream code. Ars Umbris has no sandbox.'
    exit 0
    ;;
  setup|dev) ;;
  *) echo 'arsumbris: expected setup or dev (see --help)' >&2; exit 2 ;;
esac
if [[ $# -ne 1 ]]; then
  echo 'arsumbris: expected exactly one subcommand' >&2
  exit 2
fi

root="$HOME/arsumbris"
device="$HOME/.arsumbris"
export PATH="$device/engine/bin:$PATH"

if [[ "$1" == dev ]]; then
  if [[ ! -f "$root/au-host/package.json" ]]; then
    echo 'arsumbris: run arsumbris setup first' >&2
    exit 1
  fi
  cd "$root/au-host"
  exec pnpm dev
fi

if [[ "$(uname -s)" != Darwin ]] || ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  echo 'arsumbris: setup requires macOS and Xcode Command Line Tools (xcode-select --install)' >&2
  exit 1
fi

# Nix Python's libffi callback allocation crashes on macOS 27 during node-gyp.
# The already-required Command Line Tools Python can build node-pty successfully.
export NODE_GYP_FORCE_PYTHON=/usr/bin/python3

version=0.0.1-alpha
# INSTALL.md and the config seeder are pinned together; parts use the release tag.
entry_revision=a9f6cceedb191b8504443222d55d3106f9f36ba9
repos=(
  arsumbris au-engine au-engine-sdk au-type-system au-host
  au-mcp au-mcp-sdk au-mcp-core au-mcp-adapter-cc au-mcp-adapter-codex
  au-type-codegen au-base-types au-weave au-agent-guides au-rules
  au-writing-style au-skills au-govern au-competency au-ingest
  au-tree-research au-defaults
)

# Inspect every existing destination before cloning or building anything. Never
# reset, pull, switch branches, or overwrite a user's existing checkout.
for repo in "${repos[@]}"; do
  destination="$root/$repo"
  revision="$version"
  if [[ "$repo" == arsumbris ]]; then revision="$entry_revision"; fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ -L "$destination" || ! -d "$destination/.git" ]] \
      || [[ "$(git -C "$destination" remote get-url origin)" != "https://github.com/arsumbris/$repo.git" ]] \
      || [[ "$(git -C "$destination" rev-parse HEAD)" != "$(git -C "$destination" rev-parse "$revision^{commit}")" ]] \
      || [[ -n "$(git -C "$destination" status --porcelain)" ]]; then
      echo "arsumbris: preserving $destination; expected a clean upstream checkout at $revision" >&2
      exit 1
    fi
  fi
done

mkdir -p "$root" "$device"
for repo in "${repos[@]}"; do
  destination="$root/$repo"
  if [[ -e "$destination" ]]; then continue; fi
  if [[ "$repo" == arsumbris ]]; then
    git clone --no-checkout "https://github.com/arsumbris/$repo.git" "$destination"
    git -C "$destination" checkout --detach "$entry_revision"
  else
    git clone --branch "$version" --depth 1 "https://github.com/arsumbris/$repo.git" "$destination"
  fi
done

(
  cd "$root/au-engine"
  cargo install --locked --path crates/au-cli --root "$device/engine"
)
for repo in au-engine-sdk au-mcp au-mcp-sdk au-mcp-core au-mcp-adapter-cc au-mcp-adapter-codex au-type-codegen au-host; do
  (cd "$root/$repo" && pnpm install --frozen-lockfile)
done
(
  cd "$root/au-host"
  pnpm --filter app exec install-electron
  pnpm --filter app rebuild:native
  pnpm -r build
  pnpm --filter app build:shared-deps
)
python3 "$root/arsumbris/scripts/seed-device-config.py" --root "$root" --au-path "$device/engine/bin/au"
python3 "$root/arsumbris/scripts/seed-device-config.py" --root "$root" --au-path "$device/engine/bin/au" --write

echo 'Ars Umbris setup complete. Launch it yourself with: arsumbris dev'
