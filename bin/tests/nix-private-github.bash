#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
wrapper="${NIX_PRIVATE_GITHUB:-$repo_root/bin/nix-private-github}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf '%s\n' 'test-token' >"$tmp/token"
cat >"$tmp/capture" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$NIX_CONFIG" == *'access-tokens = github.com=test-token'* ]]
[[ "$*" == 'build --flake .#nuc' ]]
printf '%s\n' 'authenticated command ran'
EOF
chmod +x "$tmp/capture"

output="$(GITHUB_NIX_TOKEN_FILE="$tmp/token" "$wrapper" "$tmp/capture" build --flake .#nuc)"
[[ "$output" == 'authenticated command ran' ]]
[[ "$output" != *'test-token'* ]]

if GITHUB_NIX_TOKEN_FILE="$tmp/missing" "$wrapper" true 2>"$tmp/error"; then
  echo 'wrapper unexpectedly accepted a missing token' >&2
  exit 1
fi
grep -Fq 'GitHub token file is missing or empty' "$tmp/error"
