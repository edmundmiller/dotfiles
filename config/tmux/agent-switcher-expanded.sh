#!/usr/bin/env bash
set -euo pipefail

status_dir="$HOME/.cache/tmux-agent-status"
plugin_root=""

# Prefer explicit plugin path when available.
if cmd="$(tmux show -gv @agent-sidebar-toggle-cmd 2>/dev/null)" && [ -n "$cmd" ]; then
  plugin_root="${cmd%/scripts/sidebar-toggle.sh}"
fi

# Fallback: parse the bound S key popup command for hook-based-switcher.sh path.
if [ -z "$plugin_root" ]; then
  s_bind="$(tmux list-keys | grep '^bind-key    -T prefix' | grep 'hook-based-switcher.sh' | head -1 || true)"
  if [ -n "$s_bind" ]; then
    plugin_root="$(printf '%s' "$s_bind" | sed -E 's|.* (/nix/store/[^ ]+)/scripts/hook-based-switcher.sh.*|\1|')"
  fi
fi

if [[ -z "$plugin_root" || ! -d "$plugin_root/scripts" ]]; then
  echo "tmux-agent-status plugin path not found" >&2
  exit 1
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/tmux-agent-switcher.XXXXXX")"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

cp -R "$plugin_root/scripts" "$tmpdir/scripts"
script="$tmpdir/scripts/hook-based-switcher.sh"

python3 - "$script" "$status_dir" <<'PY'
import sys
from pathlib import Path

script = Path(sys.argv[1])
status_dir = sys.argv[2]
text = script.read_text()
needle = 'configure_state_dir "$state_dir"\n'
insert = f'''configure_state_dir "$state_dir"

# Auto-expand active sessions in popup (working/wait/ask)
if [ -d "{status_dir}" ]; then
  : > "$state_dir/expanded_sessions"
  for sf in "{status_dir}"/*.status; do
    [ -f "$sf" ] || continue
    session="${{sf##*/}}"
    session="${{session%.status}}"
    session="${{session%-remote}}"
    st="$(cat "$sf" 2>/dev/null || true)"
    case "$st" in
      working|wait|ask)
        printf '%s\n' "$session" >> "$state_dir/expanded_sessions"
        ;;
    esac
  done
  sort -u -o "$state_dir/expanded_sessions" "$state_dir/expanded_sessions" 2>/dev/null || true
fi
'''
if needle not in text:
    raise SystemExit('expected insertion point not found')
script.write_text(text.replace(needle, insert, 1))
PY

exec "$script"
