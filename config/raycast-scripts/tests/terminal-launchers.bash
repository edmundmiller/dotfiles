#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
scripts_dir="$repo_root/config/raycast-scripts"
skhd_config="$repo_root/config/skhd/skhdrc"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/home/.config/tmux"
cat >"$tmp_dir/bin/open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$TERMINAL_LAUNCHER_CAPTURE"
EOF
chmod +x "$tmp_dir/bin/open"

assert_launcher() {
  local script=$1
  shift
  local capture="$tmp_dir/${script%.sh}.args"
  local expected="$tmp_dir/${script%.sh}.expected"

  TERMINAL_LAUNCHER_CAPTURE="$capture" \
    HOME="$tmp_dir/home" \
    PATH="$tmp_dir/bin:/usr/bin:/bin" \
    "$scripts_dir/$script"

  printf '%s\n' -na Ghostty.app --args -e "$@" >"$expected"
  diff -u "$expected" "$capture"
}

assert_launcher open-plain-terminal.sh /bin/zsh -l
assert_launcher open-tmux-terminal.sh tmux new-session -A -s home
assert_launcher open-herdr-terminal.sh "$tmp_dir/home/.config/tmux/open-herdr.sh"

for script in open-plain-terminal.sh open-tmux-terminal.sh open-herdr-terminal.sh; do
  grep -q '^# @raycast.mode silent$' "$scripts_dir/$script"
  test -x "$scripts_dir/$script"
done

grep -Fxq 'cmd - return : "$HOME/Scripts/raycast/open-plain-terminal.sh"' "$skhd_config"
grep -Fxq 'cmd + alt - return : "$HOME/Scripts/raycast/open-tmux-terminal.sh"' "$skhd_config"
grep -Fxq 'cmd + ctrl - return : "$HOME/Scripts/raycast/open-herdr-terminal.sh"' "$skhd_config"

echo "PASS terminal launchers"
