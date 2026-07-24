#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
fake_dir=$(mktemp -d)
trap 'rm -rf "$fake_dir"' EXIT

cat >"$fake_dir/nix" <<EOF
#!/bin/sh
touch "$fake_dir/called"
exit 97
EOF
chmod +x "$fake_dir/nix"

PATH="$fake_dir:$PATH" "$repo_root/bin/hey" show >/dev/null 2>&1
test ! -e "$fake_dir/called"
