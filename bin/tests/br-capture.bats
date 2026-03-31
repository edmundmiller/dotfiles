#!/usr/bin/env bats

setup() {
  root_dir=$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)
  script="$root_dir/bin/br-capture"
  mock_bin="$BATS_TEST_TMPDIR/mock-bin"
  pbcopy_log="$BATS_TEST_TMPDIR/pbcopy.log"
  br_log="$BATS_TEST_TMPDIR/br.log"

  mkdir -p "$mock_bin"
  : > "$pbcopy_log"
  : > "$br_log"

  cat > "$mock_bin/gum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

subcommand="${1:-}"
shift || true

case "$subcommand" in
  style)
    exit 0
    ;;
  input)
    printf '%s\n' "${MOCK_GUM_INPUT:-Mock issue}"
    ;;
  spin)
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--" ]]; then
        shift
        break
      fi
      shift
    done
    "$@"
    ;;
  *)
    echo "unexpected gum subcommand: $subcommand" >&2
    exit 64
    ;;
esac
EOF
  chmod +x "$mock_bin/gum"

  cat > "$mock_bin/br" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "create" ]]; then
  echo "unexpected br command: $*" >&2
  exit 64
fi

shift
printf '%s\n' "$*" >> "$BR_LOG"
printf '%s\n' "${MOCK_BR_OUTPUT:-demo-123}"
EOF
  chmod +x "$mock_bin/br"

  cat > "$mock_bin/pbcopy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat > "$PBCOPY_LOG"
EOF
  chmod +x "$mock_bin/pbcopy"

  cat > "$mock_bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$mock_bin/sleep"
}

@test "br-capture copies a generic non-dotfiles issue id in quick mode" {
  repo_dir="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$repo_dir/.beads"

  run env PATH="$mock_bin:$PATH" PBCOPY_LOG="$pbcopy_log" BR_LOG="$br_log" MOCK_GUM_INPUT="Ship fix" MOCK_BR_OUTPUT="acme-7f3k" bash -c 'cd "$0" && "$1" --quick' "$repo_dir" "$script"

  [ "$status" -eq 0 ]
  [ "$(cat "$pbcopy_log")" = "acme-7f3k" ]
  [[ "$(cat "$br_log")" == *"--silent --title Ship fix --type task --priority P2"* ]]
}

@test "br-capture still handles dotfiles issue ids in quick mode" {
  repo_dir="$BATS_TEST_TMPDIR/repo-dotfiles"
  mkdir -p "$repo_dir/.beads"

  run env PATH="$mock_bin:$PATH" PBCOPY_LOG="$pbcopy_log" BR_LOG="$br_log" MOCK_GUM_INPUT="Ship fix" MOCK_BR_OUTPUT="dotfiles-ctxc" bash -c 'cd "$0" && "$1" --quick' "$repo_dir" "$script"

  [ "$status" -eq 0 ]
  [ "$(cat "$pbcopy_log")" = "dotfiles-ctxc" ]
  [[ "$(cat "$br_log")" == *"--silent --title Ship fix --type task --priority P2"* ]]
}
